import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';

void main() {
  const characterName = '이슈아이';
  final requestPath =
      '/characters/${Uri.encodeComponent(characterName)}/siblings';

  late Dio dio;
  late DioAdapter dioAdapter;
  late LostArkCharacterRemoteDataSource dataSource;

  setUp(() async {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);

    final tokenStore = _InMemoryApiTokenStore();
    await tokenStore.write(ApiToken('jwt-value'));

    dataSource = LostArkCharacterRemoteDataSource(
      apiClient: LostArkApiClient(apiTokenStore: tokenStore, dio: dio),
    );
  });

  test('fetches and decodes sibling characters', () async {
    dioAdapter.onGet(
      requestPath,
      (server) => server.reply(200, [
        {
          'ServerName': '루페온',
          'CharacterName': characterName,
          'CharacterLevel': 70,
          'CharacterClassName': '바드',
          'ItemAvgLevel': '1,766.66',
        },
      ]),
    );

    final result = await dataSource.fetchSiblings('  $characterName  ');

    expect(result, hasLength(1));
    expect(result.single.serverName, '루페온');
    expect(result.single.characterName, characterName);
    expect(result.single.characterLevel, 70);
    expect(result.single.characterClassName, '바드');
    expect(result.single.itemAvgLevel, '1,766.66');
  });

  test('returns an empty list for an empty API response', () async {
    dioAdapter.onGet(requestPath, (server) => server.reply(200, []));

    final result = await dataSource.fetchSiblings(characterName);

    expect(result, isEmpty);
  });

  test('rejects an empty character name before requesting', () async {
    await expectLater(dataSource.fetchSiblings('   '), throwsArgumentError);
  });

  test('maps an invalid list item to an invalid response error', () async {
    dioAdapter.onGet(
      requestPath,
      (server) => server.reply(200, ['invalid-item']),
    );

    await expectLater(
      dataSource.fetchSiblings(characterName),
      throwsA(
        isA<LostArkApiException>().having(
          (error) => error.type,
          'type',
          LostArkApiErrorType.invalidResponse,
        ),
      ),
    );
  });

  test('maps a missing required field to an invalid response error', () async {
    dioAdapter.onGet(
      requestPath,
      (server) => server.reply(200, [
        {
          'ServerName': '루페온',
          'CharacterName': characterName,
          'CharacterLevel': 70,
          'ItemAvgLevel': '1,766.66',
        },
      ]),
    );

    await expectLater(
      dataSource.fetchSiblings(characterName),
      throwsA(
        isA<LostArkApiException>().having(
          (error) => error.type,
          'type',
          LostArkApiErrorType.invalidResponse,
        ),
      ),
    );
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
