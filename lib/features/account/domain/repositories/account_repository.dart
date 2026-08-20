import '../entities/character_build_draft.dart';
import '../entities/character_build_snapshot.dart';
import '../entities/character_profile.dart';
import '../entities/character_summary.dart';
import '../entities/local_game_account.dart';

abstract interface class AccountRepository {
  Future<List<CharacterSummary>> fetchCharacters(String characterName);

  Future<CharacterProfile> fetchCharacterProfile(String characterName);

  Future<LocalGameAccount?> loadMainAccount();

  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  });

  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  );

  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  });

  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  });

  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  });

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
