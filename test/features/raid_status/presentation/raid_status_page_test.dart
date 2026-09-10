import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';
import 'package:lost_party/features/group/domain/repositories/group_character_search_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/raid_status/data/repositories/drift_raid_status_filter_store.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_filter_screen.dart';
import 'package:lost_party/features/raid_status/domain/repositories/raid_status_filter_store.dart';
import 'package:lost_party/features/raid_status/presentation/pages/party_read_detail_page.dart';
import 'package:lost_party/features/raid_status/presentation/pages/raid_status_page.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  Future<FakePartyEventSyncService> pumpPage(
    WidgetTester tester, {
    Stream<PartyReadSnapshot<ActiveRaidSummary>>? activeRaids,
    Stream<PartyReadSnapshot<PartyApplicationSummary>>? applications,
    AccountDatabase? database,
    RaidCatalogRepository? raidCatalogRepository,
    RaidStatusFilterStore? filterStore,
    GroupReadRepository? groupReadRepository,
    ActivityCharactersRepository? activityCharactersRepository,
    GroupCharacterSearchRepository? characterSearchRepository,
    Stream<PartyReadSnapshot<PartyMemberDisplay>> Function(
      String recruitmentId,
    )?
    membersForId,
    VoidCallback? onInitialLoadComplete,
  }) async {
    final activeDatabase = database ?? AccountDatabase(NativeDatabase.memory());
    if (database == null) addTearDown(activeDatabase.close);
    final syncService = FakePartyEventSyncService();

    await tester.pumpWidget(
      MaterialApp(
        home: RaidStatusPage(
          partyReadRepository: FakePartyReadRepository(
            activeRaids: activeRaids,
            applications: applications,
            membersForId: membersForId,
          ),
          accountDatabase: activeDatabase,
          eventSyncService: syncService,
          playerId: 'player-1',
          cycleKey: '2026-08-19',
          raidCatalogRepository: raidCatalogRepository,
          filterStore: filterStore,
          groupReadRepository: groupReadRepository,
          activityCharactersRepository: activityCharactersRepository,
          characterSearchRepository: characterSearchRepository,
          onInitialLoadComplete: onInitialLoadComplete,
        ),
      ),
    );
    return syncService;
  }

  testWidgets('첫 snapshot 전에는 로딩을 표시한다', (tester) async {
    final pending = StreamController<PartyReadSnapshot<ActiveRaidSummary>>();
    addTearDown(pending.close);

    await pumpPage(tester, activeRaids: pending.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('두 목록과 부가 로딩 및 첫 렌더링 뒤 초기 완료를 한 번 알린다', (
    tester,
  ) async {
    final active = StreamController<PartyReadSnapshot<ActiveRaidSummary>>();
    final applications =
        StreamController<PartyReadSnapshot<PartyApplicationSummary>>();
    addTearDown(active.close);
    addTearDown(applications.close);
    var completedCount = 0;

    await pumpPage(
      tester,
      activeRaids: active.stream,
      applications: applications.stream,
      onInitialLoadComplete: () => completedCount++,
    );
    await tester.pump();
    expect(completedCount, 0);

    active.add(const PartyReadSnapshot(items: [], isFromCache: false));
    await tester.pump();
    expect(completedCount, 0);

    applications.add(const PartyReadSnapshot(items: [], isFromCache: false));
    await tester.pumpAndSettle();
    expect(completedCount, 1);

    active.add(const PartyReadSnapshot(items: [], isFromCache: false));
    applications.add(const PartyReadSnapshot(items: [], isFromCache: false));
    await tester.pump();
    expect(completedCount, 1);
  });

  testWidgets('두 목록의 첫 오류도 초기 로딩 완료 조건으로 처리한다', (tester) async {
    var completedCount = 0;

    await pumpPage(
      tester,
      activeRaids: Stream.error(StateError('active failed')),
      applications: Stream.error(StateError('applications failed')),
      onInitialLoadComplete: () => completedCount++,
    );
    await tester.pumpAndSettle();

    expect(completedCount, 1);
  });

  testWidgets('빈 목록은 빈 상태로 표시한다', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('진행 중인 레이드가 없습니다.'), findsOneWidget);
    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsNothing);
  });

  testWidgets('진행 중인 파티를 목록으로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.textContaining('4막 - 노말'), findsOneWidget);
    expect(find.text('내가 만든 방'), findsOneWidget);
    expect(find.text('이슈아이'), findsOneWidget);
    expect(find.text('파티장 이슈아이 · 기상술사'), findsNothing);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('진행 중 카드에 방별 읽지 않은 이벤트 수를 표시한다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    for (var index = 0; index < 2; index++) {
      await database.syncPartyNotificationReceipt(
        eventId: 'room-event-$index',
        playerId: 'player-1',
        type: PartyEventType.applicationSubmitted.wireName,
        recruitmentId: 'recruitment-1',
        occurredAt: DateTime.utc(2026, 8, 26, 12, index),
        expiresAt: DateTime.utc(2026, 9, 23),
      );
    }

    await pumpPage(
      tester,
      database: database,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(
      const ValueKey('raidRoomUnreadBadge_recruitment-1'),
    );
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('진행 중 목록을 아래로 당기면 방별 읽지 않은 수를 다시 읽는다', (
    tester,
  ) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpPage(
      tester,
      database: database,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('raidRoomUnreadBadge_recruitment-1')),
      findsNothing,
    );

    await database.syncPartyNotificationReceipt(
      eventId: 'new-room-event',
      playerId: 'player-1',
      type: PartyEventType.applicationSubmitted.wireName,
      recruitmentId: 'recruitment-1',
      occurredAt: DateTime.utc(2026, 9, 8, 6),
      expiresAt: DateTime.utc(2026, 10, 6),
    );
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(
      const ValueKey('raidRoomUnreadBadge_recruitment-1'),
    );
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);
  });

  testWidgets('진행 중 카드에 남은 자리와 제한을 한 줄로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [_activeRaid(raidStartAt: DateTime.utc(2026, 8, 26, 12))],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8/26(수) 21:00'), findsNothing);
    expect(
      find.text('멤버 2/8 · 남은 자리 6 · 전투력 제한 없음 · 숙련도 제한 없음'),
      findsOneWidget,
    );
  });

  testWidgets('그룹 전용 진행 중 카드에 그룹 배지를 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [_activeRaid(visibility: 'group', groupId: 'group-1')],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('그룹'), findsOneWidget);
  });

  testWidgets('반복 레이드의 이번 주 진행 상태를 배지로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [_activeRaid(continueTogether: true)],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('금주 진행'), findsOneWidget);
    expect(find.text('다음주 대기'), findsNothing);
  });

  testWidgets('완료된 반복 레이드는 다음 주 대기 상태를 배지로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [
            _activeRaid(
              continueTogether: true,
              currentCycleStatus: 'completed',
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('다음주 대기'), findsOneWidget);
    expect(find.text('금주 진행'), findsNothing);
  });

  testWidgets('신청 중은 승인 대기와 처리 결과를 나누어 표시한다', (tester) async {
    await pumpPage(
      tester,
      applications: Stream.value(
        PartyReadSnapshot(
          items: [
            _application(
              characterId: 'character-1',
              characterName: '대기캐릭',
              status: RecruitmentApplicationStatus.pending,
            ),
            _application(
              characterId: 'character-2',
              characterName: '종료캐릭',
              status: RecruitmentApplicationStatus.superseded,
              resolutionReason: 'recruitmentClosed',
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pendingRaidsTab')));
    await tester.pumpAndSettle();

    expect(find.text('승인 대기'), findsWidgets);
    expect(find.text('최근 처리 결과'), findsOneWidget);
    expect(find.text('모집이 종료되어 신청이 닫혔습니다.'), findsOneWidget);
    expect(find.text('대기캐릭'), findsOneWidget);
    expect(find.text('종료캐릭'), findsOneWidget);
  });

  testWidgets('캐시 snapshot이면 오프라인 안내를 함께 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsOneWidget);
  });

  testWidgets('목록 없이 발생한 오류는 실패 안내로 표시한다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.error(
        const PartyReadException(PartyReadFailureType.permissionDenied),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('조회 권한을 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsNothing);
  });

  testWidgets('진입 시 이벤트 동기화를 실행하고 완료 기록 빈 상태를 표시한다', (tester) async {
    final syncService = await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(syncService.syncCount, 1);

    await tester.tap(find.byKey(const ValueKey('raidHistoryTab')));
    await tester.pumpAndSettle();

    expect(find.text('완료 기록이 없습니다.'), findsOneWidget);
  });

  testWidgets('완료 기록을 숨기면 목록에서 사라지고 토글로 되돌릴 수 있다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.syncPartyHistoryEvent(
      eventId: 'event-1',
      playerId: 'player-1',
      characterId: 'character-1',
      recruitmentId: 'recruitment-1',
      raidId: 'act4',
      difficultyId: 'normal',
      cycleKey: '2026-08-19',
      serverStatus: 'completed',
      occurredAt: DateTime.utc(2026, 8, 20),
    );

    await pumpPage(tester, database: database);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidHistoryTab')));
    await tester.pumpAndSettle();

    expect(find.text('act4 - normal'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('숨기기'));
    await tester.pumpAndSettle();

    expect(find.text('act4 - normal'), findsNothing);
    expect(find.text('완료 기록이 없습니다.'), findsOneWidget);

    await tester.tap(find.text('숨긴 기록 보기'));
    await tester.pumpAndSettle();

    expect(find.text('act4 - normal'), findsOneWidget);
    expect(find.text('목록에서 숨긴 기록입니다.'), findsOneWidget);
  });

  testWidgets('진행 중 카드를 누르면 읽기 전용 상세로 이동한다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FakePartyReadRepository(
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _publicSummary(), isFromCache: false),
      ),
    );
    final router = GoRouter(
      initialLocation: '/raid-status',
      routes: [
        GoRoute(
          path: '/raid-status',
          builder: (context, state) => RaidStatusPage(
            partyReadRepository: repository,
            accountDatabase: database,
            eventSyncService: FakePartyEventSyncService(),
            playerId: 'player-1',
            cycleKey: '2026-08-19',
          ),
          routes: [
            GoRoute(
              path: ':recruitmentId',
              builder: (context, state) => PartyReadDetailPage(
                recruitmentId: state.pathParameters['recruitmentId']!,
                partyReadRepository: repository,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4막 노말 모집'));
    await tester.pumpAndSettle();

    expect(find.text('이 화면은 조회 전용입니다. 신청과 수정은 아직 연결되지 않았습니다.'), findsOneWidget);
    expect(find.text('모집 수정'), findsNothing);
    expect(repository.requestedRecruitmentId, 'recruitment-1');
  });

  testWidgets('진행 중 탭에 레이드 필터 영역을 두고 신청 중에는 두지 않는다', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('레이드 필터: 모든 레이드'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pendingRaidsTab')));
    await tester.pumpAndSettle();
    expect(find.text('레이드 필터: 모든 레이드'), findsNothing);
  });

  testWidgets('공개 조건 필터는 로컬 원본만 좁히고 둘 다 해제하면 전체로 돌아간다', (tester) async {
    await pumpPage(
      tester,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [
            _activeRaid(),
            _activeRaid(
              id: 'group-raid',
              title: '그룹 세르카',
              raidId: 'serca',
              groupId: 'group-1',
              visibility: 'group',
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('그룹 세르카'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('raidStatusFilterCount')), findsOneWidget);
    expect(find.text('2개'), findsWidgets);
    expect(find.text('그룹원'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicOpen')));
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsNothing);
    expect(find.text('그룹 세르카'), findsOneWidget);
    expect(find.text('레이드 필터: 그룹 공개'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicGroup')));
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('그룹 세르카'), findsOneWidget);
    expect(find.text('레이드 필터: 모든 레이드'), findsOneWidget);
  });

  testWidgets('레이드 칩은 차원 AND로 목록을 좁히고 개수를 즉시 갱신한다', (tester) async {
    await pumpPage(
      tester,
      raidCatalogRepository: _FilterCatalogRepository(),
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [
            _activeRaid(),
            _activeRaid(
              id: 'serca-raid',
              title: '세르카 하드',
              raidId: 'serca',
              difficultyId: 'hard',
              groupId: 'group-1',
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('raidStatusFilterRaidChip-act4')),
    );
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('세르카 하드'), findsNothing);
    expect(find.text('1개'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('raidStatusFilterDifficultyChip-hard')),
    );
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 레이드가 없습니다.'), findsOneWidget);
    expect(find.text('0개'), findsWidgets);
  });

  testWidgets('필터 선택은 앱 재진입 후에도 로컬에 남는다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftRaidStatusFilterStore(database);
    final snapshot = PartyReadSnapshot(
      items: [
        _activeRaid(),
        _activeRaid(
          id: 'group-raid',
          title: '그룹 세르카',
          raidId: 'serca',
          groupId: 'group-1',
          visibility: 'group',
        ),
      ],
      isFromCache: false,
    );

    await pumpPage(
      tester,
      activeRaids: Stream.value(snapshot),
      database: database,
      filterStore: store,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicOpen')));
    await tester.pumpAndSettle();
    expect(find.text('그룹 세르카'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
    expect(
      (await store.load('player-1', RaidFilterScreen.activeRaids)).includeGroup,
      isTrue,
    );
    expect(
      (await store.load(
        'player-1',
        RaidFilterScreen.activeRaids,
      )).includePublic,
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage(
      tester,
      activeRaids: Stream.value(snapshot),
      database: database,
      filterStore: store,
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(find.text('레이드 필터: 그룹 공개'), findsOneWidget);
    expect(find.text('그룹 세르카'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
  });

  testWidgets('그룹원 칩은 현재 Player를 제외하고 AND로 목록과 개수를 갱신한다', (tester) async {
    await pumpPage(
      tester,
      groupReadRepository: _PageGroupReadRepository(
        groups: [_pageGroupRelation()],
        membersByGroup: {
          'group-1': [
            _pageGroupMember(playerId: 'player-1', name: '내캐릭'),
            _pageGroupMember(playerId: 'player-2', name: '친구딜러'),
            _pageGroupMember(playerId: 'player-3', name: '친구서폿'),
          ],
        },
      ),
      activityCharactersRepository: _PageActivity({
        'player-2': {'char-21'},
        'player-3': {'char-33'},
      }),
      characterSearchRepository: _PageSearch({
        'player-2': [
          _pageSearchChar(playerId: 'player-2', id: 'char-21', name: '딜러A'),
        ],
        'player-3': [
          _pageSearchChar(playerId: 'player-3', id: 'char-33', name: '서폿A'),
        ],
      }),
      membersForId: (id) => Stream.value(
        PartyReadSnapshot(
          items: [
            _pageMemberDisplay(playerId: 'player-2', characterId: 'char-21'),
            _pageMemberDisplay(playerId: 'player-3', characterId: 'char-33'),
          ],
          isFromCache: false,
        ),
      ),
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [
            _activeRaid(
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2', 'player-3'},
            ),
            _activeRaid(
              id: 'only-two',
              title: '그룹 세르카',
              raidId: 'serca',
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2'},
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
      findsNothing,
    );
    expect(find.text('그룹원'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicOpen')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-1')),
      findsNothing,
    );
    expect(find.text('내캐릭'), findsNothing);
    expect(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
    );
    await tester.tap(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-3')),
    );
    await tester.tap(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-3')),
    );
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('그룹 세르카'), findsNothing);
    expect(find.text('1개'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('raidStatusFilterCharacterChip-player-2-char-21'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('raidStatusFilterCharacterChip-player-2-char-21'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('1개'), findsWidgets);
  });

  testWidgets('그룹원 선택은 앱 재진입 후에도 로컬에 남는다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftRaidStatusFilterStore(database);
    final groups = _PageGroupReadRepository(
      groups: [_pageGroupRelation()],
      membersByGroup: {
        'group-1': [_pageGroupMember(playerId: 'player-2', name: '친구딜러')],
      },
    );
    final snapshot = PartyReadSnapshot(
      items: [
        _activeRaid(
          groupId: 'group-1',
          memberPlayerIds: {'player-1', 'player-2'},
        ),
        _activeRaid(
          id: 'solo',
          title: '혼자 진행',
          raidId: 'serca',
          groupId: 'group-1',
          memberPlayerIds: {'player-1'},
        ),
      ],
      isFromCache: false,
    );

    await pumpPage(
      tester,
      activeRaids: Stream.value(snapshot),
      database: database,
      filterStore: store,
      groupReadRepository: groups,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicOpen')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
    );
    await tester.tap(
      find.byKey(const ValueKey('raidStatusFilterMemberChip-player-2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('혼자 진행'), findsNothing);
    expect(
      (await store.load(
        'player-1',
        RaidFilterScreen.activeRaids,
      )).memberPlayerIds,
      {'player-2'},
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage(
      tester,
      activeRaids: Stream.value(snapshot),
      database: database,
      filterStore: store,
      groupReadRepository: groups,
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(find.text('레이드 필터: 그룹 공개 · 친구딜러'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('혼자 진행'), findsNothing);
  });

  testWidgets('초기화는 필터를 전체 보기로 되돌리고 저장한다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftRaidStatusFilterStore(database);
    await pumpPage(
      tester,
      database: database,
      filterStore: store,
      activeRaids: Stream.value(
        PartyReadSnapshot(
          items: [
            _activeRaid(),
            _activeRaid(
              id: 'group-raid',
              title: '그룹 세르카',
              raidId: 'serca',
              groupId: 'group-1',
              visibility: 'group',
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterPublicOpen')));
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('raidStatusFilterReset')));
    await tester.pumpAndSettle();
    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.text('그룹 세르카'), findsOneWidget);
    expect(find.text('레이드 필터: 모든 레이드'), findsOneWidget);
    expect(
      (await store.load(
        'player-1',
        RaidFilterScreen.activeRaids,
      )).isUnrestricted,
      isTrue,
    );
  });

  testWidgets('상단 드래그 영역으로 필터 창을 닫는다', (tester) async {
    await pumpPage(
      tester,
      raidCatalogRepository: _FilterCatalogRepository(),
      activeRaids: Stream.value(
        PartyReadSnapshot(items: [_activeRaid()], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raidStatusFilterBar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('raidStatusFilterCount')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('raidStatusFilterSheetDragHandle')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('raidStatusFilterCount')), findsNothing);
  });
}

ActiveRaidSummary _activeRaid({
  String id = 'recruitment-1',
  String title = '4막 노말 모집',
  String raidId = 'act4',
  String difficultyId = 'normal',
  DateTime? raidStartAt,
  bool continueTogether = false,
  String currentCycleStatus = 'active',
  String visibility = 'public',
  String? groupId,
  Set<String> memberPlayerIds = const {},
}) => ActiveRaidSummary(
  id: id,
  title: title,
  leaderPlayerId: 'player-1',
  leaderCharacterName: '이슈아이',
  leaderClassName: '기상술사',
  raidStartAt: raidStartAt,
  metadata: RecruitmentMetadata(
    catalogVersion: '2026-08-01',
    raidId: raidId,
    difficultyId: difficultyId,
    raidName: raidId == 'serca' ? '세르카' : '4막',
    difficultyName: difficultyId == 'hard' ? '하드' : '노말',
    difficultyAlias: difficultyId == 'hard' ? '하드' : '노말',
    gateCount: 2,
    minItemLevel: 1680,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  currentCycleKey: '2026-08-19',
  memberCount: 2,
  maxMemberCount: 8,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
  isOwnedByCurrentPlayer: true,
  continueTogether: continueTogether,
  currentCycleStatus: currentCycleStatus,
  visibility: visibility,
  groupId: groupId,
  memberPlayerIds: memberPlayerIds,
);

PublicRecruitmentSummary _publicSummary() => PublicRecruitmentSummary(
  id: 'recruitment-1',
  title: '4막 노말 모집',
  leaderUserId: 'player-1',
  metadata: const RecruitmentMetadata(
    catalogVersion: '2026-08-01',
    raidId: 'act4',
    difficultyId: 'normal',
    raidName: '4막',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 2,
    minItemLevel: 1680,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  memberCount: 2,
  maxMemberCount: 8,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
);

PartyApplicationSummary _application({
  required String characterId,
  required String characterName,
  required RecruitmentApplicationStatus status,
  String? resolutionReason,
}) => PartyApplicationSummary(
  recruitmentId: 'recruitment-1',
  applicantPlayerId: 'player-1',
  cycleKey: '2026-08-19',
  characterId: characterId,
  characterName: characterName,
  className: '바드',
  requestedRole: PartyRole.support,
  status: status,
  revision: 1,
  resolutionReason: resolutionReason,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 21),
);

class _FilterCatalogRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: const [
      RaidDefinition(
        raidId: 'act4',
        officialName: '4막',
        displayName: '4막',
        aliases: [],
        partySize: 8,
        partyCount: 2,
        requiredSupportCount: 2,
        maxDealerCountPerClass: 2,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'normal',
            name: '노말',
            displayAlias: '노말',
            displayOrder: 1,
            minItemLevel: 1680,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1700,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
      RaidDefinition(
        raidId: 'serca',
        officialName: '세르카',
        displayName: '세르카',
        aliases: [],
        partySize: 4,
        partyCount: 1,
        requiredSupportCount: 1,
        maxDealerCountPerClass: 1,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1730,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
    ],
  );
}

GroupRelation _pageGroupRelation() => GroupRelation(
  groupId: 'group-1',
  playerId: 'player-1',
  relation: GroupRelationKind.member,
  groupNameSnapshot: '테스트그룹',
  displayCharacterNameSnapshot: '내캐릭',
  sourceRevision: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

GroupMember _pageGroupMember({
  required String playerId,
  required String name,
}) => GroupMember(
  groupId: 'group-1',
  playerId: playerId,
  role: GroupMemberRole.member,
  joinedAt: DateTime.utc(2026, 8, 1),
  joinSequence: 1,
  joinedBy: GroupJoinedBy.created,
  displayCharacterIdSnapshot: 'char-$playerId',
  displayCharacterNameSnapshot: name,
  revision: 1,
);

PartyMemberDisplay _pageMemberDisplay({
  required String playerId,
  required String characterId,
}) => PartyMemberDisplay(
  playerId: playerId,
  characterName: characterId,
  className: '블레이드',
  role: PartyRole.dealer,
  partyIndex: 0,
  characterId: characterId,
);

GroupRequestCharacter _pageSearchChar({
  required String playerId,
  required String id,
  required String name,
}) => GroupRequestCharacter(
  characterId: id,
  ownerPlayerId: playerId,
  characterName: name,
  serverName: '루페온',
  characterClassName: '블레이드',
);

class _PageGroupReadRepository extends Fake implements GroupReadRepository {
  _PageGroupReadRepository({
    required this.groups,
    required this.membersByGroup,
  });

  final List<GroupRelation> groups;
  final Map<String, List<GroupMember>> membersByGroup;

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) =>
      Stream.value(GroupReadSnapshot(items: groups, isFromCache: false));

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async =>
      membersByGroup[groupId] ?? const [];
}

class _PageActivity implements ActivityCharactersRepository {
  _PageActivity(this.idsByPlayer);

  final Map<String, Set<String>> idsByPlayer;

  @override
  Future<ActivityCharacters> load({required String playerId}) async =>
      ActivityCharacters(
        playerId: playerId,
        characterIds: idsByPlayer[playerId] ?? const {},
      );

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    throw UnimplementedError();
  }
}

class _PageSearch extends Fake implements GroupCharacterSearchRepository {
  _PageSearch(this.charactersByPlayer);

  final Map<String, List<GroupRequestCharacter>> charactersByPlayer;

  @override
  Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(
    String ownerPlayerId, {
    int limit = groupCharacterSearchPageSize,
  }) async => charactersByPlayer[ownerPlayerId] ?? const [];
}
