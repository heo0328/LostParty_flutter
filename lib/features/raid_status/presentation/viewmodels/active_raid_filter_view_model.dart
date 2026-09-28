import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/entities/group_relation.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../group/domain/services/activity_display_characters.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../domain/entities/raid_filter_screen.dart';
import '../../domain/entities/raid_list_sort_selection.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/entities/remaining_slots_filter_selection.dart';
import '../../domain/repositories/raid_status_filter_store.dart';
import '../../domain/services/filtered_page_session.dart';
import '../../domain/services/active_raid_cycle_visibility_policy.dart';
import '../../domain/services/raid_filter_candidates.dart';
import '../../domain/services/raid_list_sort.dart';
import '../../domain/services/raid_status_filter.dart';
import 'raid_filter_sheet_host.dart';

class ActiveRaidFilterViewState {
  const ActiveRaidFilterViewState({
    this.originalItems = const [],
    this.items = const [],
    this.selection = RaidStatusFilterSelection.unrestricted,
    this.sortSelection = RaidListSortSelection.defaults,
    this.remainingSlotsSelection = RemainingSlotsFilterSelection.unrestricted,
    this.catalog = const RaidStatusFilterCatalogOptions(),
    this.groups = const [],
    this.members = const [],
    this.ownCharacters = const [],
    this.isLoading = true,
    this.isFromCache = false,
    this.hasMore = false,
    this.failure,
    this.expiredOneShotRecruitmentIds = const [],
    this.expiredRecurringRaids = const [],
  });

  final List<ActiveRaidSummary> originalItems;
  final List<ActiveRaidSummary> items;
  final RaidStatusFilterSelection selection;
  final RaidListSortSelection sortSelection;
  final RemainingSlotsFilterSelection remainingSlotsSelection;
  final RaidStatusFilterCatalogOptions catalog;
  final List<RaidStatusFilterOption> groups;
  final List<RaidStatusFilterMemberOption> members;
  final List<RaidStatusFilterOption> ownCharacters;
  final bool isLoading;
  final bool isFromCache;
  final bool hasMore;
  final PartyReadFailureType? failure;
  final List<String> expiredOneShotRecruitmentIds;
  final List<ActiveRaidSummary> expiredRecurringRaids;

  bool get isEmptyOriginal =>
      !isLoading && failure == null && originalItems.isEmpty;

  bool get isEmptyFiltered =>
      !isLoading &&
      failure == null &&
      originalItems.isNotEmpty &&
      items.isEmpty;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;

  bool get hasFailureWithItems => failure != null && originalItems.isNotEmpty;

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

/// 진행 중 membership 스트림을 원본으로 두고 공개 조건·레이드·난이도·그룹원·
/// Character·내 Character를 로컬 적용한 뒤 인원/자리 정렬을 붙인다.
///
/// 그룹원 Character 칩 후보는 활동 Character ID와 공개 Character 표시
/// 문서를 조합한다. 누락 시 인증 활성 Character 전체로 대체하지 않는다.
/// 필터 판정은 레이드 membership `characterId`를 쓰므로 참가 중인 비활동
/// Character도 인식한다.
class ActiveRaidFilterViewModel extends ChangeNotifier
    implements RaidFilterSheetHost {
  ActiveRaidFilterViewModel({
    required Stream<PartyReadSnapshot<ActiveRaidSummary>> Function()
    streamFactory,
    required String playerId,
    required RaidStatusFilterStore filterStore,
    this.filterScreen = RaidFilterScreen.activeRaids,
    RaidCatalogRepository? catalogRepository,
    Stream<PartyReadSnapshot<PartyMemberDisplay>> Function(
      String recruitmentId,
    )?
    membersStreamFactory,
    GroupReadRepository? groupReadRepository,
    ActivityCharactersRepository? activityCharactersRepository,
    GroupCharacterSearchRepository? characterSearchRepository,
    ActiveRaidCycleVisibilityPolicy cycleVisibilityPolicy =
        const ActiveRaidCycleVisibilityPolicy(),
    DateTime Function() clock = DateTime.now,
  }) : _streamFactory = streamFactory,
       _playerId = playerId,
       _filterStore = filterStore,
       _catalogRepository = catalogRepository,
       _membersStreamFactory = membersStreamFactory,
       _groupReadRepository = groupReadRepository,
       _activityCharactersRepository = activityCharactersRepository,
       _characterSearchRepository = characterSearchRepository,
       _cycleVisibilityPolicy = cycleVisibilityPolicy,
       _clock = clock,
       _session = FilteredPageSession<ActiveRaidSummary>(
         idOf: (item) => item.id,
         matches: _unrestrictedMatcher,
       );

  static bool _unrestrictedMatcher(ActiveRaidSummary item) => true;

  final Stream<PartyReadSnapshot<ActiveRaidSummary>> Function() _streamFactory;
  final String _playerId;
  final RaidStatusFilterStore _filterStore;
  final RaidFilterScreen filterScreen;
  final RaidCatalogRepository? _catalogRepository;
  final Stream<PartyReadSnapshot<PartyMemberDisplay>> Function(
    String recruitmentId,
  )?
  _membersStreamFactory;
  final GroupReadRepository? _groupReadRepository;
  final ActivityCharactersRepository? _activityCharactersRepository;
  final GroupCharacterSearchRepository? _characterSearchRepository;
  final ActiveRaidCycleVisibilityPolicy _cycleVisibilityPolicy;
  final DateTime Function() _clock;
  final FilteredPageSession<ActiveRaidSummary> _session;

  StreamSubscription<PartyReadSnapshot<ActiveRaidSummary>>? _subscription;
  StreamSubscription<GroupReadSnapshot<GroupRelation>>? _groupsSubscription;
  var _state = const ActiveRaidFilterViewState();
  var _disposed = false;
  var _started = false;
  var _groupsLoaded = false;
  var _ownCharactersLoaded = false;
  var _candidateGeneration = 0;
  var _ownCharacterGeneration = 0;
  var _joinedGroupIds = <String>{};
  var _allGroups = const <RaidStatusFilterOption>[];
  var _allMembers = const <RaidStatusFilterMemberOption>[];
  var _ownCharacters = const <RaidStatusFilterOption>[];
  final _raidCharacterIds = <String, Map<String, String>>{};
  final _characterPrefetchAttempted = <String>{};
  List<ActiveRaidSummary> _latestSnapshotItems = const [];
  var _latestSnapshotIsFromCache = false;

  ActiveRaidFilterViewState get state => _state;

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
  bool get showOwnCharacterFilters => true;

  @override
  List<RaidStatusFilterOption> get ownCharacters => _state.ownCharacters;

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

  @override
  Future<void> resetSelection() async {
    final pruned = _prune(RaidStatusFilterSelection.unrestricted);
    _session.updateMatcher(_matcherFor(pruned));
    _emit(
      selection: pruned,
      sortSelection: RaidListSortSelection.defaults,
      remainingSlotsSelection: RemainingSlotsFilterSelection.unrestricted,
    );
    try {
      await _filterStore.save(_playerId, filterScreen, pruned);
      await _filterStore.saveSort(
        _playerId,
        filterScreen,
        RaidListSortSelection.defaults,
      );
      await _filterStore.saveRemainingSlotsFilter(
        _playerId,
        filterScreen,
        RemainingSlotsFilterSelection.unrestricted,
      );
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터·정렬 초기화 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> setSelection(RaidStatusFilterSelection selection) async {
    final pruned = _prune(selection);
    _session.updateMatcher(_matcherFor(pruned));
    _emit(selection: pruned);
    try {
      await _filterStore.save(_playerId, filterScreen, pruned);
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> setSortSelection(RaidListSortSelection selection) async {
    _emit(sortSelection: selection);
    try {
      await _filterStore.saveSort(_playerId, filterScreen, selection);
    } catch (error, stackTrace) {
      debugPrint('진행 중 정렬 저장 실패: $error');
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
    try {
      await _filterStore.saveRemainingSlotsFilter(
        _playerId,
        filterScreen,
        selection,
      );
    } catch (error, stackTrace) {
      debugPrint('진행 중 남은 자리 필터 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> toggleOwnCharacter(String characterId) =>
      setSelection(_state.selection.toggleOwnCharacter(characterId));

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_restoreSelection());
    unawaited(_loadCatalog());
    unawaited(_loadOwnCharacters());
    _listenGroups();
    _subscription = _streamFactory().listen(_onSnapshot, onError: _onError);
  }

  Future<void> _restoreSelection() async {
    try {
      final loaded = await _filterStore.load(_playerId, filterScreen);
      final loadedSort = await _filterStore.loadSort(_playerId, filterScreen);
      final loadedRemaining = await _filterStore.loadRemainingSlotsFilter(
        _playerId,
        filterScreen,
      );
      final pruned = _prune(loaded);
      if (_disposed) return;
      _session.updateMatcher(_matcherFor(pruned));
      _emit(
        selection: pruned,
        sortSelection: loadedSort,
        remainingSlotsSelection: loadedRemaining,
      );
      if (pruned != loaded) {
        await _filterStore.save(_playerId, filterScreen, pruned);
      }
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 복원 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return;
      _session.updateMatcher(
        _matcherFor(RaidStatusFilterSelection.unrestricted),
      );
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
      final pruned = _state.selection.prune(
        catalogRaidIds: catalog.raidIds,
        catalogDifficultyIds: catalog.difficultyIds,
      );
      final next = _prune(pruned);
      if (next != _state.selection) {
        _session.updateMatcher(_matcherFor(next));
        unawaited(_filterStore.save(_playerId, filterScreen, next));
      }
      _emit(catalog: catalog, selection: next);
    } catch (error, stackTrace) {
      debugPrint('진행 중 필터 카탈로그 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadOwnCharacters() async {
    final activity = _activityCharactersRepository;
    final search = _characterSearchRepository;
    if (activity == null || search == null) {
      _ownCharactersLoaded = true;
      return;
    }
    final generation = ++_ownCharacterGeneration;
    try {
      final loaded = await loadActivityDisplayCharacters(
        searchRepository: search,
        ownerPlayerId: _playerId,
        activityRepository: activity,
      );
      if (_disposed || generation != _ownCharacterGeneration) return;
      _ownCharacters = [
        for (final character in loaded)
          RaidStatusFilterOption(
            id: character.characterId,
            label: character.characterName,
          ),
      ];
      _ownCharactersLoaded = true;
      final pruned = _prune(_state.selection);
      if (pruned != _state.selection) {
        _session.updateMatcher(_matcherFor(pruned));
        unawaited(_filterStore.save(_playerId, filterScreen, pruned));
      }
      _emit(selection: pruned, ownCharacters: _ownCharacters);
    } catch (error, stackTrace) {
      debugPrint('진행 중 내 Character 후보 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed || generation != _ownCharacterGeneration) return;
      _ownCharactersLoaded = true;
      _emit(ownCharacters: const []);
    }
  }

  void _listenGroups() {
    final repository = _groupReadRepository;
    if (repository == null) return;
    _groupsSubscription = repository
        .watchMyGroups(_playerId)
        .listen(
          (snapshot) => unawaited(_reloadCandidates(snapshot.items)),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('진행 중 필터 그룹 목록 조회 실패: $error');
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
      playerId: _playerId,
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
      _session.updateMatcher(_matcherFor(pruned));
      unawaited(_filterStore.save(_playerId, filterScreen, pruned));
    }
    _emit(selection: pruned, groups: _allGroups, members: _allMembers);
  }

  void _onSnapshot(PartyReadSnapshot<ActiveRaidSummary> snapshot) {
    _latestSnapshotItems = snapshot.items;
    _latestSnapshotIsFromCache = snapshot.isFromCache;
    _applyCycleVisibility();
  }

  /// 앱이 열린 채 주차 경계를 넘은 경우 새 Firestore snapshot을 기다리지 않고
  /// 현재 시각으로 목록 수명주기를 다시 판정한다.
  void refreshCycleVisibility() => _applyCycleVisibility();

  void _applyCycleVisibility() {
    final now = _clock();
    final visible = <ActiveRaidSummary>[];
    final expiredOneShotIds = <String>[];
    final expiredRecurring = <ActiveRaidSummary>[];
    for (final item in _latestSnapshotItems) {
      final cycleState = _cycleVisibilityPolicy.classify(item, now: now);
      if (cycleState == ActiveRaidCycleState.expiredRecurring &&
          item.leaderPlayerId == _playerId) {
        expiredRecurring.add(item);
      }
      if (_cycleVisibilityPolicy.isVisible(cycleState)) {
        visible.add(item);
      } else if (cycleState == ActiveRaidCycleState.expiredOneShot) {
        expiredOneShotIds.add(item.id);
      }
    }
    _session.replaceOriginal(visible, hasMore: false);
    _emit(
      isLoading: false,
      isFromCache: _latestSnapshotIsFromCache,
      expiredOneShotRecruitmentIds: expiredOneShotIds,
      expiredRecurringRaids: expiredRecurring,
      clearFailure: true,
    );
    unawaited(_prefetchMemberCharacters(visible));
  }

  Future<void> _prefetchMemberCharacters(List<ActiveRaidSummary> items) async {
    final factory = _membersStreamFactory;
    if (factory == null) return;
    final ids = [for (final item in items) item.id];
    _raidCharacterIds.removeWhere((id, _) => !ids.contains(id));
    _characterPrefetchAttempted.removeWhere((id) => !ids.contains(id));
    var loadedNew = false;
    for (final id in ids) {
      if (!_characterPrefetchAttempted.add(id)) continue;
      try {
        final snapshot = await factory(id).first;
        if (_disposed) return;
        _raidCharacterIds[id] = {
          for (final member in snapshot.items)
            if (member.characterId != null &&
                member.characterId!.trim().isNotEmpty)
              member.playerId: member.characterId!,
        };
        loadedNew = true;
      } catch (error, stackTrace) {
        debugPrint('진행 중 필터 멤버 Character 조회 실패: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_disposed || !loadedNew) return;
    _session.updateMatcher(_matcherFor(_state.selection));
    _emit();
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
    RaidListSortSelection? sortSelection,
    RemainingSlotsFilterSelection? remainingSlotsSelection,
    RaidStatusFilterCatalogOptions? catalog,
    List<RaidStatusFilterOption>? groups,
    List<RaidStatusFilterMemberOption>? members,
    List<RaidStatusFilterOption>? ownCharacters,
    bool? isLoading,
    bool? isFromCache,
    PartyReadFailureType? failure,
    List<String>? expiredOneShotRecruitmentIds,
    List<ActiveRaidSummary>? expiredRecurringRaids,
    bool clearFailure = false,
  }) {
    if (_disposed) return;
    final nextSort = sortSelection ?? _state.sortSelection;
    final nextRemaining =
        remainingSlotsSelection ?? _state.remainingSlotsSelection;
    final afterSlots = applyRemainingSlotsFilter(
      items: _session.filteredItems,
      selection: nextRemaining,
      memberCountOf: (item) => item.memberCount,
      maxMemberCountOf: (item) => item.maxMemberCount,
    );
    final filtered = applyRaidListSort(
      items: afterSlots,
      selection: nextSort,
      memberCountOf: (item) => item.memberCount,
      maxMemberCountOf: (item) => item.maxMemberCount,
    );
    _state = ActiveRaidFilterViewState(
      originalItems: _session.originalItems,
      items: filtered,
      selection: selection ?? _state.selection,
      sortSelection: nextSort,
      remainingSlotsSelection: nextRemaining,
      catalog: catalog ?? _state.catalog,
      groups: groups ?? _state.groups,
      members: members ?? _state.members,
      ownCharacters: ownCharacters ?? _state.ownCharacters,
      isLoading: isLoading ?? _state.isLoading,
      isFromCache: isFromCache ?? _state.isFromCache,
      hasMore: _session.hasMore,
      failure: clearFailure ? null : (failure ?? _state.failure),
      expiredOneShotRecruitmentIds:
          expiredOneShotRecruitmentIds ?? _state.expiredOneShotRecruitmentIds,
      expiredRecurringRaids:
          expiredRecurringRaids ?? _state.expiredRecurringRaids,
    );
    notifyListeners();
  }

  RaidStatusFilterSelection _prune(RaidStatusFilterSelection selection) {
    var next = pruneRaidFilterSelection(
      selection: selection,
      catalog: _state.catalog,
      groupsLoaded: _groupsLoaded,
      joinedGroupIds: _joinedGroupIds,
      members: _allMembers,
    );
    if (_ownCharactersLoaded && next.ownCharacterIds.isNotEmpty) {
      final allowed = {for (final character in _ownCharacters) character.id};
      final kept = next.ownCharacterIds.intersection(allowed);
      if (kept.length != next.ownCharacterIds.length) {
        next = next.copyWith(ownCharacterIds: kept);
      }
    }
    return next;
  }

  bool Function(ActiveRaidSummary item) _matcherFor(
    RaidStatusFilterSelection selection,
  ) => raidStatusFilterMatcher<ActiveRaidSummary>(
    selection: selection,
    groupIdOf: (item) => item.groupId,
    raidIdOf: (item) => item.metadata.raidId,
    difficultyIdOf: (item) => item.metadata.difficultyId,
    memberPlayerIdsOf: (item) => item.memberPlayerIds,
    characterIdByPlayerOf: (item) => _raidCharacterIds[item.id],
    currentPlayerId: _playerId,
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
}
