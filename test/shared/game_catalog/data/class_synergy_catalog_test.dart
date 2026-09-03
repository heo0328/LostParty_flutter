import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/game_catalog/data/catalogs/class_synergy_catalog.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/class_synergy.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

void main() {
  const catalog = ClassSynergyCatalog();
  ClassSynergyResolution dealer(String name, [String? branch]) =>
      catalog.resolve(
        classNameOrId: name,
        role: GameCatalogRole.dealer,
        branchNameOrId: branch,
      );

  test('all 30 classes retain owner-supplied origin and display order', () {
    expect(catalog.classes.map((entry) => entry.className), [
      '워로드',
      '디스트로이어',
      '버서커',
      '홀리나이트',
      '발키리',
      '슬레이어',
      '바드',
      '서머너',
      '아르카나',
      '소서리스',
      '호크아이',
      '데빌헌터',
      '건슬링어',
      '블래스터',
      '스카우터',
      '기공사',
      '인파이터',
      '배틀마스터',
      '창술사',
      '스트라이커',
      '브레이커',
      '블레이드',
      '데모닉',
      '리퍼',
      '소울이터',
      '도화가',
      '기상술사',
      '환수사',
      '가디언나이트',
      '차원술사',
    ]);
    expect(
      [
        for (final origin in ClassOriginGroup.values)
          catalog.classes.where((entry) => entry.origin == origin).length,
      ],
      [6, 4, 5, 6, 4, 3, 2],
    );
    expect(
      catalog.classes.map((entry) => entry.classId).toSet(),
      hasLength(30),
    );
    expect(() => catalog.classes.clear(), throwsUnsupportedError);
  });

  test(
    'every known dealer variant has exactly one primary except combat warlord',
    () {
      for (final definition in catalog.classes) {
        final Iterable<String?> variants = definition.branches.isEmpty
            ? <String?>[null]
            : definition.branches.map((branch) => branch.id);
        for (final branch in variants) {
          final result = dealer(definition.classId, branch);
          expect(result.status, ClassSynergyResolutionStatus.resolved);
          expect(
            result.primary.length,
            branch == 'combat_readiness' ? 2 : 1,
            reason: '${definition.classId}/$branch',
          );
          expect(
            result.synergies.map((effect) => effect.type).toSet().length,
            result.synergies.length,
          );
        }
      }
    },
  );

  test('all branch-independent primary effects match supplied data', () {
    final expected = {
      '디스트로이어': '방깎',
      '버서커': '피증',
      '슬레이어': '피증',
      '서머너': '방깎',
      '아르카나': '치적',
      '소서리스': '피증',
      '데빌헌터': '치적',
      '건슬링어': '치적',
      '블래스터': '방깎',
      '스카우터': '공증',
      '기공사': '공증',
      '인파이터': '피증',
      '배틀마스터': '치적',
      '창술사': '치피증',
      '스트라이커': '치적',
      '브레이커': '피증',
      '블레이드': '백헤드 피증',
      '데모닉': '피증',
      '리퍼': '방깎',
      '소울이터': '피증',
      '환수사': '방깎',
      '가디언나이트': '피증',
      '차원술사': '방깎',
    };
    for (final entry in expected.entries) {
      expect(dealer(entry.key).primary.single.type.label, entry.value);
    }
  });

  test(
    'bard dealer branch preserves all five effects and optional mitigation',
    () {
      final result = dealer('BARD', '진실된용맹');
      expect(result.synergies.map((entry) => entry.type.label), [
        '방깎',
        '공속',
        '공깎',
        '마회',
        '받피감',
      ]);
      expect(result.synergies.last.adoption, SynergyAdoption.settingDependent);
      expect(result.alwaysAdopted, hasLength(4));
      expect(dealer('bard', 'true_courage').status, result.status);
      expect(dealer('바드').status, ClassSynergyResolutionStatus.branchRequired);
      expect(dealer('바드').synergies, isEmpty);
      expect(
        dealer('바드', '완벽한 화음').status,
        ClassSynergyResolutionStatus.unknownBranch,
      );
      expect(() => result.synergies.clear(), throwsUnsupportedError);
    },
  );

  test('support never receives dealer synergy even with a dealer branch', () {
    for (final name in ['바드', '홀리나이트', '도화가', '발키리']) {
      final definition = catalog.findClass(name)!;
      final result = catalog.resolve(
        classNameOrId: name,
        role: GameCatalogRole.support,
        branchNameOrId: definition.branches.first.id,
      );
      expect(result.status, ClassSynergyResolutionStatus.supportExcluded);
      expect(result.synergies, isEmpty);
    }
  });

  test(
    'role must be known; unknown class is not an empty resolved loadout',
    () {
      expect(
        catalog.resolve(classNameOrId: '바드', role: null).status,
        ClassSynergyResolutionStatus.roleRequired,
      );
      expect(
        dealer('미등록 직업').status,
        ClassSynergyResolutionStatus.unknownClass,
      );
      expect(catalog.findClass('데몬헌터')?.className, '데빌헌터');
    },
  );

  test('warlord extra defense reduction requires combat readiness', () {
    expect(dealer('워로드', '고독한 기사').primary.map((e) => e.type.label), [
      '백헤드 피증',
    ]);
    expect(
      dealer('워로드', '전투태세').primary.map((e) => e.type.label),
      containsAll(['방깎', '백헤드 피증']),
    );
    expect(dealer('워로드').status, ClassSynergyResolutionStatus.branchRequired);
    expect(
      dealer('워로드').primary.single.type,
      SynergyType.backHeadDamageIncrease,
    );
    expect(
      dealer('워로드', '알 수 없음').status,
      ClassSynergyResolutionStatus.unknownBranch,
    );
    expect(
      dealer('워로드', '알 수 없음').primary.single.type,
      SynergyType.backHeadDamageIncrease,
    );
  });

  test('hawk common label is available without fetching detailed build', () {
    expect(dealer('호크아이').primary.single.type, SynergyType.damageIncrease);
    expect(dealer('호크아이').synergies, hasLength(1));
    expect(dealer('호크아이', '두 번째 동료').synergies.map((e) => e.type.label), [
      '피증',
      '이속',
      '공깎',
    ]);
    expect(
      dealer('호크아이', '두 번째 동료').synergies.last.adoption,
      SynergyAdoption.settingDependent,
    );
    expect(dealer('호크아이', '죽음의 습격').synergies, hasLength(1));
  });

  test('aeromancer secondary effects do not leak between branches', () {
    expect(dealer('기상술사', '이슬비').synergies.map((e) => e.type.label), [
      '치적',
      '공깎',
    ]);
    expect(dealer('기상술사', '질풍노도').synergies.map((e) => e.type.label), [
      '치적',
      '공이속',
    ]);
    expect(dealer('기상술사').synergies, hasLength(1));
  });

  test('dual-role dealer branches require explicit matching passive', () {
    expect(dealer('홀리나이트', '심판자').primary.single.type.label, '치피증');
    expect(dealer('발키리', '빛의 기사').primary.single.type.label, '치피증');
    expect(dealer('도화가', '회귀').synergies.map((e) => e.type.label), [
      '방깎',
      '받피감',
      '공속',
    ]);
    for (final name in ['홀리나이트', '발키리', '도화가']) {
      expect(dealer(name).synergies, isEmpty);
    }
  });

  test('only the eight blue effects are setting-dependent', () {
    final optional = <String>[];
    for (final definition in catalog.classes) {
      for (final effect in definition.commonDealerSynergies) {
        if (effect.adoption == SynergyAdoption.settingDependent) {
          optional.add('${definition.className}:${effect.type.label}');
        }
      }
      for (final branch in definition.branches) {
        for (final effect in branch.synergies) {
          if (effect.adoption == SynergyAdoption.settingDependent) {
            optional.add('${definition.className}:${effect.type.label}');
          }
        }
      }
    }
    expect(
      optional,
      unorderedEquals([
        '디스트로이어:무력화',
        '기공사:받피감',
        '인파이터:무력화',
        '스트라이커:공속',
        '호크아이:공깎',
        '바드:받피감',
        '서머너:마회',
        '도화가:공속',
      ]),
    );
    expect(dealer('블래스터').alwaysAdopted.map((e) => e.type.label), [
      '방깎',
      '무력화',
    ]);
  });

  test(
    'attack power and critical-hit damage taken keep independent identifiers',
    () {
      expect(SynergyType.attackPowerIncrease.isPrimary, isTrue);
      expect(
        SynergyType.criticalHitDamageTakenIncrease.name,
        'criticalHitDamageTakenIncrease',
      );
      expect(
        SynergyType.values.map((e) => e.name).toSet(),
        hasLength(SynergyType.values.length),
      );
    },
  );
}
