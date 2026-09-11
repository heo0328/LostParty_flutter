import 'package:lost_party/features/account/data/mappers/character_build_analysis_mapper.dart';
import 'package:lost_party/features/account/data/mappers/gem_tooltip_class_extractor.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

export 'package:lost_party/features/account/data/mappers/gem_tooltip_class_extractor.dart'
    show extractGemTooltipClassNames;

class LostArkGemProbeReport {
  const LostArkGemProbeReport({
    required this.characterName,
    required this.characterClassName,
    required this.catalogVersion,
    required this.detectionStatus,
    required this.branchId,
    required this.branchDisplayName,
    required this.detectedRole,
    required this.enlightenmentNodes,
    required this.armorySkillNames,
    required this.arkGridCores,
    required this.hasValidOrderSun,
    required this.hasValidOrderMoon,
    required this.arkGridConditions,
    required this.gems,
  });

  final String characterName;
  final String characterClassName;
  final String catalogVersion;
  final String detectionStatus;
  final String? branchId;
  final String? branchDisplayName;
  final String? detectedRole;
  final List<LostArkPassiveNodeFinding> enlightenmentNodes;
  final List<String> armorySkillNames;
  final List<LostArkGridCoreFinding> arkGridCores;
  final bool hasValidOrderSun;
  final bool hasValidOrderMoon;
  final List<LostArkGridConditionFinding> arkGridConditions;
  final List<LostArkGemProbeFinding> gems;

  List<String> get catalogCandidateNames =>
      gems
          .where(
            (gem) => gem.currentValidationStatus == 'sameClassTargetUnverified',
          )
          .map((gem) => gem.targetName)
          .toSet()
          .toList(growable: false)
        ..sort();
}

class LostArkPassiveNodeFinding {
  const LostArkPassiveNodeFinding({
    required this.tier,
    required this.name,
    required this.level,
  });

  final int tier;
  final String name;
  final int level;
}

enum LostArkGridCoreSlot { sun, moon, star }

class LostArkGridCoreFinding {
  const LostArkGridCoreFinding({
    required this.slot,
    required this.coreName,
    required this.grade,
    required this.point,
  });

  final LostArkGridCoreSlot slot;
  final String coreName;
  final String grade;
  final int point;

  bool get meetsRequiredMinimum =>
      slot == LostArkGridCoreSlot.star || point >= 14;
}

class LostArkGridConditionFinding {
  const LostArkGridConditionFinding({
    required this.coreName,
    required this.conditionText,
    required this.requiredPassiveNames,
    required this.missingPassiveNames,
  });

  final String coreName;
  final String conditionText;
  final List<String> requiredPassiveNames;
  final List<String> missingPassiveNames;

  bool get isSatisfied => missingPassiveNames.isEmpty;
}

class LostArkGemProbeFinding {
  const LostArkGemProbeFinding({
    required this.slot,
    required this.level,
    required this.targetName,
    required this.tooltipClassNames,
    required this.tooltipClassMatchesCharacter,
    required this.currentCategory,
    required this.currentValidationStatus,
    required this.currentWarnings,
  });

  final int slot;
  final int level;
  final String targetName;
  final List<String> tooltipClassNames;
  final bool? tooltipClassMatchesCharacter;
  final String currentCategory;
  final String currentValidationStatus;
  final List<String> currentWarnings;
}

LostArkGemProbeReport buildLostArkGemProbeReport(
  Map<String, dynamic> response,
  GameCatalog catalog,
) {
  final profile = _asMap(response['ArmoryProfile']);
  final characterName = profile?['CharacterName'] as String? ?? '(이름 미확인)';
  final characterClassName =
      profile?['CharacterClassName'] as String? ?? '(직업 미확인)';
  final analysis = const CharacterBuildAnalysisMapper().fromJson(
    response,
    catalog: catalog,
  );
  final detection = analysis.catalogDetection;
  final enlightenmentNodes = _parseEnlightenmentNodes(response['ArkPassive']);
  final armorySkillNames =
      _asMapList(response['ArmorySkills'])
          .map((skill) => skill['Name'])
          .whereType<String>()
          .toSet()
          .toList(growable: false)
        ..sort();
  final arkGridCores = _parseOrderArkGridCores(response['ArkGrid']);
  final arkGridConditions = analysis.arkGridConditions
      .map(
        (condition) => LostArkGridConditionFinding(
          coreName: condition.coreName,
          conditionText: condition.conditionText,
          requiredPassiveNames: condition.requiredPassiveNames,
          missingPassiveNames: condition.missingPassiveNames,
        ),
      )
      .toList(growable: false);
  final armoryGem = _asMap(response['ArmoryGem']);
  final gemsBySlot = <int, Map<String, dynamic>>{};
  for (final gem in _asMapList(armoryGem?['Gems'])) {
    final slot = gem['Slot'];
    if (slot is int) {
      gemsBySlot[slot] = gem;
    }
  }
  final effectsMap = _asMap(armoryGem?['Effects']);
  final effectsBySlot = <int, Map<String, dynamic>>{};
  for (final effect in _asMapList(effectsMap?['Skills'])) {
    final slot = effect['GemSlot'];
    if (slot is int) {
      effectsBySlot[slot] = effect;
    }
  }

  final knownClassNames = <String, String>{};
  for (final definition in catalog.classes) {
    for (final name in [definition.apiClassName, ...definition.aliases]) {
      knownClassNames[_normalize(name)] = definition.apiClassName;
    }
  }
  if (characterClassName != '(직업 미확인)') {
    knownClassNames[_normalize(characterClassName)] = characterClassName;
  }

  final findings = <LostArkGemProbeFinding>[];
  for (final effect in analysis.gemEffects) {
    final sourceGem = gemsBySlot[effect.gemSlot];
    final sourceEffect = effectsBySlot[effect.gemSlot];
    final tooltipClassNames = extractGemTooltipClassNames([
      sourceGem?['Tooltip'],
      sourceEffect?['Tooltip'],
      sourceEffect?['Description'],
    ], knownClassNames);
    final normalizedCharacterClass = _normalize(characterClassName);
    final matches = tooltipClassNames.isEmpty
        ? null
        : tooltipClassNames.any(
            (name) => _normalize(name) == normalizedCharacterClass,
          );
    findings.add(
      LostArkGemProbeFinding(
        slot: effect.gemSlot,
        level: effect.gemLevel,
        targetName: effect.skillName,
        tooltipClassNames: tooltipClassNames,
        tooltipClassMatchesCharacter: matches,
        currentCategory: effect.category.name,
        currentValidationStatus: effect.validationStatus.name,
        currentWarnings: analysis.notices
            .where(
              (notice) =>
                  notice.code == 'unmatched_skill_gem_${effect.gemSlot}' ||
                  notice.code == 'foreign_class_gem_${effect.gemSlot}' ||
                  notice.code == 'unmapped_gem_${effect.gemSlot}',
            )
            .map((notice) => notice.message)
            .toList(growable: false),
      ),
    );
  }
  findings.sort((left, right) => left.slot.compareTo(right.slot));

  return LostArkGemProbeReport(
    characterName: characterName,
    characterClassName: characterClassName,
    catalogVersion: catalog.catalogVersion,
    detectionStatus: detection?.status.name ?? 'notAnalyzed',
    branchId: detection?.branchId,
    branchDisplayName: detection?.branchDisplayName,
    detectedRole: detection?.detectedRole?.name,
    enlightenmentNodes: enlightenmentNodes,
    armorySkillNames: armorySkillNames,
    arkGridCores: arkGridCores,
    hasValidOrderSun: arkGridCores.any(
      (core) => core.slot == LostArkGridCoreSlot.sun && core.point >= 14,
    ),
    hasValidOrderMoon: arkGridCores.any(
      (core) => core.slot == LostArkGridCoreSlot.moon && core.point >= 14,
    ),
    arkGridConditions: arkGridConditions,
    gems: findings,
  );
}

List<LostArkPassiveNodeFinding> _parseEnlightenmentNodes(Object? arkPassive) {
  final passiveMap = _asMap(arkPassive);
  final result = <LostArkPassiveNodeFinding>[];
  final pattern = RegExp(r'깨달음\s+(\d+)티어\s+(.+?)\s+Lv\.(\d+)');
  for (final effect in _asMapList(passiveMap?['Effects'])) {
    final description = effect['Description'];
    if (description is! String) {
      continue;
    }
    final match = pattern.firstMatch(_stripMarkup(description));
    final tier = int.tryParse(match?.group(1) ?? '');
    final name = match?.group(2)?.trim();
    final level = int.tryParse(match?.group(3) ?? '');
    if (tier == null || name == null || name.isEmpty || level == null) {
      continue;
    }
    if (tier == 1 || tier == 4) {
      result.add(
        LostArkPassiveNodeFinding(tier: tier, name: name, level: level),
      );
    }
  }
  result.sort((left, right) {
    final byTier = left.tier.compareTo(right.tier);
    return byTier != 0 ? byTier : left.name.compareTo(right.name);
  });
  return result;
}

String _stripMarkup(String value) => value
    .replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('|', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<LostArkGridCoreFinding> _parseOrderArkGridCores(Object? arkGrid) {
  final gridMap = _asMap(arkGrid);
  final result = <LostArkGridCoreFinding>[];
  for (final core in _asMapList(gridMap?['Slots'])) {
    final name = core['Name'];
    final grade = core['Grade'];
    final point = core['Point'];
    if (name is! String || grade is! String || point is! int) {
      continue;
    }
    final slot = switch (name) {
      String value when value.startsWith('질서의 해') => LostArkGridCoreSlot.sun,
      String value when value.startsWith('질서의 달') => LostArkGridCoreSlot.moon,
      String value when value.startsWith('질서의 별') => LostArkGridCoreSlot.star,
      _ => null,
    };
    if (slot != null) {
      result.add(
        LostArkGridCoreFinding(
          slot: slot,
          coreName: name,
          grade: grade,
          point: point,
        ),
      );
    }
  }
  result.sort((left, right) => left.slot.index.compareTo(right.slot.index));
  return result;
}

String _normalize(String value) => value.trim().toLowerCase();

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
}
