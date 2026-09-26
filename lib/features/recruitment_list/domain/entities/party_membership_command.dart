import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

import 'party_gem_validation_snapshot.dart';
import 'party_raid_state_conflict.dart';
import 'party_recruitment.dart';

class PartyChangeCharacterCommand {
  const PartyChangeCharacterCommand({
    required this.recruitmentId,
    required this.newCharacterId,
    required this.newRole,
    required this.expectedRecruitmentRevision,
    this.combatPower,
    this.gemValidation,
    this.buildIntegrity,
  });
  final String recruitmentId;
  final String newCharacterId;
  final PartyRole newRole;
  final int expectedRecruitmentRevision;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
  final BuildIntegritySnapshot? buildIntegrity;
}

class PartyRemoveMemberCommand {
  const PartyRemoveMemberCommand({
    required this.recruitmentId,
    required this.targetPlayerId,
    required this.expectedRecruitmentRevision,
  });
  final String recruitmentId;
  final String targetPlayerId;
  final int expectedRecruitmentRevision;
}

class PartySetApprovalPermissionCommand {
  const PartySetApprovalPermissionCommand({
    required this.recruitmentId,
    required this.targetPlayerId,
    required this.enabled,
    required this.expectedRecruitmentRevision,
  });
  final String recruitmentId;
  final String targetPlayerId;
  final bool enabled;
  final int expectedRecruitmentRevision;
}

class PartyRepositionMembersCommand {
  const PartyRepositionMembersCommand({
    required this.recruitmentId,
    required this.sourcePlayerId,
    required this.destinationPartyIndex,
    required this.destinationSlotIndex,
    required this.expectedRecruitmentRevision,
  });

  final String recruitmentId;
  final String sourcePlayerId;
  final int destinationPartyIndex;
  final int destinationSlotIndex;
  final int expectedRecruitmentRevision;
}

enum PartyMembershipFailure {
  unauthenticated,
  playerBindingMissing,
  notFound,
  unauthorized,
  ownershipLost,
  invalidCharacter,
  minimumCombatPowerNotMet,
  weeklyRaidCompleted,
  recruitmentClosed,
  alreadyCurrentCharacter,
  participationConflict,
  orphanedParticipation,
  stateInconsistent,
  roleMismatch,
  invalidComposition,
  revisionConflict,
  unsupportedOnSpark,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyMembershipResult {
  const PartyMembershipResult.success()
    : failure = null,
      orphanedParticipation = null;
  const PartyMembershipResult.failure(this.failure)
    : orphanedParticipation = null;
  const PartyMembershipResult.orphaned(this.orphanedParticipation)
    : failure = PartyMembershipFailure.orphanedParticipation;

  final PartyMembershipFailure? failure;
  final PartyOrphanedRaidParticipation? orphanedParticipation;
  bool get isSuccess => failure == null;
}
