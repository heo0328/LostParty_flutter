import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../../auth/domain/backend_auth_models.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/server_registration_api.dart';

String _newKey() {
  final bytes = base64Url
      .decode(base64Url.normalize(newAuthSecret()))
      .sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _RegistrationCommand {
  _RegistrationCommand(
    this.scope,
    this.path,
    this.method,
    this.body,
    this.query,
    this.status,
    this.startedAt,
  ) : key = _newKey();
  final AccountReadScope scope;
  final String path, method, key;
  final Map<String, dynamic> body, query;
  final int status;
  final DateTime startedAt;
}

/// Holds one immutable mutation for explicit retries, separate from local data.
class ServerRegistrationViewModel extends ChangeNotifier {
  ServerRegistrationViewModel(
    this.api,
    this.reads,
    this.session, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    session.addListener(_onSession);
    _scopeKey = (session.userId, session.generation, session.isAuthenticated);
  }
  final BackendRegistrationApi api;
  final ServerAccountReadRepository reads;
  final AccountReadSession session;
  final DateTime Function() now;
  ServerRegistrationPreview? preview;
  String? previewName;
  AccountReadException? failure;
  String? notice;
  bool busy = false, _disposed = false, _reviewed = false;
  int _ticket = 0;
  (String?, int, bool)? _scopeKey;
  DateTime? _retryAt;
  Timer? _retryTimer;
  _RegistrationCommand? _pending;
  bool get hasPending => _pending != null;
  bool get canWrite =>
      session.isAuthenticated &&
      !busy &&
      !hasPending &&
      (_retryAt == null || !now().isBefore(_retryAt!));
  bool get canRetry =>
      session.isAuthenticated &&
      !busy &&
      _pending != null &&
      now().difference(_pending!.startedAt) < const Duration(hours: 24) &&
      (_retryAt == null || !now().isBefore(_retryAt!)) &&
      failure?.code != 'IDEMPOTENCY_CONFLICT' &&
      failure?.code != 'IDEMPOTENCY_EXPIRED';
  bool get canFinishReview => !busy && _reviewed && hasPending;

  void _onSession() {
    final key = (session.userId, session.generation, session.isAuthenticated);
    if (key == _scopeKey) return;
    _scopeKey = key;
    _ticket++;
    _pending = null;
    preview = null;
    previewName = null;
    failure = null;
    notice = null;
    busy = false;
    _reviewed = false;
    _retryAt = null;
    _retryTimer?.cancel();
    notifyListeners();
  }

  bool _valid(int ticket, AccountReadScope scope) =>
      !_disposed &&
      ticket == _ticket &&
      session.isAuthenticated &&
      session.userId == scope.userId &&
      session.generation == scope.generation;
  String _text(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.runes.length > max) {
      throw const AccountReadException('INVALID_REQUEST');
    }
    return trimmed;
  }

  String _path(ServerAccountRegistration account) {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(account.registrationId) ||
        account.version < 1) {
      throw const AccountReadException('INVALID_REQUEST');
    }
    return '/v1/me/game-accounts/${account.registrationId}';
  }

  Future<void> search(String name) async {
    if (!canWrite) return;
    final scope = accountReadScope(session);
    final ticket = ++_ticket;
    busy = true;
    preview = null;
    previewName = null;
    failure = null;
    notice = null;
    notifyListeners();
    try {
      final checked = _text(name, 64);
      final json = await api.request(
        '/v1/game-accounts/preview',
        method: 'POST',
        body: {'character_name': checked},
      );
      requireAccountReadScope(session, scope);
      final result = ServerRegistrationPreview.fromJson(json!);
      if (!result.characters.any((c) => c.characterName == checked)) {
        throw const FormatException('Missing lookup character.');
      }
      if (_valid(ticket, scope)) {
        preview = result;
        previewName = checked;
      }
    } on AccountReadException catch (error) {
      if (_valid(ticket, scope)) _setFailure(error);
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

  Future<void> register(String label, bool isMain) async {
    final result = preview;
    if (!canWrite) return;
    if (result == null ||
        previewName == null ||
        !now().toUtc().isBefore(result.expiresAt)) {
      preview = null;
      previewName = null;
      failure = const AccountReadException('PREVIEW_EXPIRED');
      notifyListeners();
      return;
    }
    await _begin(
      '/v1/me/game-accounts',
      'POST',
      {
        'lookup_character_name': previewName!,
        'label': label.trim().isEmpty ? (isMain ? '메인 계정' : '부계정') : label,
        'is_main': isMain,
      },
      {},
      201,
    );
  }

  Future<void> edit(
    ServerAccountRegistration account,
    String label,
    bool isMain,
  ) => _begin(
    _path(account),
    'PATCH',
    {'expected_version': account.version, 'label': label, 'is_main': isMain},
    {},
    200,
  );
  Future<void> remove(ServerAccountRegistration account) => _begin(
    _path(account),
    'DELETE',
    {},
    {'expected_version': account.version},
    204,
  );
  Future<void> refresh(ServerAccountRegistration account) =>
      _begin('${_path(account)}/refresh', 'POST', {}, {}, 200);

  Future<void> _begin(
    String path,
    String method,
    Map<String, dynamic> body,
    Map<String, dynamic> query,
    int status,
  ) async {
    if (!canWrite) return;
    try {
      if (body.containsKey('label')) {
        body['label'] = _text(body['label'] as String, 40);
      }
      _pending = _RegistrationCommand(
        accountReadScope(session),
        path,
        method,
        Map.unmodifiable(body),
        Map.unmodifiable(query),
        status,
        now(),
      );
      await _send();
    } on AccountReadException catch (error) {
      failure = error;
      notifyListeners();
    }
  }

  void clearCompletedNotice() {
    if (!busy && !hasPending && failure == null && notice != null) {
      notice = null;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    if (canRetry) {
      await _send();
    } else {
      notice = '재시도 대기 중이거나 요청 수명이 지났습니다. 서버 상태를 확인해 주세요.';
      notifyListeners();
    }
  }

  Future<void> _send() async {
    final command = _pending!;
    requireAccountReadScope(session, command.scope);
    final ticket = ++_ticket;
    busy = true;
    failure = null;
    notice = null;
    _reviewed = false;
    notifyListeners();
    try {
      final json = await api.request(
        command.path,
        method: command.method,
        body: command.method == 'DELETE' ? null : command.body,
        query: command.query,
        idempotencyKey: command.key,
        expectedStatus: command.status,
      );
      requireAccountReadScope(session, command.scope);
      ServerRegistrationRefresh? refreshed;
      if (command.status != 204) {
        if (command.path.endsWith('/refresh')) {
          refreshed = ServerRegistrationRefresh.fromJson(json!);
        }
        final result =
            refreshed?.registration ??
            ServerAccountRegistration.fromJson(json!);
        if (result.version < 1 ||
            (command.path != '/v1/me/game-accounts' &&
                result.registrationId != command.path.split('/')[4])) {
          throw const FormatException('Unexpected registration result.');
        }
      }
      if (_valid(ticket, command.scope)) {
        _pending = null;
        preview = null;
        previewName = null;
        _retryAt = null;
        notice = refreshed == null
            ? '요청이 처리되었습니다. 현재 상태는 서버 목록에서 다시 확인해 주세요.'
            : '정보 갱신 완료 · ${refreshed.registration.label}\n'
                  '새 캐릭터 ${refreshed.addedCount}명 · 확인 필요 ${refreshed.suspectCount}명\n'
                  '서버 조회 시각: ${serverRegistrationTimeLabel(refreshed.registration.serverFetchedAt)}'
                  '${refreshed.requiresRefresh ? '\n추가 정보 갱신이 필요합니다.' : ''}';
      }
    } on AccountReadException catch (error) {
      if (_valid(ticket, command.scope)) {
        _setFailure(error);
        // Known rejected commands cannot have changed application state.
        if ((error.status == 400 ||
                error.status == 422 ||
                error.status == 403 ||
                error.status == 404 ||
                error.status == 429 ||
                error.code == 'REVISION_CONFLICT') &&
            error.code != 'REQUEST_IN_PROGRESS') {
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

  void _setFailure(AccountReadException error) {
    failure = error;
    _retryTimer?.cancel();
    _retryAt = error.retryAfter == null ? null : now().add(error.retryAfter!);
    if (error.retryAfter != null) {
      _retryTimer = Timer(error.retryAfter!, () {
        if (!_disposed) notifyListeners();
      });
    }
  }

  Future<List<ServerAccountRegistration>?> review() async {
    if (busy || !session.isAuthenticated) return null;
    final scope = accountReadScope(session), ticket = ++_ticket;
    busy = true;
    _reviewed = false;
    notifyListeners();
    try {
      final result = await reads.loadRegistrations();
      if (_valid(ticket, scope)) {
        _reviewed = true;
        return result;
      }
    } on AccountReadException catch (error) {
      if (_valid(ticket, scope)) _setFailure(error);
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
    return null;
  }

  void finishReviewedRequest() {
    if (!canFinishReview) return;
    _pending = null;
    failure = null;
    _retryAt = null;
    _reviewed = false;
    notice = '확인한 서버 상태를 기준으로 요청 확인을 종료했습니다.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _ticket++;
    session.removeListener(_onSession);
    super.dispose();
  }
}

String serverRegistrationTimeLabel(DateTime value) =>
    value.toLocal().toString().split('.').first;
