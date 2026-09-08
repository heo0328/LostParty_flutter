import 'party_recruitment.dart';
import 'party_gem_validation_snapshot.dart';

class PartyApplyCommand {
  const PartyApplyCommand({
    required this.recruitmentId,
    required this.characterId,
    required this.requestedRole,
    required this.cycleKey,
    this.combatPower,
    this.gemValidation,
  });
  final String recruitmentId;
  final String characterId;
  final PartyRole requestedRole;
  final String cycleKey;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
}

class PartyWithdrawApplicationCommand {
  const PartyWithdrawApplicationCommand({
    required this.recruitmentId,
    required this.expectedRevision,
  });
  final String recruitmentId;
  final int expectedRevision;
}

enum PartyApplicationFailure {
  unauthenticated,
  playerBindingMissing,
  notFound,
  ownershipLost,
  invalidCharacter,
  weeklyRaidCompleted,
  recruitmentClosed,
  approvalModeMismatch,
  capacityFull,
  alreadyMember,
  applicationAlreadyExists,
  applicationNotPending,
  revisionConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyApplicationCommandResult {
  const PartyApplicationCommandResult.success() : failure = null;
  const PartyApplicationCommandResult.failure(this.failure);
  final PartyApplicationFailure? failure;
  bool get isSuccess => failure == null;
}
