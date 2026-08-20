import '../../domain/entities/game_catalog.dart';

class GameCatalogMapper {
  const GameCatalogMapper();

  GameCatalog fromJson(Map<String, dynamic> json) {
    return GameCatalog(
      schemaVersion: _integer(json, 'schemaVersion'),
      catalogVersion: _string(json, 'catalogVersion'),
      updatedAt: DateTime.parse(_string(json, 'updatedAt')),
      classes: _mapList(json, 'classes', _classFromJson),
    );
  }

  GameClassDefinition _classFromJson(Map<String, dynamic> json) {
    return GameClassDefinition(
      classId: _string(json, 'classId'),
      apiClassName: _string(json, 'apiClassName'),
      aliases: _stringList(json, 'aliases'),
      supportedRoles: _stringList(
        json,
        'supportedRoles',
      ).map(_roleFromName).toSet(),
      defaultRole: _roleFromName(_string(json, 'defaultRole')),
      enlightenmentBranches: _mapList(
        json,
        'enlightenmentBranches',
        _branchFromJson,
      ),
      specialSkills: _mapList(json, 'specialSkills', _skillFromJson),
      gemSkillTargets: _mapList(
        json,
        'gemSkillTargets',
        _gemSkillTargetFromJson,
      ),
      arkGridPresets: _mapList(json, 'arkGridPresets', _presetFromJson),
    );
  }

  ClassGemSkillTarget _gemSkillTargetFromJson(Map<String, dynamic> json) {
    return ClassGemSkillTarget(
      targetId: _string(json, 'targetId'),
      name: _string(json, 'name'),
      aliases: _stringList(json, 'aliases'),
      relatedSpecialSkillIds: _stringList(json, 'relatedSpecialSkillIds'),
    );
  }

  EnlightenmentBranch _branchFromJson(Map<String, dynamic> json) {
    return EnlightenmentBranch(
      branchId: _string(json, 'branchId'),
      tier1NodeName: _string(json, 'tier1NodeName'),
      displayName: _string(json, 'displayName'),
      aliases: _stringList(json, 'aliases'),
      inferredRole: _roleFromName(_string(json, 'inferredRole')),
      relatedPassiveNodes: _stringList(json, 'relatedPassiveNodes'),
    );
  }

  ClassSpecialSkill _skillFromJson(Map<String, dynamic> json) {
    return ClassSpecialSkill(
      skillId: _string(json, 'skillId'),
      name: _string(json, 'name'),
      aliases: _stringList(json, 'aliases'),
      category: _skillCategoryFromName(_string(json, 'category')),
      relatedBranchIds: _stringList(json, 'relatedBranchIds'),
    );
  }

  ArkGridPreset _presetFromJson(Map<String, dynamic> json) {
    return ArkGridPreset(
      presetId: _string(json, 'presetId'),
      name: _string(json, 'name'),
      aliases: _stringList(json, 'aliases'),
      applicableBranchIds: _stringList(json, 'applicableBranchIds'),
      inferredRole: _roleFromName(_string(json, 'inferredRole')),
      requiredPassiveNodes: _stringList(json, 'requiredPassiveNodes'),
      optionalPassiveNodes: _stringList(json, 'optionalPassiveNodes'),
      requiredCores: _mapList(json, 'requiredCores', _coreFromJson),
      tags: _stringList(json, 'tags'),
    );
  }

  ArkGridCoreRequirement _coreFromJson(Map<String, dynamic> json) {
    final recommendedPoint = json['recommendedPoint'];
    if (recommendedPoint != null && recommendedPoint is! int) {
      throw const FormatException('recommendedPoint must be an integer.');
    }
    return ArkGridCoreRequirement(
      coreName: _string(json, 'coreName'),
      minimumPoint: _integer(json, 'minimumPoint'),
      recommendedPoint: recommendedPoint as int?,
    );
  }

  GameCatalogRole _roleFromName(String name) {
    try {
      return GameCatalogRole.values.byName(name);
    } on ArgumentError {
      throw FormatException('Unsupported catalog role: $name');
    }
  }

  ClassSpecialSkillCategory _skillCategoryFromName(String name) {
    try {
      return ClassSpecialSkillCategory.values.byName(name);
    } on ArgumentError {
      throw FormatException('Unsupported special skill category: $name');
    }
  }

  int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw FormatException('$key must be an integer.');
    }
    return value;
  }

  String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('$key must be a string.');
    }
    return value;
  }

  List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>();
  }

  List<T> _mapList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! Map)) {
      throw FormatException('$key must be an object list.');
    }
    return value
        .cast<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
