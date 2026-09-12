import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/character_build_analysis_mapper.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/shared/game_catalog/data/mappers/game_catalog_mapper.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

void main() {
  late Map<String, dynamic> fixture;
  late GameCatalog catalog;

  setUpAll(() async {
    fixture = Map<String, dynamic>.from(
      jsonDecode(
            await File(
              'test/fixtures/lost_ark/character_armory_full.json',
            ).readAsString(),
          )
          as Map,
    );
    catalog = const GameCatalogMapper().fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
              await File(
                'assets/game_catalog/game_catalog.v1.json',
              ).readAsString(),
            )
            as Map,
      ),
    );
  });

  test('detects the Bard dealer branch from the full fixture', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(
      fixture,
      catalog: catalog,
    );

    final detection = result.catalogDetection!;
    expect(detection.catalogVersion, catalog.catalogVersion);
    expect(detection.status, CharacterBuildDetectionStatus.detected);
    expect(detection.classId, 'bard');
    expect(detection.branchId, 'true_courage');
    expect(detection.branchDisplayName, '딜바드');
    expect(detection.detectedRole, CharacterBuildRole.dealer);
    expect(detection.matchedTier1Node, '진실된 용맹');
    expect(detection.matchedRelatedNodes, ['템페스트 필드']);
  });

  test('detects the Bard support branch', () {
    final modified = _deepCopy(fixture);
    final effects =
        (modified['ArkPassive'] as Map<String, dynamic>)['Effects']
            as List<dynamic>;
    for (final effect in effects.cast<Map<String, dynamic>>()) {
      final description = effect['Description'].toString();
      effect['Description'] = description
          .replaceAll('진실된 용맹', '완벽한 화음')
          .replaceAll('템페스트 필드', '세레나데 코드');
    }

    final detection = const CharacterBuildAnalysisMapper()
        .fromJson(modified, catalog: catalog)
        .catalogDetection!;

    expect(detection.status, CharacterBuildDetectionStatus.detected);
    expect(detection.branchId, 'perfect_harmony');
    expect(detection.branchDisplayName, '바드');
    expect(detection.detectedRole, CharacterBuildRole.support);
    expect(detection.matchedRelatedNodes, ['세레나데 코드']);
  });

  test(
    'detects both roles, tier-four nodes, and special gem targets for four classes',
    () async {
      final reference = Map<String, dynamic>.from(
        jsonDecode(
              await File(
                'test/fixtures/lost_ark/support_hybrid_builds_user_reference.json',
              ).readAsString(),
            )
            as Map,
      );
      expect(reference['measuredAgainstLiveApi'], isTrue);
      final cases = (reference['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(cases, hasLength(8));

      for (final buildCase in cases) {
        final result = const CharacterBuildAnalysisMapper().fromJson(
          _hybridBuildFixture(buildCase),
          catalog: catalog,
        );
        final detection = result.catalogDetection!;
        expect(detection.status, CharacterBuildDetectionStatus.detected);
        expect(detection.classId, buildCase['classId']);
        expect(detection.branchId, buildCase['branchId']);
        expect(detection.detectedRole?.name, buildCase['role']);
        expect(detection.matchedTier1Node, buildCase['tier1']);
        expect(detection.matchedRelatedNodes, [buildCase['tier4']]);
        expect(result.arkGridConditions.single.isSatisfied, isTrue);
        expect(
          result.gemEffects.single.category,
          GemSkillCategory.passiveOrIdentity,
        );
        expect(
          result.notices.where(
            (notice) => notice.code.startsWith('unknown_gem'),
          ),
          isEmpty,
        );
      }
    },
  );

  test('returns unsupported class and branch not found states', () {
    final unsupported = _deepCopy(fixture);
    (unsupported['ArmoryProfile']
            as Map<String, dynamic>)['CharacterClassName'] =
        '슬레이어';
    final unsupportedDetection = const CharacterBuildAnalysisMapper()
        .fromJson(unsupported, catalog: catalog)
        .catalogDetection!;

    final noBranch = _deepCopy(fixture);
    (noBranch['ArkPassive'] as Map<String, dynamic>)['Effects'] = <dynamic>[];
    final noBranchDetection = const CharacterBuildAnalysisMapper()
        .fromJson(noBranch, catalog: catalog)
        .catalogDetection!;

    expect(
      unsupportedDetection.status,
      CharacterBuildDetectionStatus.unsupportedClass,
    );
    expect(
      noBranchDetection.status,
      CharacterBuildDetectionStatus.branchNotFound,
    );
    expect(noBranchDetection.classId, 'bard');
  });

  test('returns ambiguous when multiple tier one branches are active', () {
    final modified = _deepCopy(fixture);
    final arkPassive = modified['ArkPassive'] as Map<String, dynamic>;
    final effects = arkPassive['Effects'] as List<dynamic>;
    effects.add({
      'Description':
          "<FONT color='#83E9FF'>깨달음</FONT> 1티어 "
          "<FONT color='#83E9FF'>완벽한 화음 Lv.1</FONT>",
    });

    final detection = const CharacterBuildAnalysisMapper()
        .fromJson(modified, catalog: catalog)
        .catalogDetection!;

    expect(detection.status, CharacterBuildDetectionStatus.ambiguous);
    expect(detection.classId, 'bard');
    expect(detection.branchId, isNull);
    expect(detection.detectedRole, isNull);
  });

  test('keeps catalog detection optional for existing analysis callers', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(fixture);

    expect(result.catalogDetection, isNull);
  });

  test('maps gem effects and passive skills from the full fixture', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(
      fixture,
      catalog: catalog,
    );

    expect(result.gemEffects, hasLength(11));
    expect(
      result.gemEffects.where(
        (effect) => effect.category == GemSkillCategory.normal,
      ),
      hasLength(10),
    );
    expect(
      result.gemEffects
          .singleWhere(
            (effect) => effect.category == GemSkillCategory.passiveOrIdentity,
          )
          .skillName,
      '템페스트 스킬',
    );
    expect(
      result.notices.where((notice) => notice.code.startsWith('unknown_gem')),
      isEmpty,
    );
  });

  test('does not use skill level to reject a gem target', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(fixture);

    final levelOneSkillGem = result.gemEffects.singleWhere(
      (effect) => effect.skillName == '수호의 연주',
    );
    expect(levelOneSkillGem.category, GemSkillCategory.normal);
  });

  test('classifies a catalog special skill without relying on its icon', () {
    final modified = _withGemTarget(
      _asBardSupport(fixture),
      name: '용맹의 세레나데',
      icon: 'https://example.com/identity.png',
    );

    final result = const CharacterBuildAnalysisMapper().fromJson(
      modified,
      catalog: catalog,
    );

    expect(
      result.gemEffects.singleWhere((effect) => effect.gemSlot == 4).category,
      GemSkillCategory.passiveOrIdentity,
    );
    expect(
      result.notices.where((notice) => notice.code == 'unknown_gem_skill_4'),
      isEmpty,
    );
  });

  test(
    'classifies the Bard composite Serenade gem target from catalog data',
    () {
      final modified = _withGemTarget(
        _asBardSupport(fixture),
        name: '세레나데 스킬',
        icon: 'https://example.com/serenade.png',
      );

      final result = const CharacterBuildAnalysisMapper().fromJson(
        modified,
        catalog: catalog,
      );

      expect(
        result.gemEffects.singleWhere((effect) => effect.gemSlot == 4).category,
        GemSkillCategory.passiveOrIdentity,
      );
      expect(
        result.notices.where((notice) => notice.code == 'unknown_gem_skill_4'),
        isEmpty,
      );
    },
  );

  test(
    'does not accept a support-only gem target for the Bard dealer branch',
    () {
      final modified = _withGemTarget(
        fixture,
        name: '세레나데 스킬',
        icon: 'https://example.com/serenade.png',
      );

      final result = const CharacterBuildAnalysisMapper().fromJson(
        modified,
        catalog: catalog,
      );

      expect(
        result.gemEffects.singleWhere((effect) => effect.gemSlot == 4).category,
        GemSkillCategory.unknown,
      );
      expect(
        result.gemEffects
            .singleWhere((effect) => effect.gemSlot == 4)
            .validationStatus,
        GemValidationStatus.sameClassTargetUnverified,
      );
    },
  );

  test('marks an unknown target from the same class as an error notice', () {
    final modified = _withGemTarget(
      fixture,
      name: '알 수 없는 스킬',
      icon: 'https://example.com/unknown.png',
    );

    final result = const CharacterBuildAnalysisMapper().fromJson(
      modified,
      catalog: catalog,
    );

    expect(
      result.gemEffects.singleWhere((effect) => effect.gemSlot == 4).category,
      GemSkillCategory.unknown,
    );
    expect(
      result.gemEffects
          .singleWhere((effect) => effect.gemSlot == 4)
          .validationStatus,
      GemValidationStatus.sameClassTargetUnverified,
    );
    expect(
      result.notices.where((notice) => notice.code == 'unmatched_skill_gem_4'),
      hasLength(1),
    );
    expect(
      result.notices
          .singleWhere((notice) => notice.code == 'unmatched_skill_gem_4')
          .level,
      BuildNoticeLevel.warning,
    );
  });

  test('does not let an Ark Passive icon bypass a known class catalog', () {
    final modified = _withGemTarget(
      fixture,
      name: '다른 직업의 특수 스킬',
      icon: 'https://example.com/ark_passive/foreign.png',
    );

    final result = const CharacterBuildAnalysisMapper().fromJson(
      modified,
      catalog: catalog,
    );

    expect(
      result.gemEffects.singleWhere((effect) => effect.gemSlot == 4).category,
      GemSkillCategory.unknown,
    );
    expect(
      result.gemEffects
          .singleWhere((effect) => effect.gemSlot == 4)
          .validationStatus,
      GemValidationStatus.sameClassTargetUnverified,
    );
  });

  test('warns only when the gem tooltip names a different class', () {
    final modified = _withGemTooltipClass(fixture, slot: 4, className: '발키리');

    final result = const CharacterBuildAnalysisMapper().fromJson(
      modified,
      catalog: catalog,
    );
    final effect = result.gemEffects.singleWhere(
      (effect) => effect.gemSlot == 4,
    );

    expect(effect.tooltipClassNames, ['발키리']);
    expect(effect.validationStatus, GemValidationStatus.foreignClass);
    expect(
      result.notices
          .singleWhere((notice) => notice.code == 'foreign_class_gem_4')
          .level,
      BuildNoticeLevel.warning,
    );
  });

  test('does not treat rune brackets as a gem class', () {
    final modified = _withGemTooltipClass(fixture, slot: 4, className: '풍요');

    final result = const CharacterBuildAnalysisMapper().fromJson(
      modified,
      catalog: catalog,
    );
    final effect = result.gemEffects.singleWhere(
      (effect) => effect.gemSlot == 4,
    );

    expect(effect.tooltipClassNames, isEmpty);
    expect(effect.validationStatus, GemValidationStatus.unavailable);
    expect(
      result.notices.where((notice) => notice.code == 'foreign_class_gem_4'),
      isEmpty,
    );
  });

  test('warns when fewer than eight runes are equipped', () {
    final modified = _deepCopy(fixture);
    final skills = modified['ArmorySkills'] as List<dynamic>;
    final skillWithRune = skills.cast<Map<String, dynamic>>().firstWhere(
      (skill) => skill['Rune'] is Map,
    );
    skillWithRune['Rune'] = null;

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);

    expect(result.runeCount, 7);
    expect(
      result.notices.singleWhere((notice) => notice.code == 'rune_count').level,
      BuildNoticeLevel.warning,
    );
  });

  test('checks Ark Grid requirements against active Ark Passive effects', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(fixture);

    expect(result.arkGridConditions, hasLength(3));
    expect(
      result.arkGridConditions.expand(
        (condition) => condition.requiredPassiveNames,
      ),
      containsAll(['진실된 용맹', '템페스트 필드']),
    );
    expect(
      result.arkGridConditions.every((condition) => condition.isSatisfied),
      isTrue,
    );
  });

  test('warns when an Ark Grid required passive is missing', () {
    final modified = _deepCopy(fixture);
    final arkPassive = modified['ArkPassive'] as Map<String, dynamic>;
    final effects = arkPassive['Effects'] as List<dynamic>;
    effects.removeWhere(
      (effect) => (effect as Map<String, dynamic>)['Description']
          .toString()
          .contains('템페스트 필드'),
    );

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);

    expect(
      result.notices.where(
        (notice) => notice.code == 'inactive_ark_grid_condition',
      ),
      hasLength(3),
    );
    expect(
      result.arkGridConditions.every(
        (condition) => condition.missingPassiveNames.contains('템페스트 필드'),
      ),
      isTrue,
    );
  });

  test('warns when an order sun or moon core is below 14 points', () {
    final modified = _deepCopy(fixture);
    final arkGrid = modified['ArkGrid'] as Map<String, dynamic>;
    final slots = arkGrid['Slots'] as List<dynamic>;
    final orderSun = slots.cast<Map<String, dynamic>>().firstWhere(
      (slot) => slot['Name'].toString().startsWith('질서의 해'),
    );
    orderSun['Point'] = 13;

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);

    final check = result.arkGridCorePoints.firstWhere(
      (check) => check.coreName.startsWith('질서의 해'),
    );
    expect(check.minimumPoint, 14);
    expect(check.meetsMinimum, isFalse);
    expect(result.arkGridMinimumIntegrity!.orderSunPoint, 13);
    expect(result.arkGridMinimumIntegrity!.orderSunMeetsMinimum, isFalse);
    expect(result.arkGridMinimumIntegrity!.orderMoonMeetsMinimum, isTrue);
    expect(result.arkGridMinimumIntegrity!.isSatisfied, isFalse);
    expect(
      result.notices.where(
        (notice) => notice.code == 'ark_grid_required_point',
      ),
      hasLength(1),
    );
  });

  test('requires both order sun and moon while ignoring chaos cores', () {
    final modified = _deepCopy(fixture);
    final arkGrid = modified['ArkGrid'] as Map<String, dynamic>;
    final slots = arkGrid['Slots'] as List<dynamic>;
    slots.removeWhere(
      (slot) =>
          (slot as Map<String, dynamic>)['Name'].toString().startsWith('질서의 해'),
    );

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);
    final integrity = result.arkGridMinimumIntegrity!;

    expect(integrity.hasOrderSun, isFalse);
    expect(integrity.hasOrderMoon, isTrue);
    expect(integrity.orderMoonPoint, 20);
    expect(integrity.isSatisfied, isFalse);
    expect(
      result.notices.where(
        (notice) => notice.code == 'ark_grid_missing_order_sun',
      ),
      hasLength(1),
    );
    expect(
      result.notices.where(
        (notice) => notice.code == 'ark_grid_missing_order_moon',
      ),
      isEmpty,
    );
  });

  test('reports a valid minimum when both order cores reach 14 points', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(fixture);
    final integrity = result.arkGridMinimumIntegrity!;

    expect(integrity.orderSunPoint, 20);
    expect(integrity.orderMoonPoint, 20);
    expect(integrity.isSatisfied, isTrue);
    expect(
      result.notices.where(
        (notice) => notice.code.startsWith('ark_grid_missing_order_'),
      ),
      isEmpty,
    );
  });

  test('warns when a relic order core has 14 but not 17 points', () {
    final modified = _deepCopy(fixture);
    final arkGrid = modified['ArkGrid'] as Map<String, dynamic>;
    final slots = arkGrid['Slots'] as List<dynamic>;
    final orderSun = slots.cast<Map<String, dynamic>>().firstWhere(
      (slot) => slot['Name'].toString().startsWith('질서의 해'),
    );
    orderSun['Point'] = 14;

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);

    final check = result.arkGridCorePoints.firstWhere(
      (check) => check.coreName.startsWith('질서의 해'),
    );
    expect(check.grade, '유물');
    expect(check.meetsMinimum, isTrue);
    expect(check.recommendedPoint, 17);
    expect(check.meetsRecommendation, isFalse);
    expect(
      result.notices.where((notice) => notice.code == 'ark_grid_relic_point'),
      hasLength(1),
    );
  });

  test('verifies user-approved special gem targets in their branches', () {
    const cases = <(String, String, String, String)>[
      ('환수사', '야성', 'wild_instinct', '둔갑 금술 스킬'),
      ('가디언나이트', '드레드 로어', 'dread_roar', '가디언 피어'),
      ('데모닉', '멈출 수 없는 충동', 'unstoppable_impulse', '블러드 제노사이드'),
    ];

    for (final (className, tier1Node, branchId, targetName) in cases) {
      var modified = _withGemTarget(
        fixture,
        name: targetName,
        icon: 'https://example.com/ark_passive/test.png',
      );
      modified = _withGemTooltipClass(modified, slot: 4, className: className);
      (modified['ArmoryProfile']
              as Map<String, dynamic>)['CharacterClassName'] =
          className;
      (modified['ArkPassive'] as Map<String, dynamic>)['Effects'] = [
        {'Description': '깨달음 1티어 $tier1Node Lv.1'},
      ];

      final result = const CharacterBuildAnalysisMapper().fromJson(
        modified,
        catalog: catalog,
      );
      final effect = result.gemEffects.singleWhere(
        (effect) => effect.gemSlot == 4,
      );

      expect(result.catalogDetection?.branchId, branchId, reason: targetName);
      expect(
        effect.category,
        GemSkillCategory.passiveOrIdentity,
        reason: targetName,
      );
      expect(
        effect.validationStatus,
        GemValidationStatus.verified,
        reason: targetName,
      );
      expect(
        result.notices.any((notice) => notice.code == 'unmatched_skill_gem_4'),
        isFalse,
        reason: targetName,
      );
    }
  });

  test('keeps equipped gem count separate from mapped effects', () {
    final modified = _deepCopy(fixture);
    final armoryGem = modified['ArmoryGem'] as Map<String, dynamic>;
    final gems = armoryGem['Gems'] as List<dynamic>;
    final skills =
        (armoryGem['Effects'] as Map<String, dynamic>)['Skills']
            as List<dynamic>;
    skills.removeLast();

    final result = const CharacterBuildAnalysisMapper().fromJson(modified);

    expect(result.equippedGemCount, gems.length);
    expect(result.gemEffects.length, skills.length);
    expect(result.gemEffectsSourceAvailable, isTrue);
  });

  test('distinguishes missing gem source from an explicitly empty list', () {
    final missing = _deepCopy(fixture)..remove('ArmoryGem');
    final empty = _deepCopy(fixture);
    final emptyGem = empty['ArmoryGem'] as Map<String, dynamic>;
    emptyGem['Gems'] = <dynamic>[];
    (emptyGem['Effects'] as Map<String, dynamic>)['Skills'] = <dynamic>[];

    final missingResult = const CharacterBuildAnalysisMapper().fromJson(
      missing,
    );
    final emptyResult = const CharacterBuildAnalysisMapper().fromJson(empty);

    expect(missingResult.equippedGemCount, isNull);
    expect(missingResult.gemEffectsSourceAvailable, isFalse);
    expect(emptyResult.equippedGemCount, 0);
    expect(emptyResult.gemEffectsSourceAvailable, isTrue);
  });
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

Map<String, dynamic> _withGemTarget(
  Map<String, dynamic> value, {
  required String name,
  required String icon,
}) {
  final modified = _deepCopy(value);
  final armoryGem = modified['ArmoryGem'] as Map<String, dynamic>;
  final effects = armoryGem['Effects'] as Map<String, dynamic>;
  final skills = effects['Skills'] as List<dynamic>;
  final target = skills.cast<Map<String, dynamic>>().singleWhere(
    (skill) => skill['GemSlot'] == 4,
  );
  target['Name'] = name;
  target['Icon'] = icon;
  return modified;
}

Map<String, dynamic> _asBardSupport(Map<String, dynamic> value) {
  final modified = _deepCopy(value);
  final effects =
      (modified['ArkPassive'] as Map<String, dynamic>)['Effects']
          as List<dynamic>;
  for (final effect in effects.cast<Map<String, dynamic>>()) {
    final description = effect['Description'].toString();
    effect['Description'] = description
        .replaceAll('진실된 용맹', '완벽한 화음')
        .replaceAll('템페스트 필드', '세레나데 코드');
  }
  return modified;
}

Map<String, dynamic> _withGemTooltipClass(
  Map<String, dynamic> value, {
  required int slot,
  required String className,
}) {
  final modified = _deepCopy(value);
  final armoryGem = modified['ArmoryGem'] as Map<String, dynamic>;
  final gems = armoryGem['Gems'] as List<dynamic>;
  final gem = gems.cast<Map<String, dynamic>>().singleWhere(
    (gem) => gem['Slot'] == slot,
  );
  gem['Tooltip'] = jsonEncode({
    'Element_006': {
      'type': 'ItemPartBox',
      'value': {
        'Element_000': '효과',
        'Element_001': '[$className] 테스트 스킬 피해 증가',
      },
    },
  });
  return modified;
}

Map<String, dynamic> _hybridBuildFixture(Map<String, dynamic> buildCase) {
  final tier1 = buildCase['tier1'] as String;
  final tier4 = buildCase['tier4'] as String;
  final conditionTooltip = jsonEncode({
    'Element_000': {
      'type': 'ItemPartBox',
      'value': {
        'Element_000': '코어 옵션 발동 조건',
        'Element_001': '1티어 $tier1 활성화 필요 4티어 $tier4 활성화 필요',
      },
    },
  });

  return {
    'ArmoryProfile': {'CharacterClassName': buildCase['className']},
    'ArmorySkills': <dynamic>[],
    'ArmoryGem': {
      'Gems': [
        {'Slot': 0, 'Level': 10},
      ],
      'Effects': {
        'Skills': [
          {
            'GemSlot': 0,
            'Name': buildCase['gemTarget'],
            'Icon': 'https://example.com/special.png',
            'Description': <String>[],
          },
        ],
      },
    },
    'ArkPassive': {
      'Effects': [
        {'Description': '깨달음 1티어 $tier1 Lv.1'},
        {'Description': '깨달음 4티어 $tier4 Lv.1'},
      ],
    },
    'ArkGrid': {
      'Slots': [
        {
          'Name': '질서의 해 : 계약 fixture',
          'Grade': '유물',
          'Point': 17,
          'Tooltip': conditionTooltip,
        },
      ],
    },
  };
}
