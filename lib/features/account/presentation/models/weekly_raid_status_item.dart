class WeeklyRaidStatusItem {
  const WeeklyRaidStatusItem({
    required this.raidId,
    required this.label,
    required this.isCompleted,
  });

  final String raidId;
  final String label;
  final bool isCompleted;
}
