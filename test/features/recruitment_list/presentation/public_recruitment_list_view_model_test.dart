import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
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
      loadNextPage: ({
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
        items: [_summary('a', title: 'old'), _summary('b')],
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
        items: [_summary('a', title: 'new'), _summary('b')],
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
      loadNextPage: ({
        required String cycleKey,
        required String currentPlayerId,
        required PublicRecruitmentPageCursor cursor,
        int limit = publicRecruitmentPageSize,
      }) async {
        nextPageCalls += 1;
        remaining -= 1;
        return PublicRecruitmentPage(
          items: const [],
          nextCursor: FakePublicRecruitmentPageCursor('page-$nextPageCalls'),
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
}

PublicRecruitmentSummary _summary(String id, {String title = 'title'}) {
  return PublicRecruitmentSummary(
    id: id,
    title: title,
    leaderUserId: 'leader',
    metadata: const RecruitmentMetadata(
      catalogVersion: 'v1',
      raidId: 'raid',
      difficultyId: 'normal',
      raidName: '레이드',
      difficultyName: '노말',
      difficultyAlias: '노말',
      gateCount: 2,
      minItemLevel: 1600,
      minCombatPower: null,
      experienceLevel: null,
      maxPlayHours: null,
    ),
    memberCount: 1,
    maxMemberCount: 8,
    isRecruiting: true,
    revision: 1,
    updatedAt: DateTime.utc(2026, 8, 20),
  );
}
