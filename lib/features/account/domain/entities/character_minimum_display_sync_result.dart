enum CharacterMinimumDisplaySyncStatus {
  skippedNoValues,
  skippedUnchanged,
  skippedUnlinked,
  updated,
  failed,
}

class CharacterMinimumDisplaySyncResult {
  const CharacterMinimumDisplaySyncResult({
    required this.status,
    this.message,
  });

  final CharacterMinimumDisplaySyncStatus status;
  final String? message;

  bool get isSuccess =>
      status == CharacterMinimumDisplaySyncStatus.skippedNoValues ||
      status == CharacterMinimumDisplaySyncStatus.skippedUnchanged ||
      status == CharacterMinimumDisplaySyncStatus.skippedUnlinked ||
      status == CharacterMinimumDisplaySyncStatus.updated;

  bool get isFailed => status == CharacterMinimumDisplaySyncStatus.failed;
}
