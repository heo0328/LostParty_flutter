import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/nice_group_policy_result.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/character_management_gateway.dart';
import '../../domain/repositories/activity_characters_repository.dart';
import '../../domain/repositories/nice_group_auto_refresh_settings_repository.dart';
import '../../domain/repositories/representative_character_sync_gateway.dart';
import '../../domain/services/nice_group_policy.dart';
import '../../domain/services/character_usage_level_policy.dart';

class CharacterManagementViewModel extends ChangeNotifier {
  CharacterManagementViewModel({
    required AccountRepository accountRepository,
    RepresentativeCharacterSyncGateway? representativeSyncGateway,
    ActivityCharactersRepository? activityCharactersRepository,
    NiceGroupAutoRefreshSettingsRepository? niceGroupSettingsRepository,
    NiceGroupPolicy niceGroupPolicy = const NiceGroupPolicy(),
    String? playerId,
    DateTime Function()? clock,
    this.accountId,
    this.managementGateway,
  }) : _accountRepository = accountRepository,
       _representativeSyncGateway = representativeSyncGateway,
       _activityCharactersRepository = activityCharactersRepository,
       _niceGroupSettingsRepository = niceGroupSettingsRepository,
       _niceGroupPolicy = niceGroupPolicy,
       _playerId = playerId?.trim() ?? '',
       _clock = clock ?? DateTime.now {
    managementGateway?.addListener(_managementChanged);
  }

  final CharacterManagementGateway? managementGateway;
  CharacterManagementSnapshot? _management;
  bool _disposed = false;
  bool _explicitRepresentative = false;
  bool _orderChanged = false;
  bool get canEditDraft => !_draftLocked;
  bool get isMemberManagement => managementGateway != null;
  bool get canSave =>
      !_isSaving && (managementGateway == null || managementGateway!.current);
  bool get _draftLocked =>
      _isSaving ||
      (managementGateway != null &&
          (!managementGateway!.current || managementGateway!.pending));
  void _managementChanged() {
    if (_disposed) return;
    if (managementGateway?.current == false && !_isLoading) {
      _account = null;
      _roster = const [];
      _message = '현재 회원의 소유 정보를 다시 확인해 주세요.';
    }
    notifyListeners();
  }

  final AccountRepository _accountRepository;
  final RepresentativeCharacterSyncGateway? _representativeSyncGateway;
  final ActivityCharactersRepository? _activityCharactersRepository;
  final NiceGroupAutoRefreshSettingsRepository? _niceGroupSettingsRepository;
  final NiceGroupPolicy _niceGroupPolicy;
  final String _playerId;
  final DateTime Function() _clock;
  final int? accountId;

  bool _isLoading = false;
  bool _isSaving = false;
  LocalGameAccount? _account;
  List<LocalGameAccount> _allAccounts = const [];
  List<LocalAccountCharacter> _roster = const [];
  Set<int> _draftSelectedIds = {};
  List<int> _draftOrderedIds = [];
  int? _draftRepresentativeId;
  int _draftDisplayLimit = 1;
  Map<int, int> _rememberedOrder = {};
  Set<String> _loadedActivityIds = {};
  NiceGroupPolicyResult _niceGroupResult = const NiceGroupPolicyResult(
    classNames: {},
  );
  bool _draftNiceGroupAutoRefreshEnabled = false;
  _DraftSnapshot? _baseline;
  RepresentativeCharacterSyncState? _representativeSyncState;
  bool _representativeSyncLoaded = false;
  String? _message;
  Timer? _cooldownTimer;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  LocalGameAccount? get account => _account;
  List<LocalAccountCharacter> get rosterCharacters => _roster;
  String? get message => _message;
  int get rosterCount => _roster.length;
  int get selectedCount => _draftSelectedIds.length;
  int get maxDisplayLimit => math.max(1, _draftSelectedIds.length);
  int get draftDisplayLimit => _draftDisplayLimit;
  int? get draftRepresentativeId => _draftRepresentativeId;
  NiceGroupPolicyResult get niceGroupResult => _niceGroupResult;
  bool get hasNiceGroupCharacters =>
      _management?.hasNiceGroup ?? !_niceGroupResult.isEmpty;
  bool get draftNiceGroupAutoRefreshEnabled =>
      _draftNiceGroupAutoRefreshEnabled;

  List<LocalAccountCharacter> get selectedCharacters {
    final byId = {for (final character in _roster) character.id: character};
    return [for (final id in _draftOrderedIds) ?byId[id]];
  }

  bool get hasUnsavedChanges {
    final baseline = _baseline;
    if (baseline == null) return false;
    return !_setEquals(baseline.selectedIds, _draftSelectedIds) ||
        !listEquals(baseline.orderedIds, _draftOrderedIds) ||
        baseline.representativeId != _draftRepresentativeId ||
        baseline.displayLimit != _draftDisplayLimit ||
        baseline.niceGroupAutoRefreshEnabled !=
            _draftNiceGroupAutoRefreshEnabled;
  }

  Duration get representativeCooldownRemaining {
    final remaining = _representativeSyncState?.remainingAt(_clock().toUtc());
    return remaining ?? Duration.zero;
  }

  String? get representativeCooldownLabel {
    final remaining = representativeCooldownRemaining;
    if (remaining <= Duration.zero) return null;
    final seconds =
        remaining.inSeconds +
        (remaining.inMilliseconds % Duration.millisecondsPerSecond == 0
            ? 0
            : 1);
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return '대표 캐릭터는 $minutesPart분 ${secondsPart.toString().padLeft(2, '0')}초 후 변경할 수 있습니다.';
  }

  bool isActivitySelected(LocalAccountCharacter character) {
    return _draftSelectedIds.contains(character.id);
  }

  bool canToggleActivity(LocalAccountCharacter character) {
    if (isMemberManagement) {
      if (_draftLocked) return false;
      if (_draftSelectedIds.contains(character.id)) {
        return character.id != _draftRepresentativeId;
      }
      return _management!.usableIds.contains(character.id);
    }
    if (_isSaving || character.serverCharacterId == null) {
      return false;
    }
    if (!_draftSelectedIds.contains(character.id)) {
      return true;
    }
    if (character.id == _draftRepresentativeId) {
      return false;
    }
    return _draftSelectedIds.length > 1;
  }

  bool canSetRepresentative(LocalAccountCharacter character) {
    if (isMemberManagement) {
      return !_draftLocked &&
          _draftSelectedIds.contains(character.id) &&
          _draftRepresentativeId != character.id &&
          _management!.usableIds.contains(character.id);
    }
    if (_isSaving ||
        !_draftSelectedIds.contains(character.id) ||
        _draftRepresentativeId == character.id) {
      return false;
    }
    if (!_requiresServerRepresentativeSync) return true;
    return _representativeSyncLoaded &&
        character.serverCharacterId != null &&
        representativeCooldownRemaining <= Duration.zero;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    if (managementGateway case final gateway?) {
      try {
        final snapshot = await gateway.load();
        if (!_disposed) _applyManagement(snapshot);
      } catch (e) {
        if (!_disposed) _message = _managementError(e);
      } finally {
        if (!_disposed) {
          _isLoading = false;
          notifyListeners();
        }
      }
      return;
    }
    await _reloadAccounts();
    await _loadNiceGroupSetting();
    await _synchronizeRepresentative();
    await _loadActivity();
    _resetDraftFromLoaded();
    _isLoading = false;
    notifyListeners();
  }

  void toggleActivity(LocalAccountCharacter character) {
    if (!canToggleActivity(character)) {
      return;
    }
    _message = null;
    if (_draftSelectedIds.contains(character.id)) {
      _draftSelectedIds = {..._draftSelectedIds}..remove(character.id);
      _draftOrderedIds = [
        for (final id in _draftOrderedIds)
          if (id != character.id) id,
      ];
    } else {
      _draftSelectedIds = {..._draftSelectedIds, character.id};
      _draftOrderedIds = _insertRestoredOrder(character.id);
    }
    _seedInitialRepresentative();
    _clampDisplayLimit();
    notifyListeners();
  }

  void setRepresentative(LocalAccountCharacter character) {
    if (!canSetRepresentative(character)) {
      return;
    }
    _message = null;
    if (isMemberManagement) _explicitRepresentative = true;
    _draftRepresentativeId = character.id;
    notifyListeners();
  }

  void changeDisplayLimit(int change) {
    if (_draftLocked) return;
    final maxLimit = math.max(1, _draftSelectedIds.length);
    final nextLimit = (_draftDisplayLimit + change).clamp(1, maxLimit);
    if (nextLimit == _draftDisplayLimit) {
      return;
    }
    _message = null;
    _draftDisplayLimit = nextLimit;
    notifyListeners();
  }

  void setNiceGroupAutoRefreshEnabled(bool enabled) {
    if (_isSaving || !hasNiceGroupCharacters) return;
    _draftNiceGroupAutoRefreshEnabled = enabled;
    _message = null;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (_draftLocked || oldIndex == newIndex) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex--;
    }
    final reordered = List<int>.of(_draftOrderedIds);
    if (oldIndex < 0 ||
        oldIndex >= reordered.length ||
        newIndex < 0 ||
        newIndex > reordered.length) {
      return;
    }
    final characterId = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, characterId);
    _draftOrderedIds = reordered;
    _orderChanged = true;
    for (var index = 0; index < reordered.length; index++) {
      _rememberedOrder[reordered[index]] = index;
    }
    _message = null;
    notifyListeners();
  }

  void discardChanges() {
    if (_draftLocked) return;
    final baseline = _baseline;
    if (baseline == null) {
      return;
    }
    _draftSelectedIds = {...baseline.selectedIds};
    _draftOrderedIds = List<int>.of(baseline.orderedIds);
    _draftRepresentativeId = baseline.representativeId;
    _draftDisplayLimit = baseline.displayLimit;
    _draftNiceGroupAutoRefreshEnabled = baseline.niceGroupAutoRefreshEnabled;
    _explicitRepresentative = false;
    _orderChanged = false;
    _message = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugClearActivitySelection() {
    _draftSelectedIds = {};
    _draftOrderedIds = [];
    _clampDisplayLimit();
    notifyListeners();
  }

  Future<void> save() async {
    final account = _account;
    if (account == null || _isSaving) {
      return;
    }
    if (managementGateway case final gateway?) {
      if (!canSave) return;
      _isSaving = true;
      _message = null;
      notifyListeners();
      try {
        _seedInitialRepresentative();
        final representative = _draftRepresentativeId;
        if (representative == null) {
          _message = '앱에서 사용할 캐릭터와 대표를 선택해 주세요.';
        } else {
          final snapshot = await gateway.save(
            selectedIds: List.of(_draftOrderedIds),
            representativeId: representative,
            displayLimit: _draftDisplayLimit,
            saveDisplayOrder: _orderChanged,
          );
          if (!_disposed) _applyManagement(snapshot);
        }
      } catch (e) {
        if (!_disposed) _message = _managementError(e);
      } finally {
        if (!_disposed) {
          _isSaving = false;
          notifyListeners();
        }
      }
      return;
    }
    if (_draftSelectedIds.isEmpty) {
      _message = '앱에서 사용할 캐릭터를 최소 1명 선택해 주세요.';
      notifyListeners();
      return;
    }

    _isSaving = true;
    _message = null;
    notifyListeners();
    try {
      final representative = _characterById(_draftRepresentativeId);
      if (representative != null &&
          account.representativeCharacterId != representative.id) {
        await _syncRepresentativeChange(account, representative);
      }

      final activityIds = _activityCharacterIdsForSave();
      final ownedIds = _ownedServerCharacterIds();
      final repository = _activityCharactersRepository;
      if (repository != null && ownedIds.isNotEmpty && _playerId.isNotEmpty) {
        final saved = await repository.save(
          SaveActivityCharactersCommand(
            activityCharacterIds: activityIds,
            ownedCharacterIds: ownedIds,
            orderedActivityCharacterIds: _orderedActivityCharacterIdsForSave(
              activityIds,
            ),
          ),
        );
        _loadedActivityIds = saved.characterIds;
      }

      for (final character in account.characters) {
        final isVisible = _draftSelectedIds.contains(character.id);
        if (character.isVisible != isVisible) {
          await _accountRepository.updateCharacterVisibility(
            accountId: account.id,
            characterId: character.id,
            isVisible: isVisible,
          );
        }
      }
      await _accountRepository.updateCharacterDisplayOrder(
        accountId: account.id,
        characterIds: _fullDisplayOrderIdsForSave(account),
      );
      await _accountRepository.updateDisplayLimit(
        accountId: account.id,
        displayLimit: _draftDisplayLimit,
      );
      final settingsRepository = _niceGroupSettingsRepository;
      if (settingsRepository != null &&
          _playerId.isNotEmpty &&
          _baseline?.niceGroupAutoRefreshEnabled !=
              _draftNiceGroupAutoRefreshEnabled) {
        await settingsRepository.saveEnabled(
          playerId: _playerId,
          enabled: _draftNiceGroupAutoRefreshEnabled,
        );
      }
      if (representative != null &&
          account.representativeCharacterId != representative.id) {
        await _accountRepository.setRepresentativeCharacter(
          accountId: account.id,
          characterId: representative.id,
        );
      }
      await _reloadAccounts();
      _resetDraftFromLoaded();
    } on ActivityCharactersSaveException catch (error) {
      _message = error.message;
    } on RepresentativeCharacterSyncException catch (error) {
      _message = error.message;
    } on Object catch (error, stackTrace) {
      debugPrint(
        'CharacterManagementViewModel.save failed: $error\n$stackTrace',
      );
      _message = '캐릭터 설정을 서버에 반영하지 못했습니다. (${error.runtimeType})';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAccounts() async {
    _allAccounts = await _accountRepository.loadAccounts();
    _niceGroupResult = _niceGroupPolicy.evaluate(_allAccounts);
    if (accountId == null) {
      _account = await _accountRepository.loadMainAccount();
    } else {
      _account = null;
      for (final account in _allAccounts) {
        if (account.id == accountId) {
          _account = account;
          break;
        }
      }
    }
    final account = _account;
    if (account == null) {
      _roster = const [];
      return;
    }
    _roster = _sortedRoster(
      account.characters,
      account.representativeCharacterId,
    );
  }

  String _managementError(Object e) {
    final pending = managementGateway?.pending == true;
    if (pending) {
      return '저장 결과 또는 표시 설정을 확인하지 못했습니다. 저장 버튼으로 같은 요청을 다시 확인해 주세요.';
    }
    if (e is AccountReadException && e.code == 'REQUEST_IN_PROGRESS') {
      return '다른 갱신 또는 저장을 처리 중입니다. 완료 후 다시 저장해 주세요.';
    }
    if (e is AccountReadException && e.code == 'CHARACTER_UNUSABLE') {
      return '현재 사용할 수 없는 캐릭터가 선택돼 있습니다. 사용 대상과 대표를 변경해 주세요.';
    }
    return '현재 소유·캐릭터 자격 또는 다른 변경을 확인해 주세요. 기존 서버 설정은 유지됩니다.';
  }

  void _applyManagement(CharacterManagementSnapshot snapshot) {
    if (_disposed || managementGateway?.current != true) return;
    _management = snapshot;
    _orderChanged = false;
    _explicitRepresentative = false;
    _account = snapshot.account;
    _allAccounts = [snapshot.account];
    _roster = _sortedRoster(
      snapshot.account.characters,
      snapshot.account.representativeCharacterId,
    );
    _rememberedOrder = {
      for (final c in _roster)
        if (c.displayOrder != null) c.id: c.displayOrder!,
    };
    _draftSelectedIds = {...snapshot.selectedIds};
    _draftOrderedIds = [
      for (final c in _roster)
        if (_draftSelectedIds.contains(c.id)) c.id,
    ];
    _draftRepresentativeId = snapshot.account.representativeCharacterId;
    _clampDisplayLimit(initial: snapshot.account.displayLimit);
    _baseline = _snapshot();
    // Initial proposal only: never write from GET or replace an existing rep.
    if (snapshot.initialSelectionRequired) {
      _draftSelectedIds = {
        for (final c in _roster)
          if (snapshot.usableIds.contains(c.id) &&
              const CharacterUsageLevelPolicy().isInUsageRange(c.itemLevel))
            c.id,
      };
      _draftOrderedIds = [
        for (final c in _roster)
          if (_draftSelectedIds.contains(c.id)) c.id,
      ];
      _clampDisplayLimit();
    }
    _seedInitialRepresentative();
  }

  LocalAccountCharacter? _highestUsable(Set<int> ids) {
    final candidates =
        _roster
            .where(
              (c) =>
                  ids.contains(c.id) && _management!.usableIds.contains(c.id),
            )
            .toList()
          ..sort((a, b) {
            final level = b.itemLevel!.compareTo(a.itemLevel!);
            return level != 0
                ? level
                : a.serverCharacterId!.compareTo(b.serverCharacterId!);
          });
    return candidates.firstOrNull;
  }

  void _seedInitialRepresentative() {
    if (!isMemberManagement ||
        _explicitRepresentative ||
        _account?.representativeCharacterId != null) {
      return;
    }
    _draftRepresentativeId = _highestUsable(_draftSelectedIds)?.id;
  }

  Future<void> _loadNiceGroupSetting() async {
    final repository = _niceGroupSettingsRepository;
    if (repository == null || _playerId.isEmpty) {
      _draftNiceGroupAutoRefreshEnabled = false;
      return;
    }
    _draftNiceGroupAutoRefreshEnabled = await repository.loadEnabled(
      playerId: _playerId,
    );
  }

  Future<void> _loadActivity() async {
    final repository = _activityCharactersRepository;
    if (repository == null || _playerId.isEmpty) {
      _loadedActivityIds = {};
      return;
    }
    try {
      final loaded = await repository.load(playerId: _playerId);
      _loadedActivityIds = loaded.characterIds;
    } on ActivityCharactersSaveException catch (error) {
      _message = error.message;
      _loadedActivityIds = {};
    } on Object catch (error, stackTrace) {
      debugPrint(
        'CharacterManagementViewModel.loadActivity failed: $error\n$stackTrace',
      );
      _message = '활동 캐릭터 설정을 불러오지 못했습니다.';
      _loadedActivityIds = {};
    }
  }

  void _resetDraftFromLoaded() {
    final account = _account;
    if (account == null) {
      _draftSelectedIds = {};
      _draftOrderedIds = [];
      _draftRepresentativeId = null;
      _draftDisplayLimit = 1;
      _baseline = _snapshot();
      return;
    }

    _draftRepresentativeId = account.representativeCharacterId;
    _rememberedOrder = {
      for (final character in account.characters)
        if (character.displayOrder != null)
          character.id: character.displayOrder!,
    };

    final currentServerIds = {
      for (final character in account.characters) ?character.serverCharacterId,
    };
    final savedForAccount = _loadedActivityIds.intersection(currentServerIds);
    final selected = <LocalAccountCharacter>[];
    if (savedForAccount.isEmpty) {
      for (final character in _roster) {
        if (character.serverCharacterId == null) continue;
        final isRepresentative =
            character.id == account.representativeCharacterId;
        if (isRepresentative || character.isVisible) {
          selected.add(character);
        }
      }
    } else {
      for (final character in _roster) {
        final serverId = character.serverCharacterId;
        if (serverId != null && savedForAccount.contains(serverId)) {
          selected.add(character);
        }
      }
    }

    final representative = _characterById(account.representativeCharacterId);
    if (representative != null &&
        representative.serverCharacterId != null &&
        !selected.any((character) => character.id == representative.id)) {
      selected.insert(0, representative);
    }

    _draftSelectedIds = {for (final character in selected) character.id};
    _draftOrderedIds = [for (final character in selected) character.id];
    _clampDisplayLimit(initial: account.displayLimit);
    _baseline = _snapshot();
  }

  Set<String> _ownedServerCharacterIds() {
    return {
      for (final account in _allAccounts)
        for (final character in account.characters)
          ?character.serverCharacterId,
    };
  }

  List<int> _fullDisplayOrderIdsForSave(LocalGameAccount account) {
    final selected = [
      for (final id in _draftOrderedIds)
        if (account.characters.any((character) => character.id == id)) id,
    ];
    final selectedSet = selected.toSet();
    return [
      ...selected,
      for (final character in _roster)
        if (!selectedSet.contains(character.id)) character.id,
    ];
  }

  Set<String> _activityCharacterIdsForSave() {
    final activityIds = <String>{};
    for (final character in selectedCharacters) {
      final serverId = character.serverCharacterId;
      if (serverId != null) {
        activityIds.add(serverId);
      }
    }

    final currentAccount = _account;
    for (final account in _allAccounts) {
      if (currentAccount != null && account.id == currentAccount.id) {
        continue;
      }
      final accountServerIds = {
        for (final character in account.characters)
          ?character.serverCharacterId,
      };
      final preserved = _loadedActivityIds.intersection(accountServerIds);
      if (preserved.isNotEmpty) {
        activityIds.addAll(preserved);
        continue;
      }
      final representative = account.characters
          .where(
            (character) => character.id == account.representativeCharacterId,
          )
          .firstOrNull;
      final representativeServerId = representative?.serverCharacterId;
      if (representativeServerId != null) {
        activityIds.add(representativeServerId);
      }
    }
    return activityIds;
  }

  List<String> _orderedActivityCharacterIdsForSave(Set<String> activityIds) {
    final ordered = <String>[];
    final seen = <String>{};
    void addServerId(String? serverId) {
      if (serverId == null ||
          seen.contains(serverId) ||
          !activityIds.contains(serverId)) {
        return;
      }
      seen.add(serverId);
      ordered.add(serverId);
    }

    for (final character in selectedCharacters) {
      addServerId(character.serverCharacterId);
    }

    final currentAccount = _account;
    final otherCharacters = [
      for (final account in _allAccounts)
        if (currentAccount == null || account.id != currentAccount.id)
          ...List<LocalAccountCharacter>.of(account.characters)
            ..sort((left, right) {
              final leftOrder = left.displayOrder ?? 1 << 30;
              final rightOrder = right.displayOrder ?? 1 << 30;
              final byOrder = leftOrder.compareTo(rightOrder);
              if (byOrder != 0) return byOrder;
              return left.characterName.compareTo(right.characterName);
            }),
    ];
    for (final character in otherCharacters) {
      addServerId(character.serverCharacterId);
    }

    for (final characterId in (activityIds.toList()..sort())) {
      addServerId(characterId);
    }
    return ordered;
  }

  List<int> _insertRestoredOrder(int characterId) {
    final restored = _rememberedOrder[characterId];
    final next = List<int>.of(_draftOrderedIds);
    if (restored == null) {
      next.add(characterId);
      return next;
    }
    var insertAt = next.length;
    for (var index = 0; index < next.length; index++) {
      final otherOrder = _rememberedOrder[next[index]];
      if (otherOrder != null && otherOrder > restored) {
        insertAt = index;
        break;
      }
    }
    next.insert(insertAt, characterId);
    return next;
  }

  void _clampDisplayLimit({int? initial}) {
    final maxLimit = math.max(1, _draftSelectedIds.length);
    final current = initial ?? _draftDisplayLimit;
    _draftDisplayLimit = current.clamp(1, maxLimit);
  }

  _DraftSnapshot _snapshot() {
    return _DraftSnapshot(
      selectedIds: {..._draftSelectedIds},
      orderedIds: List<int>.of(_draftOrderedIds),
      representativeId: _draftRepresentativeId,
      displayLimit: _draftDisplayLimit,
      niceGroupAutoRefreshEnabled: _draftNiceGroupAutoRefreshEnabled,
    );
  }

  LocalAccountCharacter? _characterById(int? characterId) {
    if (characterId == null) return null;
    return _roster
        .where((character) => character.id == characterId)
        .firstOrNull;
  }

  bool get _requiresServerRepresentativeSync {
    final account = _account;
    return _representativeSyncGateway != null &&
        account != null &&
        account.hasActiveOwnership &&
        account.serverGameAccountId != null;
  }

  Future<void> _synchronizeRepresentative() async {
    if (!_requiresServerRepresentativeSync) return;
    final account = _account!;
    final gameAccountId = account.serverGameAccountId!;
    try {
      var state = await _representativeSyncGateway!.loadState(
        gameAccountId: gameAccountId,
      );
      _representativeSyncLoaded = true;
      _representativeSyncState = state;

      final serverRepresentativeId = state.representativeCharacterId;
      if (serverRepresentativeId != null) {
        final localCharacter = account.characters
            .where(
              (character) =>
                  character.serverCharacterId == serverRepresentativeId,
            )
            .firstOrNull;
        if (localCharacter != null &&
            account.representativeCharacterId != localCharacter.id) {
          await _accountRepository.setRepresentativeCharacter(
            accountId: account.id,
            characterId: localCharacter.id,
          );
          await _reloadAccounts();
        }
        await _markReconciled(account.id, serverRepresentativeId);
        _startCooldownTimer();
        return;
      }

      final localRepresentative = account.characters
          .where(
            (character) => character.id == account.representativeCharacterId,
          )
          .firstOrNull;
      final serverCharacterId = localRepresentative?.serverCharacterId;
      if (serverCharacterId == null) return;
      state = await _representativeSyncGateway.seedRepresentative(
        gameAccountId: gameAccountId,
        characterId: serverCharacterId,
      );
      _representativeSyncState = state;
      await _markReconciled(account.id, serverCharacterId);
      _startCooldownTimer();
    } on RepresentativeCharacterSyncException catch (error) {
      _message = error.message;
    } on Object {
      _message = '대표 캐릭터 서버 상태를 확인하지 못했습니다.';
    }
  }

  Future<void> _syncRepresentativeChange(
    LocalGameAccount account,
    LocalAccountCharacter character,
  ) async {
    if (!_requiresServerRepresentativeSync) return;
    if (!_representativeSyncLoaded) {
      throw const RepresentativeCharacterSyncException(
        '대표 캐릭터 서버 상태를 먼저 확인해야 합니다.',
      );
    }
    if (representativeCooldownRemaining > Duration.zero) {
      throw const RepresentativeCharacterSyncException(
        '대표 캐릭터는 계정별로 5분에 한 번만 변경할 수 있습니다.',
      );
    }
    final serverCharacterId = character.serverCharacterId;
    if (serverCharacterId == null) {
      throw const RepresentativeCharacterSyncException(
        '서버에 동기화된 캐릭터만 대표로 지정할 수 있습니다.',
      );
    }
    _representativeSyncState = await _representativeSyncGateway!
        .setRepresentative(
          gameAccountId: account.serverGameAccountId!,
          characterId: serverCharacterId,
        );
    await _markReconciled(account.id, serverCharacterId);
    _startCooldownTimer();
  }

  Future<void> _markReconciled(int accountId, String serverCharacterId) {
    return _accountRepository.markRepresentativeReconciled(
      accountId: accountId,
      serverCharacterId: serverCharacterId,
    );
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    if (representativeCooldownRemaining <= Duration.zero) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (representativeCooldownRemaining <= Duration.zero) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    managementGateway?.removeListener(_managementChanged);
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

class _DraftSnapshot {
  const _DraftSnapshot({
    required this.selectedIds,
    required this.orderedIds,
    required this.representativeId,
    required this.displayLimit,
    required this.niceGroupAutoRefreshEnabled,
  });

  final Set<int> selectedIds;
  final List<int> orderedIds;
  final int? representativeId;
  final int displayLimit;
  final bool niceGroupAutoRefreshEnabled;
}

bool _setEquals<T>(Set<T> left, Set<T> right) {
  return left.length == right.length && left.containsAll(right);
}

List<LocalAccountCharacter> _sortedRoster(
  List<LocalAccountCharacter> characters,
  int? representativeCharacterId,
) {
  return List<LocalAccountCharacter>.of(characters)..sort((left, right) {
    final leftIsRepresentative = left.id == representativeCharacterId;
    final rightIsRepresentative = right.id == representativeCharacterId;
    if (leftIsRepresentative != rightIsRepresentative) {
      return leftIsRepresentative ? -1 : 1;
    }

    final leftOrder = left.displayOrder;
    final rightOrder = right.displayOrder;
    if (leftOrder != null && rightOrder != null) {
      return leftOrder.compareTo(rightOrder);
    }
    if (leftOrder != null) {
      return -1;
    }
    if (rightOrder != null) {
      return 1;
    }
    return (right.itemLevel ?? -1).compareTo(left.itemLevel ?? -1);
  });
}
