import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/class_synergy.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';
import 'package:lost_party/shared/game_catalog/domain/services/class_synergy_service.dart';

void main() {
  const service = ClassSynergyService();

  group('alwaysPrimaryLabels', () {
    test('returns always-adopted primary labels for a known dealer class', () {
      // 워로드 전투태세: 백헤드 피증, 받피감, 방깎 중 주요(isPrimary)는 백헤드 피증·방깎
      final labels = service.alwaysPrimaryLabels(
        className: '워로드',
        role: GameCatalogRole.dealer,
        branchNameOrId: '전투 태세',
      );
      expect(labels, containsAll(['백헤드 피증', '방깎']));
    });

    test('returns common effects when branch is unknown', () {
      // 아르카나: 특성 조건 없음 → 치적 항상
      final labels = service.alwaysPrimaryLabels(
        className: '아르카나',
        role: GameCatalogRole.dealer,
      );
      expect(labels, contains('치적'));
    });

    test('returns empty list for support role', () {
      final labels = service.alwaysPrimaryLabels(
        className: '바드',
        role: GameCatalogRole.support,
      );
      expect(labels, isEmpty);
    });

    test('returns empty list for unknown class', () {
      final labels = service.alwaysPrimaryLabels(
        className: '존재하지않는직업',
        role: GameCatalogRole.dealer,
      );
      expect(labels, isEmpty);
    });

    test('does not include setting-dependent synergies', () {
      // 호크아이 두번째동료: 피증·이속 항상, 공깎 선택채용 → 공깎 제외
      final labels = service.alwaysPrimaryLabels(
        className: '호크아이',
        role: GameCatalogRole.dealer,
        branchNameOrId: '두 번째 동료',
      );
      expect(labels, contains('피증'));
      expect(labels, isNot(contains('공깎')));
    });
  });

  group('resolve delegation', () {
    test('delegates to catalog and returns resolved status', () {
      final result = service.resolve(
        className: '블래스터',
        role: GameCatalogRole.dealer,
      );
      expect(result.status, ClassSynergyResolutionStatus.resolved);
      expect(result.primary.map((s) => s.type.label), containsAll(['방깎']));
    });

    test('returns unknownClass for unrecognized class name', () {
      final result = service.resolve(
        className: '없는직업xyz',
        role: GameCatalogRole.dealer,
      );
      expect(result.status, ClassSynergyResolutionStatus.unknownClass);
    });

    test('returns supportExcluded for support role', () {
      final result = service.resolve(
        className: '바드',
        role: GameCatalogRole.support,
      );
      expect(result.status, ClassSynergyResolutionStatus.supportExcluded);
    });
  });
}
