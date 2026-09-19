import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/character_summary_sync_result.dart';
import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/weekly_raid_claim.dart';
import '../../domain/entities/weekly_raid_claim_command.dart';
import '../../domain/entities/weekly_raid_status_projection.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/character_weekly_raid_display_repository.dart';
import '../../domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../../domain/repositories/weekly_raid_status_repository.dart';
import '../../domain/services/character_summary_sync_service.dart';
import '../../domain/services/representative_character_sync_service.dart';
import '../../domain/services/weekly_raid_display_projector.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../models/weekly_raid_status_item.dart';

class MyAccountViewModel extends ChangeNotifier {
  MyAccountViewModel({
    required ApiTokenStore apiTokenStore,
    required AccountRepository accountRepository,
    CharacterSummarySyncService? summarySyncService,
    RepresentativeCharacterSyncService? representativeSyncService,
    WeeklyRaidClaimRepository? weeklyRaidClaimRepository,
    WeeklyRaidStatusRepository? weeklyRaidStatusRepository,
    RaidCatalogRepository? raidCatalogRepository,
    CharacterWeeklyRaidDisplayRepository? weeklyRaidDisplayRepository,
    String? playerId,
    String? cycleKey,
    DateTime? cycleStartedAt,
    DateTime? cycleEndsAt,
    WeeklyRaidClaimCommandRepository? weeklyRaidClaimCommandRepository,
  }) : _apiTokenStore = apiTokenStore,
       _accountRepository = accountRepository,
       _summarySyncService = summarySyncService,
       _representativeSyncService = representativeSyncService,
       _weeklyRaidClaimRepository = weeklyRaidClaimRepository,
       _weeklyRaidStatusRepository = weeklyRaidStatusRepository,
       _raidCatalogRepository = raidCatalogRepository,
       _weeklyRaidDisplayRepository = weeklyRaidDisplayRepository,
       _playerId = playerId,
       _cycleKey = cycleKey,
       _cycleStartedAt = cycleStartedAt,
       _cycleEndsAt = cycleEndsAt,
       _weeklyRaidClaimCommandRepository = weeklyRaidClaimCommandRepository;

  final ApiTokenStore _apiTokenStore;
  final AccountRepository _accountRepository;
  final CharacterSummarySyncService? _summarySyncService;
  final RepresentativeCharacterSyncService? _representativeSyncService;
  final WeeklyRaidClaimRepository? _weeklyRaidClaimRepository;
  final WeeklyRaidStatusRepository? _weeklyRaidStatusRepository;
  final RaidCatalogRepository? _raidCatalogRepository;
  final CharacterWeeklyRaidDisplayRepository? _weeklyRaidDisplayRepository;
  final String? _playerId;
  final String? _cycleKey;
  final DateTime? _cycleStartedAt;
  final DateTime? _cycleEndsAt;
  final WeeklyRaidClaimCommandRepository? _weeklyRaidClaimCommandRepository;
  StreamSubscription<List<WeeklyRaidClaim>>? _claimSubscription;
  StreamSubscription<List<WeeklyRaidStatusProjection>>? _statusSubscription;

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
  List<WeeklyRaidStatusProjection> _weeklyRaidStatuses = const [];
  WeeklyRaidClaimReadFailureType? _claimReadFailure;
  final Set<String> _busyClaimKeys = <String>{};
  Map<int, CharacterWeeklyRaidDisplayPreference> _weeklyRaidDisplayPreferences =
      const {};
  Map<int, double?> _preferredCombatPowers = const {};
  Map<int, GemValidationSummary> _preferredGemValidationSummaries = const {};

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

  double? representativeCombatPowerFor(LocalAccountCharacter character) {
    if (character.preferredRole == null) return character.combatPower;
    return _preferredCombatPowers.containsKey(character.id)
        ? _preferredCombatPowers[character.id]
        : null;
  }

  GemValidationSummary? gemValidationSummaryFor(
    LocalAccountCharacter character,
  ) => _preferredGemValidationSummaries[character.id];

  LostArkApiErrorType? get errorType => _errorType;
  WeeklyRaidClaimReadFailureType? get claimReadFailure => _claimReadFailure;
  bool get canEditWeeklyRaidDisplay => _weeklyRaidDisplayRepository != null;

  CharacterWeeklyRaidDisplayPreference? weeklyRaidDisplayPreferenceFor(
    LocalAccountCharacter character,
  ) => _weeklyRaidDisplayPreferences[character.id];

  List<WeeklyRaidDisplayCandidate> eligibleWeeklyRaidsFor(
    LocalAccountCharacter character,
  ) {
    final catalog = _raidCatalog;
    final itemLevel = character.itemLevel;
    if (catalog == null || itemLevel == null) return const [];
    return WeeklyRaidDisplayProjector.eligibleCandidates(
      catalog: catalog,
      itemLevel: itemLevel,
    );
  }

  List<WeeklyRaidStatusItem> weeklyRaidStatusesFor(
    LocalAccountCharacter character,
  ) {
    final catalog = _raidCatalog;
    final serverCharacterId = character.serverCharacterId;
    final itemLevel = character.itemLevel;
    if (catalog == null || serverCharacterId == null || itemLevel == null) {
      return const [];
    }
    final statusByRaidId = {
      for (final status in _weeklyRaidStatuses)
        if (status.characterId == serverCharacterId) status.raidId: status,
    };
    final completedRaidIds = _weeklyRaidStatusRepository != null
        ? statusByRaidId.values
              .where((status) => status.isCompleted)
              .map((status) => status.raidId)
              .toSet()
        : _weeklyRaidClaims
              .where((claim) => claim.characterId == serverCharacterId)
              .map((claim) => claim.raidId)
              .toSet();
    final resolved = WeeklyRaidDisplayProjector.resolve(
      eligible: WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: itemLevel,
      ),
      preference: _weeklyRaidDisplayPreferences[character.id],
    );
    return resolved
        .map(
          (entry) => WeeklyRaidStatusItem(
            raidId: entry.raidId,
            difficultyId: entry.difficultyId,
            label: entry.label,
            isCompleted: completedRaidIds.contains(entry.raidId),
            statusKind: statusByRaidId[entry.raidId]?.kind,
            hasActiveEvidence:
                statusByRaidId[entry.raidId]?.hasActiveEvidence ?? false,
            hasCompletedEvidence:
                statusByRaidId[entry.raidId]?.hasCompletedEvidence ?? false,
          ),
        )
        .toList(growable: false);
  }

  int weeklyRaidResolvedCount(LocalAccountCharacter character) {
    return weeklyRaidStatusesFor(character).length;
  }

  bool hasWeeklyRaidDisplayConfigured(LocalAccountCharacter character) =>
      _weeklyRaidDisplayPreferences.containsKey(character.id);

  Future<bool> saveWeeklyRaidDisplayPreference({
    required LocalAccountCharacter character,
    required int displayCount,
    required List<String> raidIds,
  }) async {
    final repository = _weeklyRaidDisplayRepository;
    if (repository == null) return false;
    final preference = CharacterWeeklyRaidDisplayPreference(
      characterId: character.id,
      displayCount: displayCount,
      raidIds: raidIds,
    );
    if (!preference.isValid) return false;
    final eligibleIds = eligibleWeeklyRaidsFor(
      character,
    ).map((candidate) => candidate.raidId).toSet();
    if (!raidIds.every(eligibleIds.contains)) return false;
    await repository.save(preference);
    _weeklyRaidDisplayPreferences = {
      ..._weeklyRaidDisplayPreferences,
      character.id: preference,
    };
    notifyListeners();
    return true;
  }

  Future<bool> clearWeeklyRaidDisplayPreference(
    LocalAccountCharacter character,
  ) async {
    final repository = _weeklyRaidDisplayRepository;
    if (repository == null) return false;
    await repository.clear(character.id);
    final next = Map<int, CharacterWeeklyRaidDisplayPreference>.from(
      _weeklyRaidDisplayPreferences,
    )..remove(character.id);
    _weeklyRaidDisplayPreferences = next;
    notifyListeners();
    return true;
  }

  /// 원정대 전원에 동일 표시 개수를 적용한다. 입장 불가 레이드는 캐릭터별로 자동 축소한다.
  Future<bool> applyRosterWeeklyRaidDisplayCount({
    required LocalGameAccount account,
    required int displayCount,
  }) async {
    final repository = _weeklyRaidDisplayRepository;
    if (repository == null) return false;
    if (displayCount < 0 ||
        displayCount > WeeklyRaidDisplayProjector.maxDisplayCount) {
      return false;
    }
    final next = Map<int, CharacterWeeklyRaidDisplayPreference>.from(
      _weeklyRaidDisplayPreferences,
    );
    for (final character in account.characters) {
      if (character.isRosterMissing) continue;
      final eligible = eligibleWeeklyRaidsFor(character);
      final selected = WeeklyRaidDisplayProjector.selectionForCount(
        eligible: eligible,
        requestedCount: displayCount,
      );
      final preference = CharacterWeeklyRaidDisplayPreference(
        characterId: character.id,
        displayCount: selected.length,
        raidIds: selected.map((candidate) => candidate.raidId).toList(),
      );
      if (!preference.isValid) return false;
      await repository.save(preference);
      next[character.id] = preference;
    }
    _weeklyRaidDisplayPreferences = next;
    notifyListeners();
    return true;
  }

  bool isClaimCommandBusy(LocalAccountCharacter character, String raidId) {
    final serverId = character.serverCharacterId;
    return serverId != null && _busyClaimKeys.contains('$serverId:$raidId');
  }

  Future<WeeklyRaidClaimCommandResult> setWeeklyRaidCompleted({
    required LocalAccountCharacter character,
    required WeeklyRaidStatusItem raid,
    required bool completed,
    bool resolveConflicts = false,
  }) async {
    final repository = _weeklyRaidClaimCommandRepository;
    final playerId = _playerId;
    final cycleKey = _cycleKey;
    final characterId = character.serverCharacterId;
    final cycleStartedAt = _cycleStartedAt;
    final cycleEndsAt = _cycleEndsAt;
    if (repository == null ||
        playerId == null ||
        cycleKey == null ||
        characterId == null ||
        cycleStartedAt == null ||
        cycleEndsAt == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    final key = '$characterId:${raid.raidId}';
    if (!_busyClaimKeys.add(key)) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
      );
    }
    notifyListeners();
    try {
      if (completed) {
        return await repository.createManualClaim(
          CreateManualWeeklyRaidClaimCommand(
            playerId: playerId,
            characterId: characterId,
            raidId: raid.raidId,
            difficultyId: raid.difficultyId,
            cycleKey: cycleKey,
            cycleStartedAt: cycleStartedAt,
            cycleEndsAt: cycleEndsAt,
          ),
          resolveConflicts: resolveConflicts,
        );
      }
      return await repository.deleteManualClaim(
        DeleteManualWeeklyRaidClaimCommand(
          playerId: playerId,
          characterId: characterId,
          raidId: raid.raidId,
          cycleKey: cycleKey,
        ),
      );
    } finally {
      _busyClaimKeys.remove(key);
      notifyListeners();
    }
  }

  Future<WeeklyRaidClaimImpactResult> inspectWeeklyRaidCompletionImpact({
    required LocalAccountCharacter character,
    required WeeklyRaidStatusItem raid,
  }) async {
    final repository = _weeklyRaidClaimCommandRepository;
    final playerId = _playerId;
    final cycleKey = _cycleKey;
    final characterId = character.serverCharacterId;
    final cycleStartedAt = _cycleStartedAt;
    final cycleEndsAt = _cycleEndsAt;
    if (repository == null ||
        playerId == null ||
        cycleKey == null ||
        characterId == null ||
        cycleStartedAt == null ||
        cycleEndsAt == null) {
      return const WeeklyRaidClaimImpactResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    return repository.inspectManualClaimImpact(
      CreateManualWeeklyRaidClaimCommand(
        playerId: playerId,
        characterId: characterId,
        raidId: raid.raidId,
        difficultyId: raid.difficultyId,
        cycleKey: cycleKey,
        cycleStartedAt: cycleStartedAt,
        cycleEndsAt: cycleEndsAt,
      ),
    );
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
    await _loadWeeklyRaidDisplayPreferences();
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

  Future<void> _loadWeeklyRaidDisplayPreferences() async {
    final repository = _weeklyRaidDisplayRepository;
    if (repository == null) return;
    _weeklyRaidDisplayPreferences = await repository.loadAll();
  }

  void _watchWeeklyRaidClaims() {
    final playerId = _playerId;
    final cycleKey = _cycleKey;
    if (playerId == null || cycleKey == null) return;
    final statusRepository = _weeklyRaidStatusRepository;
    if (statusRepository != null) {
      unawaited(_statusSubscription?.cancel());
      _statusSubscription = statusRepository
          .watchCurrentCycleStatuses(playerId: playerId, cycleKey: cycleKey)
          .listen(
            (statuses) {
              _weeklyRaidStatuses = statuses;
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
      return;
    }
    final repository = _weeklyRaidClaimRepository;
    if (repository == null) return;
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
    unawaited(_statusSubscription?.cancel());
    super.dispose();
  }

  Future<void> loadStoredAccount() async {
    _accounts = await _accountRepository.loadAccounts();
    await _representativeSyncService?.synchronizeAccounts(_accounts);
    if (_representativeSyncService != null) {
      _accounts = await _accountRepository.loadAccounts();
    }
    await _loadPreferredCombatPowers();
    notifyListeners();
  }

  Future<void> _loadPreferredCombatPowers() async {
    final values = <int, double?>{};
    final gemSummaries = <int, GemValidationSummary>{};
    for (final account in _accounts) {
      for (final character in account.characters) {
        final preferredRole = character.preferredRole;
        if (preferredRole == null) continue;
        final snapshots = await _accountRepository.loadCharacterBuildSnapshots(
          character.id,
        );
        final preferredSnapshots =
            snapshots
                .where((snapshot) => snapshot.role == preferredRole)
                .toList()
              ..sort(
                (left, right) => right.capturedAt.compareTo(left.capturedAt),
              );
        final preferredWithCombatPower = preferredSnapshots
            .where(
              (snapshot) =>
                  snapshot.combatPower != null &&
                  snapshot.combatPower!.isFinite &&
                  snapshot.combatPower! >= 0,
            )
            .toList(growable: false);
        values[character.id] = preferredWithCombatPower.isEmpty
            ? null
            : preferredWithCombatPower.first.combatPower;
        if (preferredSnapshots.isNotEmpty) {
          gemSummaries[character.id] =
              preferredSnapshots.first.analysis.gemValidationSummary;
        }
      }
    }
    _preferredCombatPowers = Map.unmodifiable(values);
    _preferredGemValidationSummaries = Map.unmodifiable(gemSummaries);
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
