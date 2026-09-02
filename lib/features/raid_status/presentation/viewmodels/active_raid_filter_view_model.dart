import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/repositories/raid_status_filter_store.dart';
import '../../domain/services/filtered_page_session.dart';
import '../../domain/services/raid_status_filter.dart';

class ActiveRaidFilterViewState {
  const ActiveRaidFilterViewState({
    this.originalItems = const [],
    this.items = const [],
    this.selection = RaidStatusFilterSelection.unrestricted,
    this.catalog = const RaidStatusFilterCatalogOptions(),
    this.isLoading = true,
    this.isFromCache = false,
    this.hasMore = false,
    this.failure,
  });

  final List<ActiveRaidSummary> originalItems;
  final List<ActiveRaidSummary> items;
  final RaidStatusFilterSelection selection;
  final RaidStatusFilterCatalogOptions catalog;
  final bool isLoading;
  final bool isFromCache;
  final bool hasMore;
  final PartyReadFailureType? failure;

  bool get isEmptyOriginal =>
      !isLoading && failure == null && originalItems.isEmpty;

  bool get isEmptyFiltered =>
      !isLoading &&
      failure == null &&
      originalItems.isNotEmpty &&
      items.isEmpty;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;

  bool get hasFailureWithItems => failure != null && originalItems.isNotEmpty;

  String get barLabel => raidStatusFilterBarLabel(
    selection,
    raidNames: catalog.raidNames,
    difficultyNames: catalog.difficultyNames,
  );

  String get countLabel =>
      raidStatusFilterCountLabel(count: items.length, hasMore: hasMore);
}

/// 진행 중 membership 스트림을 원본으로 두고 공개 조건·레이드·난이도를 로컬 적용한다.
/// 칩 조작은 서버 조회를 만들지 않는다.
class ActiveRaidFilterViewModel extends ChangeNotifier {
  ActiveRaidFilterViewModel({
    required Stream<PartyReadSnapshot<ActiveRaidSummary>> Function()
    streamFactory,
    required String playerId,
    required RaidStatusFilterStore filterStore,
    RaidCatalogRepository? catalogRepository,
  }) : _streamFactory = streamFactory,
       _playerId = playerId,
       _filterStore = filterStore,
       _catalogRepository = catalogRepository,
       _session = FilteredPageSession<ActiveRaidSummary>(
         idOf: (item) => item.id,
         matches: _matcherFor(RaidStatusFilterSelection.unrestricted),
       );

  final Stream<PartyReadSnapshot<ActiveRaidSummary>> Function() _streamFactory;
  final String _playerId;
  final RaidStatusFilterStore _filterStore;
  final RaidCatalogRepository? _catalogRepository;
  final FilteredPageSession<ActiveRaidSummary> _session;

  StreamSubscription<PartyReadSnapshot<ActiveRaidSummary>>? _subscription;
  var _state = const ActiveRaidFilterViewState();
  var _disposed = false;
  var _started = false;

  ActiveRaidFilterViewState get state => _state;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_restoreSelection());
    unawaited(_loadCatalog());
    _subscription = _streamFactory().listen(_onSnapshot, onError: _onError);
  }

  Future<void> setSelection(RaidStatusFilterSelection selection) async {
    final pruned = _prune(selection);
    _session.updateMatcher(_matcherFor(pruned));
    _emit(selection: pruned);
    try {
      await _filterStore.save(_playerId, pruned);
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _restoreSelection() async {
    try {
      final loaded = _prune(await _filterStore.load(_playerId));
      if (_disposed) return;
      _session.updateMatcher(_matcherFor(loaded));
      _emit(selection: loaded);
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 복원 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return;
      _session.updateMatcher(
        _matcherFor(RaidStatusFilterSelection.unrestricted),
      );
      _emit(selection: RaidStatusFilterSelection.unrestricted);
    }
  }

  Future<void> _loadCatalog() async {
    final repository = _catalogRepository;
    if (repository == null) return;
    try {
      final catalog = raidStatusFilterCatalogOptions(
        await repository.loadCatalog(),
      );
      if (_disposed) return;
      final pruned = _state.selection.prune(
        catalogRaidIds: catalog.raidIds,
        catalogDifficultyIds: catalog.difficultyIds,
      );
      if (pruned != _state.selection) {
        _session.updateMatcher(_matcherFor(pruned));
        unawaited(_filterStore.save(_playerId, pruned));
      }
      _emit(catalog: catalog, selection: pruned);
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 카탈로그 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onSnapshot(PartyReadSnapshot<ActiveRaidSummary> snapshot) {
    _session.replaceOriginal(snapshot.items, hasMore: false);
    _emit(
      isLoading: false,
      isFromCache: snapshot.isFromCache,
      clearFailure: true,
    );
  }

  void _onError(Object error) {
    _emit(
      isLoading: false,
      failure: error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown,
    );
  }

  void _emit({
    RaidStatusFilterSelection? selection,
    RaidStatusFilterCatalogOptions? catalog,
    bool? isLoading,
    bool? isFromCache,
    PartyReadFailureType? failure,
    bool clearFailure = false,
  }) {
    if (_disposed) return;
    _state = ActiveRaidFilterViewState(
      originalItems: _session.originalItems,
      items: _session.filteredItems,
      selection: selection ?? _state.selection,
      catalog: catalog ?? _state.catalog,
      isLoading: isLoading ?? _state.isLoading,
      isFromCache: isFromCache ?? _state.isFromCache,
      hasMore: _session.hasMore,
      failure: clearFailure ? null : (failure ?? _state.failure),
    );
    notifyListeners();
  }

  RaidStatusFilterSelection _prune(RaidStatusFilterSelection selection) {
    final catalog = _state.catalog;
    if (catalog.raids.isEmpty && catalog.difficulties.isEmpty) {
      return selection;
    }
    return selection.prune(
      catalogRaidIds: catalog.raidIds,
      catalogDifficultyIds: catalog.difficultyIds,
    );
  }

  static bool Function(ActiveRaidSummary item) _matcherFor(
    RaidStatusFilterSelection selection,
  ) => raidStatusFilterMatcher<ActiveRaidSummary>(
    selection: selection,
    groupIdOf: (item) => item.groupId,
    raidIdOf: (item) => item.metadata.raidId,
    difficultyIdOf: (item) => item.metadata.difficultyId,
  );

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
