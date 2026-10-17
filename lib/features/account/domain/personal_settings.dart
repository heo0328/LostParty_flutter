import 'role_summary.dart';

int presentationCount(Object? value) {
  roleCheck(value is int && value >= 1 && value <= 200);
  return value as int;
}

class AccountPresentation {
  AccountPresentation.fromJson(Map<String, dynamic> json) {
    roleShape(
      json,
      'registration_id game_account_id registration_version ownership_revision version visible_count saved_at',
    );
    registrationId = roleId(json['registration_id']);
    accountId = roleId(json['game_account_id']);
    registrationVersion = rolePositive(json['registration_version']);
    ownershipRevision = rolePositive(json['ownership_revision']);
    version = rolePositive(json['version']);
    visibleCount = presentationCount(json['visible_count']);
    savedAt = json['saved_at'] == null ? null : roleUtc(json['saved_at']);
    roleCheck(
      version == 1 ? savedAt == null && visibleCount == 6 : savedAt != null,
    );
  }
  late final String registrationId, accountId;
  late final int registrationVersion, ownershipRevision, version, visibleCount;
  late final DateTime? savedAt;
  Map<String, dynamic> toJson() => {
    'registration_id': registrationId,
    'game_account_id': accountId,
    'registration_version': registrationVersion,
    'ownership_revision': ownershipRevision,
    'version': version,
    'visible_count': visibleCount,
    'saved_at': savedAt?.toIso8601String(),
  };
}
