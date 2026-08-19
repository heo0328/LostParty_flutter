import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'account_database.g.dart';

class AccountCharacterSnapshot {
  const AccountCharacterSnapshot({
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    required this.itemLevel,
    required this.fetchedAt,
  });

  final String serverName;
  final String characterName;
  final int characterLevel;
  final String characterClassName;
  final double? itemLevel;
  final DateTime fetchedAt;
}

class GameAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text()();

  BoolColumn get isMain => boolean().withDefault(const Constant(false))();

  TextColumn get lookupCharacterName => text()();

  IntColumn get representativeCharacterId => integer().nullable()();

  IntColumn get displayLimit => integer().withDefault(const Constant(6))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

class AccountCharacters extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId =>
      integer().references(GameAccounts, #id, onDelete: KeyAction.cascade)();

  TextColumn get serverName => text()();

  TextColumn get characterName => text()();

  IntColumn get characterLevel => integer()();

  TextColumn get characterClassName => text()();

  RealColumn get itemLevel => real().nullable()();

  RealColumn get combatPower => real().nullable()();

  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  IntColumn get displayOrder => integer().nullable()();

  DateTimeColumn get lastSummaryFetchedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId, serverName, characterName},
  ];
}

@DataClassName('CharacterBuildSnapshotRow')
class CharacterBuildSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get characterId => integer().references(
    AccountCharacters,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get role => text()();

  TextColumn get rawJson => text()();

  RealColumn get itemLevel => real().nullable()();

  RealColumn get combatPower => real().nullable()();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get dataVersion => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {characterId, role},
  ];
}

@DriftDatabase(
  tables: [GameAccounts, AccountCharacters, CharacterBuildSnapshots],
)
class AccountDatabase extends _$AccountDatabase {
  AccountDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lost_party'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(characterBuildSnapshots);
      }
    },
  );

  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required String role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
    int dataVersion = 1,
  }) {
    return transaction(() async {
      if (role != 'dealer' && role != 'support') {
        throw ArgumentError.value(role, 'role', 'Unsupported build role.');
      }
      final character = await (select(
        accountCharacters,
      )..where((table) => table.id.equals(characterId))).getSingleOrNull();
      if (character == null) {
        throw ArgumentError.value(
          characterId,
          'characterId',
          'Character not found.',
        );
      }

      final existing =
          await (select(characterBuildSnapshots)..where(
                (table) =>
                    table.characterId.equals(characterId) &
                    table.role.equals(role),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await into(characterBuildSnapshots).insert(
          CharacterBuildSnapshotsCompanion.insert(
            characterId: characterId,
            role: role,
            rawJson: rawJson,
            itemLevel: Value(itemLevel),
            combatPower: Value(combatPower),
            capturedAt: capturedAt,
            dataVersion: Value(dataVersion),
          ),
        );
        return;
      }

      await (update(
        characterBuildSnapshots,
      )..where((table) => table.id.equals(existing.id))).write(
        CharacterBuildSnapshotsCompanion(
          rawJson: Value(rawJson),
          itemLevel: Value(itemLevel),
          combatPower: Value(combatPower),
          capturedAt: Value(capturedAt),
          dataVersion: Value(dataVersion),
        ),
      );
    });
  }

  Future<List<CharacterBuildSnapshotRow>> loadCharacterBuildSnapshots(
    int characterId,
  ) {
    return (select(characterBuildSnapshots)
          ..where((table) => table.characterId.equals(characterId))
          ..orderBy([(table) => OrderingTerm.asc(table.role)]))
        .get();
  }

  Future<int> createAccount({
    required String label,
    required bool isMain,
    required String lookupCharacterName,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return into(gameAccounts).insert(
      GameAccountsCompanion.insert(
        label: label,
        isMain: Value(isMain),
        lookupCharacterName: lookupCharacterName,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
    DateTime? now,
  }) async {
    final character =
        await (select(accountCharacters)..where(
              (table) =>
                  table.id.equals(characterId) &
                  table.accountId.equals(accountId),
            ))
            .getSingleOrNull();

    if (character == null) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'Representative character must belong to the account.',
      );
    }

    final updatedRows =
        await (update(
          gameAccounts,
        )..where((table) => table.id.equals(accountId))).write(
          GameAccountsCompanion(
            representativeCharacterId: Value(characterId),
            updatedAt: Value(now ?? DateTime.now()),
          ),
        );

    if (updatedRows != 1) {
      throw ArgumentError.value(accountId, 'accountId', 'Account not found.');
    }
  }

  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
    DateTime? now,
  }) async {
    if (displayLimit < 1) {
      throw ArgumentError.value(
        displayLimit,
        'displayLimit',
        'Display limit must be at least 1.',
      );
    }

    final updatedRows =
        await (update(
          gameAccounts,
        )..where((table) => table.id.equals(accountId))).write(
          GameAccountsCompanion(
            displayLimit: Value(displayLimit),
            updatedAt: Value(now ?? DateTime.now()),
          ),
        );

    if (updatedRows != 1) {
      throw ArgumentError.value(accountId, 'accountId', 'Account not found.');
    }
  }

  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) async {
    final updatedRows =
        await (update(accountCharacters)..where(
              (table) =>
                  table.id.equals(characterId) &
                  table.accountId.equals(accountId),
            ))
            .write(AccountCharactersCompanion(isVisible: Value(isVisible)));

    if (updatedRows != 1) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'Character not found in the account.',
      );
    }
  }

  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) {
    return transaction(() async {
      final storedCharacters = await (select(
        accountCharacters,
      )..where((table) => table.accountId.equals(accountId))).get();
      final storedIds = storedCharacters
          .map((character) => character.id)
          .toSet();
      if (characterIds.length != storedIds.length ||
          !storedIds.containsAll(characterIds)) {
        throw ArgumentError.value(
          characterIds,
          'characterIds',
          'Display order must contain every character in the account once.',
        );
      }

      for (var index = 0; index < characterIds.length; index++) {
        await (update(accountCharacters)
              ..where((table) => table.id.equals(characterIds[index])))
            .write(AccountCharactersCompanion(displayOrder: Value(index)));
      }
    });
  }

  Future<int> saveMainAccountSnapshot({
    required String lookupCharacterName,
    required List<AccountCharacterSnapshot> characters,
    DateTime? now,
  }) {
    return transaction(() async {
      final timestamp = now ?? DateTime.now();
      final existingAccount = await (select(
        gameAccounts,
      )..where((table) => table.isMain.equals(true))).getSingleOrNull();
      final existingCharacters = existingAccount == null
          ? const <AccountCharacter>[]
          : await (select(
                  accountCharacters,
                )..where((table) => table.accountId.equals(existingAccount.id)))
                .get();
      final existingCharactersByKey = {
        for (final character in existingCharacters)
          _characterKey(character.serverName, character.characterName):
              character,
      };

      String? previousRepresentativeName;
      if (existingAccount?.representativeCharacterId case final id?) {
        previousRepresentativeName =
            await (select(accountCharacters)
                  ..where((table) => table.id.equals(id)))
                .map((row) => row.characterName)
                .getSingleOrNull();
      }

      final accountId =
          existingAccount?.id ??
          await createAccount(
            label: '메인 계정',
            isMain: true,
            lookupCharacterName: lookupCharacterName,
            now: timestamp,
          );

      if (existingAccount != null) {
        await (update(
          gameAccounts,
        )..where((table) => table.id.equals(accountId))).write(
          GameAccountsCompanion(
            lookupCharacterName: Value(lookupCharacterName),
            updatedAt: Value(timestamp),
          ),
        );
      }

      final insertedCharacters = <int, String>{};
      final incomingCharacterKeys = <String>{};
      for (final character in characters) {
        final key = _characterKey(
          character.serverName,
          character.characterName,
        );
        incomingCharacterKeys.add(key);
        final existingCharacter = existingCharactersByKey[key];
        final int characterId;
        if (existingCharacter == null) {
          characterId = await into(accountCharacters).insert(
            AccountCharactersCompanion.insert(
              accountId: accountId,
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: Value(character.itemLevel),
              lastSummaryFetchedAt: character.fetchedAt,
            ),
          );
        } else {
          characterId = existingCharacter.id;
          await (update(
            accountCharacters,
          )..where((table) => table.id.equals(existingCharacter.id))).write(
            AccountCharactersCompanion(
              characterLevel: Value(character.characterLevel),
              characterClassName: Value(character.characterClassName),
              itemLevel: Value(character.itemLevel),
              lastSummaryFetchedAt: Value(character.fetchedAt),
            ),
          );
        }
        insertedCharacters[characterId] = character.characterName;
      }

      for (final existingCharacter in existingCharacters) {
        final key = _characterKey(
          existingCharacter.serverName,
          existingCharacter.characterName,
        );
        if (!incomingCharacterKeys.contains(key)) {
          await (delete(
            accountCharacters,
          )..where((table) => table.id.equals(existingCharacter.id))).go();
        }
      }

      final representativeName =
          previousRepresentativeName ?? lookupCharacterName;
      int? representativeId;
      for (final entry in insertedCharacters.entries) {
        if (entry.value == representativeName) {
          representativeId = entry.key;
          break;
        }
      }

      if (representativeId == null &&
          representativeName != lookupCharacterName) {
        for (final entry in insertedCharacters.entries) {
          if (entry.value == lookupCharacterName) {
            representativeId = entry.key;
            break;
          }
        }
      }

      if (representativeId == null) {
        throw StateError(
          'The representative character is missing from the account snapshot.',
        );
      }

      await setRepresentativeCharacter(
        accountId: accountId,
        characterId: representativeId,
        now: timestamp,
      );
      return accountId;
    });
  }

  String _characterKey(String serverName, String characterName) {
    return '$serverName\u0000$characterName';
  }
}
