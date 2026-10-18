import '../../domain/services/account_detail_access.dart';
import '../../domain/services/character_lookup_name.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../../auth/domain/backend_auth_models.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/server_registration_api.dart';
import '../../domain/server_combat_power.dart';
import '../../../../shared/lost_ark_api/client/api_cooldown.dart';

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
    this.cooldown,
    this.onCommandStarted,
    this.onCommandFinished,
  }) : now = now ?? DateTime.now {
    cooldown?.addListener(_cooldownChanged);
    session.addListener(_onSession);
    _scopeKey = (session.userId, session.generation, session.isAuthenticated);
  }
  final BackendRegistrationApi api;
  final ServerAccountReadRepository reads;
  final AccountReadSession session;
  final DateTime Function() now;
  final ApiCooldown? cooldown;
  final void Function(AccountReadScope)? onCommandStarted;
  final void Function(AccountReadScope)? onCommandFinished;
  void _cooldownChanged() {
    if (!_disposed) notifyListeners();
  }

  int get retrySeconds {
    final own = _retryAt == null
        ? 0
        : (_retryAt!.difference(now()).inMilliseconds / 1000).ceil().clamp(
            0,
            86400,
          );
    return own > (cooldown?.seconds ?? 0) ? own : (cooldown?.seconds ?? 0);
  }

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
  List<ServerPowerResult> powerResults = const [];
  bool powerContext = false;
  bool get hasPending => _pending != null;
  bool get canWrite =>
      session.isAuthenticated &&
      !busy &&
      !hasPending &&
      cooldown?.active != true &&
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
    powerResults = const [];
    powerContext = false;
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
    powerContext = false;
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
      if (result.characters
              .where(
                (c) => matchesCharacterLookupName(checked, c.characterName),
              )
              .length !=
          1) {
        throw const FormatException('Missing or ambiguous lookup character.');
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
        'label': label,
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

  Future<void> refreshPower(
    ServerAccountRegistration account,
    List<Map<String, String>> targets,
  ) async {
    if (!canWrite) return;
    if (!hasAccountDetailAccess(
      ownershipStatus: account.ownershipStatus,
      accountId: account.gameAccountId,
      ownershipRevision: account.ownershipRevision,
    )) {
      failure = const AccountReadException('OWNERSHIP_REQUIRED');
      notifyListeners();
      return;
    }
    if (targets.isEmpty ||
        targets.length > 20 ||
        targets.any(
          (t) =>
              t.length != 2 ||
              !t.containsKey('server_name') ||
              !t.containsKey('character_name') ||
              t.values.any((v) => v.trim().isEmpty || v.runes.length > 64),
        )) {
      failure = const AccountReadException('INVALID_REQUEST');
      notifyListeners();
      return;
    }
    await _begin(
      '${_path(account)}/combat-power/refresh',
      'POST',
      {
        'characters': List.unmodifiable(
          targets.map((t) => Map<String, String>.unmodifiable(t)),
        ),
      },
      {},
      200,
    );
  }

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
        final label = (body['label'] as String).trim();
        if (label.runes.length > 40) {
          throw const AccountReadException('INVALID_REQUEST');
        }
        body['label'] = label;
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
      powerResults = const [];
      powerContext = path.endsWith('/combat-power/refresh');
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

  Future<void> _requirePowerOwnership(
    _RegistrationCommand command,
    int ticket,
  ) async {
    if (!command.path.endsWith('/combat-power/refresh')) return;
    final current = await reads.loadRegistrations();
    requireAccountReadScope(session, command.scope);
    if (!_valid(ticket, command.scope)) {
      throw const AccountReadException('STALE_READ');
    }
    final id = command.path.split('/')[4];
    final account = current.where((a) => a.registrationId == id).firstOrNull;
    if (account == null ||
        !hasAccountDetailAccess(
          ownershipStatus: account.ownershipStatus,
          accountId: account.gameAccountId,
          ownershipRevision: account.ownershipRevision,
        )) {
      throw const AccountReadException('OWNERSHIP_REQUIRED', status: 403);
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
    onCommandStarted?.call(command.scope);
    notifyListeners();
    try {
      await _requirePowerOwnership(command, ticket);
      final json = await api.request(
        command.path,
        method: command.method,
        body: command.method == 'DELETE' ? null : command.body,
        query: command.query,
        idempotencyKey: command.key,
        expectedStatus: command.status,
      );
      requireAccountReadScope(session, command.scope);
      await _requirePowerOwnership(command, ticket);
      requireAccountReadScope(session, command.scope);
      if (!_valid(ticket, command.scope)) return;
      ServerRegistrationRefresh? refreshed;
      ServerAccountRegistration? savedRegistration;
      List<ServerPowerResult>? powers;
      if (command.path.endsWith('/combat-power/refresh')) {
        powers = ServerPowerResult.decode(
          json!,
          (command.body['characters'] as List).cast<Map<String, String>>(),
        );
      } else if (command.status != 204) {
        if (command.path.endsWith('/refresh')) {
          refreshed = ServerRegistrationRefresh.fromJson(json!);
        }
        final result =
            refreshed?.registration ??
            ServerAccountRegistration.fromJson(json!);
        savedRegistration = result;
        if (result.version < 1 ||
            (command.path != '/v1/me/game-accounts' &&
                result.registrationId != command.path.split('/')[4])) {
          throw const FormatException('Unexpected registration result.');
        }
      }
      if (_valid(ticket, command.scope)) {
        powerResults = powers ?? const [];
        _pending = null;
        preview = null;
        previewName = null;
        _retryAt = null;
        for (final power in powerResults) {
          if (power.retryAt != null) {
            if (power.reason == 'UPSTREAM_RATE_LIMITED') {
              cooldown?.observe(power.retryAt!);
            }
            _setFailure(
              AccountReadException(
                power.reason!,
                retryAfter: power.retryAfter,
                retryAt: power.retryAt,
              ),
            );
          } else if (power.reason == 'LOSTARK_KEY_REJECTED') {
            failure = const AccountReadException('LOSTARK_KEY_REJECTED');
          }
        }
        notice = powers != null
            ? '전투력 확인을 마쳤습니다. 새로 확인 ${powers.where((p) => p.status == 'updated').length}명 · '
                  '최근 정보 사용 ${powers.where((p) => p.status == 'cached').length}명\n'
                  '정보 없음 ${powers.where((p) => p.status == 'unavailable').length}명 · '
                  '실패 ${powers.where((p) => p.status == 'failed').length}명 · '
                  '제외 ${powers.where((p) => p.status == 'skipped').length}명 · '
                  '다음에 확인 ${powers.where((p) => p.status == 'deferred').length}명'
            : refreshed == null
            ? (command.method == 'POST' &&
                      command.path == '/v1/me/game-accounts' &&
                      savedRegistration?.ownershipStatus == 'owned' &&
                      savedRegistration?.verificationStatus == 'verified'
                  ? '인증된 원정대를 등록했습니다.'
                  : '변경 사항을 저장했습니다.')
            : '정보 갱신 완료\n'
                  '새 캐릭터 ${refreshed.addedCount}명 · 확인 필요 ${refreshed.suspectCount}명\n'
                  '마지막 확인: ${serverRegistrationTimeLabel(refreshed.registration.serverFetchedAt)}'
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
                {
                  'LOSTARK_KEY_NOT_CONFIGURED',
                  'LOSTARK_KEY_REJECTED',
                  'LOSTARK_KEY_CHANGED',
                  'UPSTREAM_RATE_LIMITED',
                }.contains(error.code) ||
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
        onCommandFinished?.call(command.scope);
        notifyListeners();
      }
    }
  }

  void _setFailure(AccountReadException error) {
    failure = error;
    _retryTimer?.cancel();
    final candidate =
        error.retryAt ??
        (error.retryAfter == null ? null : now().add(error.retryAfter!));
    if (candidate != null &&
        (_retryAt == null || candidate.isAfter(_retryAt!))) {
      _retryAt = candidate;
    }
    if (retrySeconds > 0) {
      _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (retrySeconds == 0) timer.cancel();
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
    cooldown?.removeListener(_cooldownChanged);
    super.dispose();
  }
}

String serverRegistrationTimeLabel(DateTime value) =>
    localDateTimeToSeconds(value);
