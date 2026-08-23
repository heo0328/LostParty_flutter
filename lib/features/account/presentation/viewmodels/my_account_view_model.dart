import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';

class MyAccountViewModel extends ChangeNotifier {
  MyAccountViewModel({
    required ApiTokenStore apiTokenStore,
    required AccountRepository accountRepository,
  }) : _apiTokenStore = apiTokenStore,
       _accountRepository = accountRepository;

  final ApiTokenStore _apiTokenStore;
  final AccountRepository _accountRepository;

  bool _isLoadingTokenStatus = false;
  bool _isFetchingCharacters = false;
  bool _hasApiToken = false;
  bool _hasFetchedCharacters = false;
  List<CharacterSummary> _characters = const [];
  CharacterProfile? _lookupProfile;
  List<LocalGameAccount> _accounts = const [];
  LostArkApiErrorType? _errorType;

  bool get isLoadingTokenStatus => _isLoadingTokenStatus;
  bool get isFetchingCharacters => _isFetchingCharacters;
  bool get hasApiToken => _hasApiToken;
  bool get hasFetchedCharacters => _hasFetchedCharacters;
  List<CharacterSummary> get characters => _characters;
  CharacterProfile? get lookupProfile => _lookupProfile;
  List<LocalGameAccount> get accounts => _accounts;
  LocalGameAccount? get mainAccount {
    for (final account in _accounts) {
      if (account.isMain) return account;
    }
    return null;
  }

  LostArkApiErrorType? get errorType => _errorType;

  Future<void> loadTokenStatus() async {
    _isLoadingTokenStatus = true;
    notifyListeners();

    _hasApiToken = await _apiTokenStore.read() != null;
    _isLoadingTokenStatus = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    await loadTokenStatus();
    await loadStoredAccount();
  }

  Future<void> loadStoredAccount() async {
    _accounts = await _accountRepository.loadAccounts();
    notifyListeners();
  }

  Future<void> fetchCharacters(String characterName) async {
    _isFetchingCharacters = true;
    _errorType = null;
    notifyListeners();

    try {
      _characters = await _accountRepository.fetchCharacters(characterName);
      _lookupProfile = await _accountRepository.fetchCharacterProfile(
        characterName,
      );
      _accounts = await _accountRepository.loadAccounts();
      _hasFetchedCharacters = true;
    } on LostArkApiException catch (error) {
      _errorType = error.type;
      _hasFetchedCharacters = false;
    } finally {
      _isFetchingCharacters = false;
    }

    notifyListeners();
  }

  Future<void> addAccount({
    required String label,
    required String lookupCharacterName,
  }) async {
    if (_accountRepository is! AccountManagementRepository) {
      throw UnsupportedError('Account management is not available.');
    }
    final repository = _accountRepository as AccountManagementRepository;
    _isFetchingCharacters = true;
    _errorType = null;
    notifyListeners();
    try {
      await repository.addAccount(
        label: label,
        lookupCharacterName: lookupCharacterName,
      );
      _accounts = await _accountRepository.loadAccounts();
    } on LostArkApiException catch (error) {
      _errorType = error.type;
      rethrow;
    } finally {
      _isFetchingCharacters = false;
      notifyListeners();
    }
  }

  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
  }) async {
    if (_accountRepository is! AccountManagementRepository) {
      throw UnsupportedError('Account management is not available.');
    }
    final repository = _accountRepository as AccountManagementRepository;
    await repository.updateAccount(
      accountId: accountId,
      label: label,
      isMain: isMain,
    );
    _accounts = await _accountRepository.loadAccounts();
    notifyListeners();
  }

  Future<void> deleteAccount(int accountId) async {
    if (_accountRepository is! AccountManagementRepository) {
      throw UnsupportedError('Account management is not available.');
    }
    final repository = _accountRepository as AccountManagementRepository;
    await repository.deleteAccount(accountId);
    _accounts = await _accountRepository.loadAccounts();
    notifyListeners();
  }
}
