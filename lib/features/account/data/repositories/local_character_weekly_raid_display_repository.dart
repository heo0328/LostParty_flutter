import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/repositories/character_weekly_raid_display_repository.dart';
import '../local/account_database.dart';

class LocalCharacterWeeklyRaidDisplayRepository
    implements CharacterWeeklyRaidDisplayRepository {
  LocalCharacterWeeklyRaidDisplayRepository({required AccountDatabase database})
    : _database = database;

  final AccountDatabase _database;

  @override
  Future<Map<int, CharacterWeeklyRaidDisplayPreference>> loadAll() async {
    final rows = await _database.loadCharacterWeeklyRaidDisplays();
    return {
      for (final entry in rows.entries)
        entry.key: CharacterWeeklyRaidDisplayPreference(
          characterId: entry.key,
          displayCount: entry.value.displayCount,
          raidIds: entry.value.raidIds,
        ),
    };
  }

  @override
  Future<void> save(CharacterWeeklyRaidDisplayPreference preference) async {
    if (!preference.isValid) {
      throw ArgumentError.value(preference, 'preference');
    }
    await _database.saveCharacterWeeklyRaidDisplay(
      characterId: preference.characterId,
      displayCount: preference.displayCount,
      raidIds: preference.raidIds,
    );
  }

  @override
  Future<void> clear(int characterId) =>
      _database.clearCharacterWeeklyRaidDisplay(characterId);
}
