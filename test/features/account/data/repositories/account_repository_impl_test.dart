import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/datasources/local_account_data_source.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/data/repositories/account_repository_impl.dart';
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
      localDataSource: LocalAccountDataSource(database: database),
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
