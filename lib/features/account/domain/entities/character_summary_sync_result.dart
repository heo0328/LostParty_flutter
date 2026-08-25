import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';

enum CharacterSummarySyncStatus {
  skippedThrottle,
  unchanged,
  localUpdated,
  localAndServerUpdated,
  serverSyncFailed,
  apiFailed,
}

class CharacterSummarySyncResult {
  const CharacterSummarySyncResult({
    required this.status,
    this.errorType,
    this.updatedLocalCount = 0,
    this.updatedServerCount = 0,
  });

  final CharacterSummarySyncStatus status;
  final LostArkApiErrorType? errorType;
  final int updatedLocalCount;
  final int updatedServerCount;

  bool get isServerSyncFailed =>
      status == CharacterSummarySyncStatus.serverSyncFailed;

  bool get isApiFailed => status == CharacterSummarySyncStatus.apiFailed;
}

class CharacterSummarySyncReport {
  const CharacterSummarySyncReport({
    required this.results,
    this.busy = false,
  });

  final List<CharacterSummarySyncResult> results;
  final bool busy;

  bool get hasServerSyncFailure =>
      results.any((result) => result.isServerSyncFailed);

  bool get hasApiFailure => results.any((result) => result.isApiFailed);

  LostArkApiErrorType? get firstErrorType {
    for (final result in results) {
      if (result.errorType != null) return result.errorType;
    }
    return null;
  }
}
