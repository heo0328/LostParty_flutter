import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/services/activity_character_source.dart';

export '../../../account/domain/services/activity_character_source.dart'
    show charactersMatchingActivity, loadActivityCharacterIds;

Future<Set<String>?> loadRaidActivityCharacterIds({
  required ActivityCharactersRepository? repository,
  required String? playerId,
}) => loadActivityCharacterIds(repository: repository, playerId: playerId);

Iterable<LocalAccountCharacter> raidCandidateCharacters(
  LocalGameAccount account,
  Set<String>? activityCharacterIds,
) => charactersMatchingActivity(
  account,
  activityCharacterIds,
  fallback: account.visibleCharacters,
);
