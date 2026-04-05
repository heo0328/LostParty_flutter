class RaidVariation {
  final String raidId;
  final String raidBaseId;
  final String difficultyType;
  final String difficultyLabel;
  final int minItemLevel;
  final int rewardGold;

  const RaidVariation({
    required this.raidId,
    required this.raidBaseId,
    required this.difficultyType,
    required this.difficultyLabel,
    required this.minItemLevel,
    required this.rewardGold,
  });
}