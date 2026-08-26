enum WeeklyRaidClaimSource { manual, partyMember, partyOwner }

class WeeklyRaidClaim {
  const WeeklyRaidClaim({
    required this.id,
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.difficultyId,
    required this.source,
    required this.completedAt,
    required this.updatedAt,
    required this.cycleStartedAt,
    required this.cycleEndsAt,
    this.sourceRecruitmentId,
    this.sourceCompletionRevision,
  });

  final String id;
  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final String difficultyId;
  final WeeklyRaidClaimSource source;
  final String? sourceRecruitmentId;
  final int? sourceCompletionRevision;
  final DateTime completedAt;
  final DateTime updatedAt;
  final DateTime cycleStartedAt;
  final DateTime cycleEndsAt;
}
