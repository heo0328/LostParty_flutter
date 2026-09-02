import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';

Future<Set<String>?> loadRaidActivityCharacterIds({
  required ActivityCharactersRepository? repository,
  required String? playerId,
}) async {
  if (repository == null || playerId == null || playerId.isEmpty) {
    return null;
  }
  final loaded = await repository.load(playerId: playerId);
  return loaded.characterIds;
}

Iterable<LocalAccountCharacter> raidCandidateCharacters(
  LocalGameAccount account,
  Set<String>? activityCharacterIds,
) {
  if (activityCharacterIds == null) {
    return account.visibleCharacters;
  }
  return account.characters.where((character) {
    final serverId = character.serverCharacterId;
    return !character.isRosterMissing &&
        serverId != null &&
        activityCharacterIds.contains(serverId);
  });
}
