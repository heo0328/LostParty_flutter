import '../entities/party_recruitment.dart';
import '../entities/recruitment_aggregate.dart';
import '../entities/recruitment_application.dart';
import '../policies/approval_policy.dart';
import '../policies/party_composition_policy.dart';
import '../repositories/recruitment_state_repository.dart';
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
    this.stateMachine = const RecruitmentStateMachine(),
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final UserSession session;
  final RecruitmentClock clock;
  final RecruitmentIdGenerator idGenerator;
  final RecruitmentStateRepository repository;
  final WeeklyRaidClearRepository? weeklyClearRepository;
  final RecruitmentStateMachine stateMachine;
  final WeeklyRaidResetPolicy resetPolicy;

  String? get currentUserId => session.currentUserId;

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
    if (!await repository.create(aggregate)) {
      return const LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.idConflict,
      );
    }
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
    return _change(recruitmentId, (aggregate, currentUserId) {
      return stateMachine.apply(
        state: aggregate.state,
        application: RecruitmentApplication(
          applicantUserId: currentUserId,
          characterId: characterId,
          className: className,
          requestedRole: role,
        ),
      );
    });
  }

  Future<LocalRecruitmentResult> withdraw(String recruitmentId) =>
      _change(recruitmentId, (aggregate, userId) {
        return stateMachine.withdraw(
          state: aggregate.state,
          applicantUserId: userId,
          actorUserId: userId,
        );
      });

  Future<LocalRecruitmentResult> vote({
    required String recruitmentId,
    required String applicantUserId,
    required ApplicationVoteDecision decision,
  }) => _change(recruitmentId, (aggregate, userId) {
    return stateMachine.vote(
      state: aggregate.state,
      applicantUserId: applicantUserId,
      voterUserId: userId,
      decision: decision,
    );
  });

  Future<LocalRecruitmentResult> _change(
    String recruitmentId,
    RecruitmentCommandResult Function(
      RecruitmentAggregate aggregate,
      String userId,
    )
    command,
  ) async {
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
    final saved = await repository.updateIfRevision(
      recruitmentId: recruitmentId,
      expectedRevision: current.revision,
      nextState: transition.state,
      updatedAt: clock.now(),
    );
    if (saved == null) {
      return LocalRecruitmentResult.failure(
        LocalRecruitmentFailure.revisionConflict,
        aggregate: current,
      );
    }
    return LocalRecruitmentResult.success(saved);
  }
}
