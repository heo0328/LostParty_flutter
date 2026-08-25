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

  TextColumn get serverGameAccountId => text().nullable()();

  TextColumn get serverOwnershipStatus => text().nullable()();

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

  TextColumn get serverCharacterId => text().nullable()();

  IntColumn get accountId =>
      integer().references(GameAccounts, #id, onDelete: KeyAction.cascade)();

  TextColumn get serverName => text()();

  TextColumn get characterName => text()();

  IntColumn get characterLevel => integer()();

  TextColumn get characterClassName => text()();

  RealColumn get itemLevel => real().nullable()();

  RealColumn get combatPower => real().nullable()();

  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  BoolColumn get isRosterMissing =>
      boolean().withDefault(const Constant(false))();

  IntColumn get displayOrder => integer().nullable()();

  TextColumn get preferredRole => text().nullable()();

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

class RaidHistoryEntries extends Table {
  TextColumn get eventId => text()();
  TextColumn get playerId => text()();
  TextColumn get characterId => text()();
  TextColumn get recruitmentId => text()();
  TextColumn get raidId => text()();
  TextColumn get difficultyId => text()();
  TextColumn get cycleKey => text()();
  TextColumn get serverStatus => text()();
  TextColumn get localStatusOverride => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('partyEvent'))();
  TextColumn get visibility => text().withDefault(const Constant('visible'))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

@DriftDatabase(
  tables: [
    GameAccounts,
    AccountCharacters,
    CharacterBuildSnapshots,
    RaidHistoryEntries,
  ],
)
class AccountDatabase extends _$AccountDatabase {
  AccountDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lost_party'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createServerIdIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(characterBuildSnapshots);
      }
      if (from < 3) {
        await migrator.addColumn(
          accountCharacters,
          accountCharacters.preferredRole,
        );
      }
      if (from < 4) {
        await migrator.addColumn(
          gameAccounts,
          gameAccounts.serverGameAccountId,
        );
        await migrator.addColumn(
          accountCharacters,
          accountCharacters.serverCharacterId,
        );
        await _createServerIdIndexes();
      }
      if (from < 5) {
        await migrator.addColumn(
          accountCharacters,
          accountCharacters.isRosterMissing,
        );
      }
      if (from < 6) {
        await migrator.addColumn(
          gameAccounts,
          gameAccounts.serverOwnershipStatus,
        );
      }
      if (from < 7) {
        await migrator.createTable(raidHistoryEntries);
      }
    },
  );

  Future<void> syncPartyHistoryEvent({
    required String eventId,
    required String playerId,
    required String characterId,
    required String recruitmentId,
    required String raidId,
    required String difficultyId,
    required String cycleKey,
    required String serverStatus,
    required DateTime occurredAt,
    DateTime? syncedAt,
  }) async {
    if (serverStatus != 'completed' &&
        serverStatus != 'incompleteEnded' &&
        serverStatus != 'completionCancelled') {
      throw ArgumentError.value(serverStatus, 'serverStatus');
    }
    final existing = await (select(
      raidHistoryEntries,
    )..where((table) => table.eventId.equals(eventId))).getSingleOrNull();
    final timestamp = syncedAt ?? DateTime.now();
    if (existing == null) {
      await into(raidHistoryEntries).insert(
        RaidHistoryEntriesCompanion.insert(
          eventId: eventId,
          playerId: playerId,
          characterId: characterId,
          recruitmentId: recruitmentId,
          raidId: raidId,
          difficultyId: difficultyId,
          cycleKey: cycleKey,
          serverStatus: serverStatus,
          occurredAt: occurredAt,
          syncedAt: timestamp,
        ),
      );
      return;
    }
    await (update(
      raidHistoryEntries,
    )..where((table) => table.eventId.equals(eventId))).write(
      RaidHistoryEntriesCompanion(
        serverStatus: Value(serverStatus),
        occurredAt: Value(occurredAt),
        syncedAt: Value(timestamp),
      ),
    );
  }

  Future<void> setRaidHistoryVisibility(String eventId, bool visible) =>
      (update(raidHistoryEntries)
            ..where((table) => table.eventId.equals(eventId)))
          .write(
            RaidHistoryEntriesCompanion(
              visibility: Value(visible ? 'visible' : 'hidden'),
            ),
          );

  Future<void> setRaidHistoryLocalOverride(
    String eventId,
    String? status,
  ) {
    if (status != null && status != 'completed' && status != 'incomplete') {
      throw ArgumentError.value(status, 'status');
    }
    return (update(raidHistoryEntries)
          ..where((table) => table.eventId.equals(eventId)))
        .write(
          RaidHistoryEntriesCompanion(localStatusOverride: Value(status)),
        );
  }

  Future<void> _createServerIdIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX game_accounts_server_game_account_id '
      'ON game_accounts (server_game_account_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX account_characters_server_character_id '
      'ON account_characters (server_character_id)',
    );
  }

  Future<void> bindServerIdentity({
    required int localAccountId,
    required String serverGameAccountId,
    required Map<int, String> serverCharacterIdsByLocalId,
  }) {
    final normalizedAccountId = _requireServerId(
      serverGameAccountId,
      'serverGameAccountId',
    );
    final normalizedCharacterIds = serverCharacterIdsByLocalId.map(
      (localId, serverId) =>
          MapEntry(localId, _requireServerId(serverId, 'serverCharacterId')),
    );
    if (normalizedCharacterIds.values.toSet().length !=
        normalizedCharacterIds.length) {
      throw ArgumentError.value(
        serverCharacterIdsByLocalId,
        'serverCharacterIdsByLocalId',
        'Server character IDs must be unique.',
      );
    }

    return transaction(() async {
      final account = await (select(
        gameAccounts,
      )..where((table) => table.id.equals(localAccountId))).getSingleOrNull();
      if (account == null) {
        throw ArgumentError.value(
          localAccountId,
          'localAccountId',
          'Local game account does not exist.',
        );
      }
      _rejectRemap(
        currentId: account.serverGameAccountId,
        requestedId: normalizedAccountId,
        argumentName: 'serverGameAccountId',
      );

      final localCharacterIds = normalizedCharacterIds.keys.toList();
      final characters = localCharacterIds.isEmpty
          ? const <AccountCharacter>[]
          : await (select(accountCharacters)..where(
                  (table) =>
                      table.id.isIn(localCharacterIds) &
                      table.accountId.equals(localAccountId),
                ))
                .get();
      if (characters.length != localCharacterIds.length) {
        throw ArgumentError.value(
          localCharacterIds,
          'serverCharacterIdsByLocalId',
          'Every local character must belong to the selected account.',
        );
      }
      for (final character in characters) {
        _rejectRemap(
          currentId: character.serverCharacterId,
          requestedId: normalizedCharacterIds[character.id]!,
          argumentName: 'serverCharacterId',
        );
      }

      await (update(
        gameAccounts,
      )..where((table) => table.id.equals(localAccountId))).write(
        GameAccountsCompanion(
          serverGameAccountId: Value(normalizedAccountId),
          serverOwnershipStatus: const Value('active'),
        ),
      );
      for (final entry in normalizedCharacterIds.entries) {
        await (update(
          accountCharacters,
        )..where((table) => table.id.equals(entry.key))).write(
          AccountCharactersCompanion(serverCharacterId: Value(entry.value)),
        );
      }
    });
  }

  Future<void> updateServerOwnershipStatuses(
    Map<int, String> statusesByLocalAccountId,
  ) {
    return transaction(() async {
      for (final entry in statusesByLocalAccountId.entries) {
        if (entry.value != 'active' && entry.value != 'ownershipLost') {
          throw ArgumentError.value(entry.value, 'status');
        }
        await (update(
          gameAccounts,
        )..where((table) => table.id.equals(entry.key))).write(
          GameAccountsCompanion(
            serverOwnershipStatus: Value(entry.value),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  static String _requireServerId(String value, String argumentName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'Must not be blank.');
    }
    return normalized;
  }

  static void _rejectRemap({
    required String? currentId,
    required String requestedId,
    required String argumentName,
  }) {
    if (currentId != null && currentId != requestedId) {
      throw StateError(
        '$argumentName is already bound and cannot be remapped.',
      );
    }
  }

  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required String role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
    int dataVersion = 1,
  }) {
    return transaction(
      () => _saveCharacterBuildSnapshot(
        characterId: characterId,
        role: role,
        rawJson: rawJson,
        itemLevel: itemLevel,
        combatPower: combatPower,
        capturedAt: capturedAt,
        dataVersion: dataVersion,
      ),
    );
  }

  Future<void> commitCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required String serverName,
    required int characterLevel,
    required String characterClassName,
    required String role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
    int dataVersion = 1,
  }) {
    return transaction(() async {
      final character = await (select(
        accountCharacters,
      )..where((table) => table.id.equals(characterId))).getSingleOrNull();
      if (character == null || character.characterName != characterName) {
        throw ArgumentError.value(
          characterId,
          'characterId',
          'Draft character does not match the stored character.',
        );
      }
      await _saveCharacterBuildSnapshot(
        characterId: characterId,
        role: role,
        rawJson: rawJson,
        itemLevel: itemLevel,
        combatPower: combatPower,
        capturedAt: capturedAt,
        dataVersion: dataVersion,
      );
      await (update(
        accountCharacters,
      )..where((table) => table.id.equals(characterId))).write(
        AccountCharactersCompanion(
          serverName: Value(serverName),
          characterLevel: Value(characterLevel),
          characterClassName: Value(characterClassName),
          itemLevel: Value(itemLevel),
          combatPower: Value(combatPower),
        ),
      );
    });
  }

  Future<void> _saveCharacterBuildSnapshot({
    required int characterId,
    required String role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
    required int dataVersion,
  }) async {
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

  Future<int> addAccountSnapshot({
    required String label,
    required String lookupCharacterName,
    required List<AccountCharacterSnapshot> characters,
    DateTime? now,
  }) {
    return transaction(() async {
      if (characters.isEmpty) {
        throw ArgumentError.value(
          characters,
          'characters',
          'Account must contain at least one character.',
        );
      }

      final storedAccounts = await select(gameAccounts).get();
      final normalizedLabel = _resolveAccountLabel(
        requestedLabel: label,
        storedAccounts: storedAccounts,
      );

      final incomingKeys = characters
          .map(
            (character) =>
                _characterKey(character.serverName, character.characterName),
          )
          .toSet();
      final storedCharacters = await select(accountCharacters).get();
      final overlaps = storedCharacters.any(
        (character) => incomingKeys.contains(
          _characterKey(character.serverName, character.characterName),
        ),
      );
      if (overlaps) {
        throw StateError('This game account is already registered.');
      }

      final accountId = await createAccount(
        label: normalizedLabel,
        isMain: false,
        lookupCharacterName: lookupCharacterName,
        now: now,
      );
      int? representativeId;
      for (var index = 0; index < characters.length; index++) {
        final character = characters[index];
        final characterId = await into(accountCharacters).insert(
          AccountCharactersCompanion.insert(
            accountId: accountId,
            serverName: character.serverName,
            characterName: character.characterName,
            characterLevel: character.characterLevel,
            characterClassName: character.characterClassName,
            itemLevel: Value(character.itemLevel),
            displayOrder: Value(index),
            lastSummaryFetchedAt: character.fetchedAt,
          ),
        );
        if (character.characterName == lookupCharacterName) {
          representativeId = characterId;
        }
        representativeId ??= characterId;
      }
      await (update(
        gameAccounts,
      )..where((table) => table.id.equals(accountId))).write(
        GameAccountsCompanion(
          representativeCharacterId: Value(representativeId),
          displayLimit: Value(characters.length < 6 ? characters.length : 6),
          updatedAt: Value(now ?? DateTime.now()),
        ),
      );
      return accountId;
    });
  }

  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
    DateTime? now,
  }) {
    return transaction(() async {
      final account = await (select(
        gameAccounts,
      )..where((table) => table.id.equals(accountId))).getSingleOrNull();
      if (account == null) {
        throw ArgumentError.value(accountId, 'accountId', 'Account not found.');
      }
      final storedAccounts = await select(gameAccounts).get();
      final normalizedLabel = _resolveAccountLabel(
        requestedLabel: label.trim().isEmpty ? account.label : label,
        storedAccounts: storedAccounts,
        excludedAccountId: accountId,
      );
      if (!isMain && account.isMain) {
        throw StateError(
          'Promote another account instead of removing the main account.',
        );
      }
      final timestamp = now ?? DateTime.now();
      if (isMain && !account.isMain) {
        await (update(
          gameAccounts,
        )..where((table) => table.isMain.equals(true))).write(
          GameAccountsCompanion(
            isMain: const Value(false),
            updatedAt: Value(timestamp),
          ),
        );
      }
      await (update(
        gameAccounts,
      )..where((table) => table.id.equals(accountId))).write(
        GameAccountsCompanion(
          label: Value(normalizedLabel),
          isMain: Value(isMain),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }

  Future<void> deleteAccount(int accountId) {
    return transaction(() async {
      final account = await (select(
        gameAccounts,
      )..where((table) => table.id.equals(accountId))).getSingleOrNull();
      if (account == null) {
        throw ArgumentError.value(accountId, 'accountId', 'Account not found.');
      }
      if (account.isMain) {
        throw StateError('The main account cannot be deleted.');
      }
      final characters = await (select(
        accountCharacters,
      )..where((table) => table.accountId.equals(accountId))).get();
      final characterIds = characters.map((character) => character.id).toList();
      if (characterIds.isNotEmpty) {
        await (delete(
          characterBuildSnapshots,
        )..where((table) => table.characterId.isIn(characterIds))).go();
      }
      await (delete(
        accountCharacters,
      )..where((table) => table.accountId.equals(accountId))).go();
      await (delete(
        gameAccounts,
      )..where((table) => table.id.equals(accountId))).go();
    });
  }

  String _resolveAccountLabel({
    required String requestedLabel,
    required List<GameAccount> storedAccounts,
    int? excludedAccountId,
  }) {
    final usedLabels = storedAccounts
        .where((account) => account.id != excludedAccountId)
        .map((account) => account.label.trim().toLowerCase())
        .toSet();
    final requested = requestedLabel.trim();
    if (requested.isNotEmpty) {
      if (usedLabels.contains(requested.toLowerCase())) {
        throw StateError('The account label is already in use.');
      }
      return requested;
    }
    var sequence = 1;
    while (usedLabels.contains('부계정$sequence')) {
      sequence++;
    }
    return '부계정$sequence';
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

  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  }) {
    return transaction(() async {
      final character =
          await (select(accountCharacters)..where(
                (table) =>
                    table.id.equals(characterId) &
                    table.accountId.equals(accountId),
              ))
              .getSingleOrNull();
      if (character == null || !character.isRosterMissing) {
        throw StateError('Only a missing roster character can be deleted.');
      }
      await (delete(
        accountCharacters,
      )..where((table) => table.id.equals(characterId))).go();
    });
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

  Future<void> setPreferredCharacterRole({
    required int characterId,
    required String role,
  }) async {
    final updatedRows =
        await (update(accountCharacters)
              ..where((table) => table.id.equals(characterId)))
            .write(AccountCharactersCompanion(preferredRole: Value(role)));
    if (updatedRows != 1) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'Character not found.',
      );
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
              isRosterMissing: const Value(false),
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
          await (update(
            accountCharacters,
          )..where((table) => table.id.equals(existingCharacter.id))).write(
            const AccountCharactersCompanion(isRosterMissing: Value(true)),
          );
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
