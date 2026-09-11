import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/services/build_integrity_snapshot_mapper.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 9, 11, 10, 30);

  group('buildIntegritySnapshotFromAnalysis', () {
    test('maps clean when gems verified and ark grid minimum satisfied', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.verified],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.status, BuildIntegrityStatus.clean);
      expect(snapshot.issueCodes, isEmpty);
      expect(snapshot.role, BuildIntegrityRole.dealer);
      expect(snapshot.checkedAt, checkedAt);
      expect(snapshot.catalogVersion, 'catalog-v1');
      expect(snapshot.displayLabels, isEmpty);
    });

    test('maps error for same-class unmatched skill gems', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.sameClassTargetUnverified],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
        ),
        role: CharacterBuildRole.support,
        checkedAt: checkedAt,
      );

      expect(snapshot!.status, BuildIntegrityStatus.error);
      expect(
        snapshot.issueCodes,
        [BuildIntegrityIssueCode.unmatchedSkillGem],
      );
      expect(snapshot.role, BuildIntegrityRole.support);
      expect(snapshot.displayLabels, ['보석 오류']);
    });

    test('maps review for empty or unavailable gems', () {
      final empty = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [],
          equippedGemCount: 0,
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );
      final unavailable = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.unavailable],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(empty!.status, BuildIntegrityStatus.error);
      expect(empty.issueCodes, [BuildIntegrityIssueCode.gemSlotCount]);
      expect(empty.displayLabels, ['보석 오류']);
      expect(unavailable!.status, BuildIntegrityStatus.review);
      expect(unavailable.issueCodes, [BuildIntegrityIssueCode.gemUnavailable]);
    });

    test('maps error for foreign gem and keeps ark grid codes together', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [
            GemValidationStatus.foreignClass,
            GemValidationStatus.sameClassTargetUnverified,
            GemValidationStatus.unavailable,
          ],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 10,
            orderMoonPoint: 14,
          ),
          conditions: [
            const ArkGridConditionCheck(
              coreName: 'core',
              conditionText: 'need passive',
              requiredPassiveNames: ['a'],
              missingPassiveNames: ['a'],
            ),
          ],
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(snapshot!.status, BuildIntegrityStatus.error);
      expect(snapshot.issueCodes, [
        BuildIntegrityIssueCode.foreignClassGem,
        BuildIntegrityIssueCode.unmatchedSkillGem,
        BuildIntegrityIssueCode.gemUnavailable,
        BuildIntegrityIssueCode.arkGridMinimum,
        BuildIntegrityIssueCode.arkGridCondition,
      ]);
      expect(snapshot.displayLabels, [
        '보석 오류',
        '아크그리드 오류',
        '보석 정보 확인 불가',
      ]);
      expect(snapshot.displayItems.map((item) => item.isError), [
        true,
        true,
        false,
      ]);
    });

    test('maps unavailable when ark grid minimum cannot be verified', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.verified],
          minimum: null,
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(snapshot!.status, BuildIntegrityStatus.unavailable);
      expect(snapshot.issueCodes, isEmpty);
      expect(snapshot.displayLabels, ['확인 불가']);
    });

    test('keeps unmatched gem and ark errors together', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.sameClassTargetUnverified],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 1,
            orderMoonPoint: 1,
          ),
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(snapshot!.status, BuildIntegrityStatus.error);
      expect(snapshot.issueCodes, [
        BuildIntegrityIssueCode.unmatchedSkillGem,
        BuildIntegrityIssueCode.arkGridMinimum,
      ]);
    });

    test('allows null catalog version', () {
      final snapshot = buildIntegritySnapshotFromAnalysis(
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.verified],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
          includeCatalog: false,
        ),
        role: CharacterBuildRole.dealer,
        checkedAt: checkedAt,
      );

      expect(snapshot!.catalogVersion, isNull);
      expect(snapshot.status, BuildIntegrityStatus.clean);
    });
  });

  group('buildIntegritySnapshotFromBuild', () {
    test('uses snapshot role and capturedAt', () {
      final build = CharacterBuildSnapshot(
        id: 1,
        characterId: 10,
        role: CharacterBuildRole.support,
        rawJson: '{}',
        itemLevel: 1700,
        combatPower: 100,
        capturedAt: checkedAt,
        dataVersion: 1,
        analysis: _analysis(
          gemStatuses: const [GemValidationStatus.verified],
          minimum: const ArkGridMinimumIntegrity(
            orderSunPoint: 14,
            orderMoonPoint: 14,
          ),
        ),
      );

      final snapshot = buildIntegritySnapshotFromBuild(build);

      expect(snapshot!.role, BuildIntegrityRole.support);
      expect(snapshot.checkedAt, checkedAt);
      expect(snapshot.status, BuildIntegrityStatus.clean);
    });
  });

  group('BuildIntegritySnapshot.tryFromFields', () {
    test('round-trips valid fields', () {
      final original = BuildIntegritySnapshot(
        status: BuildIntegrityStatus.error,
        issueCodes: const [
          BuildIntegrityIssueCode.foreignClassGem,
          BuildIntegrityIssueCode.arkGridCondition,
        ],
        role: BuildIntegrityRole.dealer,
        checkedAt: checkedAt,
        catalogVersion: 'v1',
      );

      final parsed = BuildIntegritySnapshot.tryFromFields(original.toFields());

      expect(parsed, isNotNull);
      expect(parsed!.hasSameValues(original), isTrue);
      expect(parsed.storedSchemaVersion, 2);
      expect(original.toFields()['schemaVersion'], 2);
    });

    test('reads v1 with its legacy meaning and rejects v2-only codes in v1', () {
      final legacy = BuildIntegritySnapshot.tryFromFields(<String, Object?>{
        'schemaVersion': 1,
        'status': 'review',
        'issueCodes': const ['sameClassGemUnverified'],
        'role': 'dealer',
        'checkedAt': checkedAt,
        'catalogVersion': 'v1',
      });
      final invalidLegacy = BuildIntegritySnapshot.tryFromFields(
        <String, Object?>{
          'schemaVersion': 1,
          'status': 'error',
          'issueCodes': const ['unmatchedSkillGem'],
          'role': 'dealer',
          'checkedAt': checkedAt,
          'catalogVersion': 'v1',
        },
      );

      expect(legacy, isNotNull);
      expect(legacy!.storedSchemaVersion, 1);
      expect(legacy.displayLabels, ['보석 확인 필요']);
      expect(invalidLegacy, isNull);
    });

    test('returns null for missing, unknown, or broken maps', () {
      expect(BuildIntegritySnapshot.tryFromFields(null), isNull);
      expect(BuildIntegritySnapshot.tryFromFields(<String, Object?>{}), isNull);
      expect(
        BuildIntegritySnapshot.tryFromFields(<String, Object?>{
          'schemaVersion': 3,
          'status': 'clean',
          'issueCodes': const <String>[],
          'role': 'dealer',
          'checkedAt': checkedAt,
          'catalogVersion': null,
        }),
        isNull,
      );
      expect(
        BuildIntegritySnapshot.tryFromFields(<String, Object?>{
          'schemaVersion': 1,
          'status': 'broken',
          'issueCodes': const <String>[],
          'role': 'dealer',
          'checkedAt': checkedAt,
          'catalogVersion': null,
        }),
        isNull,
      );
      expect(
        BuildIntegritySnapshot.tryFromFields(<String, Object?>{
          'schemaVersion': 1,
          'status': 'clean',
          'issueCodes': const ['unknownCode'],
          'role': 'dealer',
          'checkedAt': checkedAt,
          'catalogVersion': null,
        }),
        isNull,
      );
      expect(
        BuildIntegritySnapshot.tryFromFields(<String, Object?>{
          'schemaVersion': 1,
          'status': 'clean',
          'issueCodes': const <String>[],
          'role': 'tank',
          'checkedAt': checkedAt,
          'catalogVersion': null,
        }),
        isNull,
      );
    });

    test('dedupes duplicate issue codes while parsing', () {
      final parsed = BuildIntegritySnapshot.tryFromFields(<String, Object?>{
        'schemaVersion': 1,
        'status': 'error',
        'issueCodes': const [
          'foreignClassGem',
          'foreignClassGem',
          'arkGridMinimum',
        ],
        'role': 'dealer',
        'checkedAt': checkedAt.toIso8601String(),
        'catalogVersion': null,
      });

      expect(parsed!.issueCodes, [
        BuildIntegrityIssueCode.foreignClassGem,
        BuildIntegrityIssueCode.arkGridMinimum,
      ]);
    });
  });
}

CharacterBuildAnalysis _analysis({
  required List<GemValidationStatus> gemStatuses,
  ArkGridMinimumIntegrity? minimum,
  List<ArkGridConditionCheck> conditions = const [],
  bool includeCatalog = true,
  int? equippedGemCount = 11,
  bool gemEffectsSourceAvailable = true,
}) {
  return CharacterBuildAnalysis(
    runeCount: 8,
    gemEffects: [
      for (var i = 0; i < gemStatuses.length; i++)
        GemSkillEffect(
          gemSlot: i,
          gemLevel: 10,
          skillName: 'skill-$i',
          descriptions: const ['desc'],
          category: GemSkillCategory.normal,
          validationStatus: gemStatuses[i],
        ),
    ],
    arkGridConditions: conditions,
    arkGridCorePoints: const [],
    notices: const [],
    catalogDetection: includeCatalog
        ? const CharacterBuildCatalogDetection(
            catalogVersion: 'catalog-v1',
            status: CharacterBuildDetectionStatus.detected,
            classId: 'berserker',
            branchId: 'mayhem',
            branchDisplayName: '광기',
            detectedRole: CharacterBuildRole.dealer,
            matchedTier1Node: 'node',
            matchedRelatedNodes: [],
          )
        : null,
    arkGridMinimumIntegrity: minimum,
    equippedGemCount: equippedGemCount,
    gemEffectsSourceAvailable: gemEffectsSourceAvailable,
  );
}
