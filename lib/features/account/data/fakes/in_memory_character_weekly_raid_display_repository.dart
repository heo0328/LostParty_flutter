import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/repositories/character_weekly_raid_display_repository.dart';

class InMemoryCharacterWeeklyRaidDisplayRepository
    implements CharacterWeeklyRaidDisplayRepository {
  final Map<int, CharacterWeeklyRaidDisplayPreference> _store = {};

  @override
  Future<Map<int, CharacterWeeklyRaidDisplayPreference>> loadAll() async =>
      Map.unmodifiable(_store);

  @override
  Future<void> save(CharacterWeeklyRaidDisplayPreference preference) async {
    if (!preference.isValid) {
      throw ArgumentError.value(preference, 'preference');
    }
    _store[preference.characterId] = CharacterWeeklyRaidDisplayPreference(
      characterId: preference.characterId,
      displayCount: preference.displayCount,
      raidIds: List.unmodifiable(preference.raidIds),
    );
  }

  @override
  Future<void> clear(int characterId) async {
    _store.remove(characterId);
  }
}
