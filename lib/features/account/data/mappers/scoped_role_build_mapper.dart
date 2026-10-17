import 'dart:convert';

import '../../../../shared/character_build/build_integrity_snapshot.dart';
import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_catalog_detection.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/role_summary.dart';
import '../../domain/services/build_integrity_snapshot_mapper.dart';
import '../../domain/services/character_build_role_policy.dart';
import '../dtos/character_profile_dto.dart';
import 'character_build_analysis_mapper.dart';

class ScopedRoleBuildDraft {
  const ScopedRoleBuildDraft._(
    this.role,
    this.rawJson,
    this.summary,
    this.serverName,
    this.characterName,
    this.className,
  );
  final CharacterBuildRole role;
  final String rawJson, serverName, characterName, className;
  final RoleSummary summary;
}

/// Uses existing game policies; a role cannot be supplied by a preferred role.
ScopedRoleBuildDraft analyzeScopedRoleBuild({
  required Map<String, dynamic> armory,
  required GameCatalog catalog,
  required int lifecycleRevision,
  required DateTime fetchedAt,
}) {
  roleCheck(fetchedAt.isUtc && lifecycleRevision > 0);
  final rawJson = jsonEncode(armory);
  final profile = CharacterProfileDto.fromJson(
    roleMap(armory['ArmoryProfile']),
  );
  roleCheck(
    profile.serverName.isNotEmpty &&
        profile.characterName.isNotEmpty &&
        profile.characterClassName.isNotEmpty,
  );
  final analysis = const CharacterBuildAnalysisMapper().fromJson(
    armory,
    catalog: catalog,
  );
  roleCheck(
    analysis.catalogDetection != null &&
        analysis.catalogDetection!.status !=
            CharacterBuildDetectionStatus.unsupportedClass,
  );
  final decision = const CharacterBuildRolePolicy().automaticRole(
    profile.characterClassName,
    analysis,
  );
  if (decision.role == null) {
    throw const FormatException('Role evidence unavailable.');
  }
  final integrity = buildIntegritySnapshotFromAnalysis(
    analysis: analysis,
    role: decision.role!,
    checkedAt: fetchedAt,
  );
  roleCheck(integrity != null);
  final issues = <String, AnalysisIssue>{};
  void add(String code, String severity) =>
      issues[code] = AnalysisIssue(code, severity);
  for (final code in integrity!.issueCodes) {
    final mapped = switch (code) {
      BuildIntegrityIssueCode.gemSlotCount => ('GEM_SLOT_COUNT', 'error'),
      BuildIntegrityIssueCode.foreignClassGem => ('FOREIGN_CLASS_GEM', 'error'),
      BuildIntegrityIssueCode.unmatchedSkillGem => (
        'UNMATCHED_SKILL_GEM',
        'error',
      ),
      BuildIntegrityIssueCode.sameClassGemUnverified => (
        'SAME_CLASS_GEM_UNVERIFIED',
        'warning',
      ),
      BuildIntegrityIssueCode.gemUnavailable => ('GEM_UNAVAILABLE', 'warning'),
      BuildIntegrityIssueCode.arkGridMinimum => ('ARK_GRID_MINIMUM', 'error'),
      BuildIntegrityIssueCode.arkGridCondition => (
        'ARK_GRID_CONDITION',
        'error',
      ),
    };
    add(mapped.$1, mapped.$2);
  }
  // Fine-grained notices stay local; aggregate the bounded diagnostic kinds.
  for (final notice in analysis.notices) {
    if (notice.level == BuildNoticeLevel.info) continue;
    if (notice.code == 'rune_count') add('RUNE_COUNT', 'warning');
    if (notice.code == 'ark_grid_relic_point') {
      add('ARK_GRID_RELIC_POINT', 'warning');
    }
  }
  var status = integrity.status;
  if (issues.values.any((e) => e.severity == 'error')) {
    status = BuildIntegrityStatus.error;
  } else if (status == BuildIntegrityStatus.clean && issues.isNotEmpty) {
    status = BuildIntegrityStatus.review;
  }
  String? decimal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll(',', '').trim();
    roleCheck(
      normalized.length <= 32 &&
          RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(normalized),
    );
    return normalized;
  }

  final power = decimal(profile.combatPower),
      level = decimal(profile.itemAvgLevel);
  final summary = RoleSummary.fromJson({
    'source': 'flutter_analysis',
    'analysis_rules_version': 'lostparty-role-summary-v1',
    'analyzed_at': fetchedAt.toIso8601String(),
    'combat_power': power,
    'item_level': level,
    'combat_power_observed_at': power == null
        ? null
        : fetchedAt.toIso8601String(),
    'item_level_observed_at': level == null
        ? null
        : fetchedAt.toIso8601String(),
    'integrity_status': status.name,
    'catalog_version': integrity.catalogVersion,
    'issues': issues.values.map((e) => e.toJson()).toList(),
    'observed_lifecycle_revision': lifecycleRevision,
  });
  return ScopedRoleBuildDraft._(
    decision.role!,
    rawJson,
    summary,
    profile.serverName,
    profile.characterName,
    profile.characterClassName,
  );
}
