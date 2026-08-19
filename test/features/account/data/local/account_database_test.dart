import 'package:drift/drift.dart' hide isNull;
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
