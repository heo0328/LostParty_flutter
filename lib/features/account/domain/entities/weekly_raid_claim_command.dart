class CreateManualWeeklyRaidClaimCommand {
  const CreateManualWeeklyRaidClaimCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.difficultyId,
    required this.cycleKey,
    required this.cycleStartedAt,
    required this.cycleEndsAt,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String difficultyId;
  final String cycleKey;
  final DateTime cycleStartedAt;
  final DateTime cycleEndsAt;
}

class ManualWeeklyRaidClaimImpact {
  const ManualWeeklyRaidClaimImpact({
    this.activeRecruitmentId,
    this.activeRecruitmentTitle,
    this.isRecruitmentLeader = false,
    this.willDisbandRecruitment = false,
    this.nextLeaderCharacterName,
    this.pendingApplicationCount = 0,
    this.orphanedRecruitmentId,
    this.orphanedCycleKey,
    this.orphanedStateRevision,
    this.isHistoricalOrphanedParticipation = false,
  });

  final String? activeRecruitmentId;
  final String? activeRecruitmentTitle;
  final bool isRecruitmentLeader;
  final bool willDisbandRecruitment;
  final String? nextLeaderCharacterName;
  final int pendingApplicationCount;
  final String? orphanedRecruitmentId;
  final String? orphanedCycleKey;
  final int? orphanedStateRevision;
  final bool isHistoricalOrphanedParticipation;

  bool get hasActiveRecruitment => activeRecruitmentId != null;
  bool get hasOrphanedParticipation => orphanedRecruitmentId != null;
  bool get requiresConfirmation =>
      hasActiveRecruitment || pendingApplicationCount > 0;
}

class CleanupOrphanRaidParticipationCommand {
  const CleanupOrphanRaidParticipationCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.recruitmentId,
    this.expectedStateRevision,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final String recruitmentId;
  final int? expectedStateRevision;
}

class DeleteManualWeeklyRaidClaimCommand {
  const DeleteManualWeeklyRaidClaimCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
}
