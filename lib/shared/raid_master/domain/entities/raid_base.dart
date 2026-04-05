class RaidBase {
  final String raidBaseId;
  final String name;
  final int partySize;
  final int gateCount;
  final List<String> difficultyIds;

  const RaidBase({
    required this.raidBaseId,
    required this.name,
    required this.partySize,
    required this.gateCount,
    required this.difficultyIds,
  });
}