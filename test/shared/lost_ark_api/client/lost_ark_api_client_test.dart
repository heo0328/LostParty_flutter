import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_config.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';

void main() {
  const testPath = '/test';

  late Dio dio;
  late DioAdapter dioAdapter;
  late _InMemoryApiTokenStore tokenStore;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    tokenStore = _InMemoryApiTokenStore();
  });

  LostArkApiClient createClient({List<String>? logs}) {
    return LostArkApiClient(
      apiTokenStore: tokenStore,
      dio: dio,
      logWriter: logs?.add,
    );
  }

  test('does not start a request when the token is missing', () async {
    var requestStarted = false;
    dioAdapter.onGet(
      testPath,
      (server) => server.replyCallback(200, (options) {
        requestStarted = true;
        return {'ok': true};
      }),
    );

    await expectLater(
      createClient().get<Map<String, dynamic>>(testPath),
      throwsA(
        isA<LostArkApiException>().having(
          (error) => error.type,
          'type',
          LostArkApiErrorType.missingToken,
        ),
      ),
    );
    expect(requestStarted, isFalse);
  });

  test('applies configuration and authorization headers', () async {
    await tokenStore.write(ApiToken('jwt-value'));
    dioAdapter.onGet(
      testPath,
      (server) => server.replyCallback(200, (options) {
        expect(options.headers['Authorization'], 'bearer jwt-value');
        expect(options.headers[Headers.acceptHeader], Headers.jsonContentType);
        expect(options.connectTimeout, LostArkApiConfig.connectTimeout);
        expect(options.sendTimeout, LostArkApiConfig.sendTimeout);
        expect(options.receiveTimeout, LostArkApiConfig.receiveTimeout);
        return {'ok': true};
      }),
    );

    final result = await createClient().get<Map<String, dynamic>>(testPath);

    expect(result, {'ok': true});
  });

  for (final errorCase in <(int, LostArkApiErrorType)>[
    (401, LostArkApiErrorType.unauthorized),
    (404, LostArkApiErrorType.notFound),
    (429, LostArkApiErrorType.rateLimited),
    (500, LostArkApiErrorType.server),
  ]) {
    test('maps HTTP ${errorCase.$1} responses', () async {
      await tokenStore.write(ApiToken('jwt-value'));
      dioAdapter.onGet(
        testPath,
        (server) => server.reply(errorCase.$1, {'error': true}),
      );

      await expectLater(
        createClient().get<Map<String, dynamic>>(testPath),
        throwsA(
          isA<LostArkApiException>()
              .having((error) => error.type, 'type', errorCase.$2)
              .having((error) => error.statusCode, 'statusCode', errorCase.$1),
        ),
      );
    });
  }

  test('maps timeout errors', () async {
    await tokenStore.write(ApiToken('jwt-value'));
    dioAdapter.onGet(
      testPath,
      (server) => server.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: testPath),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );

    await expectLater(
      createClient().get<Map<String, dynamic>>(testPath),
      throwsA(
        isA<LostArkApiException>().having(
          (error) => error.type,
          'type',
          LostArkApiErrorType.timeout,
        ),
      ),
    );
  });

  test('maps null response data as an invalid response', () async {
    await tokenStore.write(ApiToken('jwt-value'));
    dioAdapter.onGet(testPath, (server) => server.reply(204, null));

    await expectLater(
      createClient().get<Map<String, dynamic>>(testPath),
      throwsA(
        isA<LostArkApiException>().having(
          (error) => error.type,
          'type',
          LostArkApiErrorType.invalidResponse,
        ),
      ),
    );
  });

  test('diagnostic logs never include the token or headers', () async {
    const secretToken = 'secret-jwt-value';
    final logs = <String>[];
    await tokenStore.write(ApiToken(secretToken));
    dioAdapter.onGet(testPath, (server) => server.reply(200, {'ok': true}));

    await createClient(logs: logs).get<Map<String, dynamic>>(testPath);

    expect(logs, isNotEmpty);
    expect(logs.join(), isNot(contains(secretToken)));
    expect(logs.join(), isNot(contains('Authorization')));
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
