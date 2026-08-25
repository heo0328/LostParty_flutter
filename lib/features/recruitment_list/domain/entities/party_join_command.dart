import 'party_recruitment.dart';

class PartyDirectJoinCommand {
  const PartyDirectJoinCommand({
    required this.recruitmentId,
    required this.characterId,
    required this.role,
    required this.cycleKey,
    required this.expectedRecruitmentRevision,
    this.combatPower,
  });

  final String recruitmentId;
  final String characterId;
  final PartyRole role;
  final String cycleKey;
  final int expectedRecruitmentRevision;
  final double? combatPower;
}

class PartyDecideApplicationCommand {
  const PartyDecideApplicationCommand({
    required this.recruitmentId,
    required this.applicantPlayerId,
    required this.expectedApplicationRevision,
    required this.expectedRecruitmentRevision,
  });

  final String recruitmentId;
  final String applicantPlayerId;
  final int expectedApplicationRevision;
  final int expectedRecruitmentRevision;
}

enum PartyJoinFailure {
  unauthenticated,
  playerBindingMissing,
  notFound,
  unauthorized,
  ownershipLost,
  invalidCharacter,
  recruitmentClosed,
  approvalModeMismatch,
  capacityFull,
  roleCapacityFull,
  duplicateDealerClass,
  alreadyMember,
  applicationNotPending,
  participationConflict,
  revisionConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyJoinResult {
  const PartyJoinResult.success() : failure = null;
  const PartyJoinResult.failure(this.failure);

  final PartyJoinFailure? failure;
  bool get isSuccess => failure == null;
}
