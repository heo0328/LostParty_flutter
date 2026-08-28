import '../entities/character_build_draft.dart';
import '../entities/character_build_snapshot.dart';
import '../entities/character_profile.dart';
import '../entities/character_summary.dart';
import '../entities/local_game_account.dart';
import '../entities/roster_summary_apply_result.dart';

abstract interface class AccountRepository {
  Future<List<CharacterSummary>> fetchCharacters(String characterName);

  Future<CharacterProfile> fetchCharacterProfile(String characterName);

  Future<LocalGameAccount?> loadMainAccount();

  Future<List<LocalGameAccount>> loadAccounts();

  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  });

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

  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
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

  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  });
}

abstract interface class AccountManagementRepository {
  Future<LocalGameAccount> addAccount({
    required String label,
    required String lookupCharacterName,
  });

  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
  });

  Future<void> deleteAccount(int accountId);

  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  });
}
