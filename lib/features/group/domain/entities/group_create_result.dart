enum GroupCreateFailure {
  unauthenticated,
  playerBindingMissing,
  invalidCharacter,
  ownershipLost,
  activeGroupLimitReached,
  invalidRequest,
  permissionDenied,
  temporarilyUnavailable,
  unknown,
}

class GroupCreateResult {
  const GroupCreateResult.success(this.groupId) : failure = null;

  const GroupCreateResult.failure(this.failure) : groupId = null;

  final String? groupId;
  final GroupCreateFailure? failure;

  bool get isSuccess => failure == null;
}
