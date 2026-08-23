import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_application_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_command_service.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';
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
    await repository.create(_representativePendingRecruitment);
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _AccountRepository();
    final assignmentRepository = InMemoryActiveRaidAssignmentRepository();
    final service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyRepository,
      assignmentRepository: assignmentRepository,
    );
    final candidateService = RecruitmentApplicationCandidateService(
      accountRepository: accountRepository,
      weeklyClearRepository: weeklyRepository,
      session: session,
      clock: clock,
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/create',
          builder: (context, state) => RecruitmentCreatePage(
            catalogRepository: _CatalogRepository(),
            commandService: service,
            candidateService: RecruitmentLeaderCandidateService(
              accountRepository: accountRepository,
              weeklyClearRepository: weeklyRepository,
              session: session,
              clock: clock,
              assignmentRepository: assignmentRepository,
              recruitmentRepository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/recruitments/:id',
          builder: (context, state) => RecruitmentDetailPage(
            recruitmentId: state.pathParameters['id']!,
            repository: repository,
            commandService: service,
            candidateService: candidateService,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('leaderCandidateSelector')));
    await tester.pumpAndSettle();
    expect(find.text('계정 · 본계정'), findsOneWidget);
    expect(find.text('부계정 · 부계정'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leader-candidate-부계정소서')));
    await tester.pumpAndSettle();
    expect(find.textContaining('부계정 · 부계정소서'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaderCandidateSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leader-candidate-대표바드')));
    await tester.pumpAndSettle();

    expect(find.text('파티원 승인'), findsNothing);
    expect(find.text('정족수 승인'), findsNothing);
    await tester.ensureVisible(find.text('파티장 승인'));
    await tester.tap(find.text('파티장 승인'));
    await tester.pumpAndSettle();
    expect(find.text('승인 없이 바로 가입'), findsOneWidget);
    await tester.tap(find.text('파티장 승인').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('saveRecruitmentButton')),
    );
    await tester.tap(find.byKey(const ValueKey('saveRecruitmentButton')));
    await tester.pump();
    expect(find.text('모집 제목을 입력해주세요.'), findsOneWidget);
    expect(find.text('1 이상의 전투력을 입력해주세요.'), findsNothing);

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

    expect(find.text('기존 신청을 취소할까요?'), findsOneWidget);
    expect(find.textContaining('동일 레이드 신청 1건'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('cancelPendingAndCreateButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('세르카 클경 모집'), findsOneWidget);
    expect(find.text('세르카 - 노말 (노르카)'), findsOneWidget);
    expect(find.text('최소 전투력 250,000'), findsOneWidget);
    expect(find.text('1파티'), findsOneWidget);
    expect(find.text('대표바드'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deleteRecruitmentButton')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('조건에 맞는 캐릭터로 신청하고 pending 신청을 철회한다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_otherUserRecruitment);
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _AccountRepository();
    final service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyRepository,
    );
    final candidateService = RecruitmentApplicationCandidateService(
      accountRepository: accountRepository,
      weeklyClearRepository: weeklyRepository,
      session: session,
      clock: clock,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentDetailPage(
          recruitmentId: _otherUserRecruitment.id,
          repository: repository,
          commandService: service,
          candidateService: candidateService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('openApplicationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('candidate-대표바드-support')));
    await tester.pumpAndSettle();

    expect(find.text('가입 승인 대기 중입니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('withdrawApplicationButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('openApplicationButton')), findsOneWidget);
  });

  testWidgets('즉시 가입 전 동일 레이드 pending 종료를 명시적으로 확인한다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    final existingPending = _otherUserRecruitment.copyWith(
      state: _otherUserRecruitment.state.copyWith(
        applications: const {
          'local-user': RecruitmentApplication(
            applicantUserId: 'local-user',
            characterId: '대표바드',
            className: '바드',
            requestedRole: PartyRole.support,
          ),
        },
      ),
    );
    await repository.create(existingPending);
    await repository.create(_directJoinRecruitment);
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _AccountRepository();
    final service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyRepository,
    );
    final candidateService = RecruitmentApplicationCandidateService(
      accountRepository: accountRepository,
      weeklyClearRepository: weeklyRepository,
      session: session,
      clock: clock,
      recruitmentRepository: repository,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentDetailPage(
          recruitmentId: _directJoinRecruitment.id,
          repository: repository,
          commandService: service,
          candidateService: candidateService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('openApplicationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('candidate-대표바드-support')));
    await tester.pumpAndSettle();

    expect(find.text('기존 신청을 취소할까요?'), findsOneWidget);
    expect(find.textContaining('동일 레이드 신청 1건'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('keepPendingApplicationsButton')),
    );
    await tester.pumpAndSettle();
    expect(
      (await repository.getById(
        existingPending.id,
      ))!.state.applications['local-user']!.status,
      RecruitmentApplicationStatus.pending,
    );

    await tester.tap(find.byKey(const ValueKey('openApplicationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('candidate-대표바드-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancelPendingAndJoinButton')));
    await tester.pumpAndSettle();

    expect(find.text('파티에 참가했습니다.'), findsOneWidget);
    expect(
      (await repository.getById(
        existingPending.id,
      ))!.state.applications['local-user']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  testWidgets('현재 파티원이 같은 역할의 소유 캐릭터로 변경한다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_memberRecruitment);
    await repository.create(_representativePendingRecruitment);
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _AccountRepository();
    final service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyRepository,
    );
    final candidateService = RecruitmentApplicationCandidateService(
      accountRepository: accountRepository,
      weeklyClearRepository: weeklyRepository,
      session: session,
      clock: clock,
      recruitmentRepository: repository,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentDetailPage(
          recruitmentId: _memberRecruitment.id,
          repository: repository,
          commandService: service,
          candidateService: candidateService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('openCharacterChangeButton')));
    await tester.pumpAndSettle();
    expect(find.text('변경할 캐릭터 선택'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('candidate-대표바드-support')));
    await tester.pumpAndSettle();

    expect(find.text('기존 신청을 취소할까요?'), findsOneWidget);
    expect(find.text('신청 취소하고 변경'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancelPendingAndJoinButton')));
    await tester.pumpAndSettle();

    expect(find.text('파티 캐릭터를 변경했습니다.'), findsOneWidget);
    expect(
      (await repository.getById(_memberRecruitment.id))!.state.members
          .singleWhere((member) => member.userId == 'local-user')
          .characterId,
      '대표바드',
    );
    expect(
      (await repository.getById(
        _representativePendingRecruitment.id,
      ))!.state.applications['local-user']!.status,
      RecruitmentApplicationStatus.superseded,
    );
  });

  testWidgets('자동 종료된 신청은 다른 캐릭터로 다시 지원할 수 있다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    final superseded = _representativePendingRecruitment.copyWith(
      state: _representativePendingRecruitment.state.copyWith(
        applications: {
          'local-user': _representativePendingRecruitment
              .state
              .applications['local-user']!
              .copyWith(status: RecruitmentApplicationStatus.superseded),
        },
      ),
    );
    await repository.create(superseded);
    final weeklyRepository = InMemoryWeeklyRaidClearRepository();
    final session = FakeUserSession('local-user');
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final accountRepository = _AccountRepository();
    final service = RecruitmentCommandService(
      session: session,
      clock: clock,
      idGenerator: SequentialRecruitmentIdGenerator(),
      repository: repository,
      weeklyClearRepository: weeklyRepository,
    );
    final candidateService = RecruitmentApplicationCandidateService(
      accountRepository: accountRepository,
      weeklyClearRepository: weeklyRepository,
      session: session,
      clock: clock,
      recruitmentRepository: repository,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentDetailPage(
          recruitmentId: superseded.id,
          repository: repository,
          commandService: service,
          candidateService: candidateService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reapplyWithAnotherCharacterButton')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('reapplyWithAnotherCharacterButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('신청 캐릭터와 역할 선택'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-부계정소서-dealer')),
      findsOneWidget,
    );
  });

  testWidgets('파티장이 pending 신청을 승인하면 파티 구성과 신청자 상태가 갱신된다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_pendingRecruitment);
    final session = FakeUserSession('other-user');
    final service = _service(repository, session);

    await tester.pumpWidget(MaterialApp(home: _detail(repository, service)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('pendingApplication-local-user')),
    );
    await tester.pumpAndSettle();
    expect(find.text('지원바드'), findsOneWidget);
    expect(find.text('파티장 승인 대기'), findsOneWidget);
    final approveButton = find.byKey(
      const ValueKey('approveApplication-local-user'),
    );
    await tester.ensureVisible(approveButton);
    await tester.tap(approveButton);
    await tester.pumpAndSettle();

    expect(find.text('가입 신청을 승인했습니다.'), findsOneWidget);
    expect(find.text('대기 중인 가입 신청이 없습니다.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('partyMember-local-user')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('지원바드'), findsOneWidget);

    session.signIn('local-user');
    await tester.pumpWidget(MaterialApp(home: _detail(repository, service)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('approvedApplicationStatus')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('가입이 승인되었습니다. 현재 파티원입니다.'), findsOneWidget);
  });

  testWidgets('파티장이 pending 신청을 거절하면 신청자에게 거절 상태를 표시한다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_pendingRecruitment);
    final session = FakeUserSession('other-user');
    final service = _service(repository, session);

    await tester.pumpWidget(MaterialApp(home: _detail(repository, service)));
    await tester.pumpAndSettle();
    final rejectButton = find.byKey(
      const ValueKey('rejectApplication-local-user'),
    );
    await tester.ensureVisible(rejectButton);
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();
    expect(find.text('가입 신청을 거절했습니다.'), findsOneWidget);

    session.signIn('local-user');
    await tester.pumpWidget(MaterialApp(home: _detail(repository, service)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('rejectedApplicationStatus')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('가입 신청이 거절되었습니다.'), findsOneWidget);
  });

  testWidgets('파티원이 수동 알림 전송 전에 확인하고 미연결 상태를 안내받는다', (
    tester,
  ) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_memberRecruitment);
    final service = _service(repository, FakeUserSession('local-user'));
    await tester.pumpWidget(
      MaterialApp(
        home: _detailFor(_memberRecruitment.id, repository, service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notifyPartyMembersButton')));
    await tester.pumpAndSettle();
    expect(find.text('참가 인원에게 알림을 보냅니다.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmNotifyPartyMembersButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Firebase 알림 서버 연결 후 사용할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('파티장이 레이드 수정 내용을 검토한 뒤 저장한다', (tester) async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_pendingRecruitment);
    final service = _service(repository, FakeUserSession('other-user'));
    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentDetailPage(
          recruitmentId: _pendingRecruitment.id,
          repository: repository,
          commandService: service,
          candidateService: RecruitmentApplicationCandidateService(
            accountRepository: _AccountRepository(),
            weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
            session: service.session,
            clock: service.clock,
          ),
          catalogRepository: _CatalogRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editRecruitmentRaidButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('reviewRecruitmentRaidEditButton')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('자동으로 제외되지 않습니다.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmRecruitmentRaidEditButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('레이드·난이도를 변경했습니다.'), findsOneWidget);
    expect((await repository.getById(_pendingRecruitment.id))!.revision, 1);
  });
}

RecruitmentDetailPage _detailFor(
  String recruitmentId,
  InMemoryRecruitmentStateRepository repository,
  RecruitmentCommandService service,
) => RecruitmentDetailPage(
  recruitmentId: recruitmentId,
  repository: repository,
  commandService: service,
  candidateService: RecruitmentApplicationCandidateService(
    accountRepository: _AccountRepository(),
    weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
    session: service.session,
    clock: service.clock,
  ),
);

RecruitmentCommandService _service(
  InMemoryRecruitmentStateRepository repository,
  FakeUserSession session,
) => RecruitmentCommandService(
  session: session,
  clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
  idGenerator: SequentialRecruitmentIdGenerator(),
  repository: repository,
);

RecruitmentDetailPage _detail(
  InMemoryRecruitmentStateRepository repository,
  RecruitmentCommandService service,
) => RecruitmentDetailPage(
  recruitmentId: _pendingRecruitment.id,
  repository: repository,
  commandService: service,
  candidateService: RecruitmentApplicationCandidateService(
    accountRepository: _AccountRepository(),
    weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
    session: service.session,
    clock: service.clock,
  ),
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

class _AccountRepository implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    (await loadMainAccount())!,
    const LocalGameAccount(
      id: 2,
      label: '부계정',
      isMain: false,
      lookupCharacterName: '부계정소서',
      representativeCharacterId: 2,
      displayLimit: 6,
      characters: [
        LocalAccountCharacter(
          id: 2,
          serverName: '카단',
          characterName: '부계정소서',
          characterLevel: 70,
          characterClassName: '소서리스',
          itemLevel: 1750,
          combatPower: 250000,
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
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    CharacterBuildSnapshot(
      id: 1,
      characterId: characterId,
      role: characterId == 1
          ? CharacterBuildRole.support
          : CharacterBuildRole.dealer,
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

final _otherUserRecruitment = RecruitmentAggregate(
  id: 'other-recruitment',
  title: '세르카 지원 테스트',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'serca',
    difficultyId: 'normal',
    raidName: '세르카',
    difficultyName: '노말',
    difficultyAlias: '노르카',
    gateCount: 2,
    minItemLevel: 1710,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  state: RecruitmentState(
    leaderUserId: 'other-user',
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
        userId: 'other-user',
        characterId: '다른리더',
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

final _pendingRecruitment = _otherUserRecruitment.copyWith(
  state: _otherUserRecruitment.state.copyWith(
    applications: const {
      'local-user': RecruitmentApplication(
        applicantUserId: 'local-user',
        characterId: '지원바드',
        className: '바드',
        requestedRole: PartyRole.support,
      ),
    },
  ),
);

final _representativePendingRecruitment = _otherUserRecruitment.copyWith(
  state: _otherUserRecruitment.state.copyWith(
    applications: const {
      'local-user': RecruitmentApplication(
        applicantUserId: 'local-user',
        characterId: '대표바드',
        className: '바드',
        requestedRole: PartyRole.support,
      ),
    },
  ),
);

final _directJoinRecruitment = RecruitmentAggregate(
  id: 'direct-join-recruitment',
  title: '세르카 바로 참가',
  metadata: _otherUserRecruitment.metadata,
  state: RecruitmentState(
    leaderUserId: 'direct-leader',
    approvalPolicy: const ApprovalPolicy.directJoin(),
    compositionPolicy: _otherUserRecruitment.state.compositionPolicy,
    members: const [
      RecruitmentPartyMember(
        userId: 'direct-leader',
        characterId: '즉시리더',
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

final _memberRecruitment = RecruitmentAggregate(
  id: 'member-recruitment',
  title: '캐릭터 변경 테스트',
  metadata: _otherUserRecruitment.metadata,
  state: RecruitmentState(
    leaderUserId: 'other-user',
    approvalPolicy: const ApprovalPolicy.leaderOnly(),
    compositionPolicy: _otherUserRecruitment.state.compositionPolicy,
    members: const [
      RecruitmentPartyMember(
        userId: 'other-user',
        characterId: '다른리더',
        className: '블레이드',
        role: PartyRole.dealer,
        partyIndex: 0,
      ),
      RecruitmentPartyMember(
        userId: 'local-user',
        characterId: '기존바드',
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
