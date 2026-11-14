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
    required List<String> aliases,
    required this.partySize,
    required this.partyCount,
    required this.requiredSupportCount,
    required this.maxDealerCountPerClass,
    required this.gateCount,
    required this.isActive,
    required this.difficulties,
  }) : _aliases = aliases;

  final String raidId;
  final String officialName;
  final String displayName;
  final List<String> _aliases;

  /// Client alias correction also applies to a catalog fetched from the server.
  List<String> get aliases => raidId == 'horizon_cathedral'
      ? List.unmodifiable({..._aliases.where((a) => a != '성당'), '지평'})
      : _aliases;
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
    this.exactMinItemLevel,
  });

  final String difficultyId;
  final String name;

  /// Difficulty alone, separate from the combined recruitment displayAlias.
  String get displayName => switch (difficultyId) {
    'nightmare' => '나메',
    'stage1' => '1단',
    'stage2' => '2단',
    'stage3' => '3단',
    _ => name,
  };
  final String displayAlias;
  final int displayOrder;
  final int minItemLevel;

  /// Preserves the backend decimal string; legacy asset catalogs use integers.
  final String? exactMinItemLevel;
  num get requiredItemLevel => exactMinItemLevel == null
      ? minItemLevel
      : double.parse(exactMinItemLevel!);
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
