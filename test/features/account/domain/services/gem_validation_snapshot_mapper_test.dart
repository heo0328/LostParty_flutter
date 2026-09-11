import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/services/gem_validation_snapshot_mapper.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

void main() {
  test('카탈로그 버전이 있으면 보석 요약을 Snapshot으로 만든다', () {
    final snapshot = CharacterBuildSnapshot(
      id: 1,
      characterId: 10,
      role: CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1700,
      combatPower: 2500,
      capturedAt: DateTime.utc(2026, 9, 10),
      dataVersion: 1,
      analysis: CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [
          GemSkillEffect(
            gemSlot: 0,
            gemLevel: 10,
            skillName: '테스트',
            descriptions: const [],
            category: GemSkillCategory.normal,
            validationStatus: GemValidationStatus.foreignClass,
          ),
          GemSkillEffect(
            gemSlot: 1,
            gemLevel: 10,
            skillName: '테스트2',
            descriptions: const [],
            category: GemSkillCategory.normal,
            validationStatus: GemValidationStatus.foreignClass,
          ),
        ],
        arkGridConditions: const [],
        arkGridCorePoints: const [],
        notices: const [],
        catalogDetection: const CharacterBuildCatalogDetection(
          catalogVersion: '2026.09.08',
          status: CharacterBuildDetectionStatus.detected,
          classId: 'bard',
          branchId: 'dealer',
          branchDisplayName: '딜러',
          detectedRole: CharacterBuildRole.dealer,
          matchedTier1Node: null,
          matchedRelatedNodes: [],
        ),
      ),
    );

    final gem = gemValidationSnapshotFromBuild(snapshot);
    expect(gem?.status, PartyGemValidationStatus.foreignClass);
    expect(gem?.foreignClassGemCount, 2);
    expect(gem?.catalogVersion, '2026.09.08');
  });

  test('카탈로그 버전이 없으면 null이다', () {
    final snapshot = CharacterBuildSnapshot(
      id: 1,
      characterId: 10,
      role: CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1700,
      combatPower: 2500,
      capturedAt: DateTime.utc(2026, 9, 10),
      dataVersion: 1,
      analysis: const CharacterBuildAnalysis(
        runeCount: 8,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
      ),
    );
    expect(gemValidationSnapshotFromBuild(snapshot), isNull);
  });
}
