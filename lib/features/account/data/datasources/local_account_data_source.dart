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
}
