import '../entities/weekly_raid_status_projection.dart';

class WeeklyRaidStatusProjector {
  const WeeklyRaidStatusProjector._();

  static List<WeeklyRaidStatusProjection> project({
    required String playerId,
    required String cycleKey,
    required Iterable<WeeklyRaidStatusRecord> records,
  }) {
    final grouped = <String, List<WeeklyRaidStatusRecord>>{};
    for (final record in records) {
      if (record.playerId != playerId || record.cycleKey != cycleKey) continue;
      grouped.putIfAbsent(record.key, () => []).add(record);
    }

    final result = <WeeklyRaidStatusProjection>[];
    for (final recordsForKey in grouped.values) {
      final first = recordsForKey.first;
      final stateRecords = recordsForKey
          .where(
            (record) =>
                record.kind == WeeklyRaidStatusRecordKind.activeState ||
                record.kind == WeeklyRaidStatusRecordKind.completedState,
          )
          .toList(growable: false);
      final legacyRecords = recordsForKey
          .where(
            (record) =>
                record.kind == WeeklyRaidStatusRecordKind.legacyAssignment ||
                record.kind == WeeklyRaidStatusRecordKind.legacyClaim,
          )
          .toList(growable: false);

      final kind = _resolveKind(stateRecords, legacyRecords);
      final source = stateRecords.firstOrNull ?? legacyRecords.firstOrNull;
      result.add(
        WeeklyRaidStatusProjection(
          playerId: playerId,
          characterId: first.characterId,
          raidId: first.raidId,
          cycleKey: cycleKey,
          kind: kind,
          recruitmentId: kind == WeeklyRaidStatusKind.inconsistent
              ? null
              : source?.recruitmentId,
        ),
      );
    }
    result.sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(result);
  }

  static WeeklyRaidStatusKind _resolveKind(
    List<WeeklyRaidStatusRecord> states,
    List<WeeklyRaidStatusRecord> legacy,
  ) {
    if (states.length > 1 || legacy.length > 1) {
      return WeeklyRaidStatusKind.inconsistent;
    }
    if (states.isNotEmpty && legacy.isNotEmpty) {
      return WeeklyRaidStatusKind.inconsistent;
    }
    if (states.isNotEmpty) {
      return switch (states.single.kind) {
        WeeklyRaidStatusRecordKind.activeState => WeeklyRaidStatusKind.active,
        WeeklyRaidStatusRecordKind.completedState =>
          WeeklyRaidStatusKind.completed,
        _ => WeeklyRaidStatusKind.inconsistent,
      };
    }
    return switch (legacy.single.kind) {
      WeeklyRaidStatusRecordKind.legacyAssignment =>
        WeeklyRaidStatusKind.legacyActive,
      WeeklyRaidStatusRecordKind.legacyClaim =>
        WeeklyRaidStatusKind.legacyCompleted,
      _ => WeeklyRaidStatusKind.inconsistent,
    };
  }
}
