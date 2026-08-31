import 'package:flutter/material.dart';
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
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_command_service.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/presentation/models/recruitment_form_draft.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_create_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/recruitment_form.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  testWidgets('일반 휴대폰 폭에서 레이드/난이도와 전투력/숙련도를 한 줄에 둔다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: RecruitmentForm(
              titleController: TextEditingController(text: '노르카 모집'),
              combatPowerController: TextEditingController(),
              draft: const RecruitmentFormDraft.empty(),
              raidOptions: [_option],
              selectedRaid: _raid,
              selectedDifficulty: _normal,
              onTitleChanged: (_) {},
              onRaidChanged: (_) {},
              onDifficultyChanged: (_) {},
              onCombatPowerChanged: (_) {},
              onExperienceChanged: (_) {},
              onApprovalChanged: (_) {},
              onSubmit: () {},
              submitLabel: '모집 생성',
              submitting: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('모집 제목'), findsOneWidget);
    expect(find.text('파티장 역할'), findsNothing);
    expect(
      tester.getTopLeft(find.text('레이드')).dx,
      lessThan(tester.getTopLeft(find.text('난이도')).dx),
    );
    expect(
      tester.getTopLeft(find.text('최소 전투력')).dx,
      lessThan(tester.getTopLeft(find.text('숙련도')).dx),
    );
  });

  testWidgets('좁은 폭에서는 한 줄 필드를 접어 잘리지 않게 한다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: RecruitmentForm(
              titleController: TextEditingController(text: '아주 긴 레이드 이름을 위한 제목'),
              combatPowerController: TextEditingController(),
              draft: const RecruitmentFormDraft.empty(),
              raidOptions: [_option],
              selectedRaid: _raid,
              selectedDifficulty: _normal,
              onTitleChanged: (_) {},
              onRaidChanged: (_) {},
              onDifficultyChanged: (_) {},
              onCombatPowerChanged: (_) {},
              onExperienceChanged: (_) {},
              onApprovalChanged: (_) {},
              onSubmit: () {},
              submitLabel: '모집 생성',
              submitting: false,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('레이드')).dx,
      tester.getTopLeft(find.text('난이도')).dx,
    );
    expect(
      tester.getTopLeft(find.text('레이드')).dy,
      lessThan(tester.getTopLeft(find.text('난이도')).dy),
    );
    expect(
      tester.getTopLeft(find.text('최소 전투력')).dx,
      tester.getTopLeft(find.text('숙련도')).dx,
    );
    expect(
      tester.getTopLeft(find.text('최소 전투력')).dy,
      lessThan(tester.getTopLeft(find.text('숙련도')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('복수 역할 직업만 작은 역할 선택을 보여주고 선호 포지션을 선선택한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final repository = InMemoryRecruitmentStateRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentCreatePage(
          catalogRepository: _CatalogRepository(),
          commandService: RecruitmentCommandService(
            session: session,
            clock: clock,
            idGenerator: SequentialRecruitmentIdGenerator(),
            repository: repository,
            weeklyClearRepository: weeklyRepository,
            assignmentRepository: assignmentRepository,
          ),
          candidateService: RecruitmentLeaderCandidateService(
            accountRepository: _DualRoleAccountRepository(),
            weeklyClearRepository: weeklyRepository,
            session: session,
            clock: clock,
            assignmentRepository: assignmentRepository,
            recruitmentRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('leaderRole-support')), findsOneWidget);
    expect(find.text('파티장 역할'), findsNothing);
    expect(find.text('서포터'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('leaderCandidateSelector'))).height,
      closeTo(
        tester.getSize(find.byKey(const ValueKey('leaderRole-support'))).height,
        1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('leaderRole-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('딜러').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leaderRole-dealer')), findsOneWidget);
  });
}

const _normal = RaidDifficultyDefinition(
  difficultyId: 'normal',
  name: '노말',
  displayAlias: '노르카',
  displayOrder: 1,
  minItemLevel: 1710,
  clearGold: 0,
  boundGold: 0,
  isActive: true,
);

const _raid = RaidDefinition(
  raidId: 'serca',
  officialName: '세르카',
  displayName: '세르카',
  aliases: ['노르카'],
  partySize: 4,
  partyCount: 1,
  requiredSupportCount: 1,
  maxDealerCountPerClass: 1,
  gateCount: 2,
  isActive: true,
  difficulties: [_normal],
);

final _option = EligibleRaidOption(raid: _raid, difficulties: const [_normal]);

class _CatalogRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: const [_raid],
  );
}

class _DualRoleAccountRepository implements AccountRepository {
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
  ];

  @override
  Future<LocalGameAccount?> loadMainAccount() async => const LocalGameAccount(
    id: 1,
    label: '계정',
    isMain: true,
    lookupCharacterName: '대표바드',
    representativeCharacterId: 1,
    displayLimit: 6,
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverName: '루페온',
        characterName: '대표바드',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1750,
        combatPower: 250000,
        isVisible: true,
        displayOrder: 0,
        preferredRole: CharacterBuildRole.support,
      ),
    ],
  );

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    CharacterBuildSnapshot(
      id: 1,
      characterId: characterId,
      role: CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1750,
      combatPower: 250000,
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
    CharacterBuildSnapshot(
      id: 2,
      characterId: characterId,
      role: CharacterBuildRole.support,
      rawJson: '{}',
      itemLevel: 1750,
      combatPower: 250000,
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
