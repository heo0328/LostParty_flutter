enum WeeklyRaidStatusKind {
  active,
  completed,
  legacyActive,
  legacyCompleted,
  inconsistent,
}

enum WeeklyRaidStatusRecordKind {
  activeState,
  completedState,
  legacyAssignment,
  legacyClaim,
}

class WeeklyRaidStatusRecord {
  const WeeklyRaidStatusRecord({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.kind,
    this.recruitmentId,
    this.ownershipRevision = 0,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final WeeklyRaidStatusRecordKind kind;
  final String? recruitmentId;
  final int ownershipRevision;

  String get key => '$characterId:$raidId';
}

class WeeklyRaidStatusProjection {
  const WeeklyRaidStatusProjection({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.kind,
    this.recruitmentId,
    this.hasActiveEvidence = false,
    this.hasCompletedEvidence = false,
    this.hasCompletedState = false,
    this.hasLegacyClaim = false,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final WeeklyRaidStatusKind kind;
  final String? recruitmentId;
  final bool hasActiveEvidence;
  final bool hasCompletedEvidence;
  final bool hasCompletedState;
  final bool hasLegacyClaim;

  String get key => '$characterId:$raidId';

  bool get isCompleted =>
      hasCompletedEvidence ||
      kind == WeeklyRaidStatusKind.completed ||
      kind == WeeklyRaidStatusKind.legacyCompleted;

  bool get isActive =>
      hasActiveEvidence ||
      kind == WeeklyRaidStatusKind.active ||
      kind == WeeklyRaidStatusKind.legacyActive;

  bool get isInconsistent => kind == WeeklyRaidStatusKind.inconsistent;
}
