import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_create_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_command_service.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_create_page.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  testWidgets('인증된 캐릭터로 모집을 만들면 Firestore 명령을 보내고 현황 상세로 이동한다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createRepository = _RecordingPartyCreateRepository();
    final session = FakeUserSession('player-1');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _VerifiedAccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    final commandService = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: recruitmentRepository,
      weeklyClearRepository: weeklyRepository,
      assignmentRepository: assignmentRepository,
    );
    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/create',
          builder: (context, state) => RecruitmentCreatePage(
            catalogRepository: _CatalogRepository(),
            commandService: commandService,
            candidateService: RecruitmentLeaderCandidateService(
              accountRepository: accountRepository,
              weeklyClearRepository: weeklyRepository,
              session: session,
              clock: clock,
              assignmentRepository: assignmentRepository,
              recruitmentRepository: recruitmentRepository,
            ),
            partyCreateRepository: createRepository,
            newRecruitmentId: () => 'firestore-recruitment-1',
            cycleKey: '2026-08-19',
          ),
        ),
        GoRoute(
          path: '/raid-status/:recruitmentId',
          builder: (context, state) => Scaffold(
            body: Text(
              'read-detail:${state.pathParameters['recruitmentId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(createRepository.lastCommand?.leaderCharacterId, 'server-char-1');
    expect(createRepository.lastCommand?.cycleKey, '2026-08-19');
    expect(createRepository.lastCommand?.recruitmentId, 'firestore-recruitment-1');
    expect(createRepository.lastCommand?.groupId, isNull);
    expect(
      createRepository.lastCommand?.visibility,
      RecruitmentVisibility.public,
    );
    expect(find.text('read-detail:firestore-recruitment-1'), findsOneWidget);
    expect(
      await recruitmentRepository.getById('firestore-recruitment-1'),
      isNull,
    );
  });

  testWidgets('서버 캐릭터 ID가 없으면 Firestore 명령을 보내지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createRepository = _RecordingPartyCreateRepository();
    final session = FakeUserSession('player-1');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _LocalOnlyAccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    final commandService = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: recruitmentRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentCreatePage(
          catalogRepository: _CatalogRepository(),
          commandService: commandService,
          candidateService: RecruitmentLeaderCandidateService(
            accountRepository: accountRepository,
            weeklyClearRepository: weeklyRepository,
            session: session,
            clock: clock,
            assignmentRepository: assignmentRepository,
            recruitmentRepository: recruitmentRepository,
          ),
          partyCreateRepository: createRepository,
          newRecruitmentId: () => 'firestore-recruitment-1',
          cycleKey: '2026-08-19',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(createRepository.lastCommand, isNull);
    expect(find.text('게임 계정 인증이 완료된 캐릭터만 모집을 만들 수 있습니다.'), findsOneWidget);
  });

  testWidgets('그룹 레이드를 만들면 선택한 그룹과 그룹 전용 공개를 저장한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createRepository = _RecordingPartyCreateRepository();
    final session = FakeUserSession('player-1');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _VerifiedAccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    final commandService = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: recruitmentRepository,
      weeklyClearRepository: weeklyRepository,
      assignmentRepository: assignmentRepository,
    );
    await _pumpCreateRoute(
      tester,
      RecruitmentCreatePage(
        catalogRepository: _CatalogRepository(),
        commandService: commandService,
        candidateService: RecruitmentLeaderCandidateService(
          accountRepository: accountRepository,
          weeklyClearRepository: weeklyRepository,
          session: session,
          clock: clock,
          assignmentRepository: assignmentRepository,
          recruitmentRepository: recruitmentRepository,
        ),
        partyCreateRepository: createRepository,
        groupReadRepository: _FakeGroupReadRepository([_memberGroup]),
        playerId: 'player-1',
        newRecruitmentId: () => 'group-recruitment-1',
        cycleKey: '2026-08-19',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹 레이드'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(createRepository.lastCommand?.groupId, 'group-1');
    expect(
      createRepository.lastCommand?.visibility,
      RecruitmentVisibility.group,
    );
  });

  testWidgets('그룹 레이드에서 그룹만 공개를 끄면 전체 공개로 저장한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createRepository = _RecordingPartyCreateRepository();
    final session = FakeUserSession('player-1');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _VerifiedAccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    await _pumpCreateRoute(
      tester,
      RecruitmentCreatePage(
        catalogRepository: _CatalogRepository(),
        commandService: RecruitmentCommandService(
          session: session,
          clock: clock,
          idGenerator: SequentialRecruitmentIdGenerator(),
          repository: recruitmentRepository,
          weeklyClearRepository: weeklyRepository,
          assignmentRepository: assignmentRepository,
        ),
        candidateService: RecruitmentLeaderCandidateService(
          accountRepository: accountRepository,
          weeklyClearRepository: weeklyRepository,
          session: session,
          clock: clock,
          assignmentRepository: assignmentRepository,
          recruitmentRepository: recruitmentRepository,
        ),
        partyCreateRepository: createRepository,
        groupReadRepository: _FakeGroupReadRepository([_memberGroup]),
        playerId: 'player-1',
        newRecruitmentId: () => 'group-recruitment-public-1',
        cycleKey: '2026-08-19',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹 레이드'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groupOnlyVisibilityCheckbox')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(createRepository.lastCommand?.groupId, 'group-1');
    expect(
      createRepository.lastCommand?.visibility,
      RecruitmentVisibility.public,
    );
  });

  testWidgets('가입 그룹이 없으면 그룹 레이드를 만들지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createRepository = _RecordingPartyCreateRepository();
    final session = FakeUserSession('player-1');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _VerifiedAccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final recruitmentRepository = InMemoryRecruitmentStateRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentCreatePage(
          catalogRepository: _CatalogRepository(),
          commandService: RecruitmentCommandService(
            session: session,
            clock: clock,
            idGenerator: SequentialRecruitmentIdGenerator(),
            repository: recruitmentRepository,
          ),
          candidateService: RecruitmentLeaderCandidateService(
            accountRepository: accountRepository,
            weeklyClearRepository: weeklyRepository,
            session: session,
            clock: clock,
            assignmentRepository: assignmentRepository,
            recruitmentRepository: recruitmentRepository,
          ),
          partyCreateRepository: createRepository,
          groupReadRepository: _FakeGroupReadRepository(const []),
          playerId: 'player-1',
          newRecruitmentId: () => 'group-recruitment-1',
          cycleKey: '2026-08-19',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹 레이드'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('noJoinedGroupsText')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();
    expect(createRepository.lastCommand, isNull);
    expect(find.textContaining('가입한 그룹이 없어'), findsOneWidget);
  });
}

Future<void> _pumpCreateRoute(WidgetTester tester, Widget page) async {
  final router = GoRouter(
    initialLocation: '/create',
    routes: [
      GoRoute(path: '/create', builder: (_, __) => page),
      GoRoute(
        path: '/raid-status/:recruitmentId',
        builder: (context, state) => Scaffold(
          body: Text(
            'read-detail:${state.pathParameters['recruitmentId']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

class _RecordingPartyCreateRepository implements PartyCreateRepository {
  PartyCreateCommand? lastCommand;

  @override
  Future<PartyCreateResult> create(PartyCreateCommand command) async {
    lastCommand = command;
    return PartyCreateResult.success(command.recruitmentId);
  }
}

class _FakeGroupReadRepository extends Fake implements GroupReadRepository {
  _FakeGroupReadRepository(this.groups);

  final List<GroupRelation> groups;

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) =>
      Stream.value(GroupReadSnapshot(items: groups, isFromCache: false));
}

final _memberGroup = GroupRelation(
  groupId: 'group-1',
  playerId: 'player-1',
  relation: GroupRelationKind.member,
  groupNameSnapshot: '테스트그룹',
  displayCharacterNameSnapshot: '대표바드',
  sourceRevision: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

class _CatalogRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 2,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: const [
      RaidDefinition(
        raidId: 'serca',
        officialName: '고통의 마녀, 세르카',
        displayName: '세르카',
        aliases: ['세르카'],
        partySize: 4,
        partyCount: 1,
        requiredSupportCount: 1,
        maxDealerCountPerClass: 1,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'normal',
            name: '노말',
            displayAlias: '노르카',
            displayOrder: 1,
            minItemLevel: 1710,
            clearGold: 16000,
            boundGold: 16000,
            isActive: true,
          ),
        ],
      ),
    ],
  );
}

class _VerifiedAccountRepository implements AccountRepository {

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
    serverOwnershipStatus: 'active',
    characters: [
      LocalAccountCharacter(
        id: 1,
        serverCharacterId: 'server-char-1',
        serverName: '루페온',
        characterName: '대표바드',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1750,
        combatPower: 250000,
        isVisible: true,
        displayOrder: 0,
      ),
    ],
  );

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [_snapshot(characterId)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalOnlyAccountRepository extends _VerifiedAccountRepository {
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
      ),
    ],
  );
}

CharacterBuildSnapshot _snapshot(int characterId) => CharacterBuildSnapshot(
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
);
