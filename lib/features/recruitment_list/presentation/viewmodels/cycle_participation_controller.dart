import 'dart:async';
import 'dart:convert';
import '../../domain/application_memo_policy.dart';
import '../../data/application_messages.dart';
import 'application_messages_controller.dart';
import '../../data/beta/recruitment_command_transport.dart';
import '../../data/beta/beta_contract.dart';
import '../../data/beta/cycle_group_policy.dart';
import '../../data/beta/recruitment_command.dart';
import '../../data/beta/participation_command_evidence.dart';
import '../../../account/domain/member_raid_models.dart' show raidList;
import '../../../account/domain/role_summary.dart' show roleMap;
import '../../data/cycle_member_actions.dart';
import '../../data/admission_candidates.dart';
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

/// Dialog-owned feedback only. Durable command state remains in the controller.
class CompletionDialogFeedback {
  CompletionDialogFeedback(
    this.controller,
    this.room,
    this.target,
    this.action,
  ) {
    controller._completionDialog = this;
    controller._completionFeedback = true;
    if (matchesPending) {
      code = controller.failure;
      error = controller.failureDetails;
      requestKey = controller.pendingRequestKey;
      controller._detachedCompletionKey = null;
    } else {
      controller.failure = controller.notice = null;
    }
  }
  final CycleParticipationController controller;
  final String room, target, action;
  String? code, requestKey;
  String? targetLabel;
  AccountReadException? error;
  bool active = true,
      queryFailure = false,
      refreshFailed = false,
      committed = false;
  int readFailures = 0;
  bool get matchesPending => controller.matchesCompletion(room, target, action);
  bool get finished =>
      acknowledged &&
      !controller.busy &&
      !controller.hasPending &&
      !refreshFailed &&
      controller.failure == null;
  String? get round =>
      matchesPending ? controller.pendingCompletionRound : null;
  bool get acknowledged =>
      committed ||
      requestKey != null &&
          (controller.completionSuccess?.$1 == requestKey ||
              controller.departureSuccess?.$1 == requestKey ||
              (matchesPending && controller.pendingAcknowledged));

  Future<void> readTargetLabel(String Function(Map) label) async {
    final key = requestKey, savedRound = round;
    if (!active || !matchesPending) return;
    final plan = await controller.scheduleRead(room, target, 'plan');
    if (!active || !matchesPending || requestKey != key) return;
    final items = plan?.data['game_items'] as List? ?? [];
    final item = items
        .where((item) => item['round_id'] == savedRound)
        .firstOrNull;
    if (item is Map) targetLabel = label(item);
  }

  void capture({bool query = false}) {
    if (!active || controller._completionDialog != this) return;
    code = controller.failure;
    error = controller.failureDetails;
    queryFailure = query;
    refreshFailed = controller.completionRefreshFailed && acknowledged;
    if (refreshFailed) error = controller.completionRefreshError;
    if (query && code != null) readFailures++;
  }

  void close() {
    if (!active) return;
    active = false;
    if (controller._completionDialog != this) return;
    if (acknowledged) {
      controller._releasedCompletionKey = requestKey;
    } else if (requestKey != null) {
      controller._detachedCompletionKey = requestKey;
    }
    controller._completionDialog = null;
    // Clearing presentation never releases a journal or cancels a transmission.
    if (controller.completionFeedback && !matchesPending) {
      controller._failure = null;
      controller.failureDetails = null;
      controller.notice = null;
    }
    scheduleMicrotask(() {
      if (!controller._disposed) controller._emit();
    });
  }
}

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
    this.groupEffects = const [],
  }) : evidence = Map.unmodifiable(evidence),
       encoded = jsonEncode(body),
       key = newScopedCommandKey();
  _CycleCommand.restored(
    RecruitmentCommand saved,
    ParticipationCommandEvidence info,
  ) : journal = saved,
      storedEvidence = info,
      path = saved.path,
      encoded = saved.rawBody,
      key = saved.key,
      room = info.room,
      target = info.target,
      createdAt = saved.createdAt,
      method = saved.method,
      status = saved.expectedStatus,
      evidence = info.scope,
      applicationAck = info.kind == 'application',
      applicationId = info.wire['application_id'] as String?,
      applicationState = info.wire['application_state'] as String?,
      globalAck = info.wire['global_ack'] as String?,
      affectedTargets = info.affected,
      submissionAck = info.wire['submission_ack'] as Map<String, dynamic>?,
      resumeAck = null,
      departure = null,
      removal = null,
      removalMode = null,
      membership = null,
      groupEffects = cycleGroupEffects(info.wire['group_policy_effects']);
  RecruitmentCommand? journal;
  ParticipationCommandEvidence? storedEvidence;
  ParticipationCommandEvidence freeze(RecruitmentContractMode mode) {
    if (storedEvidence != null) return storedEvidence!;
    final contract = BetaContract(mode: mode),
        query = contract.query(method, path, {});
    final affected = affectedTargets ?? [target],
        targets = <String>{target, ...affected}.toList();
    final kind = membership != null
        ? 'membership'
        : removal != null
        ? 'removal'
        : departure != null
        ? 'departure'
        : submissionAck != null
        ? 'submission'
        : globalAck != null
        ? 'global'
        : applicationAck
        ? 'application'
        : 'basic';
    final frozen = ParticipationCommandEvidence.create(
      kind: kind,
      groupEffects: groupEffects,
      room: room,
      target: target,
      scope: evidence,
      applicationId: applicationId,
      applicationState: applicationState,
      affected: affected,
      globalAck: globalAck,
      submissionAck: submissionAck,
      details: membership != null
          ? MembershipAckEvidence.fromPreview(membership!).wire
          : removal != null
          ? RemovalAckEvidence.fromPreview(removal!, removalMode!).wire
          : departure != null
          ? DepartureAckEvidence.fromPreview(departure!).wire
          : null,
      method: method,
      path: path,
      rawQuery: jsonEncode(query),
      rawBody: encoded,
      key: key,
      status: status,
      targets: targets,
    );
    journal = RecruitmentCommand(
      owner: RecruitmentCommandOwner.participation,
      operation: contract.operation(method, path)['id'] as String,
      method: method,
      path: path,
      query: query,
      targetCycles: targets,
      rawBody: encoded,
      key: key,
      createdAt: createdAt.toUtc(),
      expectedStatus: status,
      contractMode: mode,
      version: 3,
      validationSnapshot: frozen.wire,
    );
    storedEvidence = frozen;
    return frozen;
  }

  final List<Map<String, dynamic>> groupEffects;
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
    this.onGroupConnectionChanged,
    this.onRelationEnded,
    this.onActiveRoomsChanged,
    this.commandTransport,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _binding = scopeKey();
    if (gateway is ApplicationMessagesGateway &&
        (gateway as ApplicationMessagesGateway).applicationMessagesEnabled) {
      messages = ApplicationMessagesController(
        gateway: gateway as ApplicationMessagesGateway,
        session: session,
        scopeKey: scopeKey,
        changes: changes,
        transport: commandTransport,
        now: this.now,
      );
    }
    session.addListener(_access);
    changes.addListener(_access);
    if (commandTransport != null && session.isAuthenticated) {
      unawaited(restorePending());
    }
  }
  final CycleInteractionGateway gateway;
  ApplicationMessagesController? messages;

  /// Production creation, participation and presets use independent durable slots.
  final RecruitmentCommandTransport? commandTransport;
  final AccountReadSession session;
  final Listenable changes;
  final String Function() scopeKey;
  final Future<void> Function(String)? onMutation;
  final VoidCallback? onGroupConnectionChanged;
  final Future<void> Function(List<String>)? onRelationEnded;
  final void Function(String commandKey)? onActiveRoomsChanged;
  final DateTime Function() now;
  late String _binding;
  bool _disposed = false, busy = false;
  int _epoch = 0, mutationVersion = 0;
  final _managementEpochs = Expando<int>();
  String? lastRoom, lastTarget, notice;
  String? _failure;
  AccountReadException? failureDetails;
  String? get failure => _failure;
  set failure(String? value) {
    _failure = value;
    failureDetails = null;
    completionRefreshFailed = false;
    completionRefreshError = null;
  }

  bool _completionFeedback = false;
  CompletionDialogFeedback? _completionDialog;
  String? _detachedCompletionKey, _releasedCompletionKey;
  bool completionNavigationAllowed(String key) =>
      !busy &&
      key != _detachedCompletionKey &&
      (!completionRefreshFailed || key == _releasedCompletionKey);
  bool matchesCompletion(String room, String target, String action) =>
      session.isAuthenticated &&
      _binding == scopeKey() &&
      _pending?.room == room &&
      _pending?.target == target &&
      switch (action) {
        'complete_item' => _pending!.path.endsWith('/completion'),
        'personal_completion' =>
          _pending!.path.endsWith('/personal-completion-departures') ||
              _pending!.path.endsWith('/personal-completion'),
        _ => false,
      };
  String? get pendingCompletionRound {
    final command = _pending;
    if (command == null) return null;
    final body = jsonDecode(command.encoded) as Map;
    return body['round_id'] as String? ??
        command.path.split('/').reversed.skip(1).firstOrNull;
  }

  bool get pendingCompletion =>
      _pending != null &&
      const {
        'completion',
        'personal-completion',
        'personal-completion-departures',
      }.contains(_pending!.path.split('/').last);

  Future<void> refreshCompletion(String room, String target) async {
    if (_disposed || busy || !session.isAuthenticated) return;
    final e = _epoch;
    busy = true;
    failure = notice = null;
    _completionFeedback = true;
    try {
      await changed(room, target, completion: true);
    } finally {
      if (_valid(e)) {
        busy = false;
        _emit();
      }
    }
  }

  bool get completionFeedback => _completionFeedback;
  bool completionRefreshFailed = false;
  AccountReadException? completionRefreshError;
  _CycleCommand? _pending;
  bool restoring = false;
  String? recoveryIssue;
  String? _publishedKey;
  bool _restoredRequest = false;
  bool get needsReview =>
      recoveryIssue == 'REQUEST_REVIEW_REQUIRED' ||
      (_pending != null &&
          !{
            RecruitmentCommandState.acknowledged,
            RecruitmentCommandState.rejected,
          }.contains(_pending!.journal?.state) &&
          (now().isBefore(_pending!.createdAt) ||
              now().difference(_pending!.createdAt) >=
                  const Duration(hours: 24)));
  String? get pendingKind => _pending?.storedEvidence?.kind;
  bool get pendingAcknowledged =>
      _pending?.journal?.state == RecruitmentCommandState.acknowledged;
  bool get waitingToRetry => _retryAt != null && now().isBefore(_retryAt!);

  (String key, String room, String target)? departureSuccess;
  (String key, String room, String target)? completionSuccess;
  (String key, String room, String target, String member)? removalSuccess;
  (String key, MembershipActionResult result)? membershipSuccess;
  (String key, String room, String target, String intent)? admissionSuccess;
  (String key, String room, List<String> targets)? relationEnded;
  DateTime? _retryAt;
  Timer? _retryTimer;
  (String, String, String, String)? scheduleSuccess;
  String? get pendingRequestKey => _pending?.key;
  bool get hasPending => _pending != null || recoveryIssue != null;

  /// Retained implementation only; see docs/project/INACTIVE_FEATURES.md (IF-001).
  /// Production has no switch to re-enable new closure/resume commands.
  bool get weeklyInterruptionEnabled => false;
  bool get canAct =>
      !_disposed &&
      session.isAuthenticated &&
      !busy &&
      !restoring &&
      !hasPending &&
      (_retryAt == null || !now().isBefore(_retryAt!));
  bool get canRetry {
    if (_disposed || busy || restoring || !session.isAuthenticated) {
      return false;
    }
    if (recoveryIssue != null) {
      return recoveryIssue == 'LOCAL_STORAGE_UNAVAILABLE' && _pending == null;
    }
    final command = _pending;
    if (command == null) return false;
    if ({
      RecruitmentCommandState.acknowledged,
      RecruitmentCommandState.rejected,
    }.contains(command.journal?.state)) {
      return true;
    }
    return !now().isBefore(command.createdAt) &&
        now().difference(command.createdAt) < const Duration(hours: 24) &&
        (_retryAt == null || !now().isBefore(_retryAt!));
  }

  String? get pendingRoom => _pending?.room;
  String? get pendingTarget => _pending?.target;
  void _emit() {
    final feedback = _completionDialog;
    if (_completionFeedback &&
        feedback?.requestKey != null &&
        (feedback!.matchesPending || feedback.acknowledged)) {
      feedback.capture();
    }
    if (!_disposed) notifyListeners();
  }

  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      session.isAuthenticated &&
      scopeKey() == _binding;
  void _access() {
    if (_binding == scopeKey() && session.isAuthenticated) return;
    final feedback = _completionDialog;
    if (feedback != null) {
      feedback.active = false;
      feedback.code = null;
      feedback.error = null;
      feedback.targetLabel = null;
    }
    _completionDialog = null;
    _detachedCompletionKey = _releasedCompletionKey = null;
    _binding = scopeKey();
    _epoch++;
    _pending = null;
    recoveryIssue = null;
    _publishedKey = null;
    _restoredRequest = false;
    restoring = false;
    departureSuccess = null;
    completionSuccess = null;
    removalSuccess = null;
    membershipSuccess = null;
    relationEnded = null;
    admissionSuccess = null;
    scheduleSuccess = null;
    _completionFeedback = false;
    busy = false;
    failure = notice = lastRoom = lastTarget = null;
    _retryAt = null;
    _retryTimer?.cancel();
    _emit();
    if (commandTransport != null && session.isAuthenticated) {
      unawaited(restorePending());
    }
  }

  Future<T?> _read<T>(
    Future<T> Function() f, {
    bool allowPending = false,
    bool completion = false,
  }) async {
    if (!completion && !hasPending && _completionFeedback) {
      failure = notice = null;
    }
    if (!hasPending) _completionFeedback = completion;
    if (allowPending) {
      if (_disposed || !session.isAuthenticated) return null;
      final e = _epoch;
      try {
        final value = await f();
        return _valid(e) ? value : null;
      } on AccountReadException catch (error) {
        if (_valid(e)) {
          failure = error.code;
          failureDetails = error;
          _emit();
        }
      } catch (_) {
        if (_valid(e)) {
          failure = 'INVALID_RESPONSE';
          _emit();
        }
      }
      return null;
    }
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

  Future<List<RecruitmentGroupChoice>?> groups() => _read(gateway.groups);

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
        groupEffects: fresh.groupEffects,
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
    completion: true,
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
    void Function(String key)? onPrepared,
  }) async {
    if (!canAct) return;
    _completionFeedback = true;
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
        groupEffects: fresh.groupEffects,
      );
      onPrepared?.call(_pending!.key);
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
      : _read(
          () => gateway.outcome(room, target, action, round: round),
          completion: true,
        );

  Future<void> complete(CycleOutcomePreview preview) async {
    if (preview.action == 'close_weekly' && !weeklyInterruptionEnabled) return;
    if (!canAct) return;
    _completionFeedback = true;
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
    allowPending: true,
    completion:
        _completionDialog?.room == room && _completionDialog?.target == target,
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

  bool get betaManagementEnabled =>
      gateway is CycleInteractionRepository &&
      (gateway as CycleInteractionRepository).contractMode ==
          RecruitmentContractMode.betaWire2;

  Future<CycleScheduleView?> openingSource(String room, String target) =>
      _read(() async {
        final cycles = await gateway.cycles();
        if (target != cycles.next.key) {
          throw const AccountReadException('TARGET_CYCLE_OUT_OF_RANGE');
        }
        return gateway.scheduleRead(room, cycles.current.key, 'plan');
      });

  Future<CycleManagementPreview?> management(
    String room,
    String target,
    String action, {
    Map<String, dynamic> query = const {},
  }) async {
    final epoch = _epoch;
    final preview = await _read(
      () => gateway.management(room, target, action, query: query),
    );
    if (preview != null) _managementEpochs[preview] = epoch;
    return preview;
  }

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
      if (preview.opening &&
          preview.scope['room_cycle_id'] == null &&
          _managementEpochs[preview] != e) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      // An absent cycle gets new prospective IDs on every GET. Submit the
      // confirmed context seed; the server revalidates its token, policy and
      // source revisions atomically before creating anything.
      final fresh = preview.opening && preview.scope['room_cycle_id'] == null
          ? preview
          : await gateway.management(
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
        groupEffects: fresh.effectsFor(frozenInput['candidate'] as String?),
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
  Future<String?> admit(
    CycleAdmissionPreview preview,
    Set<String> sessions, {
    String? applicationMemo,
    AdmissionCandidateActor? expectedActor,
    bool Function()? isCurrent,
  }) async {
    if (!canAct || isCurrent?.call() == false) return null;
    final memo = applicationMemo == null
        ? null
        : ApplicationMemoPolicy.check(applicationMemo);
    if (memo != null && (preview.intent != 'apply' || !memo.valid)) {
      failure = 'INVALID_REQUEST';
      _emit();
      return null;
    }
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
      if (!_valid(e) || isCurrent?.call() == false) return null;
      if (fresh.confirmationSignature != preview.confirmationSignature) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
      if (expectedActor != null) {
        final candidateGateway = gateway;
        if (candidateGateway is! AdmissionCandidatesGateway) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        final current = await (candidateGateway as AdmissionCandidatesGateway)
            .admissionCandidates(fresh.room, fresh.target, fresh.intent);
        if (!_valid(e) || isCurrent?.call() == false) return null;
        if (current.actor?.signature != expectedActor.signature ||
            expectedActor.participationBinding !=
                fresh.participation?.binding ||
            current.scope['room_cycle_id'] != fresh.scope['room_cycle_id'] ||
            current.scope['target_generation'] !=
                fresh.scope['target_generation'] ||
            current.scope['target_revision'] !=
                fresh.scope['target_revision']) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
      }
      final body = fresh.intent == 'change_character'
          ? await gateway.characterBody(fresh, frozenSessions)
          : fresh.body(frozenSessions);
      if (!_valid(e) || isCurrent?.call() == false) return null;
      if (expectedActor != null) {
        final expected = [
          for (final a in expectedActor.assignments)
            {
              'assignment_id': a['assignment_id'],
              'expected_revision': a['revision'],
            },
        ];
        final actual = raidList(body['assignments']).map(roleMap).toList();
        int order(Map<String, dynamic> a, Map<String, dynamic> b) =>
            (a['assignment_id'] as String).compareTo(
              b['assignment_id'] as String,
            );
        expected.sort(order);
        actual.sort(order);
        if (cycleStableJson(actual) != cycleStableJson(expected) ||
            body['expected_cycle_member_revision'] !=
                expectedActor.wire['cycle_member_revision']) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
      }
      final apply = fresh.intent == 'apply';
      if (memo != null && memo.text.isNotEmpty) {
        body['application_memo'] = memo.text;
      }
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
      final key = _pending!.key;
      await _send(e);
      return _valid(e) ? key : null;
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

  Future<void> restorePending() async {
    if (_disposed ||
        !session.isAuthenticated ||
        commandTransport == null ||
        restoring) {
      return;
    }
    final e = _epoch;
    restoring = true;
    _emit();
    try {
      final saved = await commandTransport!.restore(
        RecruitmentCommandOwner.participation,
      );
      if (!_valid(e)) return;
      if (saved == null) {
        recoveryIssue = null;
        failure = null;
        return;
      }
      if (saved.version != 3 ||
          saved.validationSnapshot == null ||
          saved.path.contains('resume') ||
          saved.path.contains('weekly-incomplete-closures')) {
        recoveryIssue = 'REQUEST_REVIEW_REQUIRED';
        return;
      }
      final info = ParticipationCommandEvidence(saved.validationSnapshot!);
      _pending = _CycleCommand.restored(saved, info);
      _restoredRequest = true;
      _retryAt = saved.retryNotBefore;
      if (saved.state == RecruitmentCommandState.needsReview) {
        recoveryIssue = 'REQUEST_REVIEW_REQUIRED';
        return;
      }
      recoveryIssue = null;
      if (saved.state == RecruitmentCommandState.acknowledged) {
        await _send(e);
      } else if (saved.state == RecruitmentCommandState.rejected) {
        await commandTransport!.releaseResolved(saved.owner, saved.key);
        if (_valid(e)) {
          _pending = null;
          _restoredRequest = false;
          _retryAt = null;
          _retryTimer?.cancel();
          notice = '이전 요청은 반영되지 않았습니다. 현재 상태를 확인한 뒤 다시 시도해 주세요.';
        }
      } else if (_retryAt != null && now().isBefore(_retryAt!)) {
        _retryTimer?.cancel();
        _retryTimer = Timer(_retryAt!.difference(now()), _emit);
      }
    } catch (error) {
      if (_valid(e)) {
        if (_pending?.journal?.state == RecruitmentCommandState.rejected) {
          failure = 'LOCAL_STORAGE_UNAVAILABLE';
          recoveryIssue = null;
        } else {
          recoveryIssue = error is FormatException
              ? 'REQUEST_REVIEW_REQUIRED'
              : 'LOCAL_STORAGE_UNAVAILABLE';
        }
      }
    } finally {
      if (_valid(e)) {
        restoring = false;
        _emit();
      }
    }
  }

  Future<void> retry() async {
    if (!canRetry) return;
    if (_pending == null) {
      await restorePending();
      return;
    }
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
    final completing = const {
      'completion',
      'personal-completion',
      'personal-completion-departures',
    }.contains(command.path.split('/').last);
    _completionFeedback = completing;
    final feedback = _completionDialog;
    if (completing && feedback == null) _detachedCompletionKey = command.key;
    if (completing &&
        feedback != null &&
        matchesCompletion(feedback.room, feedback.target, feedback.action)) {
      feedback.requestKey = command.key;
    }
    try {
      String? resumeOutcome;
      MembershipActionResult? membershipResult;
      var groupPolicyChanged = command.groupEffects.isNotEmpty;
      if (commandTransport != null) {
        final info = command.freeze(commandTransport!.mode),
            journal = command.journal!;
        final raw = await commandTransport!.submit(
          journal,
          validateAck: (raw) {
            info.validate(
              raw,
              method: journal.method,
              path: journal.path,
              key: journal.key,
              status: journal.expectedStatus,
              mode: journal.contractMode,
              rawBody: journal.rawBody,
              original: !journal.usesCycleGroupPolicy,
            );
          },
        );
        if (!_valid(e)) return;
        groupPolicyChanged =
            groupPolicyChanged || cycleGroupEffects(raw).isNotEmpty;
        command.journal = journal.transition(
          state: RecruitmentCommandState.acknowledged,
          rawAck: jsonEncode(raw),
        );
        membershipResult = info.validate(
          raw,
          method: journal.method,
          path: journal.path,
          key: journal.key,
          status: journal.expectedStatus,
          mode: journal.contractMode,
          rawBody: journal.rawBody,
          original: !journal.usesCycleGroupPolicy,
        );
      } else if (command.membership != null) {
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
      final receiving = _completionDialog;
      if (completing &&
          receiving?.active == true &&
          receiving?.requestKey == command.key) {
        receiving!.committed = true;
      }
      if (!_restoredRequest &&
          (command.path.endsWith('/applications') ||
              command.path.endsWith('/join') ||
              command.path.endsWith('/character-changes'))) {
        admissionSuccess = (
          command.key,
          command.room,
          command.target,
          command.path.endsWith('/applications')
              ? 'apply'
              : command.path.endsWith('/join')
              ? 'join'
              : 'change_character',
        );
      }
      if (membershipResult != null) {
        if (!_restoredRequest) {
          membershipSuccess = (command.key, membershipResult);
        }
        notice = '요청이 반영되었습니다.';
      }
      if (!_restoredRequest && command.path.endsWith('/completion')) {
        completionSuccess = (command.key, command.room, command.target);
      }
      if (!_restoredRequest &&
          (command.departure != null ||
              command.storedEvidence?.kind == 'departure')) {
        departureSuccess = (command.key, command.room, command.target);
      }
      if (!_restoredRequest &&
          (command.removal != null ||
              command.storedEvidence?.kind == 'removal')) {
        removalSuccess = (
          command.key,
          command.room,
          command.target,
          command.removal!.member,
        );
      }
      if (!_restoredRequest &&
          (command.path.endsWith('/schedule-proposals') ||
              command.path.endsWith('/responses') ||
              command.path.endsWith('/availability-submission'))) {
        scheduleSuccess = (
          command.key,
          command.room,
          command.target,
          command.path,
        );
      }
      if (commandTransport != null && _publishedKey == command.key) {
        await commandTransport!.releaseResolved(
          RecruitmentCommandOwner.participation,
          command.key,
        );
        if (_valid(e)) {
          _pending = null;
          _restoredRequest = false;
          failure = null;
        }
        return;
      }
      if (commandTransport == null) _pending = null;
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
      // Only the viewer's room-set changes invalidate this app-owned read.
      // One notification covers C/N effects and includes restored successful ACKs.
      if (const {
        'join',
        'continuation-participations',
        'recruitment-openings',
        'participation-cancellations',
        'leave',
        'end',
        'membership-actions',
        'completion',
        'personal-completion',
        'personal-completion-departures',
      }.contains(command.path.split('/').last)) {
        onActiveRoomsChanged?.call(command.key);
      }
      if (groupPolicyChanged ||
          (commandTransport == null &&
              command.path.endsWith('/common-settings') &&
              (jsonDecode(command.encoded) as Map)['group_id'] != null)) {
        onGroupConnectionChanged?.call();
      }
      for (final target in command.affectedTargets ?? [command.target]) {
        if (!_valid(e)) return;
        await changed(
          command.room,
          target,
          completion: completing,
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
              ([
                command.evidence['current_cycle_key'] as String,
                const PartyCyclePolicy().keyFor(
                  const PartyCyclePolicy()
                      .fromKey(command.evidence['current_cycle_key'] as String)!
                      .endsAt,
                ),
              ]).where((t) => !membershipResult!.affected.contains(t)),
            ),
          );
        } catch (_) {
          if (_valid(e)) notice = '요청은 반영되었습니다. 최신 상태를 다시 불러와 주세요.';
        }
      }
      if (commandTransport != null && _valid(e)) {
        _publishedKey = command.key;
        await commandTransport!.releaseResolved(
          RecruitmentCommandOwner.participation,
          command.key,
        );
        if (!_valid(e)) return;
        _pending = null;
        _restoredRequest = false;
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
      if (commandTransport != null) {
        if (error.code == 'REQUEST_REVIEW_REQUIRED') {
          recoveryIssue = error.code;
        }
        if (definiteRecruitmentRejection(error.status, error.code)) {
          try {
            final saved = await commandTransport!.restore(
              RecruitmentCommandOwner.participation,
            );
            if (!_valid(e)) return;
            if (saved?.state == RecruitmentCommandState.rejected &&
                saved?.key == command.key) {
              command.journal = saved;
              await commandTransport!.releaseResolved(
                RecruitmentCommandOwner.participation,
                command.key,
              );
              if (_valid(e)) {
                _pending = null;
                _restoredRequest = false;
                _retryAt = null;
                _retryTimer?.cancel();
                notice = '현재 상태를 다시 확인한 뒤 시도해 주세요.';
              }
            }
          } catch (_) {
            if (_valid(e)) failure = 'LOCAL_STORAGE_UNAVAILABLE';
          }
        }
        return;
      }
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
    } catch (error) {
      if (_valid(e)) {
        failure = 'INVALID_RESPONSE';
        if (commandTransport != null &&
            command.journal?.state == RecruitmentCommandState.acknowledged) {
          if (error is FormatException) {
            recoveryIssue = 'REQUEST_REVIEW_REQUIRED';
          } else {
            failure = 'LOCAL_STORAGE_UNAVAILABLE';
            notice = '요청은 반영되었습니다. 결과 정리를 다시 시도해 주세요.';
          }
        }
      }
    }
  }

  Future<void> changed(
    String room,
    String target, {
    bool applied = true,
    String? outcomeNotice,
    bool completion = false,
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
    } catch (error) {
      if (_valid(e)) {
        if (completion && applied) {
          _completionFeedback = true;
          completionRefreshError = error is AccountReadException
              ? error
              : const AccountReadException('INVALID_RESPONSE');
          completionRefreshFailed = true;
          notice = '완료 처리되었습니다. 최신 상태를 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
          return;
        }
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
    failureDetails = e;
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
    messages?.dispose();
    _epoch++;
    _retryTimer?.cancel();
    session.removeListener(_access);
    changes.removeListener(_access);
    super.dispose();
  }
}
