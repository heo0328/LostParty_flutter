import '../entities/character_weekly_raid_display_preference.dart';

abstract interface class CharacterWeeklyRaidDisplayRepository {
  Future<Map<int, CharacterWeeklyRaidDisplayPreference>> loadAll();

  Future<void> save(CharacterWeeklyRaidDisplayPreference preference);

  Future<void> clear(int characterId);
}
