import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/party_read_models.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/repositories/party_read_repository.dart';

class PublicRecruitmentListState {
  const PublicRecruitmentListState({
    this.items = const [],
    this.isLoading = true,
    this.isFromCache = false,
    this.failure,
    this.isLoadingMore = false,
    this.appendFailure,
    this.hasMore = false,
  });

  final List<PublicRecruitmentSummary> items;
  final bool isLoading;
  final bool isFromCache;
  final PartyReadFailureType? failure;
  final bool isLoadingMore;
  final PartyReadFailureType? appendFailure;
  final bool hasMore;

  bool get isEmpty =>
      !isLoading &&
      !isLoadingMore &&
      failure == null &&
      appendFailure == null &&
      items.isEmpty;

  bool get hasFailureWithItems => failure != null && items.isNotEmpty;

  bool get canLoadMore =>
      hasMore && !isLoading && !isLoadingMore && appendFailure == null;
}

/// 공개 모집 첫 페이지 실시간 구독과 cursor 기반 추가 페이지를 병합한다.
class PublicRecruitmentListViewModel extends ChangeNotifier {
  PublicRecruitmentListViewModel({
    required PartyReadRepository repository,
    required String cycleKey,
    required String currentPlayerId,
    this.pageSize = publicRecruitmentPageSize,
    this.emptyAutoFillMaxPages = publicRecruitmentEmptyAutoFillMaxPages,
  }) : _repository = repository,
       _cycleKey = cycleKey,
       _currentPlayerId = currentPlayerId;

  final PartyReadRepository _repository;
  final String _cycleKey;
  final String _currentPlayerId;
  final int pageSize;
  final int emptyAutoFillMaxPages;

  StreamSubscription<PublicRecruitmentPage>? _subscription;
  PublicRecruitmentListState _state = const PublicRecruitmentListState();
  List<PublicRecruitmentSummary> _firstPageItems = const [];
  List<PublicRecruitmentSummary> _appendedItems = const [];
  Set<String>? _firstPageIds;
  PublicRecruitmentPageCursor? _nextCursor;
  var _generation = 0;
  var _autoFillCount = 0;

  PublicRecruitmentListState get state => _state;

  void start() {
    if (_subscription != null) return;
    _autoFillCount = 0;
    _subscription = _repository
        .watchPublicRecruitmentFirstPage(
          cycleKey: _cycleKey,
          currentPlayerId: _currentPlayerId,
          limit: pageSize,
        )
        .listen(_onFirstPage, onError: _onFirstPageError);
  }

  Future<void> refresh() async {
    _generation += 1;
    await _subscription?.cancel();
    _subscription = null;
    _firstPageItems = const [];
    _appendedItems = const [];
    _firstPageIds = null;
    _nextCursor = null;
    _state = const PublicRecruitmentListState();
    notifyListeners();
    start();
  }

  Future<void> loadMore({bool isRetry = false}) async {
    if (_state.isLoading || _state.isLoadingMore || !_state.hasMore) return;
    if (!isRetry && _state.appendFailure != null) return;
    final cursor = _nextCursor;
    if (cursor == null) return;

    final generation = _generation;
    _state = PublicRecruitmentListState(
      items: _state.items,
      isLoading: false,
      isFromCache: _state.isFromCache,
      failure: _state.failure,
      isLoadingMore: true,
      hasMore: _state.hasMore,
    );
    notifyListeners();

    try {
      final page = await _repository.loadPublicRecruitmentNextPage(
        cycleKey: _cycleKey,
        currentPlayerId: _currentPlayerId,
        cursor: cursor,
        limit: pageSize,
      );
      if (generation != _generation) return;
      _appendedItems = [..._appendedItems, ...page.items];
      _nextCursor = page.nextCursor;
      _state = PublicRecruitmentListState(
        items: _merge(_firstPageItems, _appendedItems),
        isLoading: false,
        isFromCache: _state.isFromCache,
        failure: _state.failure,
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
      notifyListeners();
      await _maybeAutoFill();
    } catch (error) {
      if (generation != _generation) return;
      _state = PublicRecruitmentListState(
        items: _state.items,
        isLoading: false,
        isFromCache: _state.isFromCache,
        failure: _state.failure,
        isLoadingMore: false,
        appendFailure: error is PartyReadException
            ? error.type
            : PartyReadFailureType.unknown,
        hasMore: _state.hasMore,
      );
      notifyListeners();
    }
  }

  void retryAppend() {
    unawaited(loadMore(isRetry: true));
  }

  void _onFirstPage(PublicRecruitmentPage page) {
    final newIds = page.items.map((item) => item.id).toSet();
    final previousIds = _firstPageIds;
    final idSetChanged =
        previousIds != null && !_sameIdSet(previousIds, newIds);

    if (idSetChanged) {
      _generation += 1;
      _appendedItems = const [];
      _nextCursor = page.nextCursor;
      _state = PublicRecruitmentListState(
        items: page.items,
        isLoading: false,
        isFromCache: page.isFromCache,
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } else {
      final keepAppend = previousIds != null && _appendedItems.isNotEmpty;
      if (!keepAppend) {
        _nextCursor = page.nextCursor;
      }
      _state = PublicRecruitmentListState(
        items: _merge(page.items, keepAppend ? _appendedItems : const []),
        isLoading: false,
        isFromCache: page.isFromCache,
        isLoadingMore: _state.isLoadingMore,
        appendFailure: keepAppend ? _state.appendFailure : null,
        hasMore: keepAppend ? _state.hasMore : page.hasMore,
      );
      if (!keepAppend) {
        _appendedItems = const [];
      }
    }

    _firstPageItems = page.items;
    _firstPageIds = newIds;
    notifyListeners();
    unawaited(_maybeAutoFill());
  }

  Future<void> _maybeAutoFill() async {
    if (_autoFillCount >= emptyAutoFillMaxPages) return;
    if (_state.items.isNotEmpty) return;
    if (_state.isLoading || _state.isLoadingMore) return;
    if (_state.failure != null || _state.appendFailure != null) return;
    if (!_state.hasMore || _nextCursor == null) return;
    _autoFillCount += 1;
    await loadMore();
  }

  void _onFirstPageError(Object error) {
    _state = PublicRecruitmentListState(
      items: _state.items,
      isLoading: false,
      isFromCache: _state.isFromCache,
      failure: error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown,
      isLoadingMore: _state.isLoadingMore,
      appendFailure: _state.appendFailure,
      hasMore: _state.hasMore,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  static List<PublicRecruitmentSummary> _merge(
    List<PublicRecruitmentSummary> firstPage,
    List<PublicRecruitmentSummary> appended,
  ) {
    final firstIds = firstPage.map((item) => item.id).toSet();
    return [
      ...firstPage,
      ...appended.where((item) => !firstIds.contains(item.id)),
    ];
  }

  static bool _sameIdSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    return left.containsAll(right);
  }
}
