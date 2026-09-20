import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_status_projection.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_repository.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_status_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/candidate_participation_status.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';

void main() {
  test('본계정과 부계정의 표시 캐릭터만 역할 세팅과 함께 제공한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(_query());

    expect(candidates.map((candidate) => candidate.characterId), [
      '대표바드',
      '부계정소서',
    ]);
    final representative = candidates.first;
    expect(representative.isRepresentative, isTrue);
    expect(representative.roles.map((option) => option.role), {
      PartyRole.dealer,
      PartyRole.support,
    });
    expect(representative.canSelect, isTrue);
    expect(
      representative.roles.first.gemValidation?.catalogVersion,
      '2026.09.04',
    );
    expect(
      representative.roles.first.buildIntegrity?.catalogVersion,
      '2026.09.04',
    );
  });

  test('선호 포지션이 선택 가능하면 먼저 고르고 아니면 기존 유효 역할을 유지한다', () {
    const preferredSupport = RecruitmentLeaderCandidate(
      characterId: '바드',
      localCharacterId: 1,
      accountId: 1,
      accountLabel: '계정',
      isMainAccount: true,
      isRepresentative: true,
      serverName: '루페온',
      className: '바드',
      roles: [
        RecruitmentLeaderRoleOption(
          role: PartyRole.support,
          itemLevel: 1750,
          combatPower: 1,
          rejectionReasons: [],
        ),
        RecruitmentLeaderRoleOption(
          role: PartyRole.dealer,
          itemLevel: 1750,
          combatPower: 1,
          rejectionReasons: [],
        ),
      ],
      participationStatuses: [],
      rejectionReasons: [],
    );
    expect(preferredSupport.resolveSelectedRole(), PartyRole.support);
    expect(
      preferredSupport.resolveSelectedRole(current: PartyRole.dealer),
      PartyRole.dealer,
    );

    const preferredBlocked = RecruitmentLeaderCandidate(
      characterId: '바드',
      localCharacterId: 1,
      accountId: 1,
      accountLabel: '계정',
      isMainAccount: true,
      isRepresentative: true,
      serverName: '루페온',
      className: '바드',
      roles: [
        RecruitmentLeaderRoleOption(
          role: PartyRole.support,
          itemLevel: 1700,
          combatPower: 1,
          rejectionReasons: ['입장 레벨 미달'],
        ),
        RecruitmentLeaderRoleOption(
          role: PartyRole.dealer,
          itemLevel: 1750,
          combatPower: 1,
          rejectionReasons: [],
        ),
      ],
      participationStatuses: [],
      rejectionReasons: [],
    );
    expect(preferredBlocked.resolveSelectedRole(), PartyRole.dealer);
    expect(
      preferredBlocked.resolveSelectedRole(
        usable: (option) => option.role == PartyRole.dealer,
      ),
      PartyRole.dealer,
    );
  });

  test('역할별 입장 레벨을 판정하고 저장 역할이 없으면 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(includeSubBuild: false),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(_query(minItemLevel: 1760));

    expect(candidates.first.roles.every((option) => !option.canSelect), isTrue);
    expect(candidates.last.canSelect, isFalse);
    expect(candidates.last.rejectionReasons, contains('저장된 역할 세팅이 없습니다.'));
  });

  test('최소 전투력 미달 캐릭터를 신청 및 변경 후보에서 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(_query(minCombatPower: 300001));

    expect(candidates.first.canSelect, isFalse);
    expect(
      candidates.first.roles.expand((option) => option.rejectionReasons),
      contains('최소 전투력 300,001 미달'),
    );
  });

  test('확정 참가와 사용자 일정 충돌을 생성 후보에서 차단한다', () async {
    final assignments = InMemoryActiveRaidAssignmentRepository();
    await assignments.acquire(
      ActiveRaidAssignment(
        userId: 'local-user',
        characterId: '대표바드',
        raidId: 'serca',
        difficultyId: 'hard',
        recruitmentId: 'confirmed',
        schedule: RaidParticipationSchedule(
          startAt: DateTime.utc(2026, 8, 23, 10),
          expectedEndAt: DateTime.utc(2026, 8, 23, 13),
        ),
      ),
    );
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: assignments,
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(_query());

    expect(candidates.every((candidate) => !candidate.canSelect), isTrue);
    expect(
      candidates.first.participationStatuses.map((status) => status.type),
      contains(CandidateParticipationStatusType.activeSameRaid),
    );
    expect(
      candidates.last.participationStatuses.map((status) => status.type),
      contains(CandidateParticipationStatusType.overlappingSchedule),
    );
  });

  test('서버 raidState 점유가 있는 캐릭터는 생성 후보에서 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      assignmentLookup: const _BlockingAssignmentLookup(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final representative = (await service.load(_query())).first;
    expect(representative.canSelect, isFalse);
    expect(representative.rejectionReasons, contains('동일 레이드 참가 중'));
    expect(
      representative.participationStatuses.map((status) => status.type),
      contains(CandidateParticipationStatusType.activeSameRaid),
    );
  });

  test('인증 상실 계정은 모집장 캐릭터 후보에서 제외한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _LostOwnershipAccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    expect(await service.load(_query()), isEmpty);
  });

  test('서버 Claim이 있는 캐릭터는 모집 생성 후보에서 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      weeklyRaidClaimRepository: _ClaimRepository(),
      claimPlayerId: 'player-1',
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 27)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidate = (await service.load(_query())).first;

    expect(candidate.canSelect, isFalse);
    expect(candidate.rejectionReasons, contains('이번 주 동일 레이드 완료'));
    expect(
      candidate.participationStatuses.map((status) => status.type),
      contains(CandidateParticipationStatusType.weeklyRaidClear),
    );
  });

  test('통합 완료 상태는 생성 후보에서 완료로만 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      weeklyRaidStatusRepository: const _StatusRepository(
        WeeklyRaidStatusKind.completed,
      ),
      claimPlayerId: 'player-1',
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 27)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      assignmentLookup: const _BlockingAssignmentLookup(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidate = (await service.load(_query())).first;
    final types = candidate.participationStatuses
        .map((status) => status.type)
        .toList(growable: false);

    expect(candidate.canSelect, isFalse);
    expect(types, contains(CandidateParticipationStatusType.weeklyRaidClear));
    expect(
      types,
      isNot(contains(CandidateParticipationStatusType.activeSameRaid)),
    );
  });

  test('4인 파티에서 방장과 같은 딜러 직업 신청 후보를 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('applicant'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(
      _query(
        partyRules: const RecruitmentPartyRules(
          partyCount: 1,
          membersPerParty: 4,
          supportsPerParty: 1,
          maxDealersPerClassPerParty: 1,
        ),
        occupiedMembers: const [
          OccupiedPartyMember(
            id: 'leader',
            className: '바드',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
            isLeader: true,
          ),
        ],
      ),
    );

    final bard = candidates.singleWhere(
      (candidate) => candidate.characterId == '대표바드',
    );
    expect(
      bard.optionFor(PartyRole.dealer)?.rejectionReasons,
      contains('동일 딜러 직업 자리가 없습니다.'),
    );
    expect(bard.optionFor(PartyRole.support)?.canSelect, isTrue);
    expect(bard.canSelect, isTrue);

    final sorceress = candidates.singleWhere(
      (candidate) => candidate.characterId == '부계정소서',
    );
    expect(sorceress.optionFor(PartyRole.dealer)?.canSelect, isTrue);
  });

  test('8인 파티에서는 다른 파티에 배치 가능한 동일 딜러 직업을 허용한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('applicant'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(
      _query(
        partyRules: const RecruitmentPartyRules(
          partyCount: 2,
          membersPerParty: 4,
          supportsPerParty: 1,
          maxDealersPerClassPerParty: 1,
        ),
        occupiedMembers: const [
          OccupiedPartyMember(
            id: 'leader',
            className: '바드',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
            isLeader: true,
          ),
        ],
      ),
    );

    final bard = candidates.singleWhere(
      (candidate) => candidate.characterId == '대표바드',
    );
    expect(bard.optionFor(PartyRole.dealer)?.canSelect, isTrue);
  });

  test('8인에서 같은 딜러 직업이 이미 2명이면 세 번째 신청 후보를 차단한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('applicant'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(
      _query(
        partyRules: const RecruitmentPartyRules(
          partyCount: 2,
          membersPerParty: 4,
          supportsPerParty: 1,
          maxDealersPerClassPerParty: 1,
        ),
        occupiedMembers: const [
          OccupiedPartyMember(
            id: 'leader',
            className: '바드',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
            isLeader: true,
          ),
          OccupiedPartyMember(
            id: 'member-2',
            className: '바드',
            role: PartyRole.dealer,
            partyIndex: 1,
            slotIndex: 0,
          ),
        ],
      ),
    );

    final bard = candidates.singleWhere(
      (candidate) => candidate.characterId == '대표바드',
    );
    expect(
      bard.optionFor(PartyRole.dealer)?.rejectionReasons,
      contains('동일 딜러 직업 자리가 없습니다.'),
    );
  });

  test('모집 생성 후보는 membership 구성 없이 기존처럼 통과한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
    );

    final candidates = await service.load(_query());

    expect(candidates.first.canSelect, isTrue);
    expect(candidates.first.roles.every((option) => option.canSelect), isTrue);
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

class _StatusRepository implements WeeklyRaidStatusRepository {
  const _StatusRepository(this.kind);

  final WeeklyRaidStatusKind kind;

  @override
  Stream<List<WeeklyRaidStatusProjection>> watchCurrentCycleStatuses({
    required String playerId,
    required String cycleKey,
  }) => Stream.value([
    WeeklyRaidStatusProjection(
      playerId: playerId,
      characterId: 'AbCdEfGhIjKlMnOpQrSt',
      raidId: 'serca',
      cycleKey: cycleKey,
      kind: kind,
    ),
  ]);
}

RecruitmentLeaderCandidateQuery _query({
  int minItemLevel = 1700,
  int? minCombatPower,
  RecruitmentPartyRules? partyRules,
  List<OccupiedPartyMember> occupiedMembers = const [],
  String? replacingMemberId,
}) => RecruitmentLeaderCandidateQuery(
  raidId: 'serca',
  difficultyId: 'normal',
  minItemLevel: minItemLevel,
  minCombatPower: minCombatPower,
  startAt: DateTime.utc(2026, 8, 23, 10),
  maxPlayHours: 3,
  partyRules: partyRules,
  occupiedMembers: occupiedMembers,
  replacingMemberId: replacingMemberId,
);

class _AccountRepository implements AccountRepository {
  _AccountRepository({this.includeSubBuild = true});

  final bool includeSubBuild;

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
      label: '본계정',
      isMain: true,
      lookupCharacterName: '대표바드',
      representativeCharacterId: 1,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'AbCdEfGhIjKlMnOpQrSt',
          serverName: '루페온',
          characterName: '대표바드',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1750,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
        LocalAccountCharacter(
          id: 2,
          serverName: '루페온',
          characterName: '표시제외',
          characterLevel: 70,
          characterClassName: '블레이드',
          itemLevel: 1800,
          combatPower: 400000,
          isVisible: true,
          displayOrder: 1,
        ),
      ],
    ),
    LocalGameAccount(
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
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async {
    if (characterId == 3 && !includeSubBuild) return const [];
    final roles = characterId == 1
        ? CharacterBuildRole.values
        : const [CharacterBuildRole.dealer];
    return [for (final role in roles) _snapshot(characterId, role)];
  }

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
      label: '인증 상실 계정',
      isMain: true,
      lookupCharacterName: '대표바드',
      representativeCharacterId: 1,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverName: '루페온',
          characterName: '대표바드',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1750,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];
}

CharacterBuildSnapshot _snapshot(int characterId, CharacterBuildRole role) =>
    CharacterBuildSnapshot(
      id: characterId * 10 + role.index,
      characterId: characterId,
      role: role,
      rawJson: '{}',
      itemLevel: 1750,
      combatPower: 300000,
      capturedAt: DateTime.utc(2026, 8, 23),
      dataVersion: 1,
      analysis: CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
        catalogDetection: CharacterBuildCatalogDetection(
          catalogVersion: '2026.09.04',
          status: CharacterBuildDetectionStatus.detected,
          classId: 'bard',
          branchId: 'support',
          branchDisplayName: '서포터',
          detectedRole: role,
          matchedTier1Node: '절실한 구원',
          matchedRelatedNodes: [],
        ),
      ),
    );

class _BlockingAssignmentLookup implements ActiveRaidAssignmentLookup {
  const _BlockingAssignmentLookup();

  @override
  Future<bool> blocksCandidate({
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
  }) async => characterId == 'AbCdEfGhIjKlMnOpQrSt';
}
