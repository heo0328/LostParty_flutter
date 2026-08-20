import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_command_service.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_create_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_detail_page.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  testWidgets('좁은 화면에서 모집을 생성하고 상세 파티 구성을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryRecruitmentStateRepository();
    final service = RecruitmentCommandService(
      session: FakeUserSession('local-user'),
      clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/create',
          builder: (context, state) => RecruitmentCreatePage(
            accountRepository: _AccountRepository(),
            catalogRepository: _CatalogRepository(),
            commandService: service,
          ),
        ),
        GoRoute(
          path: '/recruitments/:id',
          builder: (context, state) => RecruitmentDetailPage(
            recruitmentId: state.pathParameters['id']!,
            repository: repository,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('saveRecruitmentButton')),
    );
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pump();
    expect(find.text('모집 제목을 입력해주세요.'), findsOneWidget);
    expect(find.text('1 이상의 전투력을 입력해주세요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recruitmentTitleField')),
      '세르카 클경 모집',
    );
    await tester.enterText(
      find.byKey(const ValueKey('minCombatPowerField')),
      '250000',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('saveRecruitmentButton')),
    );
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(find.text('세르카 클경 모집'), findsOneWidget);
    expect(find.text('세르카 - 노말 (노르카)'), findsOneWidget);
    expect(find.text('최소 전투력 250,000'), findsOneWidget);
    expect(find.text('1파티'), findsOneWidget);
    expect(find.text('대표바드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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

class _AccountRepository implements AccountRepository {
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
