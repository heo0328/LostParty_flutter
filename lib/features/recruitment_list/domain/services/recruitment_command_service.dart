import '../entities/party_recruitment.dart';
import '../entities/active_raid_assignment.dart';
import '../entities/recruitment_aggregate.dart';
import '../entities/recruitment_application.dart';
import '../policies/approval_policy.dart';
import '../policies/party_composition_policy.dart';
import '../repositories/recruitment_state_repository.dart';
import '../repositories/active_raid_assignment_repository.dart';
import '../repositories/weekly_raid_clear_repository.dart';
import '../policies/weekly_raid_reset_policy.dart';
import '../state/recruitment_state_machine.dart';
import 'recruitment_runtime.dart';

enum LocalRecruitmentFailure {
  none,
  unauthenticated,
  notFound,
  idConflict,
  revisionConflict,
  domainRejected,
}

class LocalRecruitmentResult {
  const LocalRecruitmentResult._({
    required this.isSuccess,
    required this.failure,
    this.aggregate,
    this.domainFailure = RecruitmentCommandFailure.none,
  });

  const LocalRecruitmentResult.success(RecruitmentAggregate aggregate)
    : this._(
        isSuccess: true,
        failure: LocalRecruitmentFailure.none,
        aggregate: aggregate,
      );

  const LocalRecruitmentResult.failure(
    LocalRecruitmentFailure failure, {
    RecruitmentAggregate? aggregate,
    RecruitmentCommandFailure domainFailure = RecruitmentCommandFailure.none,
  }) : this._(
         isSuccess: false,
         failure: failure,
         aggregate: aggregate,
         domainFailure: domainFailure,
       );

  final bool isSuccess;
  final LocalRecruitmentFailure failure;
  final RecruitmentAggregate? aggregate;
  final RecruitmentCommandFailure domainFailure;
}

class RecruitmentCommandService {
  const RecruitmentCommandService({
    required this.session,
    required this.clock,
    required this.idGenerator,
    required this.repository,
    this.weeklyClearRepository,
    this.assignmentRepository,
    this.stateMachine = const RecruitmentStateMachine(),
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final UserSession session;
  final RecruitmentClock clock;
  final RecruitmentIdGenerator idGenerator;
  final RecruitmentStateRepository repository;
  final WeeklyRaidClearRepository? weeklyClearRepository;
  final ActiveRaidAssignmentRepository? assignmentRepository;
  final RecruitmentStateMachine stateMachine;
  final WeeklyRaidResetPolicy resetPolicy;

  String? get currentUserId => session.currentUserId;

  Future<int> countPendingApplications({
    required String characterId,
    required String raidId,
  }) async {
    final userId = session.currentUserId;
    if (userId == null) return 0;
    return repository.countPendingApplications(
      applicantUserId: userId,
      characterId: characterId,
      raidId: raidId,
    );
  }

  Future<LocalRecruitmentResult> createRecruitment({
    required String title,
    required RecruitmentMetadata metadata,
    required String leaderCharacterId,
    required String leaderClassName,
    required PartyRole leaderRole,
    required ApprovalPolicy approvalPolicy,
    required PartyCompositionPolicy compositionPolicy,
  }) async {
    final userId = session.currentUserId;
    if (userId == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.unauthenticated,
      );
    }
    final id = idGenerator.nextId();
    final timestamp = clock.now();
    final aggregate = RecruitmentAggregate(
      id: id,
      title: title,
      metadata: metadata,
      state: RecruitmentState(
        leaderUserId: userId,
        approvalPolicy: approvalPolicy,
        compositionPolicy: compositionPolicy,
        members: [
          RecruitmentPartyMember(
            userId: userId,
            characterId: leaderCharacterId,
            className: leaderClassName,
            role: leaderRole,
            partyIndex: 0,
          ),
        ],
      ),
      revision: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final assignment = _assignmentFor(
      aggregate: aggregate,
      userId: userId,
      characterId: leaderCharacterId,
    );
    final acquisitionFailure = await _acquire(assignment, aggregate);
    if (acquisitionFailure != null) return acquisitionFailure;
    if (!await repository.create(aggregate)) {
      await _release(assignment);
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.idConflict,
      );
    }
    await _supersedeOtherPending(assignment, timestamp);
    return LocalRecruitmentResult.success(aggregate);
  }

  Future<LocalRecruitmentResult> apply({
    required String recruitmentId,
    required String characterId,
    required String className,
    required PartyRole role,
  }) async {
    final userId = session.currentUserId;
    if (userId == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.unauthenticated,
      );
    }
    final current = await repository.getById(recruitmentId);
    if (current == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.notFound,
      );
    }
    final clearRepository = weeklyClearRepository;
    if (clearRepository != null &&
        await clearRepository.hasClear(
          userId: userId,
          characterId: characterId,
          raidId: current.metadata.raidId,
          resetWeekKey: resetPolicy.weekFor(clock.now()).key,
        )) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure: RecruitmentCommandFailure.weeklyRaidAlreadyCleared,
      );
    }
    return _change(
      recruitmentId,
      (aggregate, currentUserId) {
        return stateMachine.apply(
          state: aggregate.state,
          application: RecruitmentApplication(
            applicantUserId: currentUserId,
            characterId: characterId,
            className: className,
            requestedRole: role,
          ),
        );
      },
      confirmedAssignment: (aggregate, transition) {
        final application = transition.state.applications[userId];
        if (application?.status != RecruitmentApplicationStatus.approved) {
          return null;
        }
        return _assignmentFor(
          aggregate: aggregate,
          userId: userId,
          characterId: characterId,
        );
      },
    );
  }

  Future<LocalRecruitmentResult> withdraw(String recruitmentId) =>
      _change(recruitmentId, (aggregate, userId) {
        return stateMachine.withdraw(
          state: aggregate.state,
          applicantUserId: userId,
          actorUserId: userId,
        );
      });

  Future<LocalRecruitmentResult> changeCharacter({
    required String recruitmentId,
    required String characterId,
    required String className,
    bool cancelPendingApplications = false,
  }) async {
    final userId = session.currentUserId;
    if (userId == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.unauthenticated,
      );
    }
    final current = await repository.getById(recruitmentId);
    if (current == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.notFound,
      );
    }
    final currentMember = current.state.members
        .where((member) => member.userId == userId)
        .firstOrNull;
    if (currentMember == null) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure: RecruitmentCommandFailure.unauthorized,
      );
    }
    final pendingCount = await repository.countPendingApplications(
      applicantUserId: userId,
      characterId: characterId,
      raidId: current.metadata.raidId,
    );
    if (pendingCount > 0 && !cancelPendingApplications) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure:
            RecruitmentCommandFailure.pendingApplicationsRequireConfirmation,
      );
    }
    final clearRepository = weeklyClearRepository;
    if (clearRepository != null &&
        await clearRepository.hasClear(
          userId: userId,
          characterId: characterId,
          raidId: current.metadata.raidId,
          resetWeekKey: resetPolicy.weekFor(clock.now()).key,
        )) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure: RecruitmentCommandFailure.weeklyRaidAlreadyCleared,
      );
    }
    final transition = stateMachine.changeCharacter(
      state: current.state,
      actorUserId: userId,
      characterId: characterId,
      className: className,
    );
    if (!transition.isSuccess) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure: transition.failure,
      );
    }
    final oldAssignment = _assignmentFor(
      aggregate: current,
      userId: userId,
      characterId: currentMember.characterId,
    );
    final newAssignment = _assignmentFor(
      aggregate: current,
      userId: userId,
      characterId: characterId,
    );
    final assignmentStore = assignmentRepository;
    var replacedExistingAssignment = false;
    if (assignmentStore != null) {
      final assignments = await assignmentStore.getByUser(userId);
      replacedExistingAssignment = assignments.any(
        (assignment) =>
            assignment.characterRaidKey == oldAssignment.characterRaidKey &&
            assignment.recruitmentId == recruitmentId,
      );
      final assignmentResult = replacedExistingAssignment
          ? await assignmentStore.replace(
              current: oldAssignment,
              replacement: newAssignment,
            )
          : await assignmentStore.acquire(newAssignment);
      if (!assignmentResult.isSuccess) {
        return LocalRecruitmentResult.failure(
          LocalRecruitmentFailure.domainRejected,
          aggregate: current,
          domainFailure: RecruitmentCommandFailure.participationConflict,
        );
      }
    }
    final saved = await repository.updateIfRevision(
      recruitmentId: recruitmentId,
      expectedRevision: current.revision,
      nextState: transition.state,
      updatedAt: clock.now(),
    );
    if (saved == null) {
      if (assignmentStore != null) {
        if (replacedExistingAssignment) {
          await assignmentStore.replace(
            current: newAssignment,
            replacement: oldAssignment,
          );
        } else {
          await _release(newAssignment);
        }
      }
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.revisionConflict,
        aggregate: current,
      );
    }
    await _supersedeOtherPending(newAssignment, saved.updatedAt);
    return LocalRecruitmentResult.success(saved);
  }

  Future<LocalRecruitmentResult> vote({
    required String recruitmentId,
    required String applicantUserId,
    required ApplicationVoteDecision decision,
  }) => _change(
    recruitmentId,
    (aggregate, userId) {
      return stateMachine.vote(
        state: aggregate.state,
        applicantUserId: applicantUserId,
        voterUserId: userId,
        decision: decision,
      );
    },
    confirmedAssignment: (aggregate, transition) {
      final before = aggregate.state.applications[applicantUserId];
      final after = transition.state.applications[applicantUserId];
      if (before?.status != RecruitmentApplicationStatus.pending ||
          after?.status != RecruitmentApplicationStatus.approved) {
        return null;
      }
      return _assignmentFor(
        aggregate: aggregate,
        userId: applicantUserId,
        characterId: after!.characterId,
      );
    },
  );

  Future<LocalRecruitmentResult> _change(
    String recruitmentId,
    RecruitmentCommandResult Function(
      RecruitmentAggregate aggregate,
      String userId,
    )
    command, {
    ActiveRaidAssignment? Function(
      RecruitmentAggregate aggregate,
      RecruitmentCommandResult transition,
    )?
    confirmedAssignment,
  }) async {
    final userId = session.currentUserId;
    if (userId == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.unauthenticated,
      );
    }
    final current = await repository.getById(recruitmentId);
    if (current == null) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.notFound,
      );
    }

    final transition = command(current, userId);
    if (!transition.isSuccess) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.domainRejected,
        aggregate: current,
        domainFailure: transition.failure,
      );
    }
    final assignment = confirmedAssignment?.call(current, transition);
    if (assignment != null) {
      final acquisitionFailure = await _acquire(assignment, current);
      if (acquisitionFailure != null) return acquisitionFailure;
    }
    final saved = await repository.updateIfRevision(
      recruitmentId: recruitmentId,
      expectedRevision: current.revision,
      nextState: transition.state,
      updatedAt: clock.now(),
    );
    if (saved == null) {
      if (assignment != null) await _release(assignment);
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.revisionConflict,
        aggregate: current,
      );
    }
    if (assignment != null) {
      await _supersedeOtherPending(assignment, saved.updatedAt);
    }
    return LocalRecruitmentResult.success(saved);
  }

  ActiveRaidAssignment _assignmentFor({
    required RecruitmentAggregate aggregate,
    required String userId,
    required String characterId,
  }) {
    final startAt = aggregate.metadata.raidStartAt ?? aggregate.createdAt;
    final maxPlayHours = aggregate.metadata.maxPlayHours;
    return ActiveRaidAssignment(
      userId: userId,
      characterId: characterId,
      raidId: aggregate.metadata.raidId,
      difficultyId: aggregate.metadata.difficultyId,
      recruitmentId: aggregate.id,
      schedule: RaidParticipationSchedule(
        startAt: startAt,
        expectedEndAt: maxPlayHours == null
            ? null
            : startAt.add(Duration(hours: maxPlayHours)),
      ),
    );
  }

  Future<LocalRecruitmentResult?> _acquire(
    ActiveRaidAssignment assignment,
    RecruitmentAggregate aggregate,
  ) async {
    final assignmentStore = assignmentRepository;
    if (assignmentStore == null) return null;
    final acquired = await assignmentStore.acquire(assignment);
    if (acquired.isSuccess) return null;
    return LocalRecruitmentResult.failure(
      LocalRecruitmentFailure.domainRejected,
      aggregate: aggregate,
      domainFailure: RecruitmentCommandFailure.participationConflict,
    );
  }

  Future<void> _release(ActiveRaidAssignment assignment) async {
    await assignmentRepository?.release(
      userId: assignment.userId,
      characterId: assignment.characterId,
      raidId: assignment.raidId,
      recruitmentId: assignment.recruitmentId,
    );
  }

  Future<void> _supersedeOtherPending(
    ActiveRaidAssignment assignment,
    DateTime updatedAt,
  ) async {
    await repository.supersedePendingApplications(
      applicantUserId: assignment.userId,
      characterId: assignment.characterId,
      raidId: assignment.raidId,
      excludingRecruitmentId: assignment.recruitmentId,
      updatedAt: updatedAt,
    );
  }
}
