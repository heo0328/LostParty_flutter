import 'dart:convert';

import '../../../../shared/character_build/build_integrity_snapshot.dart';
import 'entities/character_build_role.dart';
import 'scoped_cache_models.dart';

const roleSummaryContract = '6e4f625c3b62c92ec412373b33ed8a3441af8149';
const personalSettingsContract = '7027f0b690e1c232fafc5d09faa9d6c169c99962';

void roleCheck(bool valid) {
  if (!valid) throw const FormatException('Invalid role summary.');
}

void roleShape(Map<String, dynamic> json, String names) {
  final keys = names.split(' ');
  roleCheck(json.length == keys.length && keys.every(json.containsKey));
}

Map<String, dynamic> roleMap(Object? value) {
  roleCheck(value is Map<String, dynamic>);
  return value as Map<String, dynamic>;
}

int rolePositive(Object? value) {
  roleCheck(value is int && value > 0);
  return value as int;
}

String roleId(Object? value) {
  roleCheck(value is String);
  try {
    return cacheUuid(value as String);
  } on ScopedCacheException {
    throw const FormatException('Invalid role identity.');
  }
}

DateTime roleUtc(Object? value) {
  roleCheck(value is String);
  final raw = value as String;
  roleCheck(
    RegExp(
      r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|\+00:00)$',
    ).hasMatch(raw),
  );
  final result = DateTime.parse(raw);
  roleCheck(result.toIso8601String().substring(0, 19) == raw.substring(0, 19));
  return result.toUtc();
}

String roleIdentifier(Object? value) {
  roleCheck(
    value is String && RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(value),
  );
  return value as String;
}

CharacterBuildRole summaryRole(Object? value) {
  roleCheck(value == 'dealer' || value == 'support');
  return CharacterBuildRole.values.byName(value as String);
}

class AnalysisIssue {
  AnalysisIssue(this.code, this.severity) {
    roleCheck(RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(code));
    roleCheck(severity == 'warning' || severity == 'error');
  }
  factory AnalysisIssue.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'code severity');
    roleCheck(json['code'] is String && json['severity'] is String);
    return AnalysisIssue(json['code'] as String, json['severity'] as String);
  }
  final String code, severity;
  Map<String, dynamic> toJson() => {'code': code, 'severity': severity};
}

/// Canonical immutable P1 payload; no armory raw, local integer ID or secrets.
class RoleSummary {
  factory RoleSummary.fromJson(Map<String, dynamic> json) {
    roleShape(
      json,
      'source analysis_rules_version analyzed_at combat_power item_level combat_power_observed_at item_level_observed_at integrity_status catalog_version issues observed_lifecycle_revision',
    );
    roleCheck(json['source'] == 'flutter_analysis');
    final rules = roleIdentifier(json['analysis_rules_version']);
    final catalog = json['catalog_version'] == null
        ? null
        : roleIdentifier(json['catalog_version']);
    final analyzed = roleUtc(json['analyzed_at']);
    String? number(String key) {
      final raw = json[key];
      roleCheck(
        raw == null ||
            (raw is String &&
                raw.length <= 32 &&
                RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(raw)),
      );
      return raw as String?;
    }

    final power = number('combat_power'), level = number('item_level');
    DateTime? observed(String key, String? value) {
      roleCheck((json[key] == null) == (value == null));
      return value == null ? null : roleUtc(json[key]);
    }

    final powerAt = observed('combat_power_observed_at', power);
    final levelAt = observed('item_level_observed_at', level);
    roleCheck(json['issues'] is List && (json['issues'] as List).length <= 20);
    final issues = (json['issues'] as List)
        .map((e) => AnalysisIssue.fromJson(roleMap(e)))
        .toList();
    roleCheck(
      issues.map((e) => '${e.code}:${e.severity}').toSet().length ==
          issues.length,
    );
    final statusName = json['integrity_status'];
    roleCheck(BuildIntegrityStatus.values.any((s) => s.name == statusName));
    final status = BuildIntegrityStatus.values.byName(statusName as String);
    final errors = issues.any((e) => e.severity == 'error');
    roleCheck(switch (status) {
      BuildIntegrityStatus.clean => issues.isEmpty,
      BuildIntegrityStatus.review => issues.isNotEmpty && !errors,
      BuildIntegrityStatus.error => errors,
      BuildIntegrityStatus.unavailable => !errors,
    });
    return RoleSummary._(
      rules,
      catalog,
      analyzed,
      power,
      level,
      powerAt,
      levelAt,
      status,
      List.unmodifiable(issues),
      rolePositive(json['observed_lifecycle_revision']),
    );
  }
  const RoleSummary._(
    this.rulesVersion,
    this.catalogVersion,
    this.analyzedAt,
    this.combatPower,
    this.itemLevel,
    this.powerObservedAt,
    this.levelObservedAt,
    this.integrity,
    this.issues,
    this.lifecycleRevision,
  );
  final String rulesVersion;
  final String? catalogVersion, combatPower, itemLevel;
  final DateTime analyzedAt;
  final DateTime? powerObservedAt, levelObservedAt;
  final BuildIntegrityStatus integrity;
  final List<AnalysisIssue> issues;
  final int lifecycleRevision;
  Map<String, dynamic> toJson() => {
    'source': 'flutter_analysis',
    'analysis_rules_version': rulesVersion,
    'analyzed_at': analyzedAt.toIso8601String(),
    'combat_power': combatPower,
    'item_level': itemLevel,
    'combat_power_observed_at': powerObservedAt?.toIso8601String(),
    'item_level_observed_at': levelObservedAt?.toIso8601String(),
    'integrity_status': integrity.name,
    'catalog_version': catalogVersion,
    'issues': issues.map((e) => e.toJson()).toList(),
    'observed_lifecycle_revision': lifecycleRevision,
  };
  bool same(RoleSummary? other) =>
      other != null && jsonEncode(toJson()) == jsonEncode(other.toJson());
}

class StoredRoleSummary {
  StoredRoleSummary.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'version summary saved_at');
    version = rolePositive(json['version']);
    summary = json['summary'] == null
        ? null
        : RoleSummary.fromJson(roleMap(json['summary']));
    savedAt = json['saved_at'] == null ? null : roleUtc(json['saved_at']);
    roleCheck(
      summary == null
          ? version == 1 && savedAt == null
          : version >= 2 && savedAt != null,
    );
  }
  late final int version;
  late final RoleSummary? summary;
  late final DateTime? savedAt;
  Map<String, dynamic> toJson() => {
    'version': version,
    'summary': summary?.toJson(),
    'saved_at': savedAt?.toIso8601String(),
  };
}

class PersonalProfile {
  PersonalProfile.fromJson(Map<String, dynamic> json) {
    roleShape(
      json,
      'character_id game_account_id ownership_revision lifecycle_revision lifecycle_state dealer support preferences',
    );
    characterId = roleId(json['character_id']);
    accountId = roleId(json['game_account_id']);
    ownershipRevision = rolePositive(json['ownership_revision']);
    lifecycleRevision = rolePositive(json['lifecycle_revision']);
    roleCheck(
      json['lifecycle_state'] == 'active' ||
          json['lifecycle_state'] == 'suspect',
    );
    lifecycleState = json['lifecycle_state'] as String;
    dealer = StoredRoleSummary.fromJson(roleMap(json['dealer']));
    support = StoredRoleSummary.fromJson(roleMap(json['support']));
    for (final value in [dealer, support]) {
      roleCheck(
        value.summary == null ||
            value.summary!.lifecycleRevision <= lifecycleRevision,
      );
    }
    preferences = PersonalPreferences.fromJson(roleMap(json['preferences']));
  }
  late final String characterId, accountId, lifecycleState;
  late final int ownershipRevision, lifecycleRevision;
  late final StoredRoleSummary dealer, support;
  late final PersonalPreferences preferences;
  StoredRoleSummary role(CharacterBuildRole role) =>
      role == CharacterBuildRole.dealer ? dealer : support;
}

/// P2 user-owned values. Visibility never grants activity or ownership.
class PreferenceValues {
  PreferenceValues({
    this.preferredRole,
    this.visible = true,
    this.displayOrder,
  }) {
    roleCheck(
      displayOrder == null ||
          (displayOrder! >= 0 && displayOrder! <= 2147483647),
    );
  }
  factory PreferenceValues.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'preferred_role visible display_order');
    roleCheck(json['visible'] is bool);
    roleCheck(json['display_order'] == null || json['display_order'] is int);
    return PreferenceValues(
      preferredRole: json['preferred_role'] == null
          ? null
          : summaryRole(json['preferred_role']),
      visible: json['visible'] as bool,
      displayOrder: json['display_order'] as int?,
    );
  }
  final CharacterBuildRole? preferredRole;
  final bool visible;
  final int? displayOrder;
  Map<String, dynamic> toJson() => {
    'preferred_role': preferredRole?.name,
    'visible': visible,
    'display_order': displayOrder,
  };
}

class PersonalPreferences {
  PersonalPreferences.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'version preferred_role visible display_order saved_at');
    version = rolePositive(json['version']);
    values = PreferenceValues.fromJson({
      for (final k in ['preferred_role', 'visible', 'display_order'])
        k: json[k],
    });
    savedAt = json['saved_at'] == null ? null : roleUtc(json['saved_at']);
    roleCheck(
      version == 1
          ? savedAt == null &&
                values.preferredRole == null &&
                values.visible &&
                values.displayOrder == null
          : savedAt != null,
    );
  }
  late final int version;
  late final PreferenceValues values;
  late final DateTime? savedAt;
  Map<String, dynamic> toJson() => {
    'version': version,
    ...values.toJson(),
    'saved_at': savedAt?.toIso8601String(),
  };
}

class RoleSummaryAck {
  RoleSummaryAck.fromJson(Map<String, dynamic> json) {
    roleShape(
      json,
      'character_id role ownership_revision lifecycle_revision version summary saved_at',
    );
    characterId = roleId(json['character_id']);
    role = summaryRole(json['role']);
    ownershipRevision = rolePositive(json['ownership_revision']);
    lifecycleRevision = rolePositive(json['lifecycle_revision']);
    stored = StoredRoleSummary.fromJson({
      'version': json['version'],
      'summary': json['summary'],
      'saved_at': json['saved_at'],
    });
    roleCheck(
      stored.summary != null &&
          stored.summary!.lifecycleRevision == lifecycleRevision,
    );
  }
  late final String characterId;
  late final CharacterBuildRole role;
  late final int ownershipRevision, lifecycleRevision;
  late final StoredRoleSummary stored;
}
