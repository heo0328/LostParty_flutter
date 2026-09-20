import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import 'party_gem_validation_snapshot.dart';
import 'party_recruitment.dart';
import 'party_raid_state_conflict.dart';

class PartyDirectJoinCommand {
  const PartyDirectJoinCommand({
    required this.recruitmentId,
    required this.characterId,
    required this.role,
    required this.cycleKey,
    required this.expectedRecruitmentRevision,
    this.combatPower,
    this.gemValidation,
    this.buildIntegrity,
  });

  final String recruitmentId;
  final String characterId;
  final PartyRole role;
  final String cycleKey;
  final int expectedRecruitmentRevision;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
  final BuildIntegritySnapshot? buildIntegrity;
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
  minimumCombatPowerNotMet,
  weeklyRaidCompleted,
  recruitmentClosed,
  approvalModeMismatch,
  capacityFull,
  roleCapacityFull,
  duplicateDealerClass,
  alreadyMember,
  applicationNotPending,
  participationConflict,
  orphanedParticipation,
  stateInconsistent,
  revisionConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyJoinResult {
  const PartyJoinResult.success()
    : failure = null,
      orphanedParticipation = null,
      didRollOverHistoricalState = false;
  const PartyJoinResult.failure(this.failure)
    : orphanedParticipation = null,
      didRollOverHistoricalState = false;
  const PartyJoinResult.orphaned(this.orphanedParticipation)
    : failure = PartyJoinFailure.orphanedParticipation,
      didRollOverHistoricalState = false;
  const PartyJoinResult.historicalStateRolledOver()
    : failure = null,
      orphanedParticipation = null,
      didRollOverHistoricalState = true;

  final PartyJoinFailure? failure;
  final PartyOrphanedRaidParticipation? orphanedParticipation;
  final bool didRollOverHistoricalState;
  bool get isSuccess => failure == null && !didRollOverHistoricalState;
}
