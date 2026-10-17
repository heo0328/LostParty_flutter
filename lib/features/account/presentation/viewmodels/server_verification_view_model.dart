import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/client/api_cooldown.dart';
import '../../../auth/domain/backend_auth_models.dart';
import '../../data/server_account_verification_client.dart';
import '../../domain/account_read_session.dart';
import '../../domain/server_account_verification.dart';

/// Display context of the original start; never sent as ownership evidence.
class VerificationAttemptContext {
  const VerificationAttemptContext({
    this.registrationId,
    this.registrationLabel,
    this.characterName,
    this.serverName,
  });

  final String? registrationId, registrationLabel, characterName, serverName;
}

/// Private, in-memory challenge state. Never grants local ownership or binds IDs.
class ServerVerificationViewModel extends ChangeNotifier {
  ServerVerificationViewModel(
    this.client, {
    DateTime Function()? now,
    this.cooldown,
  }) : now = now ?? DateTime.now {
    _sessionKey = _currentSession;
    session.addListener(_onSession);
    cooldown?.addListener(_changed);
  }

  final ServerAccountVerificationClient client;
  final DateTime Function() now;
  final ApiCooldown? cooldown;
  AccountReadSession get session => client.session;
  ServerAccountVerification? value;
  VerificationAttemptContext? _attempt;
  VerificationAttemptContext? get attempt => _attempt;
  AccountReadException? failure;
  String? verdictCode;
  bool busy = false, _disposed = false;
  bool _recoveryBlocked = false;
  bool _alreadyVerified = false;
  bool get alreadyVerified => _alreadyVerified;
  String? _challengeId;
  ServerVerificationCommand? _pending;
  DateTime? _startedAt, _observedAt, _retryAt;
  Timer? _timer;
  int _ticket = 0;
  late (String?, int, bool) _sessionKey;
  (String?, int, bool) get _currentSession =>
      (session.userId, session.generation, session.isAuthenticated);
  bool get signedIn => session.isAuthenticated;
  bool get hasPending => _pending != null;
  bool get hasChallenge => _challengeId != null;
  bool get _ready => !_disposed && signedIn && !busy && retrySeconds == 0;
  bool get canStart =>
      _ready &&
      !hasPending &&
      (_alreadyVerified ||
          !hasChallenge ||
          (value != null && value!.status != ServerVerificationStatus.pending));
  bool get canConfirm =>
      _ready &&
      !hasPending &&
      !_alreadyVerified &&
      value?.status == ServerVerificationStatus.pending &&
      remainingSeconds > 0;
  bool get canCancel =>
      _ready &&
      !hasPending &&
      !_alreadyVerified &&
      value?.status == ServerVerificationStatus.pending;
  bool get canReload => _ready && hasChallenge;
  bool get canRetry =>
      _ready &&
      hasPending &&
      !_recoveryBlocked &&
      now().difference(_startedAt!) < const Duration(hours: 24) &&
      failure?.code != 'IDEMPOTENCY_CONFLICT' &&
      failure?.code != 'IDEMPOTENCY_EXPIRED';

  String? get pendingAction {
    final command = _pending;
    if (command == null) return null;
    if (command.method == 'DELETE') return '인증 취소';
    return command.challengeId == null ? '인증 시작' : '장비 변경 확인';
  }

  int get remainingSeconds {
    final snapshot = value, observed = _observedAt;
    if (snapshot == null ||
        observed == null ||
        snapshot.status != ServerVerificationStatus.pending) {
      return 0;
    }
    final elapsed = now().difference(observed).inSeconds;
    return (snapshot.remainingSeconds - elapsed.clamp(0, 1 << 31)).clamp(
      0,
      snapshot.remainingSeconds,
    );
  }

  int get retrySeconds {
    final own = _retryAt == null
        ? 0
        : (_retryAt!.difference(now()).inMilliseconds / 1000).ceil().clamp(
            0,
            1 << 31,
          );
    final shared = cooldown?.seconds ?? 0;
    return own > shared ? own : shared;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onSession() {
    if (_sessionKey == _currentSession) return;
    _sessionKey = _currentSession;
    _ticket++;
    _pending = null;
    _alreadyVerified = false;
    _recoveryBlocked = false;
    _challengeId = null;
    _startedAt = _observedAt = _retryAt = null;
    value = null;
    _attempt = null;
    failure = null;
    verdictCode = null;
    busy = false;
    _timer?.cancel();
    _changed();
  }

  bool _valid(int ticket, AccountReadScope scope) =>
      !_disposed &&
      ticket == _ticket &&
      signedIn &&
      scope.userId == session.userId &&
      scope.generation == session.generation;

  String _newKey() {
    final bytes = base64Url
        .decode(base64Url.normalize(newAuthSecret()))
        .sublist(0, 16);
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> start({
    String? registrationId,
    String? characterName,
    String? registrationLabel,
    VerificationTarget? targetCharacter,
    int? expectedRegistrationVersion,
  }) async {
    if (!canStart) return;
    try {
      if ((registrationId == null) == (characterName == null)) {
        throw const FormatException('Select one verification source.');
      }
      if (registrationId == null &&
          (targetCharacter != null || expectedRegistrationVersion != null)) {
        throw const FormatException('Direct input cannot have a target.');
      }
      final command = registrationId != null
          ? ServerVerificationCommand.startForRegistration(
              session,
              registrationId: registrationId,
              idempotencyKey: _newKey(),
              targetCharacter: targetCharacter,
              expectedRegistrationVersion: expectedRegistrationVersion,
            )
          : ServerVerificationCommand.startForName(
              session,
              characterName: characterName!,
              idempotencyKey: _newKey(),
            );
      _challengeId = null;
      _alreadyVerified = false;
      _attempt = VerificationAttemptContext(
        registrationId: command.registrationId,
        registrationLabel: registrationId == null ? null : registrationLabel,
        characterName:
            targetCharacter?.characterName ??
            (registrationId == null ? characterName!.trim() : null),
        serverName: targetCharacter?.serverName,
      );
      value = null;
      verdictCode = null;
      await _submit(command);
    } on FormatException {
      failure = const AccountReadException('INVALID_REQUEST');
      _changed();
    }
  }

  Future<void> confirm() async {
    if (!canConfirm) return;
    await _submit(
      ServerVerificationCommand.confirm(
        session,
        challengeId: _challengeId!,
        idempotencyKey: _newKey(),
      ),
    );
  }

  Future<void> cancel() async {
    if (!canCancel) return;
    await _submit(
      ServerVerificationCommand.cancel(
        session,
        challengeId: _challengeId!,
        idempotencyKey: _newKey(),
      ),
    );
  }

  Future<void> _submit(ServerVerificationCommand command) async {
    _recoveryBlocked = false;
    _pending = command;
    _startedAt = now();
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  void _watchTime() {
    _timer?.cancel();
    if (remainingSeconds == 0 && retrySeconds == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds == 0 && retrySeconds == 0) timer.cancel();
      _changed();
    });
  }

  void _fail(AccountReadException error) {
    failure = error;
    if (hasPending &&
        {'IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_EXPIRED'}.contains(error.code)) {
      _recoveryBlocked = true;
    }
    final relative = error.retryAfter == null
        ? null
        : now().add(error.retryAfter!);
    for (final deadline in [relative, error.retryAt]) {
      if (deadline != null &&
          (_retryAt == null || deadline.isAfter(_retryAt!))) {
        _retryAt = deadline;
      }
    }
    _watchTime();
  }

  Future<void> _read(int ticket, AccountReadScope scope) async {
    final result = await client.load(_challengeId!);
    if (!_valid(ticket, scope)) return;
    value = result;
    _observedAt = now();
    if (result.status != ServerVerificationStatus.pending) verdictCode = null;
    if (result.status == ServerVerificationStatus.pending &&
        result.resultCode != null) {
      verdictCode = result.resultCode;
    }
    _watchTime();
  }

  Future<void> reload() async {
    if (!canReload) return;
    final scope = accountReadScope(session), ticket = ++_ticket;
    busy = true;
    failure = null;
    value = null;
    _changed();
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
        _changed();
      }
    }
  }

  Future<void> _send() async {
    final command = _pending!, scope = _pending!.scope, ticket = ++_ticket;
    var writeSettled = false;
    busy = true;
    failure = null;
    _changed();
    try {
      final response = await client.execute(command);
      if (!_valid(ticket, scope)) return;
      _challengeId = response?.challengeId ?? command.challengeId;
      // Success/replay settles this write, but its snapshot may be historical.
      _pending = null;
      writeSettled = true;
      _startedAt = null;
      value = null;
      verdictCode = response?.resultCode;
      await _read(ticket, scope);
    } on AccountReadException catch (error) {
      if (!_valid(ticket, scope)) return;
      _fail(error);
      if (!writeSettled &&
          error.status == 409 &&
          error.code == 'ALREADY_VERIFIED') {
        _pending = null;
        _startedAt = null;
        _alreadyVerified = true;
        value = null;
        if (hasChallenge) {
          try {
            await _read(ticket, scope);
          } catch (_) {
            // Ownership rejection is settled even if the challenge GET fails.
          }
        }
        if (_valid(ticket, scope)) failure = error;
        return;
      }
      // Definitive rejections can be retried as a new user action. Ambiguous
      // responses (including unknown 409s and idempotency errors) keep the command.
      if (!writeSettled &&
          ({400, 403, 404, 422, 429}.contains(error.status) ||
              {
                'REVISION_CONFLICT',
                'VERIFICATION_EXPIRED',
                'VERIFICATION_CANCELLED',
                'IDENTITY_CONFLICT',
                'REGISTRATION_EXISTS',
              }.contains(error.code))) {
        _pending = null;
        if (hasChallenge) {
          value = null;
          try {
            await _read(ticket, scope);
          } on AccountReadException catch (e) {
            if (_valid(ticket, scope)) _fail(e);
          } catch (_) {
            if (_valid(ticket, scope)) {
              _fail(const AccountReadException('INVALID_RESPONSE'));
            }
          }
        }
      }
    } catch (_) {
      if (_valid(ticket, scope)) {
        _fail(const AccountReadException('INVALID_RESPONSE'));
      }
    } finally {
      if (_valid(ticket, scope)) {
        busy = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    _timer?.cancel();
    session.removeListener(_onSession);
    cooldown?.removeListener(_changed);
    super.dispose();
  }
}
