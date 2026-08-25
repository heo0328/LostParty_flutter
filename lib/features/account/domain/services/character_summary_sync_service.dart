import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../entities/character_summary.dart';
import '../entities/character_summary_sync_result.dart';
import '../entities/local_game_account.dart';
import '../repositories/account_repository.dart';
import '../repositories/character_summary_sync_gateway.dart';

typedef CharacterSummaryFetcher =
    Future<List<CharacterSummary>> Function(String characterName);

class CharacterSummarySyncService {
  CharacterSummarySyncService({
    required AccountRepository accountRepository,
    required CharacterSummaryFetcher fetchSummaries,
    required CharacterSummarySyncGateway? syncGateway,
    DateTime Function()? clock,
    this.autoSyncInterval = const Duration(minutes: 1),
  }) : _accountRepository = accountRepository,
       _fetchSummaries = fetchSummaries,
       _syncGateway = syncGateway,
       _clock = clock ?? DateTime.now;

  final AccountRepository _accountRepository;
  final CharacterSummaryFetcher _fetchSummaries;
  final CharacterSummarySyncGateway? _syncGateway;
  final DateTime Function() _clock;
  final Duration autoSyncInterval;

  Future<CharacterSummarySyncReport> syncAccounts({
    required bool force,
    String? preferredMainLookupName,
  }) async {
    final accounts = await _accountRepository.loadAccounts();
    if (accounts.isEmpty) {
      return const CharacterSummarySyncReport(results: []);
    }

    final results = <CharacterSummarySyncResult>[];
    for (final account in accounts) {
      final lookupName = account.isMain &&
              preferredMainLookupName != null &&
              preferredMainLookupName.trim().isNotEmpty
          ? preferredMainLookupName.trim()
          : account.lookupCharacterName.trim();
      if (lookupName.isEmpty) continue;
      results.add(
        await _syncAccount(
          account: account,
          lookupName: lookupName,
          force: force,
        ),
      );
    }
    return CharacterSummarySyncReport(results: results);
  }

  Future<CharacterSummarySyncResult> _syncAccount({
    required LocalGameAccount account,
    required String lookupName,
    required bool force,
  }) async {
    final now = _clock();
    if (!force && !_shouldAutoSync(account, now)) {
      return const CharacterSummarySyncResult(
        status: CharacterSummarySyncStatus.skippedThrottle,
      );
    }

    final List<CharacterSummary> summaries;
    try {
      summaries = await _fetchSummaries(lookupName);
      if (summaries.isEmpty) {
        return const CharacterSummarySyncResult(
          status: CharacterSummarySyncStatus.apiFailed,
          errorType: LostArkApiErrorType.invalidResponse,
        );
      }
    } on LostArkApiException catch (error) {
      return CharacterSummarySyncResult(
        status: CharacterSummarySyncStatus.apiFailed,
        errorType: error.type,
      );
    }

    final applyResult = await _accountRepository.applyRosterSummarySync(
      accountId: account.id,
      lookupCharacterName: lookupName,
      summaries: summaries,
      fetchedAt: now,
    );

    if (applyResult.serverPatches.isEmpty) {
      return CharacterSummarySyncResult(
        status: applyResult.updatedLocalCount > 0
            ? CharacterSummarySyncStatus.localUpdated
            : CharacterSummarySyncStatus.unchanged,
        updatedLocalCount: applyResult.updatedLocalCount,
      );
    }

    final gateway = _syncGateway;
    if (gateway == null) {
      return CharacterSummarySyncResult(
        status: CharacterSummarySyncStatus.serverSyncFailed,
        updatedLocalCount: applyResult.updatedLocalCount,
        updatedServerCount: 0,
      );
    }

    try {
      await gateway.updateSummaries(applyResult.serverPatches);
      return CharacterSummarySyncResult(
        status: CharacterSummarySyncStatus.localAndServerUpdated,
        updatedLocalCount: applyResult.updatedLocalCount,
        updatedServerCount: applyResult.serverPatches.length,
      );
    } on Object {
      return CharacterSummarySyncResult(
        status: CharacterSummarySyncStatus.serverSyncFailed,
        updatedLocalCount: applyResult.updatedLocalCount,
        updatedServerCount: 0,
      );
    }
  }

  bool _shouldAutoSync(LocalGameAccount account, DateTime now) {
    DateTime? latest;
    for (final character in account.characters) {
      final fetchedAt = character.lastSummaryFetchedAt;
      if (fetchedAt == null) continue;
      if (latest == null || fetchedAt.isAfter(latest)) {
        latest = fetchedAt;
      }
    }
    if (latest == null) return true;
    return now.difference(latest) >= autoSyncInterval;
  }
}
