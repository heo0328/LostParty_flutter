import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import 'party_recruitment.dart';
import 'party_gem_validation_snapshot.dart';
import 'party_raid_state_conflict.dart';

class PartyApplyCommand {
  const PartyApplyCommand({
    required this.recruitmentId,
    required this.characterId,
    required this.requestedRole,
    required this.cycleKey,
    this.combatPower,
    this.gemValidation,
    this.buildIntegrity,
  });
  final String recruitmentId;
  final String characterId;
  final PartyRole requestedRole;
  final String cycleKey;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
  final BuildIntegritySnapshot? buildIntegrity;
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
  participationConflict,
  orphanedParticipation,
  stateInconsistent,
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
  const PartyApplicationCommandResult.success()
    : failure = null,
      orphanedParticipation = null,
      didRollOverHistoricalState = false;
  const PartyApplicationCommandResult.failure(this.failure)
    : orphanedParticipation = null,
      didRollOverHistoricalState = false;
  const PartyApplicationCommandResult.orphaned(this.orphanedParticipation)
    : failure = PartyApplicationFailure.orphanedParticipation,
      didRollOverHistoricalState = false;
  const PartyApplicationCommandResult.historicalStateRolledOver()
    : failure = null,
      orphanedParticipation = null,
      didRollOverHistoricalState = true;
  final PartyApplicationFailure? failure;
  final PartyOrphanedRaidParticipation? orphanedParticipation;
  final bool didRollOverHistoricalState;
  bool get isSuccess => failure == null && !didRollOverHistoricalState;
}
