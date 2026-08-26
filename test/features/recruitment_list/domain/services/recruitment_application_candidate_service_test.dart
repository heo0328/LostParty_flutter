import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_repository.dart';
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
  test('ě­í ëł ě ěĽ ě¸íęłź ëŞ¨ë  ě ě˛­ ěĄ°ęą´ě íëł´ëłëĄ íě íë¤', () async {
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    await weeklyRepository.saveAll([
      WeeklyRaidClear(
        userId: 'user-b',
        characterId: 'ěëŁë°ë',
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

    final dealer = candidates.singleWhere((item) => item.characterId == 'ę°ëĽëëŹ');
    final cleared = candidates.singleWhere(
      (item) => item.characterId == 'ěëŁë°ë',
    );
    expect(dealer.canApply, isTrue);
    expect(cleared.canApply, isFalse);
    expect(cleared.rejectionReasons, contains('이번 주 동일 레이드 완료'));
    expect(
      candidates.any(
        (candidate) =>
            candidate.characterId == 'ëśęłě ěě' && candidate.accountLabel == 'ëśęłě ',
      ),
      isTrue,
    );
  });

  test('ëěź ë ě´ë ě ě˛­ ěě íě  ě°¸ę° ěśŠëě íëł´ ěíëĄ ě ęłľíë¤', () async {
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    recruitmentRepository.seed(
      _aggregate.copyWith(
        state: _aggregate.state.copyWith(
          applications: const {
            'user-b': RecruitmentApplication(
              applicantUserId: 'user-b',
              characterId: 'ę°ëĽëëŹ',
              className: 'ë¸ë ě´ë',
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
        characterId: 'ę°ëĽëëŹ',
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
    )).singleWhere((item) => item.characterId == 'ę°ëĽëëŹ');

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

  test('ěşëŚ­í° ëłę˛˝ íëł´ë ę°ëĽí ë¤ëĽ¸ ě­í ęłź ëśęłě ęšě§ íŹí¨íë¤', () async {
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-a'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    );

    final candidates = await service.loadForCharacterChange(_aggregate);

    expect(
      candidates.map((candidate) => candidate.characterId),
      containsAll(['ę°ëĽëëŹ', 'ěëŁë°ë', 'ëśęłě ěě']),
    );
    expect(
      candidates.map((candidate) => candidate.role),
      containsAll([PartyRole.dealer, PartyRole.support]),
    );
  });

  test('ě¸ěŚ ěě¤ ęłě ě ě ě˛­ ěşëŚ­í° íëł´ěě ě ě¸íë¤', () async {
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _LostOwnershipAccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-a'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    );

    expect(await service.load(_aggregate), isEmpty);
  });

  test('서버 Claim이 있는 캐릭터는 신청과 캐릭터 변경 후보에서 차단한다', () async {
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      weeklyRaidClaimRepository: _ClaimRepository(),
      claimPlayerId: 'player-1',
      session: FakeUserSession('user-b'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 27)),
    );

    final candidates = await service.load(_aggregate);
    final completed = candidates.where(
      (candidate) =>
          candidate.rejectionReasons.contains('이번 주 동일 레이드 완료'),
    );

    expect(completed, isNotEmpty);
    expect(completed.every((candidate) => !candidate.canApply), isTrue);
  });
}

class _ClaimRepository implements WeeklyRaidClaimRepository {
  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) => Stream.value([
    WeeklyRaidClaim(
      id: '${cycleKey}_AbCdEfGhIjKlMnOpQrSt_serca',
      playerId: playerId,
      characterId: 'AbCdEfGhIjKlMnOpQrSt',
      raidId: 'serca',
      cycleKey: cycleKey,
      difficultyId: 'hard',
      source: WeeklyRaidClaimSource.manual,
      cycleStartedAt: DateTime.utc(2026, 8, 25, 21),
      cycleEndsAt: DateTime.utc(2026, 9, 1, 21),
      completedAt: DateTime.utc(2026, 8, 27),
      updatedAt: DateTime.utc(2026, 8, 27),
    ),
  ]);
}

class _AccountRepository implements AccountRepository {

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    (await loadMainAccount())!,
    const LocalGameAccount(
      id: 2,
      label: 'ëśęłě ',
      isMain: false,
      lookupCharacterName: 'ëśęłě ěě',
      representativeCharacterId: 3,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 3,
          serverName: 'ěš´ë¨',
          characterName: 'ëśęłě ěě',
          characterLevel: 70,
          characterClassName: 'ěěëŚŹě¤',
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
    label: 'ęłě ',
    isMain: true,
    lookupCharacterName: 'ę°ëĽëëŹ',
    representativeCharacterId: 1,
    displayLimit: 6,
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverCharacterId: 'AbCdEfGhIjKlMnOpQrSt',
        serverName: 'ëŁ¨íě¨',
        characterName: 'ę°ëĽëëŹ',
        characterLevel: 70,
        characterClassName: 'ë¸ë ě´ë',
        itemLevel: 1750,
        combatPower: 300000,
        isVisible: true,
        displayOrder: 0,
      ),
      LocalAccountCharacter(
        id: 2,
        serverName: 'ëŁ¨íě¨',
        characterName: 'ěëŁë°ë',
        characterLevel: 70,
        characterClassName: 'ë°ë',
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

class _LostOwnershipAccountRepository extends _AccountRepository {

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      serverGameAccountId: 'account-1',
      serverOwnershipStatus: 'ownershipLost',
      label: 'ě¸ěŚ ěě¤ ęłě ',
      isMain: true,
      lookupCharacterName: 'ę°ëĽëëŹ',
      representativeCharacterId: 1,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverName: 'ëŁ¨íě¨',
          characterName: 'ę°ëĽëëŹ',
          characterLevel: 70,
          characterClassName: 'ë¸ë ě´ë',
          itemLevel: 1750,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];
}

final _aggregate = RecruitmentAggregate(
  id: 'recruitment-1',
  title: 'ě¸ëĽ´ěš´',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: 'normal',
    raidName: 'ě¸ëĽ´ěš´',
    difficultyName: 'ë¸ë§',
    difficultyAlias: 'ë¸ëĽ´ěš´',
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
        characterId: 'ëŚŹë',
        className: 'ë°í¤ëŚŹ',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);
