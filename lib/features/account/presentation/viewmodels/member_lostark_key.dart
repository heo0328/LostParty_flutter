import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../auth/domain/backend_auth_models.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_registration_api.dart';
import '../../../../shared/lost_ark_api/auth/api_token.dart';
import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/api_cooldown.dart';

class MemberKeyStatus {
  MemberKeyStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null ||
        json.length != 3 ||
        json['configured'] is! bool ||
        json['version'] is! int ||
        (json['version'] as int) < 1 ||
        !json.containsKey('updated_at')) {
      throw const FormatException('Invalid key status');
    }
    configured = json['configured'] as bool;
    version = json['version'] as int;
    final time = json['updated_at'];
    if (time != null &&
        (time is! String || !RegExp(r'(Z|\+00:00)$').hasMatch(time))) {
      throw const FormatException('Invalid key time');
    }
    updatedAt = time == null ? null : DateTime.parse(time as String).toUtc();
  }
  late final bool configured;
  late final int version;
  late final DateTime? updatedAt;
}

abstract interface class MemberKeyStorage {
  Future<void> write(String owner, String token, int version);
  Future<void> delete(String owner);
}

class SecureMemberKeyStorage implements MemberKeyStorage {
  SecureMemberKeyStorage(this.environment, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final String environment;
  final FlutterSecureStorage storage;
  String _key(String owner) =>
      'lostark_member_${base64Url.encode(utf8.encode('$environment/$owner'))}';
  @override
  Future<void> write(String owner, String token, int version) => storage.write(
    key: _key(owner),
    value: jsonEncode({'token': token, 'version': version}),
  );
  @override
  Future<void> delete(String owner) => storage.delete(key: _key(owner));
}

class _KeyCommand {
  _KeyCommand(this.scope, this.version, this.token, this.started) {
    final bytes = base64Url
        .decode(base64Url.normalize(newAuthSecret()))
        .sublist(0, 16);
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    key =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
  final AccountReadScope scope;
  final int version;
  final String? token;
  final DateTime started;
  late final String key;
}

/// Account-scoped token source; member secrets never enter the guest store.
class MemberLostArkKey extends ChangeNotifier implements ApiTokenStore {
  MemberLostArkKey(
    this.api,
    this.session,
    this.storage,
    this.guest,
    this.cooldown,
  ) {
    session.addListener(_sessionChanged);
    _sessionChanged();
  }
  final BackendRegistrationApi api;
  final AccountReadSession session;
  final MemberKeyStorage storage;
  final ApiTokenStore guest;
  final ApiCooldown cooldown;
  static const path = '/v1/me/lostark-api-key';
  MemberKeyStatus? value;
  AccountReadException? failure;
  String? notice;
  bool busy = false, _disposed = false;
  ApiToken? _token;
  int _ticket = 0;
  (String?, int, bool)? _scope;
  _KeyCommand? _pending;
  Future<void>? _sync;
  DateTime? _pendingRetryAt;
  Timer? _pendingTimer;
  Future<void> _storageQueue = Future.value();
  bool get signedIn => session.isAuthenticated;
  bool get localReady => signedIn && _token != null;
  bool get hasPending => _pending != null;
  bool get canChange => signedIn && value != null && !busy && !hasPending;
  bool get canRetry =>
      signedIn &&
      !busy &&
      _pending != null &&
      (_pendingRetryAt == null || !DateTime.now().isBefore(_pendingRetryAt!)) &&
      DateTime.now().difference(_pending!.started) <
          const Duration(hours: 24) &&
      !{'IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_EXPIRED'}.contains(failure?.code);
  bool _valid(int ticket, AccountReadScope scope) =>
      !_disposed &&
      ticket == _ticket &&
      signedIn &&
      session.userId == scope.userId &&
      session.generation == scope.generation;
  Future<void> _local(Future<void> Function() action) {
    final result = _storageQueue.then((_) => action());
    _storageQueue = result.catchError((Object _) {});
    return result;
  }

  void _sessionChanged() {
    final next = (session.userId, session.generation, signedIn);
    if (next == _scope) return;
    final previous = _scope?.$1;
    _scope = next;
    _ticket++;
    _pending = null;
    _token = null;
    _sync = null;
    _pendingTimer?.cancel();
    _pendingRetryAt = null;
    value = null;
    failure = null;
    notice = null;
    busy = false;
    cooldown.clear();
    if (previous != null) {
      unawaited(
        _local(() => storage.delete(previous)).catchError((Object _) {}),
      );
    }
    notifyListeners();
    if (signedIn) unawaited(reload());
  }

  Future<void> reload() {
    if (_disposed || !signedIn || busy) return _sync ?? Future.value();
    final operation = _reload();
    _sync = operation;
    return operation;
  }

  Future<void> _reload() async {
    final scope = accountReadScope(session), ticket = ++_ticket;
    busy = true;
    failure = null;
    value = null;
    _token = null;
    notifyListeners();
    try {
      await _readAndRestore(ticket, scope);
    } on AccountReadException catch (e) {
      if (_valid(ticket, scope)) failure = e;
    } catch (_) {
      if (_valid(ticket, scope)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
    } finally {
      if (_valid(ticket, scope)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _readAndRestore(int ticket, AccountReadScope scope) async {
    final status = MemberKeyStatus.fromJson(await api.request(path));
    if (!_valid(ticket, scope)) return;
    value = status;
    _token = null;
    // Serialize deletion/writes with logout and subsequent sessions.
    try {
      await _local(() async {
        if (_valid(ticket, scope)) await storage.delete(scope.userId);
      });
    } catch (_) {
      throw const AccountReadException('KEY_DEVICE_STORAGE_FAILED');
    }
    if (!_valid(ticket, scope) || !status.configured) return;
    final restored = await api.request(
      '$path/restore',
      method: 'POST',
      body: {'expected_version': status.version},
    );
    if (restored == null ||
        restored.length != 2 ||
        restored['version'] != status.version ||
        restored['version'] is! int ||
        !validToken(restored['token'])) {
      throw const FormatException('Invalid restored key');
    }
    if (!_valid(ticket, scope)) return;
    final token = restored['token'] as String;
    try {
      await _local(() async {
        if (_valid(ticket, scope)) {
          await storage.write(scope.userId, token, status.version);
        }
      });
    } catch (_) {
      throw const AccountReadException('KEY_DEVICE_STORAGE_FAILED');
    }
    if (_valid(ticket, scope)) {
      cooldown.bindToken(token);
      _token = ApiToken(token);
    }
  }

  static bool validToken(Object? token) =>
      token is String &&
      token.length <= 16384 &&
      !RegExp(r'\s').hasMatch(token) &&
      RegExp(
        r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
      ).hasMatch(token);
  Future<void> save(String token) async {
    if (!canChange) return;
    notice = null;
    if (!validToken(token)) {
      failure = const AccountReadException('INVALID_KEY_FORMAT');
      notifyListeners();
      return;
    }
    _pending = _KeyCommand(
      accountReadScope(session),
      value!.version,
      token,
      DateTime.now(),
    );
    await _send();
  }

  @override
  Future<void> delete() async {
    if (!signedIn) {
      await guest.delete();
      notifyListeners();
      return;
    }
    if (!canChange) return;
    _pending = _KeyCommand(
      accountReadScope(session),
      value!.version,
      null,
      DateTime.now(),
    );
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  Future<void> _send() async {
    final command = _pending!, ticket = ++_ticket;
    busy = true;
    failure = null;
    notice = null;
    notifyListeners();
    try {
      requireAccountReadScope(session, command.scope);
      final saved = MemberKeyStatus.fromJson(
        await api.request(
          path,
          method: command.token == null ? 'DELETE' : 'PUT',
          body: command.token == null
              ? null
              : {'token': command.token, 'expected_version': command.version},
          query: command.token == null
              ? {'expected_version': command.version}
              : null,
          idempotencyKey: command.key,
        ),
      );
      if (saved.configured != (command.token != null) ||
          saved.version < command.version ||
          saved.version > command.version + 1) {
        throw const FormatException('Unexpected key result');
      }
      if (!_valid(ticket, command.scope)) return;
      _pending = null;
      _token = null;
      if (!saved.configured) cooldown.clear();
      value = saved;
      notice = command.token == null ? 'API 키를 삭제했습니다.' : 'API 키를 등록했습니다.';
      await _readAndRestore(ticket, command.scope);
    } on AccountReadException catch (e) {
      if (_valid(ticket, command.scope)) {
        failure = e;
        if (e.retryAfter != null) {
          _pendingRetryAt = DateTime.now().add(e.retryAfter!);
          _pendingTimer?.cancel();
          _pendingTimer = Timer(e.retryAfter!, () {
            if (!_disposed) notifyListeners();
          });
        }
        if ({
          'REVISION_CONFLICT',
          'LOSTARK_KEY_CHANGED',
          'LOSTARK_KEY_NOT_CONFIGURED',
        }.contains(e.code)) {
          _pending = null;
          _token = null;
          try {
            await _readAndRestore(ticket, command.scope);
          } catch (_) {}
        } else if ({400, 403, 404, 422, 429}.contains(e.status)) {
          _pending = null;
        }
      }
    } catch (_) {
      if (_valid(ticket, command.scope)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
    } finally {
      if (_valid(ticket, command.scope)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Raw pending inputs do not outlive their editor.
  void leaveEditor() {
    _pending = null;
  }

  @override
  Future<ApiToken?> read() async {
    if (!signedIn) return guest.read();
    final scope = accountReadScope(session);
    await _sync;
    if (!signedIn ||
        session.userId != scope.userId ||
        session.generation != scope.generation) {
      return null;
    }
    return _token;
  }

  @override
  Future<void> write(ApiToken token) async {
    if (signedIn) {
      await save(token.value);
    } else {
      await guest.write(token);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    _token = null;
    _pending = null;
    _pendingTimer?.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
