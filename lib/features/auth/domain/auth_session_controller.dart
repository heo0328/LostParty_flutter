import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'backend_auth_models.dart';
import 'google_authentication_gateway.dart';

enum AuthStatus {
  restoring,
  guest,
  authenticating,
  signedIn,
  unavailable,
  reauthenticationRequired,
}

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({
    required BackendAuthApi api,
    required GoogleAuthenticationGateway google,
    required AuthSessionStore store,
    required this.serverClientId,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
  }) : _api = api,
       _google = google,
       _store = store,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _delay = delay ?? Future<void>.delayed;
  final BackendAuthApi _api;
  final GoogleAuthenticationGateway _google;
  final AuthSessionStore _store;
  final String serverClientId;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;
  AuthStatus status = AuthStatus.restoring;
  String? errorCode;
  AuthUser? _user;
  AuthTokens? _tokens;
  _PendingRefresh? _pending;
  Future<void>? _refreshFlight;
  Future<void> _storageQueue = Future<void>.value();
  int _epoch = 0;
  bool _disposed = false;
  bool get isAuthenticated =>
      status == AuthStatus.signedIn && _user?.status == 'active';
  bool get isBusy =>
      status == AuthStatus.restoring || status == AuthStatus.authenticating;
  String? get userId => _user?.id;
  bool get remember => _tokens?.session.remember ?? false;

  void _emit(AuthStatus value, [String? code]) {
    if (_disposed) return;
    status = value;
    errorCode = code;
    notifyListeners();
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<void> restore() async {
    final epoch = ++_epoch;
    _emit(AuthStatus.restoring);
    try {
      final raw = await _store.read();
      if (!_current(epoch)) return;
      if (raw == null) {
        _emit(AuthStatus.guest);
        return;
      }
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      if (saved['version'] != 1) {
        throw const FormatException('Invalid session cache.');
      }
      _user = AuthUser.fromJson(saved['user'] as Map<String, dynamic>);
      _tokens = AuthTokens.fromJson(saved['tokens'] as Map<String, dynamic>);
      _pending = saved['pending'] == null
          ? null
          : _PendingRefresh.fromJson(saved['pending'] as Map<String, dynamic>);
      if (!remember || _user!.status != 'active') {
        await _invalidate(epoch, 'SESSION_INVALID');
        return;
      }
      // Pending recovery takes precedence even when the cached access is valid.
      if (_pending != null || !_clock().isBefore(_tokens!.accessExpiresAt)) {
        await refresh();
      }
      if (!_current(epoch)) return;
      final access = await accessToken();
      AuthUser user;
      try {
        user = await _api.me(access);
      } on AuthApiException catch (error) {
        if (error.code != 'ACCESS_EXPIRED') rethrow;
        await refresh();
        user = await _api.me(await accessToken());
      }
      if (!_current(epoch)) return;
      if (user.id != _user!.id || user.status != 'active') {
        throw const AuthApiException('SESSION_INVALID', status: 401);
      }
      _user = user;
      await _persist(epoch);
      if (_current(epoch)) _emit(AuthStatus.signedIn);
    } on FormatException {
      await _invalidate(epoch, 'INVALID_SESSION_CACHE');
    } on TypeError {
      await _invalidate(epoch, 'INVALID_SESSION_CACHE');
    } on AuthApiException catch (error) {
      await _handleFailure(epoch, error);
    } catch (_) {
      if (_current(epoch)) _emit(AuthStatus.unavailable, 'STORAGE_UNAVAILABLE');
    }
  }

  Future<bool> login({required bool remember}) async {
    if (isBusy) return false;
    final epoch = ++_epoch;
    _emit(AuthStatus.authenticating);
    try {
      final secret = newAuthSecret();
      final challenge = await _api.challenge(authSecretDigest(secret));
      if (!_current(epoch)) return false;
      final proof = await _google.authenticate(
        serverClientId: serverClientId,
        nonce: challenge.nonce,
      );
      if (!_current(epoch)) return false;
      // Do not retry a proof exchange; each new attempt creates a new challenge.
      final result = await _api.login(
        transactionId: challenge.id,
        secret: secret,
        proof: proof.idToken,
        remember: remember,
      );
      if (!_current(epoch)) return false;
      if (result.user.status != 'active' ||
          result.tokens.session.remember != remember) {
        throw const AuthApiException('INVALID_RESPONSE');
      }
      _user = result.user;
      _tokens = result.tokens;
      _pending = null;
      await _persist(epoch);
      if (!_current(epoch)) return false;
      _emit(AuthStatus.signedIn);
      return true;
    } on GoogleAuthenticationException catch (error) {
      if (_current(epoch)) {
        _emit(
          _tokens == null ? AuthStatus.guest : AuthStatus.unavailable,
          error.failure == GoogleAuthenticationFailure.cancelled
              ? null
              : 'GOOGLE_AUTH_UNAVAILABLE',
        );
      }
    } on AuthApiException catch (error) {
      if (_current(epoch)) {
        _emit(
          _tokens == null ? AuthStatus.guest : AuthStatus.unavailable,
          error.code,
        );
      }
    } catch (_) {
      if (_current(epoch)) _emit(AuthStatus.unavailable, 'STORAGE_UNAVAILABLE');
    }
    return false;
  }

  Future<String> accessToken() async {
    if (_tokens == null) throw const AuthApiException('LOGIN_REQUIRED');
    if (_pending != null || !_clock().isBefore(_tokens!.accessExpiresAt)) {
      await refresh();
    }
    if (_tokens == null ||
        status == AuthStatus.reauthenticationRequired ||
        status == AuthStatus.unavailable) {
      throw AuthApiException(errorCode ?? 'LOGIN_REQUIRED');
    }
    return _tokens!.access;
  }

  Future<void> refresh() {
    if (_refreshFlight != null) return _refreshFlight!;
    final future = _refresh(_epoch);
    _refreshFlight = future;
    // Catch on this observer; callers still receive failures on the original future.
    unawaited(
      future.then(
        (_) {
          if (identical(_refreshFlight, future)) _refreshFlight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_refreshFlight, future)) _refreshFlight = null;
        },
      ),
    );
    return future;
  }

  Future<void> _refresh(int epoch) async {
    final original = _tokens;
    if (original == null) throw const AuthApiException('LOGIN_REQUIRED');
    final pending = _pending ??= _PendingRefresh(
      token: original.refresh,
      requestId: newAuthSecret(),
      startedAt: _clock(),
    );
    try {
      while (_current(epoch) && identical(_pending, pending)) {
        if (pending.attempts >= 3 ||
            _clock().difference(pending.startedAt) >=
                const Duration(seconds: 60)) {
          throw const AuthApiException('REFRESH_RECOVERY_EXPIRED', status: 409);
        }
        pending.attempts++;
        // Persist attempt before sending so process death cannot reset the limit.
        await _persist(epoch);
        if (!_current(epoch)) return;
        try {
          final result = await _api.refresh(pending.token, pending.requestId);
          if (!_current(epoch) || !identical(_pending, pending)) return;
          if (result.session.id != original.session.id ||
              result.session.remember != original.session.remember) {
            throw const AuthApiException('INVALID_RESPONSE');
          }
          _tokens = result;
          _pending = null;
          await _persist(epoch);
          if (_current(epoch)) _emit(AuthStatus.signedIn);
          return;
        } on AuthApiException catch (error) {
          if (!error.transient || pending.attempts >= 3) rethrow;
          final wait =
              error.retryAfter ??
              Duration(seconds: pending.attempts == 1 ? 1 : 3);
          if (_clock().difference(pending.startedAt) + wait >=
              const Duration(seconds: 60)) {
            rethrow;
          }
          await _delay(wait);
        }
      }
    } on AuthApiException catch (error) {
      await _handleFailure(epoch, error);
      rethrow;
    } catch (_) {
      if (_current(epoch)) _emit(AuthStatus.unavailable, 'STORAGE_UNAVAILABLE');
      throw const AuthApiException('STORAGE_UNAVAILABLE');
    }
  }

  Future<void> _handleFailure(int epoch, AuthApiException error) async {
    if (!_current(epoch)) return;
    if (errorCode == error.code &&
        status == AuthStatus.reauthenticationRequired) {
      return;
    }
    if (error.status == 401 || error.status == 403) {
      await _invalidate(epoch, error.code);
    } else {
      _emit(
        error.status == 409
            ? AuthStatus.reauthenticationRequired
            : AuthStatus.unavailable,
        error.code,
      );
    }
  }

  Future<void> _invalidate(int epoch, String code) async {
    if (!_current(epoch)) return;
    _user = null;
    _tokens = null;
    _pending = null;
    await _persist(epoch);
    if (_current(epoch)) _emit(AuthStatus.guest, code);
  }

  Future<void> logout() async {
    final token = _tokens?.refresh;
    final epoch = ++_epoch;
    _user = null;
    _tokens = null;
    _pending = null;
    _refreshFlight = null;
    _emit(AuthStatus.guest);
    try {
      await _persist(epoch, forceDelete: true);
    } catch (_) {
      if (_current(epoch)) _emit(AuthStatus.unavailable, 'STORAGE_UNAVAILABLE');
      return;
    }
    if (token != null) {
      try {
        await _api.logout(token);
      } on AuthApiException catch (error) {
        if (_current(epoch) && error.status != 401) {
          _emit(AuthStatus.guest, 'LOGOUT_REVOKE_PENDING');
        }
      }
    }
    if (!_current(epoch)) return;
    try {
      await _google.clearCredentialState();
    } catch (_) {
      /* Local credential is already removed. */
    }
  }

  Future<void> _persist(int epoch, {bool forceDelete = false}) {
    final payload = _tokens?.session.remember == true && _user != null
        ? jsonEncode({
            'version': 1,
            'user': _user!.toJson(),
            'tokens': _tokens!.toJson(),
            'pending': _pending?.toJson(),
          })
        : null;
    final operation = _storageQueue.then((_) async {
      if (!_current(epoch) && !forceDelete) return;
      if (payload == null) {
        await _store.delete();
      } else {
        await _store.write(payload);
      }
    });
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

class _PendingRefresh {
  _PendingRefresh({
    required this.token,
    required this.requestId,
    required this.startedAt,
  }) : attempts = 0;
  _PendingRefresh.fromJson(Map<String, dynamic> json)
    : token = json['token'] as String,
      requestId = json['request_id'] as String,
      startedAt = DateTime.parse(json['started_at'] as String).toUtc(),
      attempts = json['attempts'] as int {
    if (attempts < 0 || attempts > 3) {
      throw const FormatException('Invalid pending refresh.');
    }
  }
  final String token, requestId;
  final DateTime startedAt;
  int attempts;
  Map<String, dynamic> toJson() => {
    'token': token,
    'request_id': requestId,
    'started_at': startedAt.toIso8601String(),
    'attempts': attempts,
  };
}
