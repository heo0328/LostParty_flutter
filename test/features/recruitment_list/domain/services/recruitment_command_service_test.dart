import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/weekly_raid_clear.dart';
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
  late RecruitmentCommandService service;

  setUp(() {
    session = FakeUserSession('user-a');
    clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    repository = InMemoryRecruitmentStateRepository();
    weeklyClearRepository = InMemoryWeeklyRaidClearRepository();
    service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyClearRepository,
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
}

Future<LocalRecruitmentResult> _create(RecruitmentCommandService service) =>
    service.createRecruitment(
      title: '세르카 모집',
      metadata: _metadata,
      leaderCharacterId: 'a-character',
      leaderClassName: '바드',
      leaderRole: PartyRole.support,
      approvalPolicy: const ApprovalPolicy.anyMember(),
      compositionPolicy: _compositionPolicy,
    );

const _compositionPolicy = PartyCompositionPolicy(
  RecruitmentPartyRules(
    partyCount: 1,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  ),
);

const _metadata = RecruitmentMetadata(
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
}
