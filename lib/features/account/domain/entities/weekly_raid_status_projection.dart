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
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final WeeklyRaidStatusRecordKind kind;
  final String? recruitmentId;

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
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final WeeklyRaidStatusKind kind;
  final String? recruitmentId;

  String get key => '$characterId:$raidId';

  bool get isCompleted =>
      kind == WeeklyRaidStatusKind.completed ||
      kind == WeeklyRaidStatusKind.legacyCompleted;

  bool get isActive =>
      kind == WeeklyRaidStatusKind.active ||
      kind == WeeklyRaidStatusKind.legacyActive;

  bool get isInconsistent => kind == WeeklyRaidStatusKind.inconsistent;
}
