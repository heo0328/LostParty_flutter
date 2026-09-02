import '../entities/local_game_account.dart';
import '../repositories/activity_characters_repository.dart';

Future<Set<String>?> loadActivityCharacterIds({
  required ActivityCharactersRepository? repository,
  required String? playerId,
}) async {
  if (repository == null || playerId == null || playerId.isEmpty) {
    return null;
  }
  final loaded = await repository.load(playerId: playerId);
  return loaded.characterIds;
}

Iterable<LocalAccountCharacter> charactersMatchingActivity(
  LocalGameAccount account,
  Set<String>? activityCharacterIds, {
  Iterable<LocalAccountCharacter>? fallback,
}) {
  if (activityCharacterIds == null) {
    return fallback ?? account.characters;
  }
  return account.characters.where((character) {
    final serverId = character.serverCharacterId;
    return !character.isRosterMissing &&
        serverId != null &&
        activityCharacterIds.contains(serverId);
  });
}
