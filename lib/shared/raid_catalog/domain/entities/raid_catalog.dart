class RaidCatalog {
  const RaidCatalog({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.updatedAt,
    required this.raids,
  });

  final int schemaVersion;
  final String catalogVersion;
  final DateTime updatedAt;
  final List<RaidDefinition> raids;
}

class RaidDefinition {
  const RaidDefinition({
    required this.raidId,
    required this.name,
    required this.partySize,
    required this.gateCount,
    required this.isActive,
    required this.difficulties,
  });

  final String raidId;
  final String name;
  final int partySize;
  final int gateCount;
  final bool isActive;
  final List<RaidDifficultyDefinition> difficulties;
}

class RaidDifficultyDefinition {
  const RaidDifficultyDefinition({
    required this.difficultyId,
    required this.name,
    required this.displayOrder,
    required this.minItemLevel,
    required this.rewardGold,
    required this.isActive,
  });

  final String difficultyId;
  final String name;
  final int displayOrder;
  final int minItemLevel;
  final int rewardGold;
  final bool isActive;
}

class RaidCatalogReference {
  const RaidCatalogReference({
    required this.catalogVersion,
    required this.raidId,
    required this.difficultyId,
    required this.selectedGates,
  });

  final String catalogVersion;
  final String raidId;
  final String difficultyId;
  final Set<int> selectedGates;
}
