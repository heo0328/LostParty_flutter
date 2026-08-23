import 'package:flutter/foundation.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';

class CharacterManagementViewModel extends ChangeNotifier {
  CharacterManagementViewModel({
    required AccountRepository accountRepository,
    this.accountId,
  }) : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;
  final int? accountId;

  bool _isLoading = false;
  bool _isSaving = false;
  LocalGameAccount? _account;
  List<LocalAccountCharacter> _characters = const [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  LocalGameAccount? get account => _account;
  List<LocalAccountCharacter> get characters => _characters;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setRepresentative(LocalAccountCharacter character) async {
    final account = _account;
    if (account == null) {
      return;
    }

    await _save(() async {
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
    notifyListeners();
    try {
      await operation();
      await _reload();
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
