class WeeklyRaidClaimDto {
  const WeeklyRaidClaimDto({
    required this.schemaVersion,
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.difficultyId,
    required this.source,
    required this.completedAt,
    required this.updatedAt,
    required this.cycleStartedAt,
    required this.cycleEndsAt,
    this.sourceRecruitmentId,
    this.sourceCompletionRevision,
  });

  final int schemaVersion;
  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final String difficultyId;
  final String source;
  final Object? completedAt;
  final Object? updatedAt;
  final Object? cycleStartedAt;
  final Object? cycleEndsAt;
  final String? sourceRecruitmentId;
  final int? sourceCompletionRevision;

  factory WeeklyRaidClaimDto.fromMap(Map<String, Object?> data) {
    return WeeklyRaidClaimDto(
      schemaVersion: _asInt(data['schemaVersion']),
      playerId: data['playerId'] as String,
      characterId: data['characterId'] as String,
      raidId: data['raidId'] as String,
      cycleKey: data['cycleKey'] as String,
      difficultyId: data['difficultyId'] as String,
      source: data['source'] as String,
      sourceRecruitmentId: data['sourceRecruitmentId'] as String?,
      sourceCompletionRevision: data['sourceCompletionRevision'] == null
          ? null
          : _asInt(data['sourceCompletionRevision']),
      completedAt: data['completedAt'],
      updatedAt: data['updatedAt'],
      cycleStartedAt: data['cycleStartedAt'],
      cycleEndsAt: data['cycleEndsAt'],
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected int, got $value');
  }
}
