import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/activity_characters_repository.dart';
import '../../domain/repositories/representative_character_sync_gateway.dart';

class CharacterManagementViewModel extends ChangeNotifier {
  CharacterManagementViewModel({
    required AccountRepository accountRepository,
    RepresentativeCharacterSyncGateway? representativeSyncGateway,
    ActivityCharactersRepository? activityCharactersRepository,
    String? playerId,
    DateTime Function()? clock,
    this.accountId,
  }) : _accountRepository = accountRepository,
       _representativeSyncGateway = representativeSyncGateway,
       _activityCharactersRepository = activityCharactersRepository,
       _playerId = playerId?.trim() ?? '',
       _clock = clock ?? DateTime.now;

  final AccountRepository _accountRepository;
  final RepresentativeCharacterSyncGateway? _representativeSyncGateway;
  final ActivityCharactersRepository? _activityCharactersRepository;
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
        baseline.displayLimit != _draftDisplayLimit;
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
    await _reloadAccounts();
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
    _clampDisplayLimit();
    notifyListeners();
  }

  void setRepresentative(LocalAccountCharacter character) {
    if (!canSetRepresentative(character)) {
      return;
    }
    _message = null;
    _draftRepresentativeId = character.id;
    notifyListeners();
  }

  void changeDisplayLimit(int change) {
    final maxLimit = math.max(1, _draftSelectedIds.length);
    final nextLimit = (_draftDisplayLimit + change).clamp(1, maxLimit);
    if (nextLimit == _draftDisplayLimit) {
      return;
    }
    _message = null;
    _draftDisplayLimit = nextLimit;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (_isSaving || oldIndex == newIndex) {
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
    for (var index = 0; index < reordered.length; index++) {
      _rememberedOrder[reordered[index]] = index;
    }
    _message = null;
    notifyListeners();
  }

  void discardChanges() {
    final baseline = _baseline;
    if (baseline == null) {
      return;
    }
    _draftSelectedIds = {...baseline.selectedIds};
    _draftOrderedIds = List<int>.of(baseline.orderedIds);
    _draftRepresentativeId = baseline.representativeId;
    _draftDisplayLimit = baseline.displayLimit;
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
        characterIds: _draftOrderedIds,
      );
      await _accountRepository.updateDisplayLimit(
        accountId: account.id,
        displayLimit: _draftDisplayLimit,
      );
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
      _message = '캐릭터 설정을 서버에 반영하지 못했습니다.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAccounts() async {
    _allAccounts = await _accountRepository.loadAccounts();
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
  });

  final Set<int> selectedIds;
  final List<int> orderedIds;
  final int? representativeId;
  final int displayLimit;
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
