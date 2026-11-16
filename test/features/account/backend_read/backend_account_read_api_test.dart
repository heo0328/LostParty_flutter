import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import '../../../support/server_account_read_fakes.dart';

void main() {
  test('public HTTP request omits Authorization on the actual wire', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final connection = Dio(
      BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'),
    );
    final guest = ReadSessionFake()..change(authenticated: false);
    final request = server.first.then((r) async {
      final authorization = r.headers.value(HttpHeaders.authorizationHeader);
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(<String, dynamic>{}));
      await r.response.close();
      return authorization;
    });
    try {
      await DioBackendAccountReadApi(
        connection,
        guest,
      ).requestPublic('/v1/raid-cycle');
      expect(await request, isNull);
    } finally {
      connection.close(force: true);
      guest.dispose();
      await server.close(force: true);
    }
  });
  late Dio dio;
  late ReadSessionFake session;
  late DioBackendAccountReadApi api;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'));
    session = ReadSessionFake();
    api = DioBackendAccountReadApi(dio, session);
  });
  tearDown(() {
    dio.close();
    session.dispose();
  });
  Matcher code(String expected) => isA<AccountReadException>().having(
    (error) => error.code,
    'code',
    expected,
  );
  void fail(
    RequestOptions options,
    RequestInterceptorHandler handler,
    int status,
    String error,
  ) => handler.reject(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        headers: Headers.fromMap({
          'retry-after': ['2'],
        }),
        data: {
          'error': {
            'code': error,
            'request_id': 'safe-request-id',
            'message': 'never display raw upstream message',
          },
        },
      ),
    ),
  );

  test(
    'only ACCESS_EXPIRED is refreshed and GET retried once with new bearer',
    () async {
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.method, 'GET');
            expect(options.queryParameters['limit'], 100);
            expect(
              options.headers['Authorization'],
              requests == 1 ? 'Bearer test-access' : 'Bearer refreshed-access',
            );
            if (requests == 1) {
              fail(options, handler, 401, 'ACCESS_EXPIRED');
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: registrationPageJson(empty: true),
                ),
              );
            }
          },
        ),
      );
      expect((await api.registrations()).items, isEmpty);
      expect(requests, 2);
      expect(session.refreshCalls, 1);
      expect(session.rejects, 0);
    },
  );
  test(
    'public search does not acquire a token or reject a member session',
    () async {
      session.change(authenticated: false);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers.containsKey('Authorization'), isFalse);
            fail(options, handler, 401, 'ACCESS_EXPIRED');
          },
        ),
      );
      await expectLater(
        api.requestPublic('/v2/raid-rooms/search', method: 'POST', body: {}),
        throwsA(code('ACCESS_EXPIRED')),
      );
      expect(session.accessCalls, 0);
      expect(session.refreshCalls, 0);
      expect(session.rejects, 0);
    },
  );
  test(
    'public transport cannot bypass private endpoint authentication',
    () async {
      session.change(authenticated: false);
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (_, handler) {
            requests++;
            handler.reject(DioException(requestOptions: RequestOptions()));
          },
        ),
      );
      await expectLater(
        api.requestPublic('/v1/me/game-accounts'),
        throwsA(code('AUTH_REQUIRED')),
      );
      expect(requests, 0);
      expect(session.accessCalls, 0);
    },
  );
  test(
    'late public result is discarded after authentication changes',
    () async {
      session.change(authenticated: false);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            session.change(authenticated: true);
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: {}),
            );
          },
        ),
      );
      await expectLater(
        api.requestPublic('/v1/raid-cycle'),
        throwsA(code('STALE_READ')),
      );
    },
  );
  test('a second expired response does not enter a refresh loop', () async {
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          fail(options, handler, 401, 'ACCESS_EXPIRED');
        },
      ),
    );
    await expectLater(api.registrations(), throwsA(code('ACCESS_EXPIRED')));
    expect(requests, 2);
    expect(session.refreshCalls, 1);
    expect(session.rejects, 1);
  });
  for (final entry in [
    (401, 'SESSION_REVOKED', 1),
    (403, 'ACCOUNT_DISABLED', 1),
    (403, 'OWNERSHIP_REQUIRED', 0),
  ]) {
    test('${entry.$2} has its own session policy', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              fail(options, handler, entry.$1, entry.$2),
        ),
      );
      await expectLater(api.registrations(), throwsA(code(entry.$2)));
      expect(session.refreshCalls, 0);
      expect(session.rejects, entry.$3);
      expect(session.isAuthenticated, entry.$3 == 0);
    });
  }
  test('guest never obtains access or sends HTTP', () async {
    session.change(authenticated: false);
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (_, handler) {
          requests++;
          handler.reject(DioException(requestOptions: RequestOptions()));
        },
      ),
    );
    await expectLater(api.registrations(), throwsA(code('LOGIN_REQUIRED')));
    expect(requests, 0);
    expect(session.accessCalls, 0);
  });
  test(
    'malformed success is not converted to a successful empty page',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'items': []},
            ),
          ),
        ),
      );
      await expectLater(api.registrations(), throwsA(code('INVALID_RESPONSE')));
    },
  );
  test(
    '503 exposes safe code/request ID and wait but not raw message',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              fail(options, handler, 503, 'UPSTREAM_UNAVAILABLE'),
        ),
      );
      try {
        await api.registrations();
        expect(false, isTrue, reason: 'expected failure');
      } on AccountReadException catch (error) {
        expect(error.code, 'UPSTREAM_UNAVAILABLE');
        expect(error.requestId, 'safe-request-id');
        expect(error.retryAfter, const Duration(seconds: 2));
        expect(error.toString(), isNot(contains('upstream message')));
      }
    },
  );
}
