import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/representative_character_sync_gateway.dart';

class CharacterManagementViewModel extends ChangeNotifier {
  CharacterManagementViewModel({
    required AccountRepository accountRepository,
    RepresentativeCharacterSyncGateway? representativeSyncGateway,
    DateTime Function()? clock,
    this.accountId,
  }) : _accountRepository = accountRepository,
       _representativeSyncGateway = representativeSyncGateway,
       _clock = clock ?? DateTime.now;

  final AccountRepository _accountRepository;
  final RepresentativeCharacterSyncGateway? _representativeSyncGateway;
  final DateTime Function() _clock;
  final int? accountId;

  bool _isLoading = false;
  bool _isSaving = false;
  LocalGameAccount? _account;
  List<LocalAccountCharacter> _characters = const [];
  RepresentativeCharacterSyncState? _representativeSyncState;
  bool _representativeSyncLoaded = false;
  String? _representativeMessage;
  Timer? _cooldownTimer;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  LocalGameAccount? get account => _account;
  List<LocalAccountCharacter> get characters => _characters;
  String? get representativeMessage => _representativeMessage;

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

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _reload();
    await _synchronizeRepresentative();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setRepresentative(LocalAccountCharacter character) async {
    final account = _account;
    if (account == null) {
      return;
    }
    if (account.representativeCharacterId == character.id) return;

    await _save(() async {
      await _syncRepresentativeChange(account, character);
      if (!character.isVisible) {
        await _accountRepository.updateCharacterVisibility(
          accountId: account.id,
          characterId: character.id,
          isVisible: true,
        );
      }
      await _accountRepository.setRepresentativeCharacter(
        accountId: account.id,
        characterId: character.id,
      );
    });
  }

  Future<void> setCharacterVisibility(
    LocalAccountCharacter character,
    bool isVisible,
  ) async {
    final account = _account;
    if (account == null) {
      return;
    }

    final isHidingRepresentative =
        !isVisible && account.representativeCharacterId == character.id;
    if (!isHidingRepresentative) {
      await _save(
        () => _accountRepository.updateCharacterVisibility(
          accountId: account.id,
          characterId: character.id,
          isVisible: isVisible,
        ),
      );
      return;
    }

    final replacement = _highestItemLevelCharacterExcept(character.id);
    if (replacement == null) {
      return;
    }

    await _save(() async {
      await _syncRepresentativeChange(account, replacement);
      await _accountRepository.updateCharacterVisibility(
        accountId: account.id,
        characterId: character.id,
        isVisible: false,
      );
      if (!replacement.isVisible) {
        await _accountRepository.updateCharacterVisibility(
          accountId: account.id,
          characterId: replacement.id,
          isVisible: true,
        );
      }
      await _accountRepository.setRepresentativeCharacter(
        accountId: account.id,
        characterId: replacement.id,
      );
    });
  }

  Future<void> changeDisplayLimit(int change) async {
    final account = _account;
    if (account == null) {
      return;
    }
    final nextLimit = (account.displayLimit + change).clamp(
      1,
      account.characters.length,
    );
    if (nextLimit == account.displayLimit) {
      return;
    }

    await _save(
      () => _accountRepository.updateDisplayLimit(
        accountId: account.id,
        displayLimit: nextLimit,
      ),
    );
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final account = _account;
    if (account == null) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex--;
    }

    final reordered = List<LocalAccountCharacter>.of(_characters);
    final character = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, character);
    _characters = reordered;
    notifyListeners();

    await _save(
      () => _accountRepository.updateCharacterDisplayOrder(
        accountId: account.id,
        characterIds: reordered.map((item) => item.id).toList(growable: false),
      ),
    );
  }

  Future<void> _save(Future<void> Function() operation) async {
    _isSaving = true;
    _representativeMessage = null;
    notifyListeners();
    try {
      await operation();
      await _reload();
    } on RepresentativeCharacterSyncException catch (error) {
      _representativeMessage = error.message;
    } on Object {
      _representativeMessage = '대표 캐릭터 변경을 저장하지 못했습니다.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    if (accountId == null) {
      _account = await _accountRepository.loadMainAccount();
    } else {
      final accounts = await _accountRepository.loadAccounts();
      _account = null;
      for (final account in accounts) {
        if (account.id == accountId) {
          _account = account;
          break;
        }
      }
    }
    final account = _account;
    if (account == null) {
      _characters = const [];
      return;
    }

    _characters = List<LocalAccountCharacter>.of(account.characters)
      ..sort((left, right) {
        final leftIsRepresentative =
            left.id == account.representativeCharacterId;
        final rightIsRepresentative =
            right.id == account.representativeCharacterId;
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

  bool get _requiresServerRepresentativeSync {
    final account = _account;
    return _representativeSyncGateway != null &&
        account != null &&
        account.hasActiveOwnership &&
        account.serverGameAccountId != null;
  }

  bool canSetRepresentative(LocalAccountCharacter character) {
    if (_isSaving || _account?.representativeCharacterId == character.id) {
      return false;
    }
    if (!_requiresServerRepresentativeSync) return true;
    return _representativeSyncLoaded &&
        character.serverCharacterId != null &&
        representativeCooldownRemaining <= Duration.zero;
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
          await _reload();
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
      _representativeMessage = error.message;
    } on Object {
      _representativeMessage = '대표 캐릭터 서버 상태를 확인하지 못했습니다.';
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

  LocalAccountCharacter? _highestItemLevelCharacterExcept(int characterId) {
    final candidates =
        _characters.where((character) => character.id != characterId).toList()
          ..sort((left, right) {
            final itemLevelComparison = (right.itemLevel ?? -1).compareTo(
              left.itemLevel ?? -1,
            );
            if (itemLevelComparison != 0) {
              return itemLevelComparison;
            }
            return left.characterName.compareTo(right.characterName);
          });
    return candidates.firstOrNull;
  }
}
