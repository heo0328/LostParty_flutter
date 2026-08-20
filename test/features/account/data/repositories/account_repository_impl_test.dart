import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/datasources/local_account_data_source.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/data/repositories/account_repository_impl.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/shared/game_catalog/data/mappers/game_catalog_mapper.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';
import 'package:lost_party/shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';

void main() {
  const lookupCharacterName = '이슈아이';
  final requestPath =
      '/characters/${Uri.encodeComponent(lookupCharacterName)}/siblings';

  late AccountDatabase database;
  late Dio dio;
  late DioAdapter dioAdapter;
  late AccountRepositoryImpl repository;
  late GameCatalog catalog;

  setUpAll(() async {
    catalog = const GameCatalogMapper().fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
              await File(
                'assets/game_catalog/game_catalog.v1.json',
              ).readAsString(),
            )
            as Map,
      ),
    );
  });

  setUp(() async {
    database = AccountDatabase(NativeDatabase.memory());
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    final tokenStore = _InMemoryApiTokenStore();
    await tokenStore.write(ApiToken('jwt-value'));
    repository = AccountRepositoryImpl(
      remoteDataSource: LostArkCharacterRemoteDataSource(
        apiClient: LostArkApiClient(apiTokenStore: tokenStore, dio: dio),
      ),
      localDataSource: LocalAccountDataSource(
        database: database,
        gameCatalogRepository: _FakeGameCatalogRepository(catalog),
      ),
    );
  });

  tearDown(() => database.close());

  test('saves siblings as the main account snapshot', () async {
    dioAdapter.onGet(
      requestPath,
      (server) => server.reply(200, [
        {
          'ServerName': '루페온',
          'CharacterName': lookupCharacterName,
          'CharacterLevel': 70,
          'CharacterClassName': '바드',
          'ItemAvgLevel': '1,766.66',
        },
        {
          'ServerName': '카단',
          'CharacterName': '다른캐릭터',
          'CharacterLevel': 70,
          'CharacterClassName': '슬레이어',
          'ItemAvgLevel': '1,700.00',
        },
      ]),
    );

    final result = await repository.fetchCharacters(lookupCharacterName);

    final account = await database.select(database.gameAccounts).getSingle();
    final storedCharacters = await database
        .select(database.accountCharacters)
        .get();
    final representative = storedCharacters.singleWhere(
      (character) => character.id == account.representativeCharacterId,
    );

    expect(result, hasLength(2));
    expect(account.isMain, isTrue);
    expect(account.lookupCharacterName, lookupCharacterName);
    expect(account.displayLimit, 6);
    expect(storedCharacters, hasLength(2));
    expect(representative.characterName, lookupCharacterName);
  });

  test(
    'loads the main account and subaccounts with their own characters',
    () async {
      final now = DateTime.utc(2026, 8, 20);
      final mainId = await database.createAccount(
        label: '메인 계정',
        isMain: true,
        lookupCharacterName: '메인바드',
        now: now,
      );
      final subId = await database.createAccount(
        label: '부계정',
        isMain: false,
        lookupCharacterName: '부계정소서',
        now: now,
      );
      for (final entry in [(mainId, '메인바드'), (subId, '부계정소서')]) {
        await database
            .into(database.accountCharacters)
            .insert(
              AccountCharactersCompanion.insert(
                accountId: entry.$1,
                serverName: '루페온',
                characterName: entry.$2,
                characterLevel: 70,
                characterClassName: '바드',
                itemLevel: const Value(1750),
                lastSummaryFetchedAt: now,
              ),
            );
      }

      final accounts = await repository.loadAccounts();

      expect(accounts.map((account) => account.label), ['메인 계정', '부계정']);
      expect(accounts.first.characters.single.characterName, '메인바드');
      expect(accounts.last.characters.single.characterName, '부계정소서');
    },
  );

  test('creates an analyzed draft without changing local data', () async {
    dioAdapter.onGet(
      requestPath,
      (server) => server.reply(200, [
        {
          'ServerName': '루페온',
          'CharacterName': lookupCharacterName,
          'CharacterLevel': 70,
          'CharacterClassName': '바드',
          'ItemAvgLevel': '1,766.66',
        },
      ]),
    );
    await repository.fetchCharacters(lookupCharacterName);
    final character = await database
        .select(database.accountCharacters)
        .getSingle();
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/lost_ark/character_armory_full.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    (fixture['ArmoryProfile'] as Map<String, dynamic>)['CharacterName'] =
        lookupCharacterName;
    dioAdapter.onGet(
      '/armories/characters/${Uri.encodeComponent(lookupCharacterName)}',
      (server) => server.reply(200, fixture),
    );

    final accountBefore = await repository.loadMainAccount();
    final draft = await repository.createCharacterBuildDraft(
      characterId: character.id,
      characterName: lookupCharacterName,
    );

    expect(draft.characterId, character.id);
    expect(draft.profile.characterName, lookupCharacterName);
    expect(draft.analysis.runeCount, 8);
    expect(draft.analysis.gemEffects, hasLength(11));
    expect(
      draft.analysis.catalogDetection!.status,
      CharacterBuildDetectionStatus.detected,
    );
    expect(draft.analysis.catalogDetection!.branchDisplayName, '딜바드');
    expect(
      draft.analysis.catalogDetection!.detectedRole,
      CharacterBuildRole.dealer,
    );
    expect(jsonDecode(draft.rawJson), isA<Map<String, dynamic>>());
    expect(draft.fetchedAt, isNotNull);
    expect(await database.loadCharacterBuildSnapshots(character.id), isEmpty);
    expect(
      (await repository.loadMainAccount())!.characters.single.combatPower,
      accountBefore!.characters.single.combatPower,
    );
  });

  test('commits only the selected role and updates the profile', () async {
    final character = await _prepareCharacterAndArmory(
      repository: repository,
      database: database,
      dioAdapter: dioAdapter,
      lookupCharacterName: lookupCharacterName,
      requestPath: requestPath,
    );
    await database.saveCharacterBuildSnapshot(
      characterId: character.id,
      role: CharacterBuildRole.dealer.name,
      rawJson: '{}',
      itemLevel: 1600,
      combatPower: 80000,
      capturedAt: DateTime(2025),
    );

    final draft = await repository.createCharacterBuildDraft(
      characterId: character.id,
      characterName: lookupCharacterName,
    );
    final snapshot = await repository.commitCharacterBuildDraft(
      draft: draft,
      role: CharacterBuildRole.support,
    );

    expect(snapshot.role, CharacterBuildRole.support);
    expect(snapshot.rawJson, draft.rawJson);
    expect(
      draft.fetchedAt.difference(snapshot.capturedAt).inSeconds.abs(),
      lessThan(1),
    );
    expect(
      snapshot.analysis.catalogDetection!.detectedRole,
      CharacterBuildRole.dealer,
    );
    final stored = await database.loadCharacterBuildSnapshots(character.id);
    expect(stored, hasLength(2));
    expect(
      stored
          .singleWhere((row) => row.role == CharacterBuildRole.dealer.name)
          .rawJson,
      '{}',
    );
    expect(
      stored
          .singleWhere((row) => row.role == CharacterBuildRole.support.name)
          .rawJson,
      draft.rawJson,
    );
    expect(
      (await repository.loadMainAccount())!.characters.single.combatPower,
      draft.profile.combatPower,
    );
  });
}

Future<AccountCharacter> _prepareCharacterAndArmory({
  required AccountRepositoryImpl repository,
  required AccountDatabase database,
  required DioAdapter dioAdapter,
  required String lookupCharacterName,
  required String requestPath,
}) async {
  dioAdapter.onGet(
    requestPath,
    (server) => server.reply(200, [
      {
        'ServerName': '루페온',
        'CharacterName': lookupCharacterName,
        'CharacterLevel': 70,
        'CharacterClassName': '바드',
        'ItemAvgLevel': '1,766.66',
      },
    ]),
  );
  await repository.fetchCharacters(lookupCharacterName);
  final character = await database
      .select(database.accountCharacters)
      .getSingle();
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/lost_ark/character_armory_full.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  (fixture['ArmoryProfile'] as Map<String, dynamic>)['CharacterName'] =
      lookupCharacterName;
  dioAdapter.onGet(
    '/armories/characters/${Uri.encodeComponent(lookupCharacterName)}',
    (server) => server.reply(200, fixture),
  );
  return character;
}

class _FakeGameCatalogRepository implements GameCatalogRepository {
  const _FakeGameCatalogRepository(this.catalog);

  final GameCatalog catalog;

  @override
  Future<GameCatalog> loadCatalog() async => catalog;
}

class _InMemoryApiTokenStore implements ApiTokenStore {
  ApiToken? _token;

  @override
  Future<ApiToken?> read() async => _token;

  @override
  Future<void> write(ApiToken token) async {
    _token = token;
  }

  @override
  Future<void> delete() async {
    _token = null;
  }
}
