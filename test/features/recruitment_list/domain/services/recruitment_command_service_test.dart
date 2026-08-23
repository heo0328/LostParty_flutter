import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/weekly_raid_clear.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_command_service.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  late FakeUserSession session;
  late FakeRecruitmentClock clock;
  late InMemoryRecruitmentStateRepository repository;
  late InMemoryWeeklyRaidClearRepository weeklyClearRepository;
  late InMemoryActiveRaidAssignmentRepository assignmentRepository;
  late RecruitmentCommandService service;

  setUp(() {
    session = FakeUserSession('user-a');
    clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    repository = InMemoryRecruitmentStateRepository();
    weeklyClearRepository = InMemoryWeeklyRaidClearRepository();
    assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyClearRepository,
      assignmentRepository: assignmentRepository,
    );
  });

  test('A 생성, C 가입, B 신청, C 승인 흐름을 모든 사용자가 공유한다', () async {
    final created = await _create(service);
    final recruitmentId = created.aggregate!.id;

    session.signIn('user-c');
    await service.apply(
      recruitmentId: recruitmentId,
      characterId: 'c-character',
      className: '블레이드',
      role: PartyRole.dealer,
    );
    session.signIn('user-a');
    await service.vote(
      recruitmentId: recruitmentId,
      applicantUserId: 'user-c',
      decision: ApplicationVoteDecision.approve,
    );

    session.signIn('user-b');
    await service.apply(
      recruitmentId: recruitmentId,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );
    clock.advance(const Duration(minutes: 10));
    session.signIn('user-c');
    final approved = await service.vote(
      recruitmentId: recruitmentId,
      applicantUserId: 'user-b',
      decision: ApplicationVoteDecision.approve,
    );

    expect(approved.isSuccess, isTrue);
    expect(approved.aggregate!.revision, 4);
    expect(
      approved.aggregate!.state.members.map((member) => member.userId),
      containsAll(['user-a', 'user-b', 'user-c']),
    );
    expect(approved.aggregate!.updatedAt, DateTime.utc(2026, 8, 20, 0, 10));

    session.signIn('user-a');
    final fromA = await repository.getById(recruitmentId);
    session.signIn('user-b');
    final fromB = await repository.getById(recruitmentId);
    expect(identical(fromA, fromB), isTrue);
  });

  test('실패한 명령은 revision과 갱신 시각을 변경하지 않는다', () async {
    final created = await _create(service);
    final id = created.aggregate!.id;
    session.signIn('user-b');
    await service.apply(
      recruitmentId: id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );
    final before = await repository.getById(id);
    clock.advance(const Duration(hours: 1));
    session.signIn('outsider');

    final failed = await service.vote(
      recruitmentId: id,
      applicantUserId: 'user-b',
      decision: ApplicationVoteDecision.approve,
    );
    final after = await repository.getById(id);

    expect(failed.failure, LocalRecruitmentFailure.domainRejected);
    expect(failed.domainFailure, RecruitmentCommandFailure.unauthorized);
    expect(after!.revision, before!.revision);
    expect(after.updatedAt, before.updatedAt);
    expect(after.state.applications['user-b']!.votes, isEmpty);
  });

  test('로그아웃 상태에서는 생성과 명령을 실행하지 않는다', () async {
    session.signOut();

    final create = await _create(service);
    final apply = await service.apply(
      recruitmentId: 'missing',
      characterId: 'character',
      className: '발키리',
      role: PartyRole.dealer,
    );

    expect(create.failure, LocalRecruitmentFailure.unauthenticated);
    expect(apply.failure, LocalRecruitmentFailure.unauthenticated);
    expect(await repository.getPublicRecruitments(), isEmpty);
  });

  test('성공한 신청만 revision을 올리고 공개 읽기 모델에 반영한다', () async {
    final created = await _create(service);
    session.signIn('user-b');
    final applied = await service.apply(
      recruitmentId: created.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );
    final duplicate = await service.apply(
      recruitmentId: created.aggregate!.id,
      characterId: 'b-character-2',
      className: '소서리스',
      role: PartyRole.dealer,
    );
    final summaries = await repository.getPublicRecruitments();

    expect(applied.aggregate!.revision, 1);
    expect(duplicate.failure, LocalRecruitmentFailure.domainRejected);
    expect((await repository.getById(created.aggregate!.id))!.revision, 1);
    expect(summaries.single.revision, 1);
  });

  test('저장 직전 revision 충돌을 명시적인 실패로 반환한다', () async {
    final created = await _create(service);
    session.signIn('user-b');
    final conflictingService = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: _ConflictingRepository(repository),
    );

    final result = await conflictingService.apply(
      recruitmentId: created.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );

    expect(result.failure, LocalRecruitmentFailure.revisionConflict);
    expect(result.aggregate!.revision, 0);
    expect((await repository.getById(created.aggregate!.id))!.revision, 1);
  });

  test('같은 주차에 동일 레이드를 완료한 캐릭터의 신청을 거절한다', () async {
    final created = await _create(service);
    session.signIn('user-b');
    await weeklyClearRepository.saveAll([
      WeeklyRaidClear(
        userId: 'user-b',
        characterId: 'b-character',
        raidId: 'serca',
        difficultyId: 'nightmare',
        resetWeekKey: '2026-08-19',
        completedAt: clock.now(),
        recruitmentId: 'old-recruitment',
        completedByUserId: 'user-c',
      ),
    ]);

    final result = await service.apply(
      recruitmentId: created.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );

    expect(result.failure, LocalRecruitmentFailure.domainRejected);
    expect(
      result.domainFailure,
      RecruitmentCommandFailure.weeklyRaidAlreadyCleared,
    );
    expect(result.aggregate!.revision, 0);
  });

  test('같은 캐릭터로 동일 레이드 모집을 다시 생성하지 못한다', () async {
    final first = await _create(service);

    final second = await _create(service);

    expect(first.isSuccess, isTrue);
    expect(second.failure, LocalRecruitmentFailure.domainRejected);
    expect(
      second.domainFailure,
      RecruitmentCommandFailure.participationConflict,
    );
    expect(await repository.getPublicRecruitments(), hasLength(1));
  });

  test('모집 생성은 동일 레이드 pending 종료를 명시적으로 확인한다', () async {
    repository.seed(
      RecruitmentAggregate(
        id: 'pending-recruitment',
        title: '신청 중인 모집',
        metadata: _metadata,
        state: RecruitmentState(
          leaderUserId: 'other-user',
          approvalPolicy: const ApprovalPolicy.leaderOnly(),
          compositionPolicy: _compositionPolicy,
          members: const [
            RecruitmentPartyMember(
              userId: 'other-user',
              characterId: 'other-character',
              className: '블레이드',
              role: PartyRole.dealer,
              partyIndex: 0,
            ),
          ],
          applications: const {
            'user-a': RecruitmentApplication(
              applicantUserId: 'user-a',
              characterId: 'a-character',
              className: '바드',
              requestedRole: PartyRole.support,
            ),
          },
        ),
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 20),
      ),
    );

    final rejected = await _create(service);
    expect(
      rejected.domainFailure,
      RecruitmentCommandFailure.pendingApplicationsRequireConfirmation,
    );

    final created = await _create(service, cancelPendingApplications: true);
    expect(created.isSuccess, isTrue);
    expect(
      (await repository.getById(
        'pending-recruitment',
      ))!.state.applications['user-a']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  test('파티장은 모집을 삭제하고 모든 확정 점유를 해제한다', () async {
    final created = await _create(service);

    final deleted = await service.deleteRecruitment(created.aggregate!.id);

    expect(deleted.isSuccess, isTrue);
    expect(await repository.getById(created.aggregate!.id), isNull);
    expect(await assignmentRepository.getByUser('user-a'), isEmpty);
  });

  test('즉시 가입 확정 시 같은 캐릭터와 레이드의 다른 pending 신청을 종료한다', () async {
    final approval = await _create(service);
    final direct = await service.createRecruitment(
      title: '즉시 가입 모집',
      metadata: RecruitmentMetadata(
        catalogVersion: 'test',
        raidId: 'serca',
        difficultyId: 'hard',
        raidName: '세르카',
        difficultyName: '하드',
        difficultyAlias: '하르카',
        gateCount: 2,
        minItemLevel: 1710,
        minCombatPower: null,
        experienceLevel: null,
        maxPlayHours: 3,
        raidStartAt: _laterStart,
      ),
      leaderCharacterId: 'other-leader',
      leaderClassName: '블레이드',
      leaderRole: PartyRole.dealer,
      approvalPolicy: const ApprovalPolicy.directJoin(),
      compositionPolicy: _compositionPolicy,
    );
    session.signIn('user-b');
    await service.apply(
      recruitmentId: approval.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );

    final joined = await service.apply(
      recruitmentId: direct.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );

    expect(joined.isSuccess, isTrue);
    expect(
      (await repository.getById(
        approval.aggregate!.id,
      ))!.state.applications['user-b']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  test('승인 경쟁에서는 최초 승인만 확정되고 다른 pending은 자동 종료한다', () async {
    final first = await _create(service);
    session.signIn('user-c');
    final second = await _createWith(
      service,
      title: '두 번째 승인 모집',
      leaderCharacterId: 'c-character',
      difficultyId: 'hard',
      raidStartAt: _laterStart,
    );
    session.signIn('user-b');
    for (final id in [first.aggregate!.id, second.aggregate!.id]) {
      await service.apply(
        recruitmentId: id,
        characterId: 'b-character',
        className: '발키리',
        role: PartyRole.dealer,
      );
    }

    session.signIn('user-a');
    final approved = await service.vote(
      recruitmentId: first.aggregate!.id,
      applicantUserId: 'user-b',
      decision: ApplicationVoteDecision.approve,
    );

    expect(approved.isSuccess, isTrue);
    expect(
      (await repository.getById(
        second.aggregate!.id,
      ))!.state.applications['user-b']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  test('자동 종료 전 승인 경쟁도 확정 점유가 두 번째 가입을 차단한다', () async {
    final created = await _create(service);
    session.signIn('user-b');
    await service.apply(
      recruitmentId: created.aggregate!.id,
      characterId: 'b-character',
      className: '발키리',
      role: PartyRole.dealer,
    );
    await assignmentRepository.acquire(
      ActiveRaidAssignment(
        userId: 'user-b',
        characterId: 'b-character',
        raidId: 'serca',
        difficultyId: 'hard',
        recruitmentId: 'already-confirmed-party',
        schedule: RaidParticipationSchedule(
          startAt: _laterStart,
          expectedEndAt: _laterStart.add(const Duration(hours: 3)),
        ),
      ),
    );

    session.signIn('user-a');
    final rejected = await service.vote(
      recruitmentId: created.aggregate!.id,
      applicantUserId: 'user-b',
      decision: ApplicationVoteDecision.approve,
    );

    expect(rejected.failure, LocalRecruitmentFailure.domainRejected);
    expect(
      rejected.domainFailure,
      RecruitmentCommandFailure.participationConflict,
    );
    final unchanged = await repository.getById(created.aggregate!.id);
    expect(
      unchanged!.state.applications['user-b']!.status,
      RecruitmentApplicationStatus.pending,
    );
    expect(unchanged.state.applications['user-b']!.votes, isEmpty);
  });

  test('파티 내 캐릭터 변경은 역할을 유지하고 확정 점유를 교체한다', () async {
    final created = await _create(service);
    repository.seed(
      RecruitmentAggregate(
        id: 'pending-other',
        title: '다른 모집',
        metadata: _metadata,
        state: RecruitmentState(
          leaderUserId: 'user-z',
          approvalPolicy: const ApprovalPolicy.leaderOnly(),
          compositionPolicy: _compositionPolicy,
          members: const [
            RecruitmentPartyMember(
              userId: 'user-z',
              characterId: 'z-character',
              className: '블레이드',
              role: PartyRole.dealer,
              partyIndex: 0,
            ),
          ],
          applications: const {
            'user-a': RecruitmentApplication(
              applicantUserId: 'user-a',
              characterId: 'replacement-bard',
              className: '바드',
              requestedRole: PartyRole.support,
            ),
          },
        ),
        revision: 0,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );

    final requiresConfirmation = await service.changeCharacter(
      recruitmentId: created.aggregate!.id,
      characterId: 'replacement-bard',
      className: '바드',
    );
    expect(
      requiresConfirmation.domainFailure,
      RecruitmentCommandFailure.pendingApplicationsRequireConfirmation,
    );

    final changed = await service.changeCharacter(
      recruitmentId: created.aggregate!.id,
      characterId: 'replacement-bard',
      className: '바드',
      cancelPendingApplications: true,
    );

    expect(changed.isSuccess, isTrue);
    final member = changed.aggregate!.state.members.single;
    expect(member.characterId, 'replacement-bard');
    expect(member.role, PartyRole.support);
    final assignments = await assignmentRepository.getByUser('user-a');
    expect(assignments, hasLength(1));
    expect(assignments.single.characterId, 'replacement-bard');
    expect(
      (await repository.getById(
        'pending-other',
      ))!.state.applications['user-a']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  test('같은 캐릭터의 반대 역할로 확정 점유를 유지하며 변경한다', () async {
    final created = await _create(service);

    final changed = await service.changeCharacter(
      recruitmentId: created.aggregate!.id,
      characterId: 'a-character',
      className: '바드',
      role: PartyRole.dealer,
    );

    expect(changed.isSuccess, isTrue);
    expect(changed.aggregate!.state.members.single.role, PartyRole.dealer);
    final assignments = await assignmentRepository.getByUser('user-a');
    expect(assignments, hasLength(1));
    expect(assignments.single.characterId, 'a-character');
  });
}

final _laterStart = DateTime.utc(2026, 8, 20, 10);

Future<LocalRecruitmentResult> _createWith(
  RecruitmentCommandService service, {
  required String title,
  required String leaderCharacterId,
  required String difficultyId,
  required DateTime raidStartAt,
}) => service.createRecruitment(
  title: title,
  metadata: RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: difficultyId,
    raidName: '세르카',
    difficultyName: difficultyId,
    difficultyAlias: difficultyId,
    gateCount: 2,
    minItemLevel: 1710,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: 3,
    raidStartAt: raidStartAt,
  ),
  leaderCharacterId: leaderCharacterId,
  leaderClassName: '블레이드',
  leaderRole: PartyRole.dealer,
  approvalPolicy: const ApprovalPolicy.anyMember(),
  compositionPolicy: _compositionPolicy,
);

Future<LocalRecruitmentResult> _create(
  RecruitmentCommandService service, {
  bool cancelPendingApplications = false,
}) => service.createRecruitment(
  title: '세르카 모집',
  metadata: _metadata,
  leaderCharacterId: 'a-character',
  leaderClassName: '바드',
  leaderRole: PartyRole.support,
  approvalPolicy: const ApprovalPolicy.anyMember(),
  compositionPolicy: _compositionPolicy,
  cancelPendingApplications: cancelPendingApplications,
);

const _compositionPolicy = PartyCompositionPolicy(
  RecruitmentPartyRules(
    partyCount: 1,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  ),
);

final _metadata = RecruitmentMetadata(
  catalogVersion: 'test',
  raidId: 'serca',
  difficultyId: 'normal',
  raidName: '세르카',
  difficultyName: '노말',
  difficultyAlias: '노르카',
  gateCount: 2,
  minItemLevel: 1710,
  minCombatPower: 200000,
  experienceLevel: ExperienceLevel.clearExp,
  maxPlayHours: 3,
  raidStartAt: DateTime.utc(2026, 8, 20),
);

class _ConflictingRepository implements RecruitmentStateRepository {
  _ConflictingRepository(this.delegate);

  final RecruitmentStateRepository delegate;

  @override
  Future<bool> create(RecruitmentAggregate aggregate) =>
      delegate.create(aggregate);

  @override
  Future<RecruitmentAggregate?> getById(String recruitmentId) =>
      delegate.getById(recruitmentId);

  @override
  Future<List<PublicRecruitmentSummary>> getPublicRecruitments() =>
      delegate.getPublicRecruitments();

  @override
  Future<bool> deleteIfRevision({
    required String recruitmentId,
    required int expectedRevision,
  }) => delegate.deleteIfRevision(
    recruitmentId: recruitmentId,
    expectedRevision: expectedRevision,
  );

  @override
  Future<RecruitmentAggregate?> updateIfRevision({
    required String recruitmentId,
    required int expectedRevision,
    required RecruitmentState nextState,
    required DateTime updatedAt,
  }) async {
    final current = await delegate.getById(recruitmentId);
    await delegate.updateIfRevision(
      recruitmentId: recruitmentId,
      expectedRevision: expectedRevision,
      nextState: current!.state,
      updatedAt: updatedAt,
    );
    return delegate.updateIfRevision(
      recruitmentId: recruitmentId,
      expectedRevision: expectedRevision,
      nextState: nextState,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<int> supersedePendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
    required String excludingRecruitmentId,
    required DateTime updatedAt,
  }) => delegate.supersedePendingApplications(
    applicantUserId: applicantUserId,
    characterId: characterId,
    raidId: raidId,
    excludingRecruitmentId: excludingRecruitmentId,
    updatedAt: updatedAt,
  );

  @override
  Future<int> countPendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
  }) => delegate.countPendingApplications(
    applicantUserId: applicantUserId,
    characterId: characterId,
    raidId: raidId,
  );
}
