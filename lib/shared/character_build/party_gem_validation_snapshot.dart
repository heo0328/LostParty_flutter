enum PartyGemValidationStatus {
  verified,
  error,
  sameClassTargetUnverified,
  foreignClass,
  unavailable,
}

/// 파티·그룹 membership에 공개하는 최소 보석 검증 정보.
/// 보석명, Tooltip, Armory 원문은 포함하지 않는다.
class PartyGemValidationSnapshot {
  const PartyGemValidationSnapshot({
    required this.status,
    required this.foreignClassGemCount,
    required this.unverifiedSameClassGemCount,
    required this.validatedAt,
    required this.catalogVersion,
    this.schemaVersion = 1,
    this.equippedGemCount,
    this.unmatchedSkillGemCount = 0,
  });

  final PartyGemValidationStatus status;
  final int foreignClassGemCount;
  final int unverifiedSameClassGemCount;
  final DateTime validatedAt;
  final String catalogVersion;
  final int schemaVersion;
  final int? equippedGemCount;
  final int unmatchedSkillGemCount;

  Map<String, Object?> toFields() => schemaVersion >= 2
      ? {
          'gemValidationSchemaVersion': 2,
          'gemValidationStatus': status.name,
          'equippedGemCount': equippedGemCount,
          'foreignClassGemCount': foreignClassGemCount,
          'unmatchedSkillGemCount': unmatchedSkillGemCount,
          'gemValidatedAt': validatedAt,
          'catalogVersion': catalogVersion,
        }
      : {
          'gemValidationStatus': status.name,
          'foreignClassGemCount': foreignClassGemCount,
          'unverifiedSameClassGemCount': unverifiedSameClassGemCount,
          'gemValidatedAt': validatedAt,
          'catalogVersion': catalogVersion,
        };

  bool hasSameValues(PartyGemValidationSnapshot? other) {
    if (other == null) return false;
    return schemaVersion == other.schemaVersion &&
        status == other.status &&
        equippedGemCount == other.equippedGemCount &&
        unmatchedSkillGemCount == other.unmatchedSkillGemCount &&
        foreignClassGemCount == other.foreignClassGemCount &&
        unverifiedSameClassGemCount == other.unverifiedSameClassGemCount &&
        validatedAt == other.validatedAt &&
        catalogVersion == other.catalogVersion;
  }

  /// 신청·membership Snapshot에서 다섯 필드가 모두 유효할 때만 읽는다.
  static PartyGemValidationSnapshot? tryFromFields(
    Map<String, Object?> data, {
    required DateTime? Function(Object? value) parseDate,
  }) {
    if (data['gemValidationSchemaVersion'] == 2) {
      return _tryFromV2(data, parseDate: parseDate);
    }
    final statusName = data['gemValidationStatus'];
    final foreignCount = data['foreignClassGemCount'];
    final unverifiedCount = data['unverifiedSameClassGemCount'];
    final catalogVersion = data['catalogVersion'];
    if (statusName is! String ||
        foreignCount is! int ||
        unverifiedCount is! int ||
        catalogVersion is! String ||
        catalogVersion.trim().isEmpty ||
        foreignCount < 0 ||
        unverifiedCount < 0) {
      return null;
    }
    final status = PartyGemValidationStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    if (status == null) return null;
    final validatedAt = parseDate(data['gemValidatedAt']);
    if (validatedAt == null) return null;
    return PartyGemValidationSnapshot(
      status: status,
      foreignClassGemCount: foreignCount,
      unverifiedSameClassGemCount: unverifiedCount,
      validatedAt: validatedAt,
      catalogVersion: catalogVersion,
      schemaVersion: 1,
    );
  }

  static PartyGemValidationSnapshot? _tryFromV2(
    Map<String, Object?> data, {
    required DateTime? Function(Object? value) parseDate,
  }) {
    final statusName = data['gemValidationStatus'];
    final equippedCount = data['equippedGemCount'];
    final foreignCount = data['foreignClassGemCount'];
    final unmatchedCount = data['unmatchedSkillGemCount'];
    final catalogVersion = data['catalogVersion'];
    final status = PartyGemValidationStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    final validatedAt = parseDate(data['gemValidatedAt']);
    if (statusName is! String ||
        status == null ||
        status == PartyGemValidationStatus.sameClassTargetUnverified ||
        status == PartyGemValidationStatus.foreignClass ||
        (equippedCount != null &&
            (equippedCount is! int || equippedCount < 0)) ||
        foreignCount is! int ||
        foreignCount < 0 ||
        unmatchedCount is! int ||
        unmatchedCount < 0 ||
        catalogVersion is! String ||
        catalogVersion.trim().isEmpty ||
        validatedAt == null) {
      return null;
    }
    return PartyGemValidationSnapshot(
      status: status,
      foreignClassGemCount: foreignCount,
      unverifiedSameClassGemCount: 0,
      validatedAt: validatedAt,
      catalogVersion: catalogVersion,
      schemaVersion: 2,
      equippedGemCount: equippedCount as int?,
      unmatchedSkillGemCount: unmatchedCount,
    );
  }

  /// Firestore Timestamp 등을 그대로 보존해 membership에 복사한다.
  static Map<String, Object?>? copyFieldsIfComplete(
    Map<Object?, Object?> data,
  ) {
    if (data['gemValidationSchemaVersion'] == 2) {
      final statusName = data['gemValidationStatus'];
      final equippedCount = data['equippedGemCount'];
      final foreignCount = data['foreignClassGemCount'];
      final unmatchedCount = data['unmatchedSkillGemCount'];
      final catalogVersion = data['catalogVersion'];
      final validatedAt = data['gemValidatedAt'];
      if ((statusName != 'verified' &&
              statusName != 'error' &&
              statusName != 'unavailable') ||
          (equippedCount != null &&
              (equippedCount is! int || equippedCount < 0)) ||
          foreignCount is! int ||
          foreignCount < 0 ||
          unmatchedCount is! int ||
          unmatchedCount < 0 ||
          catalogVersion is! String ||
          catalogVersion.trim().isEmpty ||
          validatedAt == null) {
        return null;
      }
      return {
        'gemValidationSchemaVersion': 2,
        'gemValidationStatus': statusName,
        'equippedGemCount': equippedCount,
        'foreignClassGemCount': foreignCount,
        'unmatchedSkillGemCount': unmatchedCount,
        'gemValidatedAt': validatedAt,
        'catalogVersion': catalogVersion,
      };
    }
    final statusName = data['gemValidationStatus'];
    final foreignCount = data['foreignClassGemCount'];
    final unverifiedCount = data['unverifiedSameClassGemCount'];
    final catalogVersion = data['catalogVersion'];
    final validatedAt = data['gemValidatedAt'];
    if (statusName is! String ||
        foreignCount is! int ||
        unverifiedCount is! int ||
        catalogVersion is! String ||
        catalogVersion.trim().isEmpty ||
        foreignCount < 0 ||
        unverifiedCount < 0 ||
        validatedAt == null ||
        !PartyGemValidationStatus.values.any(
          (value) => value.name == statusName,
        )) {
      return null;
    }
    return {
      'gemValidationStatus': statusName,
      'foreignClassGemCount': foreignCount,
      'unverifiedSameClassGemCount': unverifiedCount,
      'gemValidatedAt': validatedAt,
      'catalogVersion': catalogVersion,
    };
  }
}
