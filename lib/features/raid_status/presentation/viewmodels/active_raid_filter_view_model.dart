import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/entities/group_relation.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../domain/entities/raid_filter_screen.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/repositories/raid_status_filter_store.dart';
import '../../domain/services/filtered_page_session.dart';
import '../../domain/services/raid_filter_candidates.dart';
import '../../domain/services/raid_status_filter.dart';
import 'raid_filter_sheet_host.dart';

class ActiveRaidFilterViewState {
  const ActiveRaidFilterViewState({
    this.originalItems = const [],
    this.items = const [],
    this.selection = RaidStatusFilterSelection.unrestricted,
    this.catalog = const RaidStatusFilterCatalogOptions(),
    this.groups = const [],
    this.members = const [],
    this.isLoading = true,
    this.isFromCache = false,
    this.hasMore = false,
    this.failure,
  });

  final List<ActiveRaidSummary> originalItems;
  final List<ActiveRaidSummary> items;
  final RaidStatusFilterSelection selection;
  final RaidStatusFilterCatalogOptions catalog;
  final List<RaidStatusFilterOption> groups;
  final List<RaidStatusFilterMemberOption> members;
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

  String get countLabel =>
      raidStatusFilterCountLabel(count: items.length, hasMore: hasMore);
}

/// 진행 중 membership 스트림을 원본으로 두고 공개 조건·레이드·난이도·그룹원·
/// Character를 로컬 적용한다. 칩 조작은 서버 조회를 만들지 않는다.
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
  }) : _streamFactory = streamFactory,
       _playerId = playerId,
       _filterStore = filterStore,
       _catalogRepository = catalogRepository,
       _membersStreamFactory = membersStreamFactory,
       _groupReadRepository = groupReadRepository,
       _activityCharactersRepository = activityCharactersRepository,
       _characterSearchRepository = characterSearchRepository,
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
  final FilteredPageSession<ActiveRaidSummary> _session;

  StreamSubscription<PartyReadSnapshot<ActiveRaidSummary>>? _subscription;
  StreamSubscription<GroupReadSnapshot<GroupRelation>>? _groupsSubscription;
  var _state = const ActiveRaidFilterViewState();
  var _disposed = false;
  var _started = false;
  var _groupsLoaded = false;
  var _candidateGeneration = 0;
  var _joinedGroupIds = <String>{};
  var _allGroups = const <RaidStatusFilterOption>[];
  var _allMembers = const <RaidStatusFilterMemberOption>[];
  final _raidCharacterIds = <String, Map<String, String>>{};
  final _characterPrefetchAttempted = <String>{};

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
  String get filterCountLabel => _state.countLabel;

  @override
  String get filterBarLabel => _state.barLabel;

  @override
  Future<void> resetSelection() =>
      setSelection(RaidStatusFilterSelection.unrestricted);

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

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_restoreSelection());
    unawaited(_loadCatalog());
    _listenGroups();
    _subscription = _streamFactory().listen(_onSnapshot, onError: _onError);
  }

  Future<void> _restoreSelection() async {
    try {
      final loaded = await _filterStore.load(_playerId, filterScreen);
      final pruned = _prune(loaded);
      if (_disposed) return;
      _session.updateMatcher(_matcherFor(pruned));
      _emit(selection: pruned);
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
    _session.replaceOriginal(snapshot.items, hasMore: false);
    _emit(
      isLoading: false,
      isFromCache: snapshot.isFromCache,
      clearFailure: true,
    );
    unawaited(_prefetchMemberCharacters(snapshot.items));
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
    RaidStatusFilterCatalogOptions? catalog,
    List<RaidStatusFilterOption>? groups,
    List<RaidStatusFilterMemberOption>? members,
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
      groups: groups ?? _state.groups,
      members: members ?? _state.members,
      isLoading: isLoading ?? _state.isLoading,
      isFromCache: isFromCache ?? _state.isFromCache,
      hasMore: _session.hasMore,
      failure: clearFailure ? null : (failure ?? _state.failure),
    );
    notifyListeners();
  }

  RaidStatusFilterSelection _prune(RaidStatusFilterSelection selection) =>
      pruneRaidFilterSelection(
        selection: selection,
        catalog: _state.catalog,
        groupsLoaded: _groupsLoaded,
        joinedGroupIds: _joinedGroupIds,
        members: _allMembers,
      );

  bool Function(ActiveRaidSummary item) _matcherFor(
    RaidStatusFilterSelection selection,
  ) => raidStatusFilterMatcher<ActiveRaidSummary>(
    selection: selection,
    groupIdOf: (item) => item.groupId,
    raidIdOf: (item) => item.metadata.raidId,
    difficultyIdOf: (item) => item.metadata.difficultyId,
    memberPlayerIdsOf: (item) => item.memberPlayerIds,
    characterIdByPlayerOf: (item) => _raidCharacterIds[item.id],
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
