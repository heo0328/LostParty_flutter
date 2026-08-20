import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/weekly_raid_clear.dart';

void main() {
  test('같은 캐릭터와 레이드의 같은 주차는 난이도와 관계없이 귀속된다', () async {
    final repository = InMemoryWeeklyRaidClearRepository();
    await repository.saveAll([
      WeeklyRaidClear(
        userId: 'user-a',
        characterId: 'character-a',
        raidId: 'serca',
        difficultyId: 'normal',
        resetWeekKey: '2026-08-19',
        completedAt: DateTime.utc(2026, 8, 20),
        recruitmentId: 'recruitment-1',
        completedByUserId: 'user-b',
      ),
    ]);

    expect(
      await repository.hasClear(
        userId: 'user-a',
        characterId: 'character-a',
        raidId: 'serca',
        resetWeekKey: '2026-08-19',
      ),
      isTrue,
    );
    expect(
      await repository.hasClear(
        userId: 'user-a',
        characterId: 'character-a',
        raidId: 'serca',
        resetWeekKey: '2026-08-26',
      ),
      isFalse,
    );
  });
}
