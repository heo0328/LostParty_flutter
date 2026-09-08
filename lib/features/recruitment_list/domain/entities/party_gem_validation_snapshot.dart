enum PartyGemValidationStatus {
  verified,
  sameClassTargetUnverified,
  foreignClass,
  unavailable,
}

/// 파티 지원 시점에 공개하는 최소 보석 검증 정보.
/// 보석명, Tooltip, Armory 원문은 포함하지 않는다.
class PartyGemValidationSnapshot {
  const PartyGemValidationSnapshot({
    required this.status,
    required this.foreignClassGemCount,
    required this.unverifiedSameClassGemCount,
    required this.validatedAt,
    required this.catalogVersion,
  });

  final PartyGemValidationStatus status;
  final int foreignClassGemCount;
  final int unverifiedSameClassGemCount;
  final DateTime validatedAt;
  final String catalogVersion;

  Map<String, Object?> toFields() => {
    'gemValidationStatus': status.name,
    'foreignClassGemCount': foreignClassGemCount,
    'unverifiedSameClassGemCount': unverifiedSameClassGemCount,
    'gemValidatedAt': validatedAt,
    'catalogVersion': catalogVersion,
  };
}
