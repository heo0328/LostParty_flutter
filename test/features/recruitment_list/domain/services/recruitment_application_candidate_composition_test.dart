import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_application_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  test('4인 파티에서 방장과 같은 딜러 직업 신청 후보를 차단한다', () async {
    final candidates = await _service().load(_fourPlayerAggregate);

    final dealer = candidates.singleWhere(
      (item) => item.characterId == '신청블레이드',
    );
    expect(dealer.canApply, isFalse);
    expect(dealer.rejectionReasons, contains('동일 딜러 직업 자리가 없습니다.'));
  });

  test('8인 파티에서는 다른 파티 배치가 가능한 동일 딜러 직업을 허용한다', () async {
    final candidates = await _service().load(_eightPlayerAggregate);

    final dealer = candidates.singleWhere(
      (item) => item.characterId == '신청블레이드',
    );
    expect(dealer.canApply, isTrue);
  });
}

RecruitmentApplicationCandidateService _service() =>
    RecruitmentApplicationCandidateService(
      accountRepository: _AccountRepository(),
      weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
      session: FakeUserSession('user-b'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    );

final _fourPlayerAggregate = RecruitmentAggregate(
  id: 'recruitment-1',
  title: '세르카',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: 'normal',
    raidName: '세르카',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 2,
    minItemLevel: 1710,
    minCombatPower: null,
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
        characterId: '리더블레이드',
        className: '블레이드',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);

final _eightPlayerAggregate = RecruitmentAggregate(
  id: 'recruitment-8',
  title: '세르카',
  metadata: _fourPlayerAggregate.metadata,
  state: RecruitmentState(
    leaderUserId: 'user-a',
    approvalPolicy: const ApprovalPolicy.leaderOnly(),
    compositionPolicy: const PartyCompositionPolicy(
      RecruitmentPartyRules(
        partyCount: 2,
        membersPerParty: 4,
        supportsPerParty: 1,
        maxDealersPerClassPerParty: 1,
      ),
    ),
    members: const [
      RecruitmentPartyMember(
        userId: 'user-a',
        characterId: '리더블레이드',
        className: '블레이드',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
    ],
  ),
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);

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
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '신청블레이드',
      representativeCharacterId: 1,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'char-blade',
          serverName: '루페온',
          characterName: '신청블레이드',
          characterLevel: 70,
          characterClassName: '블레이드',
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
  ) async => [
    CharacterBuildSnapshot(
      id: characterId,
      characterId: characterId,
      role: CharacterBuildRole.dealer,
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
