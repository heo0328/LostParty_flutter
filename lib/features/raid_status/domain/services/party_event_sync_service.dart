enum PartyEventSyncFailure {
  unauthenticated,
  playerBindingMissing,
  permissionDenied,
  temporarilyUnavailable,
  invalidData,
  unknown,
}

class PartyEventSyncResult {
  const PartyEventSyncResult.success(this.syncedCount) : failure = null;
  const PartyEventSyncResult.failure(this.failure) : syncedCount = 0;

  final int syncedCount;
  final PartyEventSyncFailure? failure;

  bool get isSuccess => failure == null;
}

abstract class PartyEventSyncService {
  Future<PartyEventSyncResult> sync();
}
