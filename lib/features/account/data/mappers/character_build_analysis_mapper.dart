import 'dart:convert';

import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_catalog_detection.dart';
import 'gem_tooltip_class_extractor.dart';

class CharacterBuildAnalysisMapper {
  const CharacterBuildAnalysisMapper();

  CharacterBuildAnalysis fromJson(
    Map<String, dynamic> json, {
    GameCatalog? catalog,
  }) {
    final skills = _mapList(json['ArmorySkills']);
    final skillNames = skills
        .map((skill) => skill['Name'])
        .whereType<String>()
        .toSet();
    final runeCount = skills.where((skill) => skill['Rune'] is Map).length;
    final notices = <BuildNotice>[];
    final classDefinition = catalog == null
        ? null
        : _findClassForBuild(json, catalog);
    final activePassiveNames = _parseActivePassiveNames(json['ArkPassive']);
    final catalogDetection = catalog == null
        ? null
        : _detectCatalogBuild(
            json,
            catalog: catalog,
            activePassiveNames: activePassiveNames,
          );

    if (runeCount != CharacterBuildAnalysis.expectedRuneCount) {
      notices.add(
        BuildNotice(
          code: 'rune_count',
          level: BuildNoticeLevel.warning,
          message: '장착된 룬이 $runeCount개입니다. 일반 스킬 8개의 룬 설정을 확인해 주세요.',
        ),
      );
    }

    final gemEffects = _parseGemEffects(
      json['ArmoryGem'],
      skillNames: skillNames,
      catalogSkillNames: _catalogGemSkillNames(
        classDefinition,
        branchId: catalogDetection?.branchId,
      ),
      characterClassName:
          _map(json['ArmoryProfile'])?['CharacterClassName'] as String?,
      knownClassNames: catalog == null
          ? const {}
          : buildKnownGemClassNames(
              catalog.classes.map(
                (definition) => (
                  apiClassName: definition.apiClassName,
                  aliases: definition.aliases,
                ),
              ),
            ),
      allowPassiveIconFallback: classDefinition == null,
      notices: notices,
    );
    final arkGridConditions = _parseArkGridConditions(
      json['ArkGrid'],
      activePassiveNames: activePassiveNames,
      notices: notices,
    );
    final arkGridMinimumResult = _parseRequiredArkGridCorePoints(
      json['ArkGrid'],
      notices: notices,
    );

    return CharacterBuildAnalysis(
      runeCount: runeCount,
      gemEffects: gemEffects,
      arkGridConditions: arkGridConditions,
      arkGridCorePoints: arkGridMinimumResult.checks,
      arkGridMinimumIntegrity: arkGridMinimumResult.integrity,
      notices: notices,
      catalogDetection: catalogDetection,
    );
  }

  GameClassDefinition? _findClassForBuild(
    Map<String, dynamic> json,
    GameCatalog catalog,
  ) {
    final profile = _map(json['ArmoryProfile']);
    final apiClassName = profile?['CharacterClassName'];
    return apiClassName is String
        ? _findClass(catalog.classes, apiClassName)
        : null;
  }

  Set<String> _catalogGemSkillNames(
    GameClassDefinition? definition, {
    required String? branchId,
  }) {
    if (definition == null) {
      return const {};
    }
    return {
      for (final skill in definition.specialSkills)
        if (branchId == null || skill.relatedBranchIds.contains(branchId))
          skill.name,
      for (final skill in definition.specialSkills)
        if (branchId == null || skill.relatedBranchIds.contains(branchId))
          ...skill.aliases,
      for (final target in definition.gemSkillTargets)
        if (_targetMatchesBranch(definition, target, branchId)) target.name,
      for (final target in definition.gemSkillTargets)
        if (_targetMatchesBranch(definition, target, branchId))
          ...target.aliases,
    };
  }

  bool _targetMatchesBranch(
    GameClassDefinition definition,
    ClassGemSkillTarget target,
    String? branchId,
  ) {
    if (branchId == null) {
      return true;
    }
    final relatedSkills = definition.specialSkills.where(
      (skill) => target.relatedSpecialSkillIds.contains(skill.skillId),
    );
    return relatedSkills.any(
      (skill) => skill.relatedBranchIds.contains(branchId),
    );
  }

  CharacterBuildCatalogDetection _detectCatalogBuild(
    Map<String, dynamic> json, {
    required GameCatalog catalog,
    required Set<String> activePassiveNames,
  }) {
    final profile = _map(json['ArmoryProfile']);
    final apiClassName = profile?['CharacterClassName'];
    final classDefinition = apiClassName is String
        ? _findClass(catalog.classes, apiClassName)
        : null;
    if (classDefinition == null) {
      return CharacterBuildCatalogDetection(
        catalogVersion: catalog.catalogVersion,
        status: CharacterBuildDetectionStatus.unsupportedClass,
        classId: null,
        branchId: null,
        branchDisplayName: null,
        detectedRole: null,
        matchedTier1Node: null,
        matchedRelatedNodes: const [],
      );
    }

    final matchingBranches = classDefinition.enlightenmentBranches
        .where((branch) => activePassiveNames.contains(branch.tier1NodeName))
        .toList(growable: false);
    if (matchingBranches.isEmpty) {
      return CharacterBuildCatalogDetection(
        catalogVersion: catalog.catalogVersion,
        status: CharacterBuildDetectionStatus.branchNotFound,
        classId: classDefinition.classId,
        branchId: null,
        branchDisplayName: null,
        detectedRole: null,
        matchedTier1Node: null,
        matchedRelatedNodes: const [],
      );
    }
    if (matchingBranches.length > 1) {
      final relatedNodes = matchingBranches
          .expand((branch) => branch.relatedPassiveNodes)
          .where(activePassiveNames.contains)
          .toSet()
          .toList(growable: false);
      return CharacterBuildCatalogDetection(
        catalogVersion: catalog.catalogVersion,
        status: CharacterBuildDetectionStatus.ambiguous,
        classId: classDefinition.classId,
        branchId: null,
        branchDisplayName: null,
        detectedRole: null,
        matchedTier1Node: null,
        matchedRelatedNodes: relatedNodes,
      );
    }

    final branch = matchingBranches.single;
    return CharacterBuildCatalogDetection(
      catalogVersion: catalog.catalogVersion,
      status: CharacterBuildDetectionStatus.detected,
      classId: classDefinition.classId,
      branchId: branch.branchId,
      branchDisplayName: branch.displayName,
      detectedRole: characterBuildRoleFromCatalogRole(branch.inferredRole),
      matchedTier1Node: branch.tier1NodeName,
      matchedRelatedNodes: branch.relatedPassiveNodes
          .where(activePassiveNames.contains)
          .toList(growable: false),
    );
  }

  GameClassDefinition? _findClass(
    List<GameClassDefinition> classes,
    String apiClassName,
  ) {
    final normalizedName = apiClassName.trim().toLowerCase();
    for (final definition in classes) {
      final names = [definition.apiClassName, ...definition.aliases];
      if (names.any((name) => name.trim().toLowerCase() == normalizedName)) {
        return definition;
      }
    }
    return null;
  }

  ({List<ArkGridCorePointCheck> checks, ArkGridMinimumIntegrity integrity})
  _parseRequiredArkGridCorePoints(
    Object? arkGrid, {
    required List<BuildNotice> notices,
  }) {
    final gridMap = _map(arkGrid);
    final checks = <ArkGridCorePointCheck>[];
    int? orderSunPoint;
    int? orderMoonPoint;
    for (final slot in _mapList(gridMap?['Slots'])) {
      final coreName = slot['Name'];
      final grade = slot['Grade'];
      final point = slot['Point'];
      if (coreName is! String || grade is! String || point is! int) {
        continue;
      }
      if (!coreName.startsWith('질서의 해') && !coreName.startsWith('질서의 달')) {
        continue;
      }

      if (coreName.startsWith('질서의 해')) {
        orderSunPoint = _higherPoint(orderSunPoint, point);
      } else {
        orderMoonPoint = _higherPoint(orderMoonPoint, point);
      }

      const minimumPoint = 14;
      final recommendedPoint = _isRelicOrHigher(grade) ? 17 : minimumPoint;
      final check = ArkGridCorePointCheck(
        coreName: coreName,
        grade: grade,
        point: point,
        minimumPoint: minimumPoint,
        recommendedPoint: recommendedPoint,
      );
      checks.add(check);

      if (!check.meetsMinimum) {
        notices.add(
          BuildNotice(
            code: 'ark_grid_required_point',
            level: BuildNoticeLevel.warning,
            message: '$coreName이 ${point}P입니다. 필수 14P 효과가 활성화되지 않았습니다.',
          ),
        );
      } else if (!check.meetsRecommendation) {
        notices.add(
          BuildNotice(
            code: 'ark_grid_relic_point',
            level: BuildNoticeLevel.warning,
            message: '$coreName이 ${point}P입니다. 유물 이상 코어의 17P 효과가 활성화되지 않았습니다.',
          ),
        );
      }
    }
    if (orderSunPoint == null) {
      notices.add(
        const BuildNotice(
          code: 'ark_grid_missing_order_sun',
          level: BuildNoticeLevel.warning,
          message: '질서의 해 코어가 없습니다. 필수 14P 효과를 확인해 주세요.',
        ),
      );
    }
    if (orderMoonPoint == null) {
      notices.add(
        const BuildNotice(
          code: 'ark_grid_missing_order_moon',
          level: BuildNoticeLevel.warning,
          message: '질서의 달 코어가 없습니다. 필수 14P 효과를 확인해 주세요.',
        ),
      );
    }

    return (
      checks: checks,
      integrity: ArkGridMinimumIntegrity(
        orderSunPoint: orderSunPoint,
        orderMoonPoint: orderMoonPoint,
      ),
    );
  }

  int _higherPoint(int? current, int candidate) {
    if (current == null || candidate > current) {
      return candidate;
    }
    return current;
  }

  bool _isRelicOrHigher(String grade) {
    return grade == '유물' || grade == '고대';
  }

  List<GemSkillEffect> _parseGemEffects(
    Object? armoryGem, {
    required Set<String> skillNames,
    required Set<String> catalogSkillNames,
    required String? characterClassName,
    required Map<String, String> knownClassNames,
    required bool allowPassiveIconFallback,
    required List<BuildNotice> notices,
  }) {
    final gemMap = _map(armoryGem);
    final levelsBySlot = <int, int>{};
    final gemsBySlot = <int, Map<String, dynamic>>{};
    for (final gem in _mapList(gemMap?['Gems'])) {
      final slot = gem['Slot'];
      final level = gem['Level'];
      if (slot is int && level is int) {
        levelsBySlot[slot] = level;
        gemsBySlot[slot] = gem;
      }
    }

    final effectsMap = _map(gemMap?['Effects']);
    final effects = <GemSkillEffect>[];
    final mappedSlots = <int>{};
    for (final skill in _mapList(effectsMap?['Skills'])) {
      final slot = skill['GemSlot'];
      final name = skill['Name'];
      if (slot is! int || name is! String) {
        continue;
      }
      mappedSlots.add(slot);
      final icon = skill['Icon'];
      final category = skillNames.contains(name)
          ? GemSkillCategory.normal
          : catalogSkillNames.contains(name) ||
                allowPassiveIconFallback &&
                    icon is String &&
                    icon.contains('ark_passive')
          ? GemSkillCategory.passiveOrIdentity
          : GemSkillCategory.unknown;
      final descriptions = _stringList(skill['Description']);
      final tooltipClassNames = extractGemTooltipClassNames([
        gemsBySlot[slot]?['Tooltip'],
        skill['Tooltip'],
        skill['Description'],
      ], knownClassNames);
      final normalizedCharacterClass = characterClassName?.trim().toLowerCase();
      final hasMatchingClass =
          normalizedCharacterClass != null &&
          tooltipClassNames.any(
            (name) => name.trim().toLowerCase() == normalizedCharacterClass,
          );
      final validationStatus = tooltipClassNames.isEmpty
          ? GemValidationStatus.unavailable
          : !hasMatchingClass
          ? GemValidationStatus.foreignClass
          : category == GemSkillCategory.unknown
          ? GemValidationStatus.sameClassTargetUnverified
          : GemValidationStatus.verified;
      effects.add(
        GemSkillEffect(
          gemSlot: slot,
          gemLevel: levelsBySlot[slot] ?? 0,
          skillName: name,
          descriptions: descriptions,
          category: category,
          tooltipClassNames: tooltipClassNames,
          validationStatus: validationStatus,
        ),
      );

      if (validationStatus == GemValidationStatus.foreignClass) {
        notices.add(
          BuildNotice(
            code: 'foreign_class_gem_$slot',
            level: BuildNoticeLevel.warning,
            message: '$name 보석은 다른 직업 보석입니다: ${tooltipClassNames.join(', ')}',
          ),
        );
      } else if (validationStatus ==
          GemValidationStatus.sameClassTargetUnverified) {
        notices.add(
          BuildNotice(
            code: 'unverified_same_class_gem_$slot',
            level: BuildNoticeLevel.info,
            message: '$name 보석은 해당 직업 보석이지만 현재 스킬 또는 등록 특수 스킬에서 확인되지 않습니다.',
          ),
        );
      }
    }

    for (final slot in levelsBySlot.keys.where(
      (slot) => !mappedSlots.contains(slot),
    )) {
      notices.add(
        BuildNotice(
          code: 'unmapped_gem_$slot',
          level: BuildNoticeLevel.warning,
          message: '$slot번 보석의 적용 효과를 확인할 수 없습니다.',
        ),
      );
    }

    effects.sort((left, right) => left.gemSlot.compareTo(right.gemSlot));
    return effects;
  }

  Set<String> _parseActivePassiveNames(Object? arkPassive) {
    final passiveMap = _map(arkPassive);
    final names = <String>{};
    for (final effect in _mapList(passiveMap?['Effects'])) {
      final description = effect['Description'];
      if (description is! String) {
        continue;
      }
      final cleanDescription = _stripMarkup(description);
      final match = RegExp(
        r'\d+티어\s+(.+?)\s+Lv\.\d+',
      ).firstMatch(cleanDescription);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return names;
  }

  List<ArkGridConditionCheck> _parseArkGridConditions(
    Object? arkGrid, {
    required Set<String> activePassiveNames,
    required List<BuildNotice> notices,
  }) {
    final gridMap = _map(arkGrid);
    final checks = <ArkGridConditionCheck>[];
    for (final slot in _mapList(gridMap?['Slots'])) {
      final coreName = slot['Name'];
      final tooltip = slot['Tooltip'];
      if (coreName is! String || tooltip is! String) {
        continue;
      }
      final condition = _extractArkGridCondition(tooltip);
      if (condition == null) {
        continue;
      }
      final requiredNames = _extractRequiredPassiveNames(condition);
      final missingNames = requiredNames
          .where((name) => !activePassiveNames.contains(name))
          .toList(growable: false);
      checks.add(
        ArkGridConditionCheck(
          coreName: coreName,
          conditionText: condition,
          requiredPassiveNames: requiredNames,
          missingPassiveNames: missingNames,
        ),
      );

      if (requiredNames.isEmpty) {
        notices.add(
          BuildNotice(
            code: 'unreadable_ark_grid_condition',
            level: BuildNoticeLevel.info,
            message: '$coreName의 발동 조건을 자동으로 판독하지 못했습니다.',
          ),
        );
      } else if (missingNames.isNotEmpty) {
        notices.add(
          BuildNotice(
            code: 'inactive_ark_grid_condition',
            level: BuildNoticeLevel.warning,
            message:
                '$coreName에 필요한 아크패시브가 활성화되지 않았습니다: ${missingNames.join(', ')}',
          ),
        );
      }
    }
    return checks;
  }

  String? _extractArkGridCondition(String tooltip) {
    final decoded = jsonDecode(tooltip);
    if (decoded is! Map) {
      return null;
    }
    for (final element in decoded.values) {
      final elementMap = _map(element);
      if (elementMap?['type'] != 'ItemPartBox') {
        continue;
      }
      final strings = _flattenStrings(elementMap?['value'])
          .map(_stripMarkup)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final headerIndex = strings.indexWhere(
        (value) => value.contains('코어 옵션 발동 조건'),
      );
      if (headerIndex >= 0 && headerIndex + 1 < strings.length) {
        return strings.skip(headerIndex + 1).join(' ').trim();
      }
    }
    return null;
  }

  List<String> _extractRequiredPassiveNames(String condition) {
    final names = <String>[];
    final exclusiveMatch = RegExp(r'^(.+?)\s*전용').firstMatch(condition);
    final exclusiveName = exclusiveMatch?.group(1)?.trim();
    if (exclusiveName != null && exclusiveName.isNotEmpty) {
      names.add(exclusiveName);
    }
    final activationMatches = RegExp(
      r'(?:아크 패시브\s*)?\d+티어\s+(.+?)\s+활성화 필요',
    ).allMatches(condition);
    for (final match in activationMatches) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
    }
    return names;
  }

  String _stripMarkup(String value) {
    return value
        .replaceAll(RegExp('<[^>]+>', caseSensitive: false), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Iterable<String> _flattenStrings(Object? value) sync* {
    if (value is String) {
      yield value;
    } else if (value is List) {
      for (final item in value) {
        yield* _flattenStrings(item);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        yield* _flattenStrings(item);
      }
    }
  }

  Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList(growable: false);
  }
}
