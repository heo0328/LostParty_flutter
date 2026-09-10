import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/data/repositories/drift_raid_status_filter_store.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_filter_screen.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_list_sort_selection.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_status_filter_selection.dart';
import 'package:lost_party/features/raid_status/domain/entities/remaining_slots_filter_selection.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/public_recruitment_list_view_model.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  late StreamController<PublicRecruitmentPage> firstPage;
  late Completer<PublicRecruitmentPage>? nextPageCompleter;
  var nextPageCalls = 0;

  setUp(() {
    firstPage = StreamController<PublicRecruitmentPage>.broadcast();
    nextPageCompleter = null;
    nextPageCalls = 0;
  });

  tearDown(() async {
    await firstPage.close();
  });

  PublicRecruitmentListViewModel createViewModel() {
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
      loadNextPage:
          ({
            required String cycleKey,
            required String currentPlayerId,
            required PublicRecruitmentPageCursor cursor,
            int limit = publicRecruitmentPageSize,
          }) async {
            nextPageCalls += 1;
            final completer = nextPageCompleter;
            if (completer != null) {
              return completer.future;
            }
            return PublicRecruitmentPage(
              items: [_summary('next-$nextPageCalls')],
              nextCursor: const FakePublicRecruitmentPageCursor('next'),
              hasMore: false,
              isFromCache: false,
            );
          },
    );
    return PublicRecruitmentListViewModel(
      repository: repository,
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      pageSize: 2,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('첫 snapshot 전에는 loading을 유지한다', () {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    expect(viewModel.state.isLoading, isTrue);
    expect(viewModel.state.isEmpty, isFalse);
  });

  test('목록 시작 시 기존 그룹 listing 보완을 한 번 호출한다', () async {
    var calls = 0;
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
    );
    final viewModel = PublicRecruitmentListViewModel(
      repository: repository,
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      backfillOwnGroupListings: () async {
        calls += 1;
      },
    )..start();
    addTearDown(viewModel.dispose);
    await settle();
    expect(calls, 1);
  });

  test('첫 snapshot이 비어 있으면 빈 목록이다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      const PublicRecruitmentPage(
        items: [],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isEmpty, isTrue);
  });

  test('캐시 snapshot은 목록과 오프라인 여부를 함께 전달한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a')],
        hasMore: false,
        isFromCache: true,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a']);
    expect(viewModel.state.isFromCache, isTrue);
  });

  test('성공 데이터 없이 발생한 오류는 전체 실패로 구분한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.addError(
      const PartyReadException(PartyReadFailureType.permissionDenied),
    );
    await settle();

    expect(viewModel.state.failure, PartyReadFailureType.permissionDenied);
    expect(viewModel.state.items, isEmpty);
  });

  test('기존 목록이 있으면 첫 페이지 후속 오류에도 목록을 유지한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('a'),
        isFromCache: false,
      ),
    );
    await settle();
    firstPage.addError(
      const PartyReadException(PartyReadFailureType.unavailable),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a']);
    expect(viewModel.state.failure, PartyReadFailureType.unavailable);
    expect(viewModel.state.hasFailureWithItems, isTrue);
  });

  test('추가 페이지를 병합하고 진행 중 중복 요청은 무시한다', () async {
    nextPageCompleter = Completer<PublicRecruitmentPage>();
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a'), _summary('b')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('b'),
        isFromCache: false,
      ),
    );
    await settle();

    unawaited(viewModel.loadMore());
    unawaited(viewModel.loadMore());
    await settle();

    expect(nextPageCalls, 1);
    expect(viewModel.state.isLoadingMore, isTrue);

    nextPageCompleter!.complete(
      PublicRecruitmentPage(
        items: [_summary('c')],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(viewModel.state.hasMore, isFalse);
    expect(viewModel.state.isLoadingMore, isFalse);
  });

  test('추가 조회 실패 시 기존 목록을 유지하고 재시도할 수 있다', () async {
    nextPageCompleter = Completer<PublicRecruitmentPage>();
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('a'),
        isFromCache: false,
      ),
    );
    await settle();

    unawaited(viewModel.loadMore());
    nextPageCompleter!.completeError(
      const PartyReadException(PartyReadFailureType.unavailable),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a']);
    expect(viewModel.state.appendFailure, PartyReadFailureType.unavailable);
    expect(viewModel.state.canLoadMore, isFalse);

    nextPageCompleter = Completer<PublicRecruitmentPage>();
    viewModel.retryAppend();
    await settle();
    expect(viewModel.state.isLoadingMore, isTrue);

    nextPageCompleter!.complete(
      PublicRecruitmentPage(
        items: [_summary('b')],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a', 'b']);
    expect(viewModel.state.appendFailure, isNull);
  });

  test('첫 페이지 ID 집합이 같으면 추가 페이지를 유지하고 내용만 갱신한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('a', title: 'old'),
          _summary('b'),
        ],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('b'),
        isFromCache: false,
      ),
    );
    await settle();
    await viewModel.loadMore();
    await settle();

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('a', title: 'new'),
          _summary('b'),
        ],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('b'),
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['a', 'b', 'next-1']);
    expect(viewModel.state.items.first.title, 'new');
  });

  test('첫 페이지 ID 집합이 바뀌면 추가 페이지와 cursor를 초기화한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a'), _summary('b')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('b'),
        isFromCache: false,
      ),
    );
    await settle();
    await viewModel.loadMore();
    await settle();
    expect(viewModel.state.items.length, 3);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('z'), _summary('a')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('a'),
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['z', 'a']);
    expect(viewModel.state.hasMore, isTrue);
  });

  test('명시적 새로고침은 첫 페이지와 추가 상태를 모두 초기화한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('a')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('a'),
        isFromCache: false,
      ),
    );
    await settle();
    await viewModel.loadMore();
    await settle();

    final refreshFuture = viewModel.refresh();
    await settle();
    expect(viewModel.state.isLoading, isTrue);
    expect(viewModel.state.items, isEmpty);

    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('fresh')],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await refreshFuture;
    await settle();

    expect(viewModel.state.items.map((e) => e.id), ['fresh']);
    expect(viewModel.state.hasMore, isFalse);
  });

  test('필터 후 첫 화면이 비고 다음 페이지가 있으면 자동 보충한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: const [],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('page-0'),
        isFromCache: false,
      ),
    );
    await settle();
    await settle();

    expect(nextPageCalls, 1);
    expect(viewModel.state.items.map((e) => e.id), ['next-1']);
    expect(viewModel.state.isEmpty, isFalse);
  });

  test('자동 보충은 시작당 최대 3페이지에서 멈춘다', () async {
    var remaining = 5;
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
      loadNextPage:
          ({
            required String cycleKey,
            required String currentPlayerId,
            required PublicRecruitmentPageCursor cursor,
            int limit = publicRecruitmentPageSize,
          }) async {
            nextPageCalls += 1;
            remaining -= 1;
            return PublicRecruitmentPage(
              items: const [],
              nextCursor: FakePublicRecruitmentPageCursor(
                'page-$nextPageCalls',
              ),
              hasMore: remaining > 0,
              isFromCache: false,
            );
          },
    );
    final viewModel = PublicRecruitmentListViewModel(
      repository: repository,
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      pageSize: 2,
      emptyAutoFillMaxPages: 3,
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: const [],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('page-0'),
        isFromCache: false,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await settle();
      if (nextPageCalls >= 3 && !viewModel.state.isLoadingMore) break;
    }

    expect(nextPageCalls, 3);
    expect(viewModel.state.items, isEmpty);
    expect(viewModel.state.hasMore, isTrue);
    expect(viewModel.state.isEmpty, isTrue);
  });

  test('공개 조건 필터는 원본을 유지하고 일치 항목만 보여 준다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);
    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('public'),
          _summary('group', groupId: 'group-1'),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.toggleGroup(),
    );
    await settle();

    expect(viewModel.state.originalItems.map((item) => item.id), [
      'public',
      'group',
    ]);
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(viewModel.state.isEmptyFiltered, isFalse);
  });

  test('필터 결과가 비고 다음 페이지가 있으면 자동 보충한다', () async {
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
      loadNextPage:
          ({
            required String cycleKey,
            required String currentPlayerId,
            required PublicRecruitmentPageCursor cursor,
            int limit = publicRecruitmentPageSize,
          }) async {
            nextPageCalls += 1;
            return PublicRecruitmentPage(
              items: [_summary('group-next', groupId: 'group-1')],
              nextCursor: const FakePublicRecruitmentPageCursor('next'),
              hasMore: false,
              isFromCache: false,
            );
          },
    );
    final viewModel = PublicRecruitmentListViewModel(
      repository: repository,
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
    )..start();
    addTearDown(viewModel.dispose);
    firstPage.add(
      PublicRecruitmentPage(
        items: [_summary('public')],
        hasMore: true,
        nextCursor: const FakePublicRecruitmentPageCursor('page-0'),
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.togglePublic(),
    );
    await settle();
    await settle();

    expect(nextPageCalls, 1);
    expect(viewModel.state.items.map((item) => item.id), ['group-next']);
    expect(viewModel.state.originalItems.map((item) => item.id), [
      'public',
      'group-next',
    ]);
  });

  test('화면별 저장은 모집 목록 키만 갱신한다', () async {
    final store = MemoryRaidStatusFilterStore({
      'player-1': RaidStatusFilterSelection.unrestricted.toggleGroup(),
    });
    final viewModel = PublicRecruitmentListViewModel(
      repository: FakePartyReadRepository(publicFirstPage: firstPage.stream),
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      const PublicRecruitmentPage(
        items: [],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();
    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.togglePublic(),
    );
    await settle();

    expect(
      (await store.load('player-1', RaidFilterScreen.activeRaids)).includeGroup,
      isFalse,
    );
    expect(
      (await store.load(
        'player-1',
        RaidFilterScreen.recruitmentList,
      )).includePublic,
      isFalse,
    );
  });

  test('미확인 참가 Character는 일치 결과에 섞지 않는다', () async {
    final members = Completer<PartyReadSnapshot<PartyMemberDisplay>>();
    final repository = FakePartyReadRepository(
      publicFirstPage: firstPage.stream,
      membersForId: (_) => Stream.fromFuture(members.future),
    );
    final viewModel = PublicRecruitmentListViewModel(
      repository: repository,
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('group', groupId: 'group-1', memberPlayerIds: {'player-2'}),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();
    await viewModel.setSelection(
      const RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        memberPlayerIds: {'player-2'},
        characterIdsByPlayer: {
          'player-2': {'char-21'},
        },
      ),
    );
    await settle();

    expect(viewModel.state.items, isEmpty);
    expect(viewModel.state.pendingCharacterCheckCount, 1);

    members.complete(
      const PartyReadSnapshot(
        items: [
          PartyMemberDisplay(
            playerId: 'player-2',
            characterId: 'char-21',
            characterName: '멤버',
            className: '바드',
            role: PartyRole.support,
            partyIndex: 0,
          ),
        ],
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((item) => item.id), ['group']);
    expect(viewModel.state.pendingCharacterCheckCount, 0);
  });

  test('기본 정렬은 참가 인원 많은 순이다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('few', memberCount: 2, maxMemberCount: 8),
          _summary('many', memberCount: 7, maxMemberCount: 8),
          _summary('mid', memberCount: 4, maxMemberCount: 8),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    expect(viewModel.state.items.map((item) => item.id), [
      'many',
      'mid',
      'few',
    ]);
    expect(viewModel.state.sortSelection.isDefault, isTrue);
    expect(viewModel.showOwnCharacterFilters, isFalse);
  });

  test('toggleMemberCountSort는 방향을 뒤집는다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = PublicRecruitmentListViewModel(
      repository: FakePartyReadRepository(publicFirstPage: firstPage.stream),
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('few', memberCount: 2, maxMemberCount: 8),
          _summary('many', memberCount: 7, maxMemberCount: 8),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.toggleMemberCountSort();
    expect(viewModel.state.items.map((item) => item.id), ['few', 'many']);
    expect(
      await store.loadSort('player-1', RaidFilterScreen.recruitmentList),
      const RaidListSortSelection(
        direction: RaidListSortDirection.ascending,
      ),
    );
  });

  test('남은 자리 2+3 필터는 OR 일치만 보여 준다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('two', memberCount: 6, maxMemberCount: 8),
          _summary('three', memberCount: 5, maxMemberCount: 8),
          _summary('one', memberCount: 7, maxMemberCount: 8),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.setRemainingSlotsSelection(
      const RemainingSlotsFilterSelection(slotCounts: {2, 3}),
    );
    expect(viewModel.state.items.map((item) => item.id), ['two', 'three']);
    expect(viewModel.state.originalItems, hasLength(3));
  });

  test('남은 자리 선택이 비면 전체를 보여 준다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('two', memberCount: 6, maxMemberCount: 8),
          _summary('one', memberCount: 7, maxMemberCount: 8),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.setRemainingSlotsSelection(
      const RemainingSlotsFilterSelection(slotCounts: {2}),
    );
    expect(viewModel.state.items.map((item) => item.id), ['two']);

    await viewModel.setRemainingSlotsSelection(
      RemainingSlotsFilterSelection.unrestricted,
    );
    expect(viewModel.state.items.map((item) => item.id), ['one', 'two']);
  });

  test('남은 자리 초기화는 메인 필터와 독립이다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = PublicRecruitmentListViewModel(
      repository: FakePartyReadRepository(publicFirstPage: firstPage.stream),
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('public'),
          _summary('group', groupId: 'group-1'),
          _summary('open', memberCount: 2, maxMemberCount: 8),
        ],
        hasMore: false,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.toggleGroup(),
    );
    await viewModel.setRemainingSlotsSelection(
      const RemainingSlotsFilterSelection(slotCounts: {6}),
    );
    expect(viewModel.state.items.map((item) => item.id), ['open']);
    expect(viewModel.state.selection.includeGroup, isFalse);

    await viewModel.setRemainingSlotsSelection(
      RemainingSlotsFilterSelection.unrestricted,
    );
    expect(viewModel.state.items.map((item) => item.id), ['open', 'public']);
    expect(viewModel.state.selection.includeGroup, isFalse);
    expect(
      await store.load('player-1', RaidFilterScreen.recruitmentList),
      isNot(RaidStatusFilterSelection.unrestricted),
    );
    expect(
      await store.loadRemainingSlotsFilter(
        'player-1',
        RaidFilterScreen.recruitmentList,
      ),
      RemainingSlotsFilterSelection.unrestricted,
    );
  });

  test('정렬을 적용·저장하고 추가 페이지 뒤에도 다시 정렬한다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = PublicRecruitmentListViewModel(
      repository: FakePartyReadRepository(
        publicFirstPage: firstPage.stream,
        loadNextPage:
            ({
              required String cycleKey,
              required String currentPlayerId,
              required PublicRecruitmentPageCursor cursor,
              int limit = publicRecruitmentPageSize,
            }) async {
              nextPageCalls += 1;
              return PublicRecruitmentPage(
                items: [_summary('next', memberCount: 1, maxMemberCount: 8)],
                nextCursor: null,
                hasMore: false,
                isFromCache: false,
              );
            },
      ),
      cycleKey: '2026-08-19',
      currentPlayerId: 'player-1',
      pageSize: 2,
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);

    firstPage.add(
      PublicRecruitmentPage(
        items: [
          _summary('full', memberCount: 8, maxMemberCount: 8),
          _summary('open', memberCount: 2, maxMemberCount: 8),
        ],
        nextCursor: const FakePublicRecruitmentPageCursor('c1'),
        hasMore: true,
        isFromCache: false,
      ),
    );
    await settle();

    await viewModel.toggleMemberCountSort();
    expect(viewModel.state.items.map((item) => item.id), ['open', 'full']);
    expect(
      await store.loadSort('player-1', RaidFilterScreen.recruitmentList),
      const RaidListSortSelection(
        direction: RaidListSortDirection.ascending,
      ),
    );

    await viewModel.loadMore();
    await settle();
    expect(viewModel.state.items.map((item) => item.id), [
      'next',
      'open',
      'full',
    ]);

    await viewModel.resetSelection();
    expect(viewModel.state.sortSelection.isDefault, isTrue);
    expect(
      await store.loadSort('player-1', RaidFilterScreen.recruitmentList),
      RaidListSortSelection.defaults,
    );
    expect(
      await store.loadRemainingSlotsFilter(
        'player-1',
        RaidFilterScreen.recruitmentList,
      ),
      RemainingSlotsFilterSelection.unrestricted,
    );
  });
}

PublicRecruitmentSummary _summary(
  String id, {
  String title = 'title',
  String raidId = 'raid',
  String difficultyId = 'normal',
  String? groupId,
  Set<String>? memberPlayerIds,
  int memberCount = 1,
  int maxMemberCount = 8,
}) {
  return PublicRecruitmentSummary(
    id: id,
    title: title,
    leaderUserId: 'leader',
    metadata: RecruitmentMetadata(
      catalogVersion: 'v1',
      raidId: raidId,
      difficultyId: difficultyId,
      raidName: '레이드',
      difficultyName: '노말',
      difficultyAlias: '노말',
      gateCount: 2,
      minItemLevel: 1600,
      minCombatPower: null,
      experienceLevel: null,
      maxPlayHours: null,
    ),
    memberCount: memberCount,
    maxMemberCount: maxMemberCount,
    isRecruiting: true,
    revision: 1,
    updatedAt: DateTime.utc(2026, 8, 20),
    groupId: groupId,
    memberPlayerIds: memberPlayerIds,
  );
}
