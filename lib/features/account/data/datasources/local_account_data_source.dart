import 'package:drift/drift.dart';

import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../local/account_database.dart';

class LocalAccountDataSource {
  LocalAccountDataSource({required AccountDatabase database})
    : _database = database;

  final AccountDatabase _database;

  Future<int> saveMainAccount({
    required String lookupCharacterName,
    required List<CharacterSummary> characters,
    DateTime? fetchedAt,
  }) {
    final timestamp = fetchedAt ?? DateTime.now();
    return _database.saveMainAccountSnapshot(
      lookupCharacterName: lookupCharacterName,
      now: timestamp,
      characters: characters
          .map(
            (character) => AccountCharacterSnapshot(
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: character.itemLevel,
              fetchedAt: timestamp,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> saveCharacterProfile(CharacterProfile profile) async {
    final account = await (_database.select(
      _database.gameAccounts,
    )..where((table) => table.isMain.equals(true))).getSingleOrNull();
    if (account == null) {
      return;
    }

    await (_database.update(_database.accountCharacters)..where(
          (table) =>
              table.accountId.equals(account.id) &
              table.characterName.equals(profile.characterName),
        ))
        .write(
          AccountCharactersCompanion(
            serverName: Value(profile.serverName),
            characterLevel: Value(profile.characterLevel),
            characterClassName: Value(profile.characterClassName),
            itemLevel: Value(profile.itemLevel),
            combatPower: Value(profile.combatPower),
          ),
        );
  }

  Future<LocalGameAccount?> loadMainAccount() async {
    final account = await (_database.select(
      _database.gameAccounts,
    )..where((table) => table.isMain.equals(true))).getSingleOrNull();
    if (account == null) {
      return null;
    }

    final characters = await (_database.select(
      _database.accountCharacters,
    )..where((table) => table.accountId.equals(account.id))).get();

    return LocalGameAccount(
      id: account.id,
      label: account.label,
      isMain: account.isMain,
      lookupCharacterName: account.lookupCharacterName,
      representativeCharacterId: account.representativeCharacterId,
      displayLimit: account.displayLimit,
      characters: characters
          .map(
            (character) => LocalAccountCharacter(
              id: character.id,
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: character.itemLevel,
              combatPower: character.combatPower,
              isVisible: character.isVisible,
              displayOrder: character.displayOrder,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) {
    return _database.setRepresentativeCharacter(
      accountId: accountId,
      characterId: characterId,
    );
  }

  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) {
    return _database.updateDisplayLimit(
      accountId: accountId,
      displayLimit: displayLimit,
    );
  }

  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) {
    return _database.updateCharacterVisibility(
      accountId: accountId,
      characterId: characterId,
      isVisible: isVisible,
    );
  }

  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) {
    return _database.updateCharacterDisplayOrder(
      accountId: accountId,
      characterIds: characterIds,
    );
  }
}
