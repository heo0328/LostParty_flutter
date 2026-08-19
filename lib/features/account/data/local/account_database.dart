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

@DriftDatabase(tables: [GameAccounts, AccountCharacters])
class AccountDatabase extends _$AccountDatabase {
  AccountDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lost_party'));

  @override
  int get schemaVersion => 1;

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
        await (delete(
          accountCharacters,
        )..where((table) => table.accountId.equals(accountId))).go();
      }

      final insertedCharacters = <int, String>{};
      for (final character in characters) {
        final existingCharacter =
            existingCharactersByKey[_characterKey(
              character.serverName,
              character.characterName,
            )];
        final characterId = await into(accountCharacters).insert(
          AccountCharactersCompanion.insert(
            accountId: accountId,
            serverName: character.serverName,
            characterName: character.characterName,
            characterLevel: character.characterLevel,
            characterClassName: character.characterClassName,
            itemLevel: Value(character.itemLevel),
            combatPower: Value(existingCharacter?.combatPower),
            isVisible: Value(existingCharacter?.isVisible ?? true),
            displayOrder: Value(existingCharacter?.displayOrder),
            lastSummaryFetchedAt: character.fetchedAt,
          ),
        );
        insertedCharacters[characterId] = character.characterName;
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
