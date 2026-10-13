import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/backend_app.dart';
import 'package:lost_party/features/auth/data/backend_auth_api.dart';
import 'package:lost_party/features/auth/domain/backend_auth_models.dart';

import 'auth_session_controller_test.dart'
    show tokenJson, userJson, initialTime;

void main() {
  test(
    'login submits agreed DTO without subject/user/role fabrication',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      RequestOptions? sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            sent = request;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  ...tokenJson(initialTime),
                  'user': userJson(),
                  'is_new_user': true,
                },
              ),
            );
          },
        ),
      );
      final login = await DioBackendAuthApi(dio).login(
        transactionId: 'transaction',
        secret: 'secret',
        proof: 'proof',
        remember: false,
      );
      expect(sent!.path, '/v1/auth/google');
      expect(sent!.method, 'POST');
      expect(sent!.data, {
        'transaction_id': 'transaction',
        'transaction_secret': 'secret',
        'google_id_token': 'proof',
        'remember_me': false,
      });
      expect(login.isNewUser, isTrue);
    },
  );
  test(
    'native tokens/request bodies are removed from surfaced transport errors',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(
              DioException(
                requestOptions: request,
                message: 'private-proof',
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 409,
                  data: {
                    'error': {
                      'code': 'REFRESH_RECOVERY_EXPIRED',
                      'message': 'private-proof',
                      'request_id': 'id',
                    },
                  },
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        DioBackendAuthApi(dio).refresh('private-refresh', 'private-request-id'),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.code, 'code', 'REFRESH_RECOVERY_EXPIRED')
              .having(
                (error) => error.toString(),
                'redacted',
                isNot(contains('private-')),
              ),
        ),
      );
    },
  );
  test('logout accepts agreed204 empty body', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) =>
            handler.resolve(Response(requestOptions: request, statusCode: 204)),
      ),
    );
    await DioBackendAuthApi(dio).logout('refresh');
  });
  test('release forbids HTTP while debug supports runtime-selected hosts', () {
    expect(allowedAuthBaseUrl('http://10.0.2.2:8000', debug: true), isTrue);
    expect(allowedAuthBaseUrl('http://10.0.2.2:8000', debug: false), isFalse);
    expect(allowedAuthBaseUrl('http://example.com', debug: true), isTrue);
    expect(allowedAuthBaseUrl('https://api.example.com', debug: false), isTrue);
    expect(
      allowedAuthBaseUrl('https://user:password@api.example.com', debug: true),
      isFalse,
    );
  });
}
