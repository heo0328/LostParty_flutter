enum GameCatalogRole { dealer, support }

enum ClassSpecialSkillCategory { identity, arkPassive }

class GameCatalog {
  const GameCatalog({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.updatedAt,
    required this.classes,
  });

  final int schemaVersion;
  final String catalogVersion;
  final DateTime updatedAt;
  final List<GameClassDefinition> classes;
}

class GameClassDefinition {
  const GameClassDefinition({
    required this.classId,
    required this.apiClassName,
    required this.aliases,
    required this.supportedRoles,
    required this.defaultRole,
    required this.enlightenmentBranches,
    required this.specialSkills,
    required this.arkGridPresets,
  });

  final String classId;
  final String apiClassName;
  final List<String> aliases;
  final Set<GameCatalogRole> supportedRoles;
  final GameCatalogRole defaultRole;
  final List<EnlightenmentBranch> enlightenmentBranches;
  final List<ClassSpecialSkill> specialSkills;
  final List<ArkGridPreset> arkGridPresets;
}

class EnlightenmentBranch {
  const EnlightenmentBranch({
    required this.branchId,
    required this.tier1NodeName,
    required this.displayName,
    required this.aliases,
    required this.inferredRole,
    required this.relatedPassiveNodes,
  });

  final String branchId;
  final String tier1NodeName;
  final String displayName;
  final List<String> aliases;
  final GameCatalogRole inferredRole;
  final List<String> relatedPassiveNodes;
}

class ClassSpecialSkill {
  const ClassSpecialSkill({
    required this.skillId,
    required this.name,
    required this.aliases,
    required this.category,
    required this.relatedBranchIds,
  });

  final String skillId;
  final String name;
  final List<String> aliases;
  final ClassSpecialSkillCategory category;
  final List<String> relatedBranchIds;
}

class ArkGridPreset {
  const ArkGridPreset({
    required this.presetId,
    required this.name,
    required this.aliases,
    required this.applicableBranchIds,
    required this.inferredRole,
    required this.requiredPassiveNodes,
    required this.optionalPassiveNodes,
    required this.requiredCores,
    required this.tags,
  });

  final String presetId;
  final String name;
  final List<String> aliases;
  final List<String> applicableBranchIds;
  final GameCatalogRole inferredRole;
  final List<String> requiredPassiveNodes;
  final List<String> optionalPassiveNodes;
  final List<ArkGridCoreRequirement> requiredCores;
  final List<String> tags;
}

class ArkGridCoreRequirement {
  const ArkGridCoreRequirement({
    required this.coreName,
    required this.minimumPoint,
    this.recommendedPoint,
  });

  final String coreName;
  final int minimumPoint;
  final int? recommendedPoint;
}
