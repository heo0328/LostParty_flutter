import '../entities/character_profile.dart';
import '../entities/character_summary.dart';
import '../entities/local_game_account.dart';

abstract interface class AccountRepository {
  Future<List<CharacterSummary>> fetchCharacters(String characterName);

  Future<CharacterProfile> fetchCharacterProfile(String characterName);

  Future<LocalGameAccount?> loadMainAccount();
}
