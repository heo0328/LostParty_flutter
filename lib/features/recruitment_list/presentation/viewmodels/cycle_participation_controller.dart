import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../data/cycle_management.dart';
import '../../data/cycle_schedule.dart';
import '../../data/cycle_outcome.dart';
import '../../domain/backend_recruitment.dart';

class _CycleCommand {
  _CycleCommand({
    required this.path,
    required Map<String, dynamic> body,
    required this.room,
    required this.target,
    required this.applicationAck,
    required this.status,
    required this.createdAt,
    required Map<String, dynamic> evidence,
    this.applicationId,
    this.applicationState,
    this.method = 'POST',
    this.globalAck,
    this.affectedTargets,
    this.submissionAck,
  }) : evidence = Map.unmodifiable(evidence),
       encoded = jsonEncode(body),
       key = newScopedCommandKey();
  final String path, encoded, key, room, target;
  final String? applicationId, applicationState;
  final String method;
  final String? globalAck;
  final List<String>? affectedTargets;
  final Map<String, dynamic>? submissionAck;
  final bool applicationAck;
  final int status;
  final DateTime createdAt;
  final Map<String, dynamic> evidence;
}

/// App-owned command recovery. Reads never substitute for an original write ACK.
class CycleParticipationController extends ChangeNotifier {
  CycleParticipationController({
    required this.gateway,
    required this.session,
    required this.changes,
    required this.scopeKey,
    this.onMutation,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _binding = scopeKey();
    session.addListener(_access);
    changes.addListener(_access);
  }
  final CycleInteractionGateway gateway;
  final AccountReadSession session;
  final Listenable changes;
  final String Function() scopeKey;
  final Future<void> Function(String)? onMutation;
  final DateTime Function() now;
  late String _binding;
  bool _disposed = false, busy = false;
  int _epoch = 0, mutationVersion = 0;
  String? failure, lastRoom, lastTarget, notice;
  _CycleCommand? _pending;
  DateTime? _retryAt;
  Timer? _retryTimer;
  bool get hasPending => _pending != null;
  bool get canAct =>
      !_disposed &&
      session.isAuthenticated &&
      !busy &&
      !hasPending &&
      (_retryAt == null || !now().isBefore(_retryAt!));
  bool get canRetry =>
      !busy &&
      session.isAuthenticated &&
      _pending != null &&
      now().difference(_pending!.createdAt) < const Duration(hours: 24) &&
      (_retryAt == null || !now().isBefore(_retryAt!));
  String? get pendingRoom => _pending?.room;
  String? get pendingTarget => _pending?.target;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      session.isAuthenticated &&
      scopeKey() == _binding;
  void _access() {
    if (_binding == scopeKey() && session.isAuthenticated) return;
    _binding = scopeKey();
    _epoch++;
    _pending = null;
    busy = false;
    failure = notice = lastRoom = lastTarget = null;
    _retryAt = null;
    _retryTimer?.cancel();
    _emit();
  }

  Future<T?> _read<T>(Future<T> Function() f) async {
    if (!canAct) return null;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final result = await f();
      return _valid(e) ? result : null;
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
    return null;
  }

  Future<List<RecruitmentCharacter>?> characters() => _read(gateway.characters);
  Future<CycleOutcomePreview?> outcome(
    String room,
    String target,
    String action, {
    String? round,
  }) => _read(() => gateway.outcome(room, target, action, round: round));

  Future<void> complete(CycleOutcomePreview preview) async {
    if (!canAct) return;
    final room = preview.plan.room, target = preview.plan.target;
    final action = preview.action,
        round = preview.round,
        signature = preview.signature;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await gateway.outcome(room, target, action, round: round);
      if (!_valid(e)) return;
      if (fresh.signature != signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = fresh.body();
      _pending = _CycleCommand(
        path: fresh.path,
        body: body,
        room: room,
        target: target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.scope,
      );
      await _send(e);
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<CycleScheduleView?> scheduleRead(
    String room,
    String target,
    String kind, {
    String? id,
    String? cursor,
  }) => _read(
    () => gateway.scheduleRead(room, target, kind, id: id, cursor: cursor),
  );
  Future<CycleSchedulePreview?> schedulePreview(
    String room,
    String target,
    String action, {
    String? id,
  }) => _read(() => gateway.schedulePreview(room, target, action, id: id));
  Future<void> scheduleCommand(
    CycleSchedulePreview preview,
    Map<String, dynamic> input,
  ) async {
    if (!canAct) return;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final frozenInput = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
      final fresh = await gateway.schedulePreview(
        preview.plan.room,
        preview.plan.target,
        preview.action,
        id: preview.id,
      );
      if (!_valid(e)) return;
      if (fresh.signature != preview.signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = fresh.body(frozenInput);
      _pending = _CycleCommand(
        path: fresh.path,
        body: body,
        room: fresh.plan.room,
        target: fresh.plan.target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.plan.scope,
        method: fresh.method,
        submissionAck: fresh.submissionEvidence,
      );
      await _send(e);
    } on FormatException {
      if (_valid(e)) failure = 'INVALID_REQUEST';
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<CycleManagementPreview?> management(
    String room,
    String target,
    String action, {
    Map<String, dynamic> query = const {},
  }) => _read(() => gateway.management(room, target, action, query: query));

  Future<void> manage(
    CycleManagementPreview preview,
    Map<String, dynamic> input,
  ) async {
    if (!canAct) return;
    final frozenInput = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await gateway.management(
        preview.room,
        preview.target,
        preview.action,
        query: preview.query,
      );
      if (!_valid(e)) return;
      if (fresh.signature != preview.signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = fresh.body(frozenInput);
      _pending = _CycleCommand(
        path: fresh.path,
        body: body,
        room: fresh.room,
        target: fresh.target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.evidence,
        method: fresh.method,
        globalAck: fresh.global ? fresh.action : null,
        affectedTargets: List.unmodifiable(fresh.affected),
      );
      await _send(e);
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<CycleAdmissionPreview?> preview(
    String room,
    String target,
    String character,
    String role,
    String intent,
  ) => _read(() => gateway.admission(room, target, character, role, intent));
  Future<CycleApplicationView?> review(
    String application,
    String target, {
    String? expectedRoom,
  }) => _read(() async {
    final view = await gateway.application(application, target);
    if (expectedRoom != null && view.room != expectedRoom) {
      throw const AccountReadException('INVALID_RESPONSE');
    }
    return view;
  });
  Future<Map<String, dynamic>?> applications(
    String room,
    String target, {
    String? cursor,
  }) => _read(() => gateway.applicationPage(room, target, cursor: cursor));
  Future<void> admit(
    CycleAdmissionPreview preview,
    Set<String> sessions,
  ) async {
    if (!canAct) return;
    final frozenSessions = Set<String>.unmodifiable(sessions);
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await gateway.admission(
        preview.room,
        preview.target,
        preview.character,
        preview.role,
        preview.intent,
      );
      if (!_valid(e)) return;
      if (fresh.confirmationSignature != preview.confirmationSignature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = fresh.intent == 'change_character'
          ? await gateway.characterBody(fresh, frozenSessions)
          : fresh.body(frozenSessions);
      if (!_valid(e)) return;
      final apply = fresh.intent == 'apply';
      _pending = _CycleCommand(
        path:
            '/v2/raid-rooms/${fresh.room}/${apply
                ? 'applications'
                : fresh.intent == 'join'
                ? 'join'
                : 'character-changes'}',
        body: body,
        room: fresh.room,
        target: fresh.target,
        applicationAck: apply,
        applicationState: apply ? 'pending' : null,
        status: apply ? 201 : 200,
        createdAt: now(),
        evidence: fresh.scope,
      );
      await _send(e);
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> decide(CycleApplicationView preview, String action) async {
    if (!canAct || !{'approve', 'reject', 'withdraw'}.contains(action)) return;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await gateway.application(
        preview.data['application_id'] as String,
        preview.target,
      );
      if (!_valid(e)) return;
      if (fresh.data['revision'] != preview.data['revision'] ||
          fresh.data['target_generation'] !=
              preview.data['target_generation'] ||
          fresh.room != preview.room ||
          fresh.scope['room_cycle_id'] != preview.scope['room_cycle_id'] ||
          fresh.scope['target_revision'] != preview.scope['target_revision']) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = await gateway.decisionBody(fresh, action);
      if (!_valid(e)) return;
      _pending = _CycleCommand(
        path:
            '/v2/raid-room-applications/${fresh.data['application_id']}/$action',
        body: body,
        room: fresh.room,
        target: fresh.target,
        applicationId: fresh.data['application_id'] as String,
        applicationAck: action != 'approve',
        applicationState: action == 'reject'
            ? 'rejected'
            : action == 'withdraw'
            ? 'withdrawn'
            : null,
        status: 200,
        createdAt: now(),
        evidence: fresh.scope,
      );
      await _send(e);
    } on AccountReadException catch (error) {
      if (_valid(e)) _fail(error);
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> retry() async {
    if (!canRetry) return;
    final e = _epoch;
    busy = true;
    failure = null;
    _emit();
    try {
      await _send(e);
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> _send(int e) async {
    final command = _pending!;
    try {
      await gateway.write(
        command.path,
        command.key,
        jsonDecode(command.encoded) as Map<String, dynamic>,
        room: command.room,
        target: command.target,
        applicationAck: command.applicationAck,
        expectedScope: command.evidence,
        applicationId: command.applicationId,
        applicationState: command.applicationState,
        status: command.status,
        method: command.method,
        globalAck: command.globalAck,
        affectedTargets: command.affectedTargets,
        submissionAck: command.submissionAck,
      );
      if (!_valid(e)) return;
      _pending = null;
      _retryAt = null;
      failure = null;
      for (final target in command.affectedTargets ?? [command.target]) {
        if (!_valid(e)) return;
        await changed(command.room, target);
      }
    } on AccountReadException catch (error) {
      if (!_valid(e)) return;
      _fail(error);
      if ({400, 403, 404, 413}.contains(error.status) ||
          (error.status == 409 &&
              !{
                'REQUEST_IN_PROGRESS',
                'IDEMPOTENCY_EXPIRED',
              }.contains(error.code))) {
        _pending = null;
        notice = '현재 상태를 다시 확인한 뒤 시도해 주세요.';
        for (final target in command.affectedTargets ?? [command.target]) {
          if (!_valid(e)) return;
          await changed(command.room, target, applied: false);
        }
      }
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    }
  }

  Future<void> changed(
    String room,
    String target, {
    bool applied = true,
  }) async {
    if (_disposed || !session.isAuthenticated) return;
    final e = _epoch;
    lastRoom = room;
    lastTarget = target;
    mutationVersion++;
    if (applied) notice = '$target 주차에 반영되었습니다.';
    _emit();
    try {
      await onMutation?.call(target);
    } catch (_) {
      if (_valid(e)) {
        notice = applied
            ? '요청은 반영되었습니다. 최신 상태를 다시 불러와 주세요.'
            : '최신 상태를 다시 불러와 주세요.';
      }
    }
  }

  void _fail(AccountReadException e) {
    failure = e.code;
    _retryAt =
        e.retryAt ?? (e.retryAfter == null ? null : now().add(e.retryAfter!));
    _retryTimer?.cancel();
    if (_retryAt != null && now().isBefore(_retryAt!)) {
      _retryTimer = Timer(_retryAt!.difference(now()), _emit);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _retryTimer?.cancel();
    session.removeListener(_access);
    changes.removeListener(_access);
    super.dispose();
  }
}
