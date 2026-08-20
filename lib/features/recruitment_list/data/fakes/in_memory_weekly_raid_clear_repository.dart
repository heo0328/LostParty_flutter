import '../../domain/entities/weekly_raid_clear.dart';
import '../../domain/repositories/weekly_raid_clear_repository.dart';

class InMemoryWeeklyRaidClearRepository implements WeeklyRaidClearRepository {
  final Map<String, WeeklyRaidClear> _store = {};

  @override
  Future<bool> hasClear({
    required String userId,
    required String characterId,
    required String raidId,
    required String resetWeekKey,
  }) async =>
      _store.containsKey(_key(userId, characterId, raidId, resetWeekKey));

  @override
  Future<void> saveAll(List<WeeklyRaidClear> clears) async {
    for (final clear in clears) {
      _store[_key(
            clear.userId,
            clear.characterId,
            clear.raidId,
            clear.resetWeekKey,
          )] =
          clear;
    }
  }

  String _key(
    String userId,
    String characterId,
    String raidId,
    String resetWeekKey,
  ) => '$userId::$characterId::$raidId::$resetWeekKey';
}
