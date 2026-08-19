import '../entities/character_profile.dart';
import '../entities/character_summary.dart';
import '../entities/local_game_account.dart';

abstract interface class AccountRepository {
  Future<List<CharacterSummary>> fetchCharacters(String characterName);

  Future<CharacterProfile> fetchCharacterProfile(String characterName);

  Future<LocalGameAccount?> loadMainAccount();

  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  });

  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  });

  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  });

  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  });
}
