import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/backend_auth_models.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_registration_api.dart';

class MemberSettings {
  const MemberSettings(this.enabled, this.version);
  factory MemberSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null ||
        json.length != 2 ||
        json['nice_group_auto_refresh_enabled'] is! bool ||
        json['version'] is! int ||
        (json['version'] as int) < 1) {
      throw const FormatException('Invalid member settings');
    }
    return MemberSettings(
      json['nice_group_auto_refresh_enabled'] as bool,
      json['version'] as int,
    );
  }
  final bool enabled;
  final int version;
}

class _SettingsCommand {
  _SettingsCommand(this.scope, bool enabled, int version, this.startedAt)
    : body = Map.unmodifiable({
        'nice_group_auto_refresh_enabled': enabled,
        'expected_version': version,
      }) {
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
  final Map<String, dynamic> body;
  final DateTime startedAt;
  late final String key;
}

/// One member-wide setting; local character drafts never save or undo it.
class MemberSettingsViewModel extends ChangeNotifier {
  MemberSettingsViewModel(this.api, this.session, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    session.addListener(_onSession);
    _onSession();
  }
  final BackendRegistrationApi api;
  final AccountReadSession session;
  final DateTime Function() now;
  MemberSettings? value;
  AccountReadException? failure;
  String? notice;
  bool busy = false, _disposed = false, reviewed = false;
  int _ticket = 0;
  (String?, int, bool)? _scopeKey;
  _SettingsCommand? _pending;
  DateTime? _retryAt;
  Timer? _retryTimer;
  bool get signedIn => session.isAuthenticated;
  bool get hasPending => _pending != null;
  bool get _delayPassed => _retryAt == null || !now().isBefore(_retryAt!);
  bool get canChange =>
      signedIn && !busy && !hasPending && value != null && _delayPassed;
  bool get canRetry =>
      signedIn &&
      !busy &&
      hasPending &&
      _delayPassed &&
      now().difference(_pending!.startedAt) < const Duration(hours: 24) &&
      failure?.code != 'IDEMPOTENCY_CONFLICT' &&
      failure?.code != 'IDEMPOTENCY_EXPIRED';

  void _onSession() {
    final key = (session.userId, session.generation, session.isAuthenticated);
    if (key == _scopeKey) return;
    _scopeKey = key;
    _ticket++;
    value = null;
    failure = null;
    notice = null;
    _pending = null;
    _retryAt = null;
    _retryTimer?.cancel();
    busy = reviewed = false;
    notifyListeners();
    if (signedIn) unawaited(reload());
  }

  bool _valid(int ticket, AccountReadScope scope) =>
      !_disposed &&
      ticket == _ticket &&
      signedIn &&
      scope.userId == session.userId &&
      scope.generation == session.generation;

  void _fail(AccountReadException error) {
    failure = error;
    _retryTimer?.cancel();
    final candidate = error.retryAfter == null
        ? null
        : now().add(error.retryAfter!);
    if (candidate != null &&
        (_retryAt == null || candidate.isAfter(_retryAt!))) {
      _retryAt = candidate;
    }
    final remaining = _retryAt?.difference(now());
    if (remaining != null && remaining > Duration.zero) {
      _retryTimer = Timer(remaining, () {
        if (!_disposed) notifyListeners();
      });
    }
  }

  Future<void> _read(int ticket, AccountReadScope scope) async {
    final result = MemberSettings.fromJson(
      await api.request('/v1/me/settings'),
    );
    if (_valid(ticket, scope)) {
      value = result;
      reviewed = hasPending;
    }
  }

  Future<void> reload() async {
    if (!signedIn || busy || _disposed) return;
    final scope = accountReadScope(session), ticket = ++_ticket;
    busy = true;
    reviewed = false;
    failure = null;
    value = null;
    notifyListeners();
    try {
      await _read(ticket, scope);
    } on AccountReadException catch (error) {
      if (_valid(ticket, scope)) _fail(error);
    } catch (_) {
      if (_valid(ticket, scope)) {
        _fail(const AccountReadException('INVALID_RESPONSE'));
      }
    } finally {
      if (_valid(ticket, scope)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> change(bool enabled) async {
    if (!canChange || enabled == value!.enabled) return;
    _pending = _SettingsCommand(
      accountReadScope(session),
      enabled,
      value!.version,
      now(),
    );
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  Future<void> _send() async {
    final command = _pending!;
    final scope = command.scope, ticket = ++_ticket;
    busy = true;
    reviewed = false;
    failure = null;
    notice = null;
    notifyListeners();
    try {
      requireAccountReadScope(session, scope);
      final saved = MemberSettings.fromJson(
        await api.request(
          '/v1/me/settings',
          method: 'PUT',
          body: command.body,
          idempotencyKey: command.key,
        ),
      );
      final expected = command.body['expected_version'] as int;
      if (saved.enabled != command.body['nice_group_auto_refresh_enabled'] ||
          saved.version < expected ||
          saved.version > expected + 1) {
        throw const FormatException('Unexpected saved settings');
      }
      if (!_valid(ticket, scope)) return;
      _pending = null;
      _retryAt = null;
      value = null;
      notice = '설정을 저장했습니다.';
      await _read(ticket, scope);
    } on AccountReadException catch (error) {
      if (_valid(ticket, scope)) {
        _fail(error);
        if (error.code == 'REVISION_CONFLICT') {
          _pending = null;
          value = null;
          notice = '다른 곳에서 설정이 변경되었습니다. 현재 값을 확인하고 다시 선택해 주세요.';
          try {
            await _read(ticket, scope);
          } on AccountReadException catch (e) {
            if (_valid(ticket, scope)) _fail(e);
          } catch (_) {
            if (_valid(ticket, scope)) {
              _fail(const AccountReadException('INVALID_RESPONSE'));
            }
          }
        } else if ({400, 403, 404, 422, 429}.contains(error.status)) {
          _pending = null;
        }
      }
    } catch (_) {
      if (_valid(ticket, scope)) {
        _fail(const AccountReadException('INVALID_RESPONSE'));
      }
    } finally {
      if (_valid(ticket, scope)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void finishReview() {
    if (_disposed || busy || !reviewed || !signedIn) return;
    _pending = null;
    reviewed = false;
    failure = null;
    notice = '서버에서 확인한 설정을 표시합니다.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    _retryTimer?.cancel();
    session.removeListener(_onSession);
    super.dispose();
  }
}
