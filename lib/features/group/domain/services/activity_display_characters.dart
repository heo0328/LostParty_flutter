import '../../../account/domain/entities/save_activity_characters_command.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../entities/group_request_character.dart';
import '../repositories/group_character_search_repository.dart';

Future<List<GroupRequestCharacter>> loadActivityDisplayCharacters({
  required GroupCharacterSearchRepository searchRepository,
  required String ownerPlayerId,
  ActivityCharactersRepository? activityRepository,
}) async {
  if (activityRepository == null) return const [];
  Set<String> activityIds;
  try {
    activityIds = (await activityRepository.load(
      playerId: ownerPlayerId,
    )).characterIds;
  } on ActivityCharactersSaveException catch (error) {
    if (error.failure == ActivityCharactersSaveFailure.permissionDenied) {
      return const [];
    }
    rethrow;
  }
  if (activityIds.isEmpty) return const [];
  final characters = await searchRepository.loadActiveCharactersForPlayer(
    ownerPlayerId,
  );
  return [
    for (final character in characters)
      if (activityIds.contains(character.characterId)) character,
  ];
}
