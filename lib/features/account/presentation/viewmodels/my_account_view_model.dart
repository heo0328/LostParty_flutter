import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/character_summary_sync_result.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/services/character_summary_sync_service.dart';

class MyAccountViewModel extends ChangeNotifier {
  MyAccountViewModel({
    required ApiTokenStore apiTokenStore,
    required AccountRepository accountRepository,
    CharacterSummarySyncService? summarySyncService,
  }) : _apiTokenStore = apiTokenStore,
       _accountRepository = accountRepository,
       _summarySyncService = summarySyncService;

  final ApiTokenStore _apiTokenStore;
  final AccountRepository _accountRepository;
  final CharacterSummarySyncService? _summarySyncService;

  bool _isLoadingTokenStatus = false;
  bool _isFetchingCharacters = false;
  bool _isAutoSyncing = false;
  bool _hasApiToken = false;
  bool _hasFetchedCharacters = false;
  bool _serverSyncFailed = false;
  List<CharacterSummary> _characters = const [];
  CharacterProfile? _lookupProfile;
  List<LocalGameAccount> _accounts = const [];
  LostArkApiErrorType? _errorType;

  bool get isLoadingTokenStatus => _isLoadingTokenStatus;
  bool get isFetchingCharacters => _isFetchingCharacters;
  bool get isAutoSyncing => _isAutoSyncing;
  bool get isNetworkBusy => _isFetchingCharacters || _isAutoSyncing;
  bool get hasApiToken => _hasApiToken;
  bool get hasFetchedCharacters => _hasFetchedCharacters;
  bool get serverSyncFailed => _serverSyncFailed;
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
    if (_hasApiToken && _accounts.isNotEmpty) {
      unawaited(syncRosterSummaries(force: false));
    }
  }

  Future<void> loadStoredAccount() async {
    _accounts = await _accountRepository.loadAccounts();
    notifyListeners();
  }

  Future<void> fetchCharacters(String characterName) async {
    if (_isFetchingCharacters || _isAutoSyncing) return;

    _isFetchingCharacters = true;
    _errorType = null;
    _serverSyncFailed = false;
    notifyListeners();

    try {
      if (_accounts.isEmpty || _summarySyncService == null) {
        _characters = await _accountRepository.fetchCharacters(characterName);
      } else {
        final report = await _summarySyncService.syncAccounts(
          force: true,
          preferredMainLookupName: characterName,
        );
        _serverSyncFailed = report.hasServerSyncFailure;
        if (report.hasApiFailure) {
          _errorType = report.firstErrorType;
          _hasFetchedCharacters = false;
          return;
        }
      }
      try {
        _lookupProfile = await _accountRepository.fetchCharacterProfile(
          characterName,
        );
      } on LostArkApiException {
        // Roster sync can succeed even if the optional profile card fails.
      }
      _accounts = await _accountRepository.loadAccounts();
      _hasFetchedCharacters = true;
    } on LostArkApiException catch (error) {
      _errorType = error.type;
      _hasFetchedCharacters = false;
    } finally {
      _isFetchingCharacters = false;
      notifyListeners();
    }
  }

  Future<CharacterSummarySyncReport?> syncRosterSummaries({
    required bool force,
    String? preferredMainLookupName,
  }) async {
    final syncService = _summarySyncService;
    if (syncService == null) return null;
    if (_isFetchingCharacters || _isAutoSyncing) {
      return const CharacterSummarySyncReport(results: [], busy: true);
    }
    if (!_hasApiToken) return null;

    if (force) {
      _isFetchingCharacters = true;
    } else {
      _isAutoSyncing = true;
    }
    _errorType = null;
    if (force) {
      _serverSyncFailed = false;
    }
    notifyListeners();

    try {
      final report = await syncService.syncAccounts(
        force: force,
        preferredMainLookupName: preferredMainLookupName,
      );
      _serverSyncFailed = report.hasServerSyncFailure;
      if (report.hasApiFailure) {
        _errorType = report.firstErrorType;
      } else if (report.results.any(
        (result) => result.status != CharacterSummarySyncStatus.skippedThrottle,
      )) {
        _accounts = await _accountRepository.loadAccounts();
      }
      return report;
    } finally {
      _isFetchingCharacters = false;
      _isAutoSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addAccount({
    required String label,
    required String lookupCharacterName,
  }) async {
    if (_isFetchingCharacters || _isAutoSyncing) return;
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

  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  }) async {
    if (_accountRepository is! AccountManagementRepository) {
      throw UnsupportedError('Account management is not available.');
    }
    await (_accountRepository as AccountManagementRepository)
        .deleteMissingCharacter(accountId: accountId, characterId: characterId);
    _accounts = await _accountRepository.loadAccounts();
    notifyListeners();
  }
}
