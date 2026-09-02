import '../../domain/entities/raid_status_filter_selection.dart';
import 'raid_status_filter.dart';

/// 서버 원본 페이지와 로컬 필터 결과를 따로 두고 §8 페이징 안전을 지킨다.
///
/// 진행 중 목록은 membership 스트림을 원본 한 페이지(hasMore=false)로 넣는다.
/// 20개 cursor 페이지는 같은 세션에 추가 페이지로 넣을 수 있다.
class FilteredPageSession<T> {
  FilteredPageSession({
    required String Function(T item) idOf,
    required bool Function(T item) matches,
    this.emptyAutoFillMaxPages = 3,
  }) : _idOf = idOf,
       _matches = matches;

  final String Function(T item) _idOf;
  bool Function(T item) _matches;
  final int emptyAutoFillMaxPages;

  var _generation = 0;
  var _original = <T>[];
  var _filtered = <T>[];
  var _originalIds = <String>{};
  Object? _nextCursor;
  var _hasMore = false;
  var _isAppending = false;
  Object? _appendFailure;
  var _autoFillCount = 0;

  int get generation => _generation;
  List<T> get originalItems => List.unmodifiable(_original);
  List<T> get filteredItems => List.unmodifiable(_filtered);
  bool get hasMore => _hasMore;
  Object? get nextCursor => _nextCursor;
  bool get isAppending => _isAppending;
  Object? get appendFailure => _appendFailure;
  int get autoFillCount => _autoFillCount;

  String get countLabel =>
      raidStatusFilterCountLabel(count: _filtered.length, hasMore: _hasMore);

  bool get canAppend =>
      _hasMore &&
      !_isAppending &&
      _nextCursor != null &&
      _appendFailure == null;

  bool get shouldAutoFill =>
      _filtered.isEmpty &&
      _hasMore &&
      _nextCursor != null &&
      !_isAppending &&
      _appendFailure == null &&
      _autoFillCount < emptyAutoFillMaxPages;

  /// 새로고침은 원본·cursor·append 오류·요청 상태를 지우고 필터 선택은 유지한다.
  int beginRefresh() {
    _generation += 1;
    _original = [];
    _filtered = [];
    _originalIds = {};
    _nextCursor = null;
    _hasMore = false;
    _isAppending = false;
    _appendFailure = null;
    _autoFillCount = 0;
    return _generation;
  }

  /// 서버가 알려 준 hasMore/cursor를 그대로 반영한다. 필터 0건이어도 종료로 보지 않는다.
  void replaceOriginal(
    List<T> items, {
    required bool hasMore,
    Object? nextCursor,
    int? generation,
  }) {
    if (generation != null && generation != _generation) return;
    _original = _uniqueById(items);
    _originalIds = {for (final item in _original) _idOf(item)};
    _hasMore = hasMore;
    _nextCursor = nextCursor;
    _isAppending = false;
    _appendFailure = null;
    _recompute();
  }

  /// 같은 cursor 중복 요청과 동시 추가는 무시한다. 통신 실패 재시도는 [isRetry].
  Object? tryBeginAppend({bool isRetry = false}) {
    if (_isAppending) return null;
    if (!_hasMore) return null;
    final cursor = _nextCursor;
    if (cursor == null) return null;
    if (!isRetry && _appendFailure != null) return null;
    _isAppending = true;
    _appendFailure = null;
    return cursor;
  }

  void completeAppend({
    required int generation,
    required List<T> items,
    required bool hasMore,
    Object? nextCursor,
  }) {
    if (generation != _generation) return;
    for (final item in items) {
      final id = _idOf(item);
      if (_originalIds.contains(id)) continue;
      _originalIds.add(id);
      _original.add(item);
    }
    _hasMore = hasMore;
    _nextCursor = nextCursor;
    _isAppending = false;
    _appendFailure = null;
    _recompute();
  }

  /// 실패 시 cursor를 전진시키지 않아 같은 페이지를 재시도할 수 있다.
  void failAppend({required int generation, required Object failure}) {
    if (generation != _generation) return;
    _isAppending = false;
    _appendFailure = failure;
  }

  /// 필터 변경은 원본을 유지하고 최신 선택으로 결과를 다시 계산한다.
  void updateMatcher(bool Function(T item) matches) {
    _matches = matches;
    _recompute();
  }

  bool markAutoFillStarted() {
    if (!shouldAutoFill) return false;
    _autoFillCount += 1;
    return true;
  }

  void _recompute() {
    _filtered = [
      for (final item in _original)
        if (_matches(item)) item,
    ];
  }

  List<T> _uniqueById(List<T> items) {
    final seen = <String>{};
    final unique = <T>[];
    for (final item in items) {
      if (seen.add(_idOf(item))) unique.add(item);
    }
    return unique;
  }
}

bool Function(T item) raidStatusFilterMatcher<T>({
  required RaidStatusFilterSelection selection,
  required String? Function(T item) groupIdOf,
  required String Function(T item) raidIdOf,
  required String Function(T item) difficultyIdOf,
}) {
  return (item) => matchesRaidStatusFilter(
    selection: selection,
    groupId: groupIdOf(item),
    raidId: raidIdOf(item),
    difficultyId: difficultyIdOf(item),
  );
}
