import '../entities/weekly_raid_clear.dart';

abstract interface class WeeklyRaidClearRepository {
  Future<bool> hasClear({
    required String userId,
    required String characterId,
    required String raidId,
    required String resetWeekKey,
  });

  Future<void> saveAll(List<WeeklyRaidClear> clears);
}
