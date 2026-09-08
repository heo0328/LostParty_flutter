import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/game_catalog/data/mappers/game_catalog_mapper.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

import '../../tool/src/lost_ark_gem_probe.dart';

void main() {
  late GameCatalog catalog;

  setUpAll(() async {
    final decoded = jsonDecode(
      await File('assets/game_catalog/game_catalog.v1.json').readAsString(),
    );
    catalog = const GameCatalogMapper().fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );
  });

  test('extracts only catalog class names from bracketed tooltip values', () {
    final result = extractGemTooltipClassNames(
      [
        jsonEncode({
          'gemEffect': "[<FONT COLOR='#FFD200'>발키리</FONT>] 신앙 스킬 피해 증가",
          'identity': '<FONT>[세레나데]</FONT> 템페스트',
          'rune': '[풍요] 아이덴티티 게이지 증가',
        }),
      ],
      const {'발키리': '발키리', '홀리나이트': '홀리나이트', '바드': '바드'},
    );

    expect(result, ['발키리']);
  });

  test('reports matching Valkyrie class scope and current unknown target', () {
    final report = buildLostArkGemProbeReport(
      _fixture(
        characterClassName: '발키리',
        targetName: '신앙 스킬',
        tooltipClassName: '발키리',
      ),
      catalog,
    );

    expect(report.characterClassName, '발키리');
    expect(report.gems.single.tooltipClassNames, ['발키리']);
    expect(report.gems.single.tooltipClassMatchesCharacter, isTrue);
    expect(report.gems.single.currentCategory, 'unknown');
    expect(
      report.gems.single.currentValidationStatus,
      'sameClassTargetUnverified',
    );
    expect(report.gems.single.currentWarnings, hasLength(1));
  });

  test('distinguishes Paladin faith gem from a Valkyrie character', () {
    final report = buildLostArkGemProbeReport(
      _fixture(
        characterClassName: '발키리',
        targetName: '신앙 스킬',
        tooltipClassName: '홀리나이트',
      ),
      catalog,
    );

    expect(report.gems.single.tooltipClassNames, ['홀리나이트']);
    expect(report.gems.single.tooltipClassMatchesCharacter, isFalse);
    expect(report.gems.single.currentValidationStatus, 'foreignClass');
  });

  test('exposes current Bard Tempest catalog gap', () {
    final report = buildLostArkGemProbeReport(
      _fixture(
        characterClassName: '바드',
        targetName: '템페스트 스킬',
        tooltipClassName: '바드',
      ),
      catalog,
    );

    expect(report.gems.single.tooltipClassMatchesCharacter, isTrue);
    expect(report.gems.single.currentCategory, 'unknown');
    expect(report.gems.single.currentWarnings, hasLength(1));
  });

  test('reports build branch, enlightenment and order grid minimums', () {
    final report = buildLostArkGemProbeReport(
      _fixture(
        characterClassName: '바드',
        targetName: '세레나데 스킬',
        tooltipClassName: '바드',
        includeBuildDetails: true,
      ),
      catalog,
    );

    expect(report.detectionStatus, 'detected');
    expect(report.branchId, 'perfect_harmony');
    expect(report.detectedRole, 'support');
    expect(report.enlightenmentNodes.map((node) => (node.tier, node.name)), [
      (1, '완벽한 화음'),
      (4, '세레나데 코드'),
    ]);
    expect(report.armorySkillNames, ['천상의 연주']);
    expect(report.arkGridCores, hasLength(3));
    expect(report.hasValidOrderSun, isTrue);
    expect(report.hasValidOrderMoon, isFalse);
    expect(report.arkGridConditions, hasLength(3));
    expect(
      report.arkGridConditions.every((condition) => condition.isSatisfied),
      isTrue,
    );
  });
}

Map<String, dynamic> _fixture({
  required String characterClassName,
  required String targetName,
  required String tooltipClassName,
  bool includeBuildDetails = false,
}) {
  return {
    'ArmoryProfile': {
      'CharacterName': '진단용캐릭터',
      'CharacterClassName': characterClassName,
    },
    'ArmorySkills': includeBuildDetails
        ? <dynamic>[
            {'Name': '천상의 연주'},
          ]
        : <dynamic>[],
    'ArmoryGem': {
      'Gems': [
        {
          'Slot': 0,
          'Level': 10,
          'Tooltip': jsonEncode({
            'Element_000': {
              'type': 'ItemPartBox',
              'value': {
                'Element_000': '보석 효과',
                'Element_001':
                    "[<FONT COLOR='#FFD200'>$tooltipClassName</FONT>] $targetName 피해 증가",
              },
            },
          }),
        },
      ],
      'Effects': {
        'Skills': [
          {
            'GemSlot': 0,
            'Name': targetName,
            'Description': [
              "[<FONT COLOR='#FFD200'>$tooltipClassName</FONT>] 피해 증가",
            ],
            'Icon': 'https://example.com/special.png',
          },
        ],
      },
    },
    if (includeBuildDetails)
      'ArkPassive': {
        'Effects': [
          {'Description': '깨달음 1티어 완벽한 화음 Lv.1'},
          {'Description': '깨달음 4티어 세레나데 코드 Lv.3'},
        ],
      },
    if (includeBuildDetails)
      'ArkGrid': {
        'Slots': [
          {
            'Name': '질서의 해 코어 : 테스트 해',
            'Grade': '유물',
            'Point': 17,
            'Tooltip': _conditionTooltip('완벽한 화음'),
          },
          {
            'Name': '질서의 달 코어 : 테스트 달',
            'Grade': '유물',
            'Point': 13,
            'Tooltip': _conditionTooltip('완벽한 화음'),
          },
          {
            'Name': '질서의 별 코어 : 테스트 별',
            'Grade': '전설',
            'Point': 5,
            'Tooltip': _conditionTooltip('완벽한 화음'),
          },
        ],
      },
  };
}

String _conditionTooltip(String passiveName) => jsonEncode({
  'Element_000': {
    'type': 'ItemPartBox',
    'value': {'Element_000': '코어 옵션 발동 조건', 'Element_001': '$passiveName 전용'},
  },
});
