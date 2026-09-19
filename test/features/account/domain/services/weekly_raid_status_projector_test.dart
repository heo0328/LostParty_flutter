import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_status_projection.dart';
import 'package:lost_party/features/account/domain/services/weekly_raid_status_projector.dart';

void main() {
  const playerId = 'player-1';
  const cycleKey = '2026-09-16';

  WeeklyRaidStatusRecord record(
    WeeklyRaidStatusRecordKind kind, {
    String characterId = 'character-1',
    String raidId = 'kazeros_act4',
    String recordCycleKey = cycleKey,
  }) => WeeklyRaidStatusRecord(
    playerId: playerId,
    characterId: characterId,
    raidId: raidId,
    cycleKey: recordCycleKey,
    kind: kind,
    recruitmentId:
        kind == WeeklyRaidStatusRecordKind.activeState ||
            kind == WeeklyRaidStatusRecordKind.legacyAssignment
        ? 'recruitment-1'
        : null,
  );

  test('현재 state는 active와 completed를 구분한다', () {
    final projected = WeeklyRaidStatusProjector.project(
      playerId: playerId,
      cycleKey: cycleKey,
      records: [
        record(WeeklyRaidStatusRecordKind.activeState),
        record(
          WeeklyRaidStatusRecordKind.completedState,
          characterId: 'character-2',
        ),
      ],
    );

    expect(projected, hasLength(2));
    expect(projected[0].kind, WeeklyRaidStatusKind.active);
    expect(projected[0].isCompleted, isFalse);
    expect(projected[1].kind, WeeklyRaidStatusKind.completed);
    expect(projected[1].isCompleted, isTrue);
  });

  test('state가 없을 때만 legacy Claim과 assignment를 fallback한다', () {
    final projected = WeeklyRaidStatusProjector.project(
      playerId: playerId,
      cycleKey: cycleKey,
      records: [
        record(WeeklyRaidStatusRecordKind.legacyClaim),
        record(
          WeeklyRaidStatusRecordKind.legacyAssignment,
          characterId: 'character-2',
        ),
      ],
    );

    expect(projected[0].kind, WeeklyRaidStatusKind.legacyCompleted);
    expect(projected[1].kind, WeeklyRaidStatusKind.legacyActive);
  });

  test('state와 legacy 문서 동시 존재는 내용과 무관하게 inconsistent다', () {
    final projected = WeeklyRaidStatusProjector.project(
      playerId: playerId,
      cycleKey: cycleKey,
      records: [
        record(WeeklyRaidStatusRecordKind.completedState),
        record(WeeklyRaidStatusRecordKind.legacyClaim),
      ],
    );

    expect(projected.single.kind, WeeklyRaidStatusKind.inconsistent);
    expect(projected.single.isCompleted, isFalse);
  });

  test('현재 주차가 아닌 record는 Projection에서 제외한다', () {
    final projected = WeeklyRaidStatusProjector.project(
      playerId: playerId,
      cycleKey: cycleKey,
      records: [
        record(
          WeeklyRaidStatusRecordKind.completedState,
          recordCycleKey: '2026-09-09',
        ),
      ],
    );

    expect(projected, isEmpty);
  });
}
