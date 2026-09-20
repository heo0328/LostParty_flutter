enum PartyApplicationCleanupFailure {
  unauthenticated,
  playerBindingMissing,
  notOrphaned,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyApplicationCleanupResult {
  const PartyApplicationCleanupResult.success() : failure = null;
  const PartyApplicationCleanupResult.failure(this.failure);

  final PartyApplicationCleanupFailure? failure;
  bool get isSuccess => failure == null;
}

abstract class PartyApplicationCleanupRepository {
  Future<PartyApplicationCleanupResult> deleteOrphan({
    required String recruitmentId,
    required String applicantPlayerId,
  });
}
