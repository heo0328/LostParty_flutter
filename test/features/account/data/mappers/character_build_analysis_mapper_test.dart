import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/character_build_analysis_mapper.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() async {
    fixture = Map<String, dynamic>.from(
      jsonDecode(
            await File(
              'test/fixtures/lost_ark/character_armory_full.json',
            ).readAsString(),
          )
          as Map,
    );
  });

  test('maps gem effects and passive skills from the full fixture', () {
    final result = const CharacterBuildAnalysisMapper().fromJson(fixture);

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
    expect(
      result.notices.where(
        (notice) => notice.code == 'ark_grid_required_point',
      ),
      hasLength(1),
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
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}
