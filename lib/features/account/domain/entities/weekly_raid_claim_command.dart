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
