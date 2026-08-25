import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/active_raid_assignment.dart';
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
}

RecruitmentLeaderCandidateQuery _query({int minItemLevel = 1700}) =>
    RecruitmentLeaderCandidateQuery(
      raidId: 'serca',
      difficultyId: 'normal',
      minItemLevel: minItemLevel,
      startAt: DateTime.utc(2026, 8, 23, 10),
      maxPlayHours: 3,
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
      analysis: const CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
      ),
    );
