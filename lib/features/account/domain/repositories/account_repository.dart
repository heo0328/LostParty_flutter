import '../entities/character_summary.dart';

abstract interface class AccountRepository {
  Future<List<CharacterSummary>> fetchCharacters(String characterName);
}
