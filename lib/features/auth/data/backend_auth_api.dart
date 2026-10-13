import 'package:dio/dio.dart';

import '../domain/backend_auth_models.dart';
import '../domain/auth_repository.dart';

class DioBackendAuthApi implements BackendAuthApi {
  DioBackendAuthApi(this._dio);
  final Dio _dio;

  @override
  Future<AuthChallenge> challenge(String secretHash) => _decode(
    () async => AuthChallenge.fromJson(
      await _request(
        'POST',
        '/v1/auth/google/challenges',
        body: {'transaction_secret_hash': secretHash},
      ),
    ),
  );
  @override
  Future<AuthLogin> login({
    required String transactionId,
    required String secret,
    required String proof,
    required bool remember,
  }) => _decode(
    () async => AuthLogin.fromJson(
      await _request(
        'POST',
        '/v1/auth/google',
        body: {
          'transaction_id': transactionId,
          'transaction_secret': secret,
          'google_id_token': proof,
          'remember_me': remember,
        },
      ),
    ),
  );
  @override
  Future<AuthTokens> refresh(String token, String requestId) => _decode(
    () async => AuthTokens.fromJson(
      await _request(
        'POST',
        '/v1/auth/refresh',
        body: {'refresh_token': token, 'refresh_request_id': requestId},
      ),
    ),
  );
  @override
  Future<AuthUser> me(String access) => _decode(
    () async =>
        AuthUser.fromJson(await _request('GET', '/v1/me', access: access)),
  );
  @override
  Future<AuthSession> session(String access) => _decode(
    () async => AuthSession.fromJson(
      await _request('GET', '/v1/auth/session', access: access),
    ),
  );
  @override
  Future<void> logout(String refresh) async {
    await _request(
      'POST',
      '/v1/auth/logout',
      body: {'refresh_token': refresh},
      noContent: true,
    );
  }

  Future<T> _decode<T>(Future<T> Function() parse) async {
    try {
      return await parse();
    } on FormatException {
      throw const AuthApiException('INVALID_RESPONSE');
    } on TypeError {
      throw const AuthApiException('INVALID_RESPONSE');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? access,
    bool noContent = false,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {if (access != null) 'Authorization': 'Bearer $access'},
        ),
      );
      if (noContent) {
        if (response.statusCode != 204) {
          throw const AuthApiException('INVALID_RESPONSE');
        }
        return {};
      }
      if (response.data is! Map<String, dynamic>) {
        throw const AuthApiException('INVALID_RESPONSE');
      }
      return response.data! as Map<String, dynamic>;
    } on DioException catch (error) {
      final response = error.response;
      final payload = response?.data;
      final apiError = payload is Map ? payload['error'] : null;
      final code = apiError is Map && apiError['code'] is String
          ? apiError['code'] as String
          : (response == null ? 'NETWORK_UNAVAILABLE' : 'INVALID_RESPONSE');
      final seconds = int.tryParse(
        response?.headers.value('retry-after') ?? '',
      );
      // Never expose DioException/requestOptions: they contain Google evidence/tokens.
      throw AuthApiException(
        code,
        status: response?.statusCode,
        retryAfter: seconds != null && seconds >= 0
            ? Duration(seconds: seconds)
            : null,
      );
    }
  }
}
