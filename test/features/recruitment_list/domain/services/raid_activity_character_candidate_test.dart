import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/raid_activity_character_source.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_application_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  test('표시 개수와 무관하게 활동 Character만 레이드 후보로 쓴다', () {
    const account = LocalGameAccount(
      id: 1,
      label: '본계정',
      isMain: true,
      lookupCharacterName: '대표바드',
      representativeCharacterId: 1,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'char-1',
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
          serverCharacterId: 'char-2',
          serverName: '루페온',
          characterName: '활동부캐',
          characterLevel: 70,
          characterClassName: '블레이드',
          itemLevel: 1800,
          combatPower: 400000,
          isVisible: true,
          displayOrder: 1,
        ),
        LocalAccountCharacter(
          id: 3,
          serverCharacterId: 'char-3',
          serverName: '루페온',
          characterName: '비활동',
          characterLevel: 70,
          characterClassName: '워로드',
          itemLevel: 1800,
          combatPower: 400000,
          isVisible: true,
          displayOrder: 2,
        ),
      ],
    );

    expect(
      account.visibleCharacters.map((character) => character.characterName),
      ['대표바드'],
    );
    expect(
      raidCandidateCharacters(account, {
        'char-1',
        'char-2',
      }).map((character) => character.characterName),
      ['대표바드', '활동부캐'],
    );
    expect(raidCandidateCharacters(account, const {}), isEmpty);
  });

  test('모집 생성 후보에서 비활동 Character를 제외한다', () async {
    final service = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
      activityCharactersRepository: _FakeActivityCharactersRepository({
        'char-1',
        'char-2',
      }),
      claimPlayerId: 'player-1',
    );

    final candidates = await service.load(
      RecruitmentLeaderCandidateQuery(
        raidId: 'serca',
        difficultyId: 'normal',
        minItemLevel: 1700,
        startAt: DateTime.utc(2026, 8, 23, 10),
        maxPlayHours: 3,
      ),
    );

    expect(candidates.map((candidate) => candidate.characterId), [
      '대표바드',
      '활동부캐',
    ]);
    expect(
      candidates.any((candidate) => candidate.characterId == '비활동'),
      isFalse,
    );
  });

  test('신청과 참가 Character 변경 후보에서 비활동 Character를 제외한다', () async {
    final service = RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-b'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
      activityCharactersRepository: _FakeActivityCharactersRepository({
        'char-1',
        'char-2',
      }),
      claimPlayerId: 'player-1',
    );

    final apply = await service.load(_aggregate);
    final change = await service.loadForCharacterChange(_memberAggregate);

    expect(apply.map((candidate) => candidate.characterId).toSet(), {
      '대표바드',
      '활동부캐',
    });
    expect(change.map((candidate) => candidate.characterId).toSet(), {'활동부캐'});
    expect(_memberAggregate.state.members.single.characterId, '대표바드');
  });

  test('활동 설정이 없으면 새 레이드 후보를 만들지 않는다', () async {
    final leader = RecruitmentLeaderCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 23)),
      assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
      recruitmentRepository: InMemoryRecruitmentStateRepository(),
      activityCharactersRepository: _FakeActivityCharactersRepository({}),
      claimPlayerId: 'player-1',
    );

    expect(
      await leader.load(
        RecruitmentLeaderCandidateQuery(
          raidId: 'serca',
          difficultyId: 'normal',
          minItemLevel: 1700,
          startAt: DateTime.utc(2026, 8, 23, 10),
          maxPlayHours: 3,
        ),
      ),
      isEmpty,
    );
  });
}

class _FakeActivityCharactersRepository
    implements ActivityCharactersRepository {
  _FakeActivityCharactersRepository(this.characterIds);

  final Set<String> characterIds;

  @override
  Future<ActivityCharacters> load({required String playerId}) async {
    return ActivityCharacters(playerId: playerId, characterIds: characterIds);
  }

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    throw UnimplementedError();
  }
}

class _AccountRepository implements AccountRepository {
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
          serverCharacterId: 'char-1',
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
          serverCharacterId: 'char-2',
          serverName: '루페온',
          characterName: '활동부캐',
          characterLevel: 70,
          characterClassName: '블레이드',
          itemLevel: 1800,
          combatPower: 400000,
          isVisible: true,
          displayOrder: 1,
        ),
        LocalAccountCharacter(
          id: 3,
          serverCharacterId: 'char-3',
          serverName: '루페온',
          characterName: '비활동',
          characterLevel: 70,
          characterClassName: '워로드',
          itemLevel: 1800,
          combatPower: 400000,
          isVisible: true,
          displayOrder: 2,
        ),
      ],
    ),
  ];

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    CharacterBuildSnapshot(
      id: characterId,
      characterId: characterId,
      role: characterId == 1
          ? CharacterBuildRole.support
          : CharacterBuildRole.dealer,
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
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _aggregate = RecruitmentAggregate(
  id: 'recruitment-1',
  title: '세르나',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: 'normal',
    raidName: '세르나',
    difficultyName: '노말',
    difficultyAlias: '노르나',
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
        className: '발키르',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);

final _memberAggregate = RecruitmentAggregate(
  id: 'recruitment-1',
  title: '세르나',
  metadata: _aggregate.metadata,
  state: RecruitmentState(
    leaderUserId: 'user-b',
    approvalPolicy: const ApprovalPolicy.leaderOnly(),
    compositionPolicy: _aggregate.state.compositionPolicy,
    members: const [
      RecruitmentPartyMember(
        userId: 'user-b',
        characterId: '대표바드',
        className: '바드',
        role: PartyRole.support,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);
