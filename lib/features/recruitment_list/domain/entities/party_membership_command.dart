class PartyChangeCharacterCommand {
  const PartyChangeCharacterCommand({required this.recruitmentId, required this.newCharacterId, required this.expectedRecruitmentRevision, this.combatPower});
  final String recruitmentId;
  final String newCharacterId;
  final int expectedRecruitmentRevision;
  final double? combatPower;
}

class PartyRemoveMemberCommand {
  const PartyRemoveMemberCommand({required this.recruitmentId, required this.targetPlayerId, required this.expectedRecruitmentRevision});
  final String recruitmentId;
  final String targetPlayerId;
  final int expectedRecruitmentRevision;
}

class PartySetApprovalPermissionCommand {
  const PartySetApprovalPermissionCommand({required this.recruitmentId, required this.targetPlayerId, required this.enabled, required this.expectedRecruitmentRevision});
  final String recruitmentId;
  final String targetPlayerId;
  final bool enabled;
  final int expectedRecruitmentRevision;
}

enum PartyMembershipFailure { unauthenticated, playerBindingMissing, notFound, unauthorized, ownershipLost, invalidCharacter, recruitmentClosed, alreadyCurrentCharacter, participationConflict, roleMismatch, invalidComposition, revisionConflict, unsupportedOnSpark, permissionDenied, temporarilyUnavailable, invalidRequest, unknown }

class PartyMembershipResult {
  const PartyMembershipResult.success() : failure = null;
  const PartyMembershipResult.failure(this.failure);
  final PartyMembershipFailure? failure;
  bool get isSuccess => failure == null;
}
