import '../../../../shared/backend/server_analysis_wire.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_catalog_detection.dart';
import '../../domain/role_summary.dart';

/// Display mapping only. The Backend already determined role and integrity.
CharacterBuildAnalysis serverAnalysisDetail(Map<String, dynamic> json) {
  ServerAnalysisWire.definition('AnalysisDetail', json);
  final d = roleMap(json['detection']);
  final minimum = json['ark_grid_minimum'];
  List<String> strings(dynamic value) => List<String>.from(value as List);
  return CharacterBuildAnalysis(
    runeCount: json['rune_count'] as int,
    equippedGemCount: json['equipped_gem_count'] as int?,
    gemEffectsSourceAvailable: json['gem_effects_source_available'] as bool,
    catalogDetection: CharacterBuildCatalogDetection(
      catalogVersion: d['catalog_version'] as String,
      status: const {
        'detected': CharacterBuildDetectionStatus.detected,
        'unsupported_class': CharacterBuildDetectionStatus.unsupportedClass,
        'branch_not_found': CharacterBuildDetectionStatus.branchNotFound,
        'ambiguous': CharacterBuildDetectionStatus.ambiguous,
      }[d['status']]!,
      classId: d['class_id'] as String?,
      branchId: d['branch_id'] as String?,
      branchDisplayName: d['branch_display_name'] as String?,
      detectedRole: d['detected_role'] == null
          ? null
          : summaryRole(d['detected_role']),
      matchedTier1Node: d['matched_tier1_node'] as String?,
      matchedRelatedNodes: strings(d['matched_related_nodes']),
    ),
    gemEffects: [
      for (final g in json['gems'] as List)
        GemSkillEffect(
          gemSlot: g['slot'] as int,
          gemLevel: g['level'] as int,
          skillName: g['target'] as String,
          descriptions: strings(g['descriptions']),
          category: const {
            'normal': GemSkillCategory.normal,
            'passive_or_identity': GemSkillCategory.passiveOrIdentity,
            'unknown': GemSkillCategory.unknown,
          }[g['category']]!,
          validationStatus: const {
            'verified': GemValidationStatus.verified,
            'same_class_target_unverified':
                GemValidationStatus.sameClassTargetUnverified,
            'foreign_class': GemValidationStatus.foreignClass,
            'unavailable': GemValidationStatus.unavailable,
          }[g['validation_status']]!,
        ),
    ],
    arkGridCorePoints: [
      for (final c in json['ark_grid_core_points'] as List)
        ArkGridCorePointCheck(
          coreName: c['name'] as String,
          grade: c['grade'] as String,
          point: c['point'] as int,
          minimumPoint: c['minimum_point'] as int,
          recommendedPoint: c['recommended_point'] as int,
        ),
    ],
    arkGridConditions: [
      for (final c in json['ark_grid_conditions'] as List)
        ArkGridConditionCheck(
          coreName: c['core_name'] as String,
          conditionText: c['condition_text'] as String,
          requiredPassiveNames: strings(c['required_passive_names']),
          missingPassiveNames: strings(c['missing_passive_names']),
        ),
    ],
    arkGridMinimumIntegrity: minimum == null
        ? null
        : ArkGridMinimumIntegrity(
            orderSunPoint: minimum['order_sun_point'] as int?,
            orderMoonPoint: minimum['order_moon_point'] as int?,
          ),
    notices: [
      for (final n in json['notices'] as List)
        BuildNotice(
          code: n['code'] as String,
          level: BuildNoticeLevel.values.byName(n['severity'] as String),
          message: n['message'] as String,
        ),
    ],
  );
}
