import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/character_summary_sync_result.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/weekly_raid_claim.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../../domain/services/character_summary_sync_service.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../models/weekly_raid_status_item.dart';

class MyAccountViewModel extends ChangeNotifier {
  MyAccountViewModel({
    required ApiTokenStore apiTokenStore,
    required AccountRepository accountRepository,
    CharacterSummarySyncService? summarySyncService,
    WeeklyRaidClaimRepository? weeklyRaidClaimRepository,
    RaidCatalogRepository? raidCatalogRepository,
    String? playerId,
    String? cycleKey,
  }) : _apiTokenStore = apiTokenStore,
       _accountRepository = accountRepository,
       _summarySyncService = summarySyncService,
       _weeklyRaidClaimRepository = weeklyRaidClaimRepository,
       _raidCatalogRepository = raidCatalogRepository,
       _playerId = playerId,
       _cycleKey = cycleKey;

  final ApiTokenStore _apiTokenStore;
  final AccountRepository _accountRepository;
  final CharacterSummarySyncService? _summarySyncService;
  final WeeklyRaidClaimRepository? _weeklyRaidClaimRepository;
  final RaidCatalogRepository? _raidCatalogRepository;
  final String? _playerId;
  final String? _cycleKey;
  StreamSubscription<List<WeeklyRaidClaim>>? _claimSubscription;

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
  RaidCatalog? _raidCatalog;
  List<WeeklyRaidClaim> _weeklyRaidClaims = const [];
  WeeklyRaidClaimReadFailureType? _claimReadFailure;

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
  WeeklyRaidClaimReadFailureType? get claimReadFailure => _claimReadFailure;

  List<WeeklyRaidStatusItem> weeklyRaidStatusesFor(
    LocalAccountCharacter character,
  ) {
    final catalog = _raidCatalog;
    final serverCharacterId = character.serverCharacterId;
    final itemLevel = character.itemLevel;
    if (catalog == null || serverCharacterId == null || itemLevel == null) {
      return const [];
    }
    final completedRaidIds = _weeklyRaidClaims
        .where((claim) => claim.characterId == serverCharacterId)
        .map((claim) => claim.raidId)
        .toSet();
    final eligible = <({RaidDefinition raid, int gold})>[];
    for (final raid in catalog.raids.where((raid) => raid.isActive)) {
      final difficulties = raid.difficulties.where(
        (difficulty) =>
            difficulty.isActive && difficulty.minItemLevel <= itemLevel,
      );
      if (difficulties.isEmpty) continue;
      final maxGold = difficulties
          .map((difficulty) => difficulty.clearGold + difficulty.boundGold)
          .reduce((left, right) => left > right ? left : right);
      eligible.add((raid: raid, gold: maxGold));
    }
    eligible.sort((left, right) {
      final gold = right.gold.compareTo(left.gold);
      return gold != 0
          ? gold
          : left.raid.displayName.compareTo(right.raid.displayName);
    });
    return eligible
        .take(3)
        .map(
          (entry) => WeeklyRaidStatusItem(
            raidId: entry.raid.raidId,
            label: entry.raid.displayName,
            isCompleted: completedRaidIds.contains(entry.raid.raidId),
          ),
        )
        .toList(growable: false);
  }

  Future<void> loadTokenStatus() async {
    _isLoadingTokenStatus = true;
    notifyListeners();

    _hasApiToken = await _apiTokenStore.read() != null;
    _isLoadingTokenStatus = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    await loadTokenStatus();
    await _loadRaidCatalog();
    await loadStoredAccount();
    _watchWeeklyRaidClaims();
    if (_hasApiToken && _accounts.isNotEmpty) {
      unawaited(syncRosterSummaries(force: false));
    }
  }

  Future<void> _loadRaidCatalog() async {
    final repository = _raidCatalogRepository;
    if (repository == null) return;
    _raidCatalog = await repository.loadCatalog();
  }

  void _watchWeeklyRaidClaims() {
    final repository = _weeklyRaidClaimRepository;
    final playerId = _playerId;
    final cycleKey = _cycleKey;
    if (repository == null || playerId == null || cycleKey == null) return;
    unawaited(_claimSubscription?.cancel());
    _claimSubscription = repository
        .watchCurrentCycleClaims(playerId: playerId, cycleKey: cycleKey)
        .listen(
          (claims) {
            _weeklyRaidClaims = claims;
            _claimReadFailure = null;
            notifyListeners();
          },
          onError: (Object error) {
            _claimReadFailure = error is WeeklyRaidClaimReadException
                ? error.type
                : WeeklyRaidClaimReadFailureType.unknown;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    unawaited(_claimSubscription?.cancel());
    super.dispose();
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
