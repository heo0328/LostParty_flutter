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
    required this.officialName,
    required this.displayName,
    required this.aliases,
    required this.partySize,
    required this.partyCount,
    required this.requiredSupportCount,
    required this.maxDealerCountPerClass,
    required this.gateCount,
    required this.isActive,
    required this.difficulties,
  });

  final String raidId;
  final String officialName;
  final String displayName;
  final List<String> aliases;
  final int partySize;
  final int partyCount;
  final int requiredSupportCount;
  final int maxDealerCountPerClass;
  final int gateCount;
  final bool isActive;
  final List<RaidDifficultyDefinition> difficulties;
}

class RaidDifficultyDefinition {
  const RaidDifficultyDefinition({
    required this.difficultyId,
    required this.name,
    required this.displayAlias,
    required this.displayOrder,
    required this.minItemLevel,
    required this.clearGold,
    required this.boundGold,
    required this.isActive,
  });

  final String difficultyId;
  final String name;
  final String displayAlias;
  final int displayOrder;
  final int minItemLevel;
  final int clearGold;
  final int boundGold;
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
