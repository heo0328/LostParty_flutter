import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/entities/group_relation.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../raid_status/domain/entities/raid_filter_screen.dart';
import '../../../raid_status/domain/entities/raid_list_sort_selection.dart';
import '../../../raid_status/domain/entities/raid_status_filter_selection.dart';
import '../../../raid_status/domain/entities/remaining_slots_filter_selection.dart';
import '../../../raid_status/domain/repositories/raid_status_filter_store.dart';
import '../../../raid_status/domain/services/raid_filter_candidates.dart';
import '../../../raid_status/domain/services/raid_list_sort.dart';
import '../../../raid_status/domain/services/raid_status_filter.dart';
import '../../../raid_status/presentation/viewmodels/raid_filter_sheet_host.dart';
import '../../domain/entities/party_read_models.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/repositories/party_read_repository.dart';

class PublicRecruitmentListState {
  const PublicRecruitmentListState({
    this.originalItems = const [],
    this.items = const [],
    this.selection = RaidStatusFilterSelection.unrestricted,
    this.sortSelection = RaidListSortSelection.defaults,
    this.remainingSlotsSelection = RemainingSlotsFilterSelection.unrestricted,
    this.catalog = const RaidStatusFilterCatalogOptions(),
    this.groups = const [],
    this.members = const [],
    this.isLoading = true,
    this.isFromCache = false,
    this.failure,
    this.isLoadingMore = false,
    this.appendFailure,
    this.hasMore = false,
    this.pendingCharacterCheckCount = 0,
    this.characterCheckFailed = false,
  });

  final List<PublicRecruitmentSummary> originalItems;
  final List<PublicRecruitmentSummary> items;
  final RaidStatusFilterSelection selection;
  final RaidListSortSelection sortSelection;
  final RemainingSlotsFilterSelection remainingSlotsSelection;
  final RaidStatusFilterCatalogOptions catalog;
  final List<RaidStatusFilterOption> groups;
  final List<RaidStatusFilterMemberOption> members;
  final bool isLoading;
  final bool isFromCache;
  final PartyReadFailureType? failure;
  final bool isLoadingMore;
  final PartyReadFailureType? appendFailure;
  final bool hasMore;
  final int pendingCharacterCheckCount;
  final bool characterCheckFailed;

  bool get isEmptyOriginal =>
      !isLoading &&
      !isLoadingMore &&
      failure == null &&
      appendFailure == null &&
      originalItems.isEmpty;

  bool get isEmptyFiltered =>
      !isLoading &&
      failure == null &&
      originalItems.isNotEmpty &&
      items.isEmpty;

  bool get isEmpty =>
      !isLoading &&
      !isLoadingMore &&
      failure == null &&
      appendFailure == null &&
      items.isEmpty &&
      originalItems.isEmpty;

  bool get hasFailureWithItems => failure != null && originalItems.isNotEmpty;

  bool get canLoadMore =>
      hasMore && !isLoading && !isLoadingMore && appendFailure == null;

  bool get showGroupMemberFilters =>
      selection.isGroupPublicOnly && groups.isNotEmpty;

  List<RaidStatusFilterMemberOption> get visibleMembers {
    if (selection.groupIds.isEmpty) return members;
    return [
      for (final member in members)
        if (member.groupIds.any(selection.groupIds.contains)) member,
    ];
  }

  String get barLabel => raidStatusFilterBarLabel(
    selection,
    raidNames: catalog.raidNames,
    difficultyNames: catalog.difficultyNames,
    groupNames: {for (final group in groups) group.id: group.label},
    memberNames: {for (final member in members) member.playerId: member.label},
  );

  String get sortBarLabel => raidListMemberCountSortLabel(sortSelection);

  String get remainingSlotsBarLabel =>
      remainingSlotsFilterBarLabel(remainingSlotsSelection);

  String get countLabel =>
      raidStatusFilterCountLabel(count: items.length, hasMore: hasMore);
}

/// 공개 모집 첫 페이지 실시간 구독과 cursor 기반 추가 페이지를 병합한 뒤
/// 레이드 현황과 같은 선택을 로컬 적용한다.
class PublicRecruitmentListViewModel extends ChangeNotifier
    implements RaidFilterSheetHost {
  PublicRecruitmentListViewModel({
    required PartyReadRepository repository,
    required String cycleKey,
    required String currentPlayerId,
    this.pageSize = publicRecruitmentPageSize,
    this.emptyAutoFillMaxPages = publicRecruitmentEmptyAutoFillMaxPages,
    this.filterScreen = RaidFilterScreen.recruitmentList,
    RaidStatusFilterStore? filterStore,
    RaidCatalogRepository? catalogRepository,
    GroupReadRepository? groupReadRepository,
    ActivityCharactersRepository? activityCharactersRepository,
    GroupCharacterSearchRepository? characterSearchRepository,
    Future<void> Function()? backfillOwnGroupListings,
  }) : _repository = repository,
       _cycleKey = cycleKey,
       _currentPlayerId = currentPlayerId,
       _filterStore = filterStore,
       _catalogRepository = catalogRepository,
       _groupReadRepository = groupReadRepository,
       _activityCharactersRepository = activityCharactersRepository,
       _characterSearchRepository = characterSearchRepository,
       _backfillOwnGroupListings = backfillOwnGroupListings;

  final PartyReadRepository _repository;
  final String _cycleKey;
  final String _currentPlayerId;
  final int pageSize;
  final int emptyAutoFillMaxPages;
  final RaidFilterScreen filterScreen;
  final RaidStatusFilterStore? _filterStore;
  final RaidCatalogRepository? _catalogRepository;
  final GroupReadRepository? _groupReadRepository;
  final ActivityCharactersRepository? _activityCharactersRepository;
  final GroupCharacterSearchRepository? _characterSearchRepository;
  final Future<void> Function()? _backfillOwnGroupListings;

  StreamSubscription<PublicRecruitmentPage>? _subscription;
  StreamSubscription<GroupReadSnapshot<GroupRelation>>? _groupsSubscription;
  PublicRecruitmentListState _state = const PublicRecruitmentListState();
  List<PublicRecruitmentSummary> _firstPageItems = const [];
  List<PublicRecruitmentSummary> _appendedItems = const [];
  Set<String>? _firstPageIds;
  PublicRecruitmentPageCursor? _nextCursor;
  var _generation = 0;
  var _autoFillCount = 0;
  var _disposed = false;
  var _groupsLoaded = false;
  var _candidateGeneration = 0;
  var _joinedGroupIds = <String>{};
  var _allGroups = const <RaidStatusFilterOption>[];
  var _allMembers = const <RaidStatusFilterMemberOption>[];
  final _characterIds = <String, Map<String, String>>{};
  final _characterRevisions = <String, int>{};
  final _failedCharacterLookups = <String>{};
  final _inFlightCharacterLookups = <String>{};

  PublicRecruitmentListState get state => _state;

  @override
  RaidStatusFilterSelection get filterSelection => _state.selection;

  @override
  RaidStatusFilterCatalogOptions get filterCatalog => _state.catalog;

  @override
  List<RaidStatusFilterOption> get filterGroups => _state.groups;

  @override
  List<RaidStatusFilterMemberOption> get filterVisibleMembers =>
      _state.visibleMembers;

  @override
  bool get showGroupMemberFilters => _state.showGroupMemberFilters;

  @override
  bool get showOwnCharacterFilters => false;

  @override
  List<RaidStatusFilterOption> get ownCharacters => const [];

  @override
  RaidListSortSelection get sortSelection => _state.sortSelection;

  @override
  String get sortBarLabel => _state.sortBarLabel;

  @override
  RemainingSlotsFilterSelection get remainingSlotsSelection =>
      _state.remainingSlotsSelection;

  @override
  String get remainingSlotsBarLabel => _state.remainingSlotsBarLabel;

  @override
  String get filterCountLabel => _state.countLabel;

  @override
  String get filterBarLabel => _state.barLabel;

  @override
  bool get canResetFilters =>
      !_state.selection.isUnrestricted ||
      !_state.sortSelection.isDefault ||
      !_state.remainingSlotsSelection.isUnrestricted;

  void start() {
    if (_subscription != null) return;
    _autoFillCount = 0;
    unawaited(_restoreSelection());
    unawaited(_loadCatalog());
    _listenGroups();
    _subscription = _repository
        .watchPublicRecruitmentFirstPage(
          cycleKey: _cycleKey,
          currentPlayerId: _currentPlayerId,
          limit: pageSize,
        )
        .listen(_onFirstPage, onError: _onFirstPageError);
    final backfill = _backfillOwnGroupListings;
    if (backfill != null) {
      unawaited(() async {
        try {
          await backfill();
        } catch (_) {}
      }());
    }
  }

  @override
  Future<void> resetSelection() async {
    final pruned = _prune(RaidStatusFilterSelection.unrestricted);
    _autoFillCount = 0;
    _emit(
      selection: pruned,
      sortSelection: RaidListSortSelection.defaults,
      remainingSlotsSelection: RemainingSlotsFilterSelection.unrestricted,
    );
    unawaited(_prefetchNeededCharacters());
    unawaited(_maybeAutoFill());
    final store = _filterStore;
    if (store == null) return;
    try {
      await store.save(_currentPlayerId, filterScreen, pruned);
      await store.saveSort(
        _currentPlayerId,
        filterScreen,
        RaidListSortSelection.defaults,
      );
      await store.saveRemainingSlotsFilter(
        _currentPlayerId,
        filterScreen,
        RemainingSlotsFilterSelection.unrestricted,
      );
    } catch (error, stackTrace) {
      debugPrint('모집 목록 필터·정렬 초기화 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> setSelection(RaidStatusFilterSelection selection) async {
    final pruned = _prune(selection);
    _autoFillCount = 0;
    _emit(selection: pruned);
    unawaited(_prefetchNeededCharacters());
    unawaited(_maybeAutoFill());
    final store = _filterStore;
    if (store == null) return;
    try {
      await store.save(_currentPlayerId, filterScreen, pruned);
    } catch (error, stackTrace) {
      debugPrint('모집 목록 필터 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> setSortSelection(RaidListSortSelection selection) async {
    _emit(sortSelection: selection);
    final store = _filterStore;
    if (store == null) return;
    try {
      await store.saveSort(_currentPlayerId, filterScreen, selection);
    } catch (error, stackTrace) {
      debugPrint('모집 목록 정렬 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> toggleMemberCountSort() =>
      setSortSelection(_state.sortSelection.toggled());

  @override
  Future<void> setRemainingSlotsSelection(
    RemainingSlotsFilterSelection selection,
  ) async {
    _emit(remainingSlotsSelection: selection);
    final store = _filterStore;
    if (store == null) return;
    try {
      await store.saveRemainingSlotsFilter(
        _currentPlayerId,
        filterScreen,
        selection,
      );
    } catch (error, stackTrace) {
      debugPrint('모집 목록 남은 자리 필터 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> toggleOwnCharacter(String characterId) async {}

  void retryCharacterChecks() {
    _failedCharacterLookups.clear();
    _emit();
    unawaited(_prefetchNeededCharacters());
  }

  Future<void> refresh() async {
    _generation += 1;
    await _subscription?.cancel();
    _subscription = null;
    _firstPageItems = const [];
    _appendedItems = const [];
    _firstPageIds = null;
    _nextCursor = null;
    _characterIds.clear();
    _characterRevisions.clear();
    _failedCharacterLookups.clear();
    _inFlightCharacterLookups.clear();
    _state = PublicRecruitmentListState(
      selection: _state.selection,
      sortSelection: _state.sortSelection,
      remainingSlotsSelection: _state.remainingSlotsSelection,
      catalog: _state.catalog,
      groups: _state.groups,
      members: _state.members,
    );
    notifyListeners();
    start();
  }

  Future<void> loadMore({bool isRetry = false}) async {
    if (_state.isLoading || _state.isLoadingMore || !_state.hasMore) return;
    if (!isRetry && _state.appendFailure != null) return;
    final cursor = _nextCursor;
    if (cursor == null) return;

    final generation = _generation;
    _emit(isLoadingMore: true, clearAppendFailure: true);
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
      _emit(isLoadingMore: false, hasMore: page.hasMore);
      unawaited(_prefetchNeededCharacters());
      await _maybeAutoFill();
    } catch (error) {
      if (generation != _generation) return;
      _emit(
        isLoadingMore: false,
        appendFailure: error is PartyReadException
            ? error.type
            : PartyReadFailureType.unknown,
      );
    }
  }

  void retryAppend() {
    unawaited(loadMore(isRetry: true));
  }

  Future<void> _restoreSelection() async {
    final store = _filterStore;
    if (store == null) return;
    try {
      final loaded = await store.load(_currentPlayerId, filterScreen);
      final loadedSort = await store.loadSort(_currentPlayerId, filterScreen);
      final loadedRemaining = await store.loadRemainingSlotsFilter(
        _currentPlayerId,
        filterScreen,
      );
      final pruned = _prune(loaded);
      if (_disposed) return;
      _emit(
        selection: pruned,
        sortSelection: loadedSort,
        remainingSlotsSelection: loadedRemaining,
      );
      if (pruned != loaded) {
        await store.save(_currentPlayerId, filterScreen, pruned);
      }
      unawaited(_prefetchNeededCharacters());
    } catch (error, stackTrace) {
      debugPrint('모집 목록 필터 복원 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return;
      _emit(
        selection: RaidStatusFilterSelection.unrestricted,
        sortSelection: RaidListSortSelection.defaults,
        remainingSlotsSelection: RemainingSlotsFilterSelection.unrestricted,
      );
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
      final next = _prune(
        _state.selection.prune(
          catalogRaidIds: catalog.raidIds,
          catalogDifficultyIds: catalog.difficultyIds,
        ),
      );
      if (next != _state.selection) {
        unawaited(_filterStore?.save(_currentPlayerId, filterScreen, next));
      }
      _emit(catalog: catalog, selection: next);
    } catch (error, stackTrace) {
      debugPrint('모집 목록 필터 카탈로그 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _listenGroups() {
    final repository = _groupReadRepository;
    if (repository == null) return;
    _groupsSubscription = repository
        .watchMyGroups(_currentPlayerId)
        .listen(
          (snapshot) => unawaited(_reloadCandidates(snapshot.items)),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('모집 목록 필터 그룹 목록 조회 실패: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  Future<void> _reloadCandidates(List<GroupRelation> relations) async {
    final repository = _groupReadRepository;
    if (repository == null) return;
    final generation = ++_candidateGeneration;
    final snapshot = await loadRaidFilterCandidates(
      repository: repository,
      playerId: _currentPlayerId,
      relations: relations,
      activityCharactersRepository: _activityCharactersRepository,
      characterSearchRepository: _characterSearchRepository,
      isStale: () => _disposed || generation != _candidateGeneration,
    );
    if (_disposed || generation != _candidateGeneration) return;
    _joinedGroupIds = snapshot.joinedGroupIds;
    _allGroups = snapshot.groups;
    _allMembers = snapshot.members;
    _groupsLoaded = true;
    final pruned = _prune(_state.selection);
    if (pruned != _state.selection) {
      unawaited(_filterStore?.save(_currentPlayerId, filterScreen, pruned));
    }
    _emit(selection: pruned, groups: _allGroups, members: _allMembers);
    unawaited(_prefetchNeededCharacters());
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
      _emit(
        isLoading: false,
        isFromCache: page.isFromCache,
        isLoadingMore: false,
        hasMore: page.hasMore,
        clearFailure: true,
        clearAppendFailure: true,
        firstPageItems: page.items,
      );
    } else {
      final keepAppend = previousIds != null && _appendedItems.isNotEmpty;
      if (!keepAppend) {
        _nextCursor = page.nextCursor;
        _appendedItems = const [];
      }
      _emit(
        isLoading: false,
        isFromCache: page.isFromCache,
        hasMore: keepAppend ? _state.hasMore : page.hasMore,
        clearFailure: true,
        clearAppendFailure: keepAppend ? false : true,
        firstPageItems: page.items,
      );
    }

    _firstPageItems = page.items;
    _firstPageIds = newIds;
    unawaited(_prefetchNeededCharacters());
    unawaited(_maybeAutoFill());
  }

  Future<void> _maybeAutoFill() async {
    if (_autoFillCount >= emptyAutoFillMaxPages) return;
    if (_state.items.isNotEmpty) return;
    if (_state.pendingCharacterCheckCount > 0) return;
    if (_state.isLoading || _state.isLoadingMore) return;
    if (_state.failure != null || _state.appendFailure != null) return;
    if (!_state.hasMore || _nextCursor == null) return;
    _autoFillCount += 1;
    await loadMore();
  }

  void _onFirstPageError(Object error) {
    _emit(
      isLoading: false,
      failure: error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown,
    );
  }

  bool get _needsCharacterLookup =>
      _state.selection.isGroupPublicOnly &&
      _state.selection.selectedCharacterCount > 0;

  Future<void> _prefetchNeededCharacters() async {
    if (!_needsCharacterLookup) {
      if (_state.pendingCharacterCheckCount == 0 &&
          !_state.characterCheckFailed) {
        return;
      }
      _emit();
      return;
    }
    _syncCharacterCache(_mergedItems());
    final needed = [
      for (final item in _mergedItems())
        if (_passesWithoutCharacters(item) &&
            !_characterIds.containsKey(item.id) &&
            !_failedCharacterLookups.contains(item.id) &&
            !_inFlightCharacterLookups.contains(item.id))
          item,
    ];
    if (needed.isEmpty) {
      _emit();
      return;
    }
    _emit();
    for (final item in needed) {
      _inFlightCharacterLookups.add(item.id);
      final generation = _generation;
      final revision = item.revision;
      try {
        final snapshot = await _repository
            .watchRecruitmentMembers(item.id)
            .first;
        if (_disposed || generation != _generation) return;
        if (_characterRevisions[item.id] != revision) continue;
        _characterIds[item.id] = {
          for (final member in snapshot.items)
            if (member.characterId != null &&
                member.characterId!.trim().isNotEmpty)
              member.playerId: member.characterId!,
        };
        _failedCharacterLookups.remove(item.id);
      } catch (error, stackTrace) {
        debugPrint('모집 목록 참가 Character 조회 실패: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (_disposed || generation != _generation) return;
        _failedCharacterLookups.add(item.id);
      } finally {
        _inFlightCharacterLookups.remove(item.id);
      }
    }
    if (_disposed) return;
    _emit();
    unawaited(_maybeAutoFill());
  }

  void _syncCharacterCache(List<PublicRecruitmentSummary> original) {
    final ids = {for (final item in original) item.id};
    _characterIds.removeWhere((id, _) => !ids.contains(id));
    _characterRevisions.removeWhere((id, _) => !ids.contains(id));
    _failedCharacterLookups.removeWhere((id) => !ids.contains(id));
    _inFlightCharacterLookups.removeWhere((id) => !ids.contains(id));
    for (final item in original) {
      final previous = _characterRevisions[item.id];
      if (previous != null && previous != item.revision) {
        _characterIds.remove(item.id);
        _failedCharacterLookups.remove(item.id);
        _inFlightCharacterLookups.remove(item.id);
      }
      _characterRevisions[item.id] = item.revision;
    }
  }

  bool _passesWithoutCharacters(PublicRecruitmentSummary item) {
    return _passesWithoutCharactersFor(item, _state.selection);
  }

  List<PublicRecruitmentSummary> _mergedItems() =>
      _merge(_firstPageItems, _appendedItems);

  void _emit({
    RaidStatusFilterSelection? selection,
    RaidListSortSelection? sortSelection,
    RemainingSlotsFilterSelection? remainingSlotsSelection,
    RaidStatusFilterCatalogOptions? catalog,
    List<RaidStatusFilterOption>? groups,
    List<RaidStatusFilterMemberOption>? members,
    bool? isLoading,
    bool? isFromCache,
    PartyReadFailureType? failure,
    bool clearFailure = false,
    bool? isLoadingMore,
    PartyReadFailureType? appendFailure,
    bool clearAppendFailure = false,
    bool? hasMore,
    List<PublicRecruitmentSummary>? firstPageItems,
  }) {
    if (_disposed) return;
    if (firstPageItems != null) {
      _firstPageItems = firstPageItems;
    }
    final original = _mergedItems();
    final nextSelection = selection ?? _state.selection;
    final nextSort = sortSelection ?? _state.sortSelection;
    final nextRemaining =
        remainingSlotsSelection ?? _state.remainingSlotsSelection;
    final needsCharacters =
        nextSelection.isGroupPublicOnly &&
        nextSelection.selectedCharacterCount > 0;
    if (needsCharacters) {
      _syncCharacterCache(original);
    }
    final matches = [
      for (final item in original)
        if (_isConfirmedMatchFor(item, nextSelection)) item,
    ];
    final afterSlots = applyRemainingSlotsFilter(
      items: matches,
      selection: nextRemaining,
      memberCountOf: (item) => item.memberCount,
      maxMemberCountOf: (item) => item.maxMemberCount,
    );
    final sorted = applyRaidListSort(
      items: afterSlots,
      selection: nextSort,
      memberCountOf: (item) => item.memberCount,
      maxMemberCountOf: (item) => item.maxMemberCount,
    );
    var pending = 0;
    var failed = false;
    if (needsCharacters) {
      for (final item in original) {
        if (!_passesWithoutCharactersFor(item, nextSelection)) continue;
        if (_characterIds.containsKey(item.id)) continue;
        if (_failedCharacterLookups.contains(item.id)) {
          failed = true;
          continue;
        }
        pending += 1;
      }
    }
    _state = PublicRecruitmentListState(
      originalItems: original,
      items: sorted,
      selection: nextSelection,
      sortSelection: nextSort,
      remainingSlotsSelection: nextRemaining,
      catalog: catalog ?? _state.catalog,
      groups: groups ?? _state.groups,
      members: members ?? _state.members,
      isLoading: isLoading ?? _state.isLoading,
      isFromCache: isFromCache ?? _state.isFromCache,
      failure: clearFailure ? null : (failure ?? _state.failure),
      isLoadingMore: isLoadingMore ?? _state.isLoadingMore,
      appendFailure: clearAppendFailure
          ? null
          : (appendFailure ?? _state.appendFailure),
      hasMore: hasMore ?? _state.hasMore,
      pendingCharacterCheckCount: pending,
      characterCheckFailed: failed,
    );
    notifyListeners();
  }

  bool _passesWithoutCharactersFor(
    PublicRecruitmentSummary item,
    RaidStatusFilterSelection selection,
  ) => matchesRaidStatusFilter(
    selection: selection,
    groupId: item.groupId,
    raidId: item.metadata.raidId,
    difficultyId: item.metadata.difficultyId,
    raidMemberPlayerIds: item.memberPlayerIds,
    skipIncompleteCharacterLookup: true,
  );

  bool _isConfirmedMatchFor(
    PublicRecruitmentSummary item,
    RaidStatusFilterSelection selection,
  ) {
    final needsCharacters =
        selection.isGroupPublicOnly &&
        selection.selectedCharacterCount > 0 &&
        _passesWithoutCharactersFor(item, selection);
    return matchesRaidStatusFilter(
      selection: selection,
      groupId: item.groupId,
      raidId: item.metadata.raidId,
      difficultyId: item.metadata.difficultyId,
      raidMemberPlayerIds: item.memberPlayerIds,
      raidCharacterIdByPlayer: needsCharacters ? _characterIds[item.id] : null,
      skipIncompleteCharacterLookup: !needsCharacters,
    );
  }

  RaidStatusFilterSelection _prune(RaidStatusFilterSelection selection) =>
      pruneRaidFilterSelection(
        selection: selection,
        catalog: _state.catalog,
        groupsLoaded: _groupsLoaded,
        joinedGroupIds: _joinedGroupIds,
        members: _allMembers,
      );

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _groupsSubscription?.cancel();
    _groupsSubscription = null;
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
