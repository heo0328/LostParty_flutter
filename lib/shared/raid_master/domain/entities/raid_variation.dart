class RaidVariation {
  final String raidId;
  final String raidBaseId;
  final int difficultyOrder;
  final String difficultyLabel;
  final int minItemLevel;
  final int rewardGold;

  const RaidVariation({
    required this.raidId,
    required this.raidBaseId,
    required this.difficultyOrder,
    required this.difficultyLabel,
    required this.minItemLevel,
    required this.rewardGold,
  });
}