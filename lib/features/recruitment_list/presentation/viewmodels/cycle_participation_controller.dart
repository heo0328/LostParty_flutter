import 'dart:async';
import 'dart:convert';
import '../../data/cycle_member_actions.dart';
import '../../data/membership_actions.dart';
import 'package:flutter/foundation.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../data/cycle_management.dart';
import '../../data/cycle_schedule.dart';
import '../../data/cycle_outcome.dart';
import '../../data/cycle_resume.dart';
import '../../domain/backend_recruitment.dart';
import '../../domain/policies/party_cycle_policy.dart';

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
    this.resumeAck,
    this.departure,
    this.removal,
    this.removalMode,
    this.membership,
  }) : evidence = Map.unmodifiable(evidence),
       encoded = jsonEncode(body),
       key = newScopedCommandKey();
  final String path, encoded, key, room, target;
  final String? applicationId, applicationState;
  final String method;
  final String? globalAck;
  final List<String>? affectedTargets;
  final Map<String, dynamic>? submissionAck;
  final String? resumeAck;
  final DeparturePreview? departure;
  final RemovalPreview? removal;
  final String? removalMode;
  final MembershipActionPreview? membership;
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
    this.onRelationEnded,
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
  final Future<void> Function(List<String>)? onRelationEnded;
  final DateTime Function() now;
  late String _binding;
  bool _disposed = false, busy = false;
  int _epoch = 0, mutationVersion = 0;
  String? failure, lastRoom, lastTarget, notice;
  _CycleCommand? _pending;
  (String key, String room, String target)? departureSuccess;
  (String key, String room, String target, String member)? removalSuccess;
  (String key, MembershipActionResult result)? membershipSuccess;
  (String key, String room, List<String> targets)? relationEnded;
  DateTime? _retryAt;
  Timer? _retryTimer;
  bool get hasPending => _pending != null;

  /// Retained implementation only; see docs/project/INACTIVE_FEATURES.md (IF-001).
  /// Production has no switch to re-enable new closure/resume commands.
  bool get weeklyInterruptionEnabled => false;
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
    departureSuccess = null;
    removalSuccess = null;
    membershipSuccess = null;
    relationEnded = null;
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
  Future<MembershipActionContext?> membershipContext(
    String room,
    String view,
  ) => _read(
    () => (gateway as MembershipActionGateway).membershipContext(room, view),
  );

  Future<String?> performMembershipAction(
    MembershipActionPreview preview, {
    required bool Function() isCurrent,
    void Function(String key)? onPrepared,
  }) async {
    // Leadership recovery UI remains a separate product proposal.
    if (preview.action == 'recover_leadership' || !canAct || !isCurrent()) {
      return null;
    }
    final e = _epoch;
    String? key;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final context = await (gateway as MembershipActionGateway)
          .membershipContext(preview.room, preview.view);
      if (!_valid(e) || !isCurrent()) return null;
      final fresh = context.select(preview.action);
      if (fresh.signature != preview.signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      _pending = _CycleCommand(
        path: fresh.path,
        body: fresh.body(),
        room: fresh.room,
        target: fresh.view,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: context.scope,
        membership: fresh,
        affectedTargets: fresh.affected,
      );
      key = _pending!.key;
      onPrepared?.call(key);
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
    return key;
  }

  Future<CycleResumePlan?> resumePlan(String room, String target) =>
      weeklyInterruptionEnabled
      ? _read(() => gateway.resumePlan(room, target))
      : Future.value(null);
  Future<CycleResumePreview?> resumePreview(
    String room,
    String target, {
    String? proposalId,
    List<dynamic>? groups,
  }) => weeklyInterruptionEnabled
      ? _read(
          () => gateway.resumePreview(
            room,
            target,
            proposalId: proposalId,
            groups: groups,
          ),
        )
      : Future.value(null);
  Future<void> resume(CycleResumePreview preview, {String? response}) async {
    if (!weeklyInterruptionEnabled || !canAct) return;
    final room = preview.plan.room,
        target = preview.plan.target,
        id = preview.proposalId;
    final signature = preview.signature;
    final groups =
        jsonDecode(jsonEncode(preview.originalBody['schedule_groups']))
            as List<dynamic>?;
    final frozenResponse = response;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await gateway.resumePreview(
        room,
        target,
        proposalId: id,
        groups: groups,
      );
      if (!_valid(e)) return;
      if (signature != fresh.signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final body = fresh.body(response: frozenResponse);
      _pending = _CycleCommand(
        path: fresh.path,
        body: body,
        room: room,
        target: target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.plan.scope,
        resumeAck: id == null ? 'create' : 'respond',
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

  Future<DeparturePreview?> departure(
    String room,
    String target,
    String round,
  ) => _read(
    () => (gateway as CycleDepartureGateway).departure(room, target, round),
  );

  Future<RemovalPreview?> removal(String room, String target, String member) =>
      _read(
        () => (gateway as CycleRemovalGateway).removal(room, target, member),
      );

  Future<String?> removeMember(
    RemovalPreview preview,
    String mode, {
    required String membership,
    required bool Function() isCurrent,
    void Function(String)? onPrepared,
  }) async {
    if (!canAct || !isCurrent()) return null;
    final e = _epoch;
    String? key;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await (gateway as CycleRemovalGateway).removal(
        preview.room,
        preview.target,
        preview.member,
      );
      if (!_valid(e) || !isCurrent()) return null;
      if (fresh.membership != membership ||
          preview.membership != membership ||
          fresh.signature(mode) != preview.signature(mode)) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      _pending = _CycleCommand(
        path: fresh.path,
        body: fresh.body(mode),
        room: fresh.room,
        target: fresh.target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.scope,
        removal: fresh,
        removalMode: mode,
        affectedTargets: List.unmodifiable(fresh.affected(mode)),
      );
      key = _pending!.key;
      onPrepared?.call(key);
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
    return key;
  }

  Future<void> depart(
    DeparturePreview preview, {
    bool Function()? isCurrent,
  }) async {
    if (!canAct) return;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _emit();
    try {
      final fresh = await (gateway as CycleDepartureGateway).departure(
        preview.room,
        preview.target,
        preview.round,
      );
      if (!_valid(e)) return;
      if (isCurrent?.call() == false) return;
      if (fresh.signature != preview.signature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      _pending = _CycleCommand(
        path: fresh.path,
        body: fresh.body(),
        room: fresh.room,
        target: fresh.target,
        applicationAck: false,
        status: 200,
        createdAt: now(),
        evidence: fresh.scope,
        departure: fresh,
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

  Future<CycleOutcomePreview?> outcome(
    String room,
    String target,
    String action, {
    String? round,
  }) => action == 'close_weekly' && !weeklyInterruptionEnabled
      ? Future.value(null)
      : _read(() => gateway.outcome(room, target, action, round: round));

  Future<void> complete(CycleOutcomePreview preview) async {
    if (preview.action == 'close_weekly' && !weeklyInterruptionEnabled) return;
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

  /// Visibility hint only; the dialog rechecks the current global permission.
  Future<bool> canEndRoom(String room, String target) async {
    if (_disposed || !session.isAuthenticated) return false;
    final epoch = _epoch;
    try {
      final preview = await gateway.management(room, target, 'end');
      return _valid(epoch) &&
          (preview.data['permission'] as Map)['allowed'] == true;
    } catch (_) {
      return false;
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
      String? resumeOutcome;
      MembershipActionResult? membershipResult;
      if (command.membership != null) {
        membershipResult = await (gateway as MembershipActionGateway)
            .writeMembershipAction(
              command.membership!,
              command.key,
              jsonDecode(command.encoded) as Map<String, dynamic>,
            );
      } else if (command.removal != null) {
        await (gateway as CycleRemovalGateway).writeRemoval(
          command.removal!,
          command.removalMode!,
          command.key,
          jsonDecode(command.encoded) as Map<String, dynamic>,
        );
      } else if (command.departure != null) {
        await (gateway as CycleDepartureGateway).writeDeparture(
          command.departure!,
          command.key,
          jsonDecode(command.encoded) as Map<String, dynamic>,
        );
      } else {
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
          resumeAck: command.resumeAck,
          onOutcome: command.resumeAck == null
              ? null
              : (v) => resumeOutcome = v,
        );
      }
      if (!_valid(e)) return;
      if (membershipResult != null) {
        membershipSuccess = (command.key, membershipResult);
        notice = '요청이 반영되었습니다.';
      }
      if (command.departure != null) {
        departureSuccess = (command.key, command.room, command.target);
      }
      if (command.removal != null) {
        removalSuccess = (
          command.key,
          command.room,
          command.target,
          command.removal!.member,
        );
      }
      _pending = null;
      _retryAt = null;
      failure = null;
      if (membershipResult != null) {
        // Publish the final ACK before any optional read. Empty effects still end
        // a persistent relation; this is not a fabricated target mutation.
        if (membershipResult.actorEnded) {
          final c = command.evidence['current_cycle_key'] as String;
          const policy = PartyCyclePolicy();
          relationEnded = (
            command.key,
            command.room,
            List.unmodifiable([c, policy.keyFor(policy.fromKey(c)!.endsAt)]),
          );
        }
        _emit();
        if (!_valid(e)) return;
      }
      for (final target in command.affectedTargets ?? [command.target]) {
        if (!_valid(e)) return;
        await changed(
          command.room,
          target,
          outcomeNotice: command.resumeAck == null
              ? null
              : resumeOutcome == 'applied'
              ? '$target 주차가 재개되었습니다. 새 일정과 참가 확인 상태를 확인해 주세요.'
              : command.resumeAck == 'create'
              ? '재개 제안이 등록되었습니다. 참가자 응답을 기다립니다.'
              : '응답이 기록되었습니다. 아직 재개되지 않았습니다.',
        );
      }
      if (membershipResult?.actorEnded == true && _valid(e)) {
        try {
          await onRelationEnded?.call(
            List.unmodifiable(
              relationEnded!.$3.where(
                (t) => !membershipResult!.affected.contains(t),
              ),
            ),
          );
        } catch (_) {
          if (_valid(e)) notice = '요청은 반영되었습니다. 최신 상태를 다시 불러와 주세요.';
        }
      }
      if (weeklyInterruptionEnabled &&
          command.resumeAck != null &&
          resumeOutcome == 'applied' &&
          _valid(e)) {
        // An original applied ACK is final even if reading the new graph fails.
        try {
          final plan = await gateway.scheduleRead(
            command.room,
            command.target,
            'plan',
          );
          if (!_valid(e)) return;
          final waiting = (plan.data['my_participations'] as List)
              .where(
                (p) =>
                    p['state'] == 'active' &&
                    p['confirmation_state'] != 'confirmed',
              )
              .length;
          notice = '${notice ?? ''} 내 참가 확인 대기 $waiting건.';
        } catch (_) {
          if (_valid(e)) notice = '${notice ?? ''} 새 일정을 다시 불러와 주세요.';
        }
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
    String? outcomeNotice,
  }) async {
    if (_disposed || !session.isAuthenticated) return;
    final e = _epoch;
    lastRoom = room;
    lastTarget = target;
    mutationVersion++;
    if (applied) notice = outcomeNotice ?? '$target 주차에 반영되었습니다.';
    _emit();
    try {
      await onMutation?.call(target);
    } catch (_) {
      if (_valid(e)) {
        notice = outcomeNotice != null
            ? '$outcomeNotice 최신 상태를 다시 불러와 주세요.'
            : applied
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
