class WeeklyRaidStatusItem {
  const WeeklyRaidStatusItem({
    required this.raidId,
    required this.difficultyId,
    required this.label,
    required this.isCompleted,
  });

  final String raidId;
  final String difficultyId;
  final String label;
  final bool isCompleted;
}
