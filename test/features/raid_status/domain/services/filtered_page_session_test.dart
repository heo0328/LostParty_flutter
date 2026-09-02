import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/services/filtered_page_session.dart';

void main() {
  FilteredPageSession<_Item> session({
    bool Function(_Item item)? matches,
    int emptyAutoFillMaxPages = 3,
  }) => FilteredPageSession<_Item>(
    idOf: (item) => item.id,
    matches: matches ?? ((item) => true),
    emptyAutoFillMaxPages: emptyAutoFillMaxPages,
  );

  test('서버 원본과 필터 결과를 별도로 유지한다', () {
    final paging = session(matches: (item) => item.id.startsWith('keep'));
    paging.replaceOriginal(
      [const _Item('keep-1'), const _Item('skip-1')],
      hasMore: true,
      nextCursor: 'c1',
    );

    expect(paging.originalItems.map((item) => item.id), ['keep-1', 'skip-1']);
    expect(paging.filteredItems.map((item) => item.id), ['keep-1']);
    expect(paging.hasMore, isTrue);
    expect(paging.countLabel, '현재 1개');
  });

  test('필터 일치가 0개여도 서버 hasMore와 cursor를 유지한다', () {
    final paging = session(matches: (_) => false);
    paging.replaceOriginal(
      [const _Item('a'), const _Item('b')],
      hasMore: true,
      nextCursor: 'c1',
    );

    expect(paging.filteredItems, isEmpty);
    expect(paging.hasMore, isTrue);
    expect(paging.nextCursor, 'c1');
    expect(paging.shouldAutoFill, isTrue);
    expect(paging.countLabel, '현재 0개');
  });

  test('한 페이지 요청 중에는 같은 cursor 추가 요청을 무시한다', () {
    final paging = session();
    paging.replaceOriginal([const _Item('a')], hasMore: true, nextCursor: 'c1');

    expect(paging.tryBeginAppend(), 'c1');
    expect(paging.isAppending, isTrue);
    expect(paging.tryBeginAppend(), isNull);
    expect(paging.tryBeginAppend(isRetry: true), isNull);
  });

  test('같은 recruitment ID는 원본에 다시 넣지 않는다', () {
    final paging = session();
    paging.replaceOriginal([const _Item('a')], hasMore: true, nextCursor: 'c1');
    final generation = paging.generation;
    paging.tryBeginAppend();
    paging.completeAppend(
      generation: generation,
      items: const [_Item('a'), _Item('b')],
      hasMore: false,
      nextCursor: null,
    );

    expect(paging.originalItems.map((item) => item.id), ['a', 'b']);
    expect(paging.hasMore, isFalse);
    expect(paging.countLabel, '2개');
  });

  test('통신 실패 시 cursor를 전진시키지 않고 재시도할 수 있다', () {
    final paging = session();
    paging.replaceOriginal([const _Item('a')], hasMore: true, nextCursor: 'c1');
    final generation = paging.generation;
    paging.tryBeginAppend();
    paging.failAppend(generation: generation, failure: 'unavailable');

    expect(paging.nextCursor, 'c1');
    expect(paging.hasMore, isTrue);
    expect(paging.appendFailure, 'unavailable');
    expect(paging.tryBeginAppend(), isNull);
    expect(paging.tryBeginAppend(isRetry: true), 'c1');
  });

  test('필터 변경과 늦은 페이지는 원본에 병합하고 최신 필터로 다시 계산한다', () {
    final paging = session(matches: (item) => item.id != 'skip');
    paging.replaceOriginal(
      [const _Item('keep'), const _Item('skip')],
      hasMore: true,
      nextCursor: 'c1',
    );
    final generation = paging.generation;
    paging.tryBeginAppend();
    paging.updateMatcher((item) => item.id == 'late');
    paging.completeAppend(
      generation: generation,
      items: const [_Item('late')],
      hasMore: false,
    );

    expect(paging.originalItems.map((item) => item.id), [
      'keep',
      'skip',
      'late',
    ]);
    expect(paging.filteredItems.map((item) => item.id), ['late']);
    expect(paging.hasMore, isFalse);
  });

  test('새로고침 이전 generation의 늦은 응답은 새 목록에 섞이지 않는다', () {
    final paging = session();
    paging.replaceOriginal(
      [const _Item('old')],
      hasMore: true,
      nextCursor: 'c1',
    );
    final stale = paging.generation;
    paging.tryBeginAppend();
    final fresh = paging.beginRefresh();
    paging.replaceOriginal(
      [const _Item('new')],
      hasMore: false,
      generation: fresh,
    );
    paging.completeAppend(
      generation: stale,
      items: const [_Item('stale')],
      hasMore: true,
      nextCursor: 'c2',
    );

    expect(paging.originalItems.map((item) => item.id), ['new']);
    expect(paging.hasMore, isFalse);
    expect(paging.nextCursor, isNull);
  });

  test('연속 빈 필터 페이지의 자동 보충은 스크롤당 한도를 넘지 않는다', () {
    final paging = session(matches: (_) => false, emptyAutoFillMaxPages: 3);
    paging.replaceOriginal(const [_Item('a')], hasMore: true, nextCursor: 'c1');

    var fills = 0;
    while (paging.shouldAutoFill && paging.markAutoFillStarted()) {
      fills += 1;
      final generation = paging.generation;
      paging.tryBeginAppend();
      paging.completeAppend(
        generation: generation,
        items: [_Item('empty-$fills')],
        hasMore: fills < 5,
        nextCursor: fills < 5 ? 'c${fills + 1}' : null,
      );
    }

    expect(fills, 3);
    expect(paging.autoFillCount, 3);
    expect(paging.hasMore, isTrue);
    expect(paging.shouldAutoFill, isFalse);
  });

  test('서버가 마지막 페이지임을 알려줄 때만 페이징을 종료한다', () {
    final paging = session(matches: (_) => false);
    paging.replaceOriginal(const [_Item('a')], hasMore: true, nextCursor: 'c1');
    expect(paging.hasMore, isTrue);
    final generation = paging.generation;
    paging.tryBeginAppend();
    paging.completeAppend(
      generation: generation,
      items: const [_Item('b')],
      hasMore: false,
    );
    expect(paging.hasMore, isFalse);
    expect(paging.tryBeginAppend(), isNull);
    expect(paging.countLabel, '0개');
  });

  test('새로고침은 필터 매처를 유지한다', () {
    final paging = session(matches: (item) => item.id == 'keep');
    paging.replaceOriginal([
      const _Item('keep'),
      const _Item('skip'),
    ], hasMore: false);
    paging.beginRefresh();
    paging.replaceOriginal([
      const _Item('keep'),
      const _Item('other'),
    ], hasMore: false);
    expect(paging.filteredItems.map((item) => item.id), ['keep']);
  });
}

class _Item {
  const _Item(this.id);

  final String id;
}
