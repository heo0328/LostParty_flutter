class RaidResetWeek {
  const RaidResetWeek({required this.key, required this.startedAt});

  final String key;
  final DateTime startedAt;
}

class WeeklyRaidClear {
  const WeeklyRaidClear({
    required this.userId,
    required this.characterId,
    required this.raidId,
    required this.difficultyId,
    required this.resetWeekKey,
    required this.completedAt,
    required this.recruitmentId,
    required this.completedByUserId,
  });

  final String userId;
  final String characterId;
  final String raidId;
  final String difficultyId;
  final String resetWeekKey;
  final DateTime completedAt;
  final String recruitmentId;
  final String completedByUserId;
}
