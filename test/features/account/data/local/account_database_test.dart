import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';

void main() {
  late AccountDatabase database;

  setUp(() {
    database = AccountDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('creates an account with a default display limit of six', () async {
    final accountId = await database.createAccount(
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      now: DateTime.utc(2026, 8, 20),
    );

    final account = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(accountId))).getSingle();

    expect(account.label, '메인 계정');
    expect(account.isMain, isTrue);
    expect(account.lookupCharacterName, '이슈아이');
    expect(account.representativeCharacterId, isNull);
    expect(account.displayLimit, 6);
  });

  test(
    'stores representative reconciliation independently of local id',
    () async {
      final accountId = await database.saveMainAccountSnapshot(
        lookupCharacterName: '본캐',
        characters: [_snapshot('본캐', DateTime.utc(2026, 8, 29))],
      );
      await database.markRepresentativeReconciled(
        accountId: accountId,
        serverCharacterId: 'server-character-1',
        now: DateTime.utc(2026, 8, 29, 1),
      );

      final account = await (database.select(
        database.gameAccounts,
      )..where((table) => table.id.equals(accountId))).getSingle();

      expect(account.serverRepresentativeCharacterId, 'server-character-1');
      expect(account.representativeReconciledAt, isNotNull);
    },
  );

  test('adds a sub account with its own representative character', () async {
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐',
      characters: [_snapshot('본캐', DateTime.utc(2026, 8, 24))],
    );

    final subAccountId = await database.addAccountSnapshot(
      label: '레이드 부계정',
      lookupCharacterName: '부캐',
      characters: [
        AccountCharacterSnapshot(
          serverName: '카단',
          characterName: '부캐',
          characterLevel: 70,
          characterClassName: '슬레이어',
          itemLevel: 1700,
          fetchedAt: DateTime.utc(2026, 8, 24),
        ),
      ],
    );

    final account = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(subAccountId))).getSingle();
    final character = await (database.select(
      database.accountCharacters,
    )..where((table) => table.accountId.equals(subAccountId))).getSingle();
    expect(account.label, '레이드 부계정');
    expect(account.isMain, isFalse);
    expect(account.representativeCharacterId, character.id);
  });

  test('rejects registering an already owned game account', () async {
    final fetchedAt = DateTime.utc(2026, 8, 24);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '중복캐릭터',
      characters: [_snapshot('중복캐릭터', fetchedAt)],
    );

    await expectLater(
      database.addAccountSnapshot(
        label: '중복 계정',
        lookupCharacterName: '중복캐릭터',
        characters: [_snapshot('중복캐릭터', fetchedAt)],
      ),
      throwsStateError,
    );
  });

  test('promoting a sub account keeps exactly one main account', () async {
    final fetchedAt = DateTime.utc(2026, 8, 24);
    final mainId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐',
      characters: [_snapshot('본캐', fetchedAt)],
    );
    final subId = await database.addAccountSnapshot(
      label: '부계정',
      lookupCharacterName: '부캐',
      characters: [
        AccountCharacterSnapshot(
          serverName: '카단',
          characterName: '부캐',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          fetchedAt: fetchedAt,
        ),
      ],
    );

    await database.updateAccount(
      accountId: subId,
      label: '새 본계정',
      isMain: true,
    );

    final accounts = await database.select(database.gameAccounts).get();
    expect(accounts.where((account) => account.isMain), hasLength(1));
    expect(
      accounts.singleWhere((account) => account.id == subId).isMain,
      isTrue,
    );
    expect(
      accounts.singleWhere((account) => account.id == mainId).isMain,
      isFalse,
    );
  });

  test('does not allow demoting the current main account directly', () async {
    final mainId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐',
      characters: [_snapshot('본캐', DateTime.utc(2026, 8, 24))],
    );

    await expectLater(
      database.updateAccount(accountId: mainId, label: '본계정', isMain: false),
      throwsStateError,
    );
  });

  test('assigns the next available default sub account label', () async {
    final fetchedAt = DateTime.utc(2026, 8, 24);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐',
      characters: [_snapshot('본캐', fetchedAt)],
    );
    await database.addAccountSnapshot(
      label: '',
      lookupCharacterName: '첫부캐',
      characters: [
        AccountCharacterSnapshot(
          serverName: '카단',
          characterName: '첫부캐',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          fetchedAt: fetchedAt,
        ),
      ],
    );
    await database.addAccountSnapshot(
      label: '',
      lookupCharacterName: '둘째부캐',
      characters: [
        AccountCharacterSnapshot(
          serverName: '아만',
          characterName: '둘째부캐',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          fetchedAt: fetchedAt,
        ),
      ],
    );

    final accounts = await database.select(database.gameAccounts).get();
    expect(
      accounts.map((account) => account.label),
      containsAll(['부계정1', '부계정2']),
    );
  });

  test('rejects a duplicate custom account label', () async {
    final fetchedAt = DateTime.utc(2026, 8, 24);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐',
      characters: [_snapshot('본캐', fetchedAt)],
    );
    await database.addAccountSnapshot(
      label: '레이드용',
      lookupCharacterName: '첫부캐',
      characters: [
        AccountCharacterSnapshot(
          serverName: '카단',
          characterName: '첫부캐',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          fetchedAt: fetchedAt,
        ),
      ],
    );

    await expectLater(
      database.addAccountSnapshot(
        label: '레이드용',
        lookupCharacterName: '둘째부캐',
        characters: [
          AccountCharacterSnapshot(
            serverName: '아만',
            characterName: '둘째부캐',
            characterLevel: 70,
            characterClassName: '바드',
            itemLevel: 1700,
            fetchedAt: fetchedAt,
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test(
    'deletes a sub account and its characters but not the main account',
    () async {
      final fetchedAt = DateTime.utc(2026, 8, 24);
      final mainId = await database.saveMainAccountSnapshot(
        lookupCharacterName: '본캐',
        characters: [_snapshot('본캐', fetchedAt)],
      );
      final subId = await database.addAccountSnapshot(
        label: '',
        lookupCharacterName: '부캐',
        characters: [
          AccountCharacterSnapshot(
            serverName: '카단',
            characterName: '부캐',
            characterLevel: 70,
            characterClassName: '바드',
            itemLevel: 1700,
            fetchedAt: fetchedAt,
          ),
        ],
      );

      await database.deleteAccount(subId);

      expect(await database.select(database.gameAccounts).get(), hasLength(1));
      expect(
        await database.select(database.accountCharacters).get(),
        hasLength(1),
      );
      await expectLater(database.deleteAccount(mainId), throwsStateError);
    },
  );

  test('changes the representative to a character in the account', () async {
    final accountId = await database.createAccount(
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
    );
    final characterId = await database
        .into(database.accountCharacters)
        .insert(
          AccountCharactersCompanion.insert(
            accountId: accountId,
            serverName: '루페온',
            characterName: '이슈아이',
            characterLevel: 70,
            characterClassName: '바드',
            itemLevel: const Value(1766.66),
            lastSummaryFetchedAt: DateTime.utc(2026, 8, 20),
          ),
        );

    await database.setRepresentativeCharacter(
      accountId: accountId,
      characterId: characterId,
    );

    final account = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(accountId))).getSingle();
    expect(account.representativeCharacterId, characterId);
  });

  test('rejects a representative from another account', () async {
    final mainAccountId = await database.createAccount(
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
    );
    final subAccountId = await database.createAccount(
      label: '부계정',
      isMain: false,
      lookupCharacterName: '부계정캐릭터',
    );
    final subCharacterId = await database
        .into(database.accountCharacters)
        .insert(
          AccountCharactersCompanion.insert(
            accountId: subAccountId,
            serverName: '카단',
            characterName: '부계정캐릭터',
            characterLevel: 70,
            characterClassName: '슬레이어',
            lastSummaryFetchedAt: DateTime.utc(2026, 8, 20),
          ),
        );

    await expectLater(
      database.setRepresentativeCharacter(
        accountId: mainAccountId,
        characterId: subCharacterId,
      ),
      throwsArgumentError,
    );
  });

  test('updates the account display limit without an API request', () async {
    final accountId = await database.createAccount(
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
    );

    await database.updateDisplayLimit(accountId: accountId, displayLimit: 8);

    final account = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(accountId))).getSingle();
    expect(account.displayLimit, 8);
  });

  test('updates character visibility for the selected account', () async {
    final accountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', DateTime.utc(2026, 8, 20))],
    );
    final character = await database
        .select(database.accountCharacters)
        .getSingle();

    await database.updateCharacterVisibility(
      accountId: accountId,
      characterId: character.id,
      isVisible: false,
    );

    final updated = await database
        .select(database.accountCharacters)
        .getSingle();
    expect(updated.isVisible, isFalse);
  });

  test('stores character display order for every account character', () async {
    final fetchedAt = DateTime.utc(2026, 8, 20);
    final accountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '첫번째',
      characters: [
        _snapshot('첫번째', fetchedAt),
        _snapshot('두번째', fetchedAt),
        _snapshot('세번째', fetchedAt),
      ],
    );
    final characters = await (database.select(
      database.accountCharacters,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    final reversedIds = characters.reversed
        .map((character) => character.id)
        .toList();

    await database.updateCharacterDisplayOrder(
      accountId: accountId,
      characterIds: reversedIds,
    );

    final ordered = await (database.select(
      database.accountCharacters,
    )..orderBy([(table) => OrderingTerm.asc(table.displayOrder)])).get();
    expect(ordered.map((character) => character.id), reversedIds);
  });

  test('keeps a changed representative when refreshing the snapshot', () async {
    final firstFetchedAt = DateTime.utc(2026, 8, 20);
    final accountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      now: firstFetchedAt,
      characters: [
        _snapshot('조회캐릭터', firstFetchedAt),
        _snapshot('선택대표', firstFetchedAt),
      ],
    );
    final selectedRepresentative = await (database.select(
      database.accountCharacters,
    )..where((table) => table.characterName.equals('선택대표'))).getSingle();
    await database.setRepresentativeCharacter(
      accountId: accountId,
      characterId: selectedRepresentative.id,
    );

    final refreshedAt = DateTime.utc(2026, 8, 20, 1);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      now: refreshedAt,
      characters: [
        _snapshot('조회캐릭터', refreshedAt),
        _snapshot('선택대표', refreshedAt),
      ],
    );

    final account = await database.select(database.gameAccounts).getSingle();
    final representative =
        await (database.select(database.accountCharacters)..where(
              (table) => table.id.equals(account.representativeCharacterId!),
            ))
            .getSingle();
    expect(representative.characterName, '선택대표');
  });

  test(
    'keeps profile and display preferences when refreshing summaries',
    () async {
      final firstFetchedAt = DateTime.utc(2026, 8, 20);
      final accountId = await database.saveMainAccountSnapshot(
        lookupCharacterName: '조회캐릭터',
        now: firstFetchedAt,
        characters: [_snapshot('조회캐릭터', firstFetchedAt)],
      );
      await (database.update(
        database.accountCharacters,
      )..where((table) => table.accountId.equals(accountId))).write(
        const AccountCharactersCompanion(
          combatPower: Value(338229.42),
          isVisible: Value(false),
          displayOrder: Value(3),
        ),
      );

      await database.saveMainAccountSnapshot(
        lookupCharacterName: '조회캐릭터',
        now: DateTime.utc(2026, 8, 20, 1),
        characters: [_snapshot('조회캐릭터', firstFetchedAt)],
      );

      final character = await database
          .select(database.accountCharacters)
          .getSingle();
      expect(character.combatPower, 338229.42);
      expect(character.isVisible, isFalse);
      expect(character.displayOrder, 3);
    },
  );

  test('stores dealer and support snapshots for one character', () async {
    final fetchedAt = DateTime.utc(2026, 8, 20);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt)],
    );
    final character = await database
        .select(database.accountCharacters)
        .getSingle();

    await database.saveCharacterBuildSnapshot(
      characterId: character.id,
      role: 'dealer',
      rawJson: '{"role":"dealer"}',
      itemLevel: 1766.67,
      combatPower: 3404.53,
      capturedAt: fetchedAt,
    );
    await database.saveCharacterBuildSnapshot(
      characterId: character.id,
      role: 'support',
      rawJson: '{"role":"support"}',
      itemLevel: 1766.67,
      combatPower: 3300,
      capturedAt: fetchedAt.add(const Duration(minutes: 1)),
    );

    final snapshots = await database.loadCharacterBuildSnapshots(character.id);
    expect(snapshots.map((snapshot) => snapshot.role), ['dealer', 'support']);
  });

  test('replaces only the snapshot for the same role', () async {
    final fetchedAt = DateTime.utc(2026, 8, 20);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt)],
    );
    final character = await database
        .select(database.accountCharacters)
        .getSingle();

    for (final role in ['dealer', 'support']) {
      await database.saveCharacterBuildSnapshot(
        characterId: character.id,
        role: role,
        rawJson: '{"version":1}',
        itemLevel: 1766.67,
        combatPower: 3300,
        capturedAt: fetchedAt,
      );
    }
    await database.saveCharacterBuildSnapshot(
      characterId: character.id,
      role: 'dealer',
      rawJson: '{"version":2}',
      itemLevel: 1766.67,
      combatPower: 3404.53,
      capturedAt: fetchedAt.add(const Duration(minutes: 1)),
    );

    final snapshots = await database.loadCharacterBuildSnapshots(character.id);
    expect(snapshots, hasLength(2));
    expect(
      snapshots.singleWhere((snapshot) => snapshot.role == 'dealer').rawJson,
      '{"version":2}',
    );
    expect(
      snapshots.singleWhere((snapshot) => snapshot.role == 'support').rawJson,
      '{"version":1}',
    );
  });

  test('keeps role snapshots when refreshing the account', () async {
    final fetchedAt = DateTime.utc(2026, 8, 20);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt)],
    );
    final originalCharacter = await database
        .select(database.accountCharacters)
        .getSingle();
    await database.saveCharacterBuildSnapshot(
      characterId: originalCharacter.id,
      role: 'dealer',
      rawJson: '{"saved":true}',
      itemLevel: 1766.67,
      combatPower: 3404.53,
      capturedAt: fetchedAt,
    );

    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt.add(const Duration(hours: 1)))],
    );

    final refreshedCharacter = await database
        .select(database.accountCharacters)
        .getSingle();
    final snapshots = await database.loadCharacterBuildSnapshots(
      refreshedCharacter.id,
    );
    expect(refreshedCharacter.id, originalCharacter.id);
    expect(snapshots.single.rawJson, '{"saved":true}');
  });

  test(
    'marks a missing roster character without deleting its local data',
    () async {
      final fetchedAt = DateTime.utc(2026, 8, 25);
      final accountId = await database.saveMainAccountSnapshot(
        lookupCharacterName: '대표캐릭터',
        characters: [
          _snapshot('대표캐릭터', fetchedAt),
          _snapshot('사라진캐릭터', fetchedAt),
        ],
      );
      final before = await (database.select(
        database.accountCharacters,
      )..where((table) => table.characterName.equals('사라진캐릭터'))).getSingle();

      await database.saveMainAccountSnapshot(
        lookupCharacterName: '대표캐릭터',
        characters: [
          _snapshot('대표캐릭터', fetchedAt.add(const Duration(days: 1))),
        ],
      );

      final missing = await (database.select(
        database.accountCharacters,
      )..where((table) => table.id.equals(before.id))).getSingle();
      expect(missing.accountId, accountId);
      expect(missing.isRosterMissing, isTrue);
    },
  );

  test(
    'only manually deletes a character marked missing from the roster',
    () async {
      final fetchedAt = DateTime.utc(2026, 8, 25);
      final accountId = await database.saveMainAccountSnapshot(
        lookupCharacterName: '대표캐릭터',
        characters: [
          _snapshot('대표캐릭터', fetchedAt),
          _snapshot('사라진캐릭터', fetchedAt),
        ],
      );
      final characters = await database
          .select(database.accountCharacters)
          .get();
      final active = characters.singleWhere(
        (character) => character.characterName == '대표캐릭터',
      );
      final missing = characters.singleWhere(
        (character) => character.characterName == '사라진캐릭터',
      );
      await database.saveMainAccountSnapshot(
        lookupCharacterName: '대표캐릭터',
        characters: [
          _snapshot('대표캐릭터', fetchedAt.add(const Duration(days: 1))),
        ],
      );

      await expectLater(
        database.deleteMissingCharacter(
          accountId: accountId,
          characterId: active.id,
        ),
        throwsStateError,
      );
      await database.deleteMissingCharacter(
        accountId: accountId,
        characterId: missing.id,
      );
      expect(
        await (database.select(
          database.accountCharacters,
        )..where((table) => table.id.equals(missing.id))).getSingleOrNull(),
        isNull,
      );
    },
  );

  test(
    'stores and restores the full armory fixture as a dealer build',
    () async {
      final rawJson = await File(
        'test/fixtures/lost_ark/character_armory_full.json',
      ).readAsString();
      final fetchedAt = DateTime.utc(2026, 8, 20);
      await database.saveMainAccountSnapshot(
        lookupCharacterName: 'MockCharacter',
        characters: [_snapshot('MockCharacter', fetchedAt)],
      );
      final character = await database
          .select(database.accountCharacters)
          .getSingle();

      await database.saveCharacterBuildSnapshot(
        characterId: character.id,
        role: 'dealer',
        rawJson: rawJson,
        itemLevel: 1766.67,
        combatPower: 3404.53,
        capturedAt: fetchedAt,
      );

      final snapshot = (await database.loadCharacterBuildSnapshots(
        character.id,
      )).single;
      expect(snapshot.role, 'dealer');
      expect(snapshot.rawJson, rawJson);
      expect(snapshot.dataVersion, 1);
    },
  );

  test('binds server account and character IDs atomically', () async {
    final fetchedAt = DateTime.utc(2026, 8, 25);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt), _snapshot('부캐릭터', fetchedAt)],
    );
    final account = await database.select(database.gameAccounts).getSingle();
    final characters = await database.select(database.accountCharacters).get();

    await database.bindServerIdentity(
      localAccountId: account.id,
      serverGameAccountId: ' game-account-1 ',
      serverCharacterIdsByLocalId: {
        for (final character in characters)
          character.id: 'character-${character.id}',
      },
    );

    final storedAccount = await database
        .select(database.gameAccounts)
        .getSingle();
    final storedCharacters = await database
        .select(database.accountCharacters)
        .get();
    expect(storedAccount.serverGameAccountId, 'game-account-1');
    expect(storedAccount.serverOwnershipStatus, 'active');
    expect(
      storedCharacters.map((character) => character.serverCharacterId),
      containsAll(characters.map((character) => 'character-${character.id}')),
    );

    await database.bindServerIdentity(
      localAccountId: account.id,
      serverGameAccountId: 'game-account-1',
      serverCharacterIdsByLocalId: {
        for (final character in characters)
          character.id: 'character-${character.id}',
      },
    );
  });

  test('updates a bound account to ownership lost', () async {
    final now = DateTime.utc(2026, 8, 25);
    final accountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '대표캐릭터',
      characters: [_snapshot('대표캐릭터', now)],
    );
    final character = await database
        .select(database.accountCharacters)
        .getSingle();
    await database.bindServerIdentity(
      localAccountId: accountId,
      serverGameAccountId: 'game-account-1',
      serverCharacterIdsByLocalId: {character.id: 'character-1'},
    );

    await database.updateServerOwnershipStatuses({accountId: 'ownershipLost'});

    final account = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(accountId))).getSingle();
    expect(account.serverOwnershipStatus, 'ownershipLost');
  });

  test('rejects server ID remapping without partial writes', () async {
    final fetchedAt = DateTime.utc(2026, 8, 25);
    await database.saveMainAccountSnapshot(
      lookupCharacterName: '조회캐릭터',
      characters: [_snapshot('조회캐릭터', fetchedAt)],
    );
    final account = await database.select(database.gameAccounts).getSingle();
    final character = await database
        .select(database.accountCharacters)
        .getSingle();
    await database.bindServerIdentity(
      localAccountId: account.id,
      serverGameAccountId: 'game-account-1',
      serverCharacterIdsByLocalId: {character.id: 'character-1'},
    );

    await expectLater(
      database.bindServerIdentity(
        localAccountId: account.id,
        serverGameAccountId: 'game-account-2',
        serverCharacterIdsByLocalId: {character.id: 'character-2'},
      ),
      throwsStateError,
    );
    final storedAccount = await database
        .select(database.gameAccounts)
        .getSingle();
    final storedCharacter = await database
        .select(database.accountCharacters)
        .getSingle();
    expect(storedAccount.serverGameAccountId, 'game-account-1');
    expect(storedCharacter.serverCharacterId, 'character-1');
  });

  test('rejects a character that belongs to another local account', () async {
    final fetchedAt = DateTime.utc(2026, 8, 25);
    final mainAccountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐릭터',
      characters: [_snapshot('본캐릭터', fetchedAt)],
    );
    await database.addAccountSnapshot(
      label: '부계정',
      lookupCharacterName: '부캐릭터',
      characters: [_snapshot('부캐릭터', fetchedAt)],
      now: fetchedAt,
    );
    final foreignCharacter = await (database.select(
      database.accountCharacters,
    )..where((table) => table.accountId.isNotValue(mainAccountId))).getSingle();

    await expectLater(
      database.bindServerIdentity(
        localAccountId: mainAccountId,
        serverGameAccountId: 'game-account-1',
        serverCharacterIdsByLocalId: {foreignCharacter.id: 'character-1'},
      ),
      throwsArgumentError,
    );
    final mainAccount = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(mainAccountId))).getSingle();
    expect(mainAccount.serverGameAccountId, isNull);
  });

  test('rejects duplicate server IDs across local rows', () async {
    final fetchedAt = DateTime.utc(2026, 8, 25);
    final firstAccountId = await database.saveMainAccountSnapshot(
      lookupCharacterName: '본캐릭터',
      characters: [_snapshot('본캐릭터', fetchedAt)],
    );
    final secondAccountId = await database.addAccountSnapshot(
      label: '부계정',
      lookupCharacterName: '부캐릭터',
      characters: [_snapshot('부캐릭터', fetchedAt)],
      now: fetchedAt,
    );
    final characters = await database.select(database.accountCharacters).get();
    final firstCharacter = characters.singleWhere(
      (character) => character.accountId == firstAccountId,
    );
    final secondCharacter = characters.singleWhere(
      (character) => character.accountId == secondAccountId,
    );
    await database.bindServerIdentity(
      localAccountId: firstAccountId,
      serverGameAccountId: 'game-account-1',
      serverCharacterIdsByLocalId: {firstCharacter.id: 'character-1'},
    );

    await expectLater(
      database.bindServerIdentity(
        localAccountId: secondAccountId,
        serverGameAccountId: 'game-account-2',
        serverCharacterIdsByLocalId: {secondCharacter.id: 'character-1'},
      ),
      throwsA(isA<Exception>()),
    );
    final secondAccount = await (database.select(
      database.gameAccounts,
    )..where((table) => table.id.equals(secondAccountId))).getSingle();
    expect(secondAccount.serverGameAccountId, isNull);
  });

  test('party event sync is idempotent and preserves local choices', () async {
    final occurredAt = DateTime.utc(2026, 8, 25);
    await database.syncPartyHistoryEvent(
      eventId: 'event-1',
      playerId: 'player',
      characterId: 'character',
      recruitmentId: 'party',
      raidId: 'serca',
      difficultyId: 'hard',
      cycleKey: '2026-08-26',
      serverStatus: 'completed',
      occurredAt: occurredAt,
    );
    await database.setRaidHistoryVisibility('event-1', false);
    await database.setRaidHistoryLocalOverride('event-1', 'incomplete');
    await database.syncPartyHistoryEvent(
      eventId: 'event-1',
      playerId: 'player',
      characterId: 'character',
      recruitmentId: 'party',
      raidId: 'serca',
      difficultyId: 'hard',
      cycleKey: '2026-08-26',
      serverStatus: 'completionCancelled',
      occurredAt: occurredAt.add(const Duration(minutes: 1)),
    );

    final rows = await database.select(database.raidHistoryEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.serverStatus, 'completionCancelled');
    expect(rows.single.visibility, 'hidden');
    expect(rows.single.localStatusOverride, 'incomplete');
  });

  test('persists raid status filter selection per player', () async {
    await database.saveRaidStatusFilterSelection(
      playerId: 'player-1',
      selectionJson:
          '{"schemaVersion":1,"includePublic":false,"includeGroup":true,"raidIds":["act4"],"difficultyIds":[]}',
      now: DateTime.utc(2026, 9, 2),
    );

    expect(
      await database.loadRaidStatusFilterSelection('player-1'),
      contains('"includeGroup":true'),
    );
    expect(await database.loadRaidStatusFilterSelection('player-2'), isNull);

    await database.saveRaidStatusFilterSelection(
      playerId: 'player-1',
      selectionJson:
          '{"schemaVersion":1,"includePublic":true,"includeGroup":true,"raidIds":[],"difficultyIds":[]}',
      now: DateTime.utc(2026, 9, 2, 1),
    );
    expect(
      await database.loadRaidStatusFilterSelection('player-1'),
      contains('"includePublic":true'),
    );

    await database.saveRaidStatusFilterSelection(
      playerId: 'player-1',
      screenKind: 'recruitmentList',
      selectionJson:
          '{"schemaVersion":1,"includePublic":false,"includeGroup":true,"raidIds":[],"difficultyIds":[]}',
      now: DateTime.utc(2026, 9, 3),
    );
    expect(
      await database.loadRaidStatusFilterSelection('player-1'),
      contains('"includePublic":true'),
    );
    expect(
      await database.loadRaidStatusFilterSelection(
        'player-1',
        screenKind: 'recruitmentList',
      ),
      contains('"includeGroup":true'),
    );
  });
}

AccountCharacterSnapshot _snapshot(String characterName, DateTime fetchedAt) {
  return AccountCharacterSnapshot(
    serverName: '루페온',
    characterName: characterName,
    characterLevel: 70,
    characterClassName: '바드',
    itemLevel: 1766.66,
    fetchedAt: fetchedAt,
  );
}
