import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/weekly_raid_clear.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_application_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  test('역할별 저장 세팅과 모든 신청 조건을 후보별로 판정한다', () async {
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    await weeklyRepository.saveAll([
      WeeklyRaidClear(
        userId: 'user-b',
        characterId: '완료바드',
        raidId: 'serca',
        difficultyId: 'hard',
        resetWeekKey: '2026-08-19',
        completedAt: DateTime.utc(2026, 8, 20),
        recruitmentId: 'old',
        completedByUserId: 'user-a',
      ),
    ]);
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: weeklyRepository,
      session: FakeUserSession('user-b'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    );

    final candidates = await service.load(_aggregate);

    final dealer = candidates.singleWhere((item) => item.characterId == '가능딜러');
    final cleared = candidates.singleWhere(
      (item) => item.characterId == '완료바드',
    );
    expect(dealer.canApply, isTrue);
    expect(cleared.canApply, isFalse);
    expect(cleared.rejectionReasons, contains('이번 주 동일 레이드 완료'));
    expect(
      candidates.any(
        (candidate) =>
            candidate.characterId == '부계정소서' && candidate.accountLabel == '부계정',
      ),
      isTrue,
    );
  });

  test('동일 레이드 신청 수와 확정 참가 충돌을 후보 상태로 제공한다', () async {
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    recruitmentRepository.seed(
      _aggregate.copyWith(
        state: _aggregate.state.copyWith(
          applications: const {
            'user-b': RecruitmentApplication(
              applicantUserId: 'user-b',
              characterId: '가능딜러',
              className: '블레이드',
              requestedRole: PartyRole.dealer,
            ),
          },
        ),
      ),
    );
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    await assignmentRepository.acquire(
      ActiveRaidAssignment(
        userId: 'user-b',
        characterId: '가능딜러',
        raidId: 'serca',
        difficultyId: 'hard',
        recruitmentId: 'confirmed-party',
        schedule: RaidParticipationSchedule(
          startAt: DateTime.utc(2026, 8, 20, 10),
          expectedEndAt: DateTime.utc(2026, 8, 20, 12),
        ),
      ),
    );
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-b'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
      assignmentRepository: assignmentRepository,
      recruitmentRepository: recruitmentRepository,
    );

    final candidate = (await service.load(
      _aggregate,
    )).singleWhere((item) => item.characterId == '가능딜러');

    expect(candidate.canApply, isFalse);
    expect(
      candidate.participationStatuses
          .where(
            (status) =>
                status.type == CandidateParticipationStatusType.pendingSameRaid,
          )
          .single
          .count,
      1,
    );
    expect(
      candidate.participationStatuses.map((status) => status.type),
      contains(CandidateParticipationStatusType.activeSameRaid),
    );
    expect(candidate.rejectionReasons, contains('동일 레이드 참가 중'));
  });

  test('캐릭터 변경 후보는 현재 파티 역할을 유지하며 부계정까지 포함한다', () async {
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-a'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    );

    final candidates = await service.loadForCharacterChange(_aggregate);

    expect(
      candidates.map((candidate) => candidate.characterId),
      containsAll(['가능딜러', '부계정소서']),
    );
    expect(
      candidates.every((candidate) => candidate.role == PartyRole.dealer),
      isTrue,
    );
    expect(
      candidates.map((candidate) => candidate.characterId),
      isNot(contains('완료바드')),
    );
  });
}

class _AccountRepository implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    (await loadMainAccount())!,
    const LocalGameAccount(
      id: 2,
      label: '부계정',
      isMain: false,
      lookupCharacterName: '부계정소서',
      representativeCharacterId: 3,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 3,
          serverName: '카단',
          characterName: '부계정소서',
          characterLevel: 70,
          characterClassName: '소서리스',
          itemLevel: 1750,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];

  @override
  Future<LocalGameAccount?> loadMainAccount() async => const LocalGameAccount(
    id: 1,
    label: '계정',
    isMain: true,
    lookupCharacterName: '가능딜러',
    representativeCharacterId: 1,
    displayLimit: 6,
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverName: '루페온',
        characterName: '가능딜러',
        characterLevel: 70,
        characterClassName: '블레이드',
        itemLevel: 1750,
        combatPower: 300000,
        isVisible: true,
        displayOrder: 0,
      ),
      LocalAccountCharacter(
        id: 2,
        serverName: '루페온',
        characterName: '완료바드',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1750,
        combatPower: 300000,
        isVisible: true,
        displayOrder: 1,
      ),
    ],
  );

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    CharacterBuildSnapshot(
      id: characterId,
      characterId: characterId,
      role: characterId == 1
          ? CharacterBuildRole.dealer
          : characterId == 2
          ? CharacterBuildRole.support
          : CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1750,
      combatPower: 300000,
      capturedAt: DateTime.utc(2026, 8, 20),
      dataVersion: 1,
      analysis: const CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
      ),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _aggregate = RecruitmentAggregate(
  id: 'recruitment-1',
  title: '세르카',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: 'normal',
    raidName: '세르카',
    difficultyName: '노말',
    difficultyAlias: '노르카',
    gateCount: 2,
    minItemLevel: 1710,
    minCombatPower: 250000,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  state: RecruitmentState(
    leaderUserId: 'user-a',
    approvalPolicy: const ApprovalPolicy.leaderOnly(),
    compositionPolicy: const PartyCompositionPolicy(
      RecruitmentPartyRules(
        partyCount: 1,
        membersPerParty: 4,
        supportsPerParty: 1,
        maxDealersPerClassPerParty: 1,
      ),
    ),
    members: const [
      RecruitmentPartyMember(
        userId: 'user-a',
        characterId: '리더',
        className: '발키리',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);
