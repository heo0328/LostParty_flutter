import 'package:dio/dio.dart';

import '../auth/api_token_store.dart';
import 'lost_ark_api_config.dart';
import 'lost_ark_api_exception.dart';
import 'lost_ark_api_log_interceptor.dart';
import 'api_cooldown.dart';

class LostArkApiClient {
  LostArkApiClient({
    required ApiTokenStore apiTokenStore,
    Dio? dio,
    LostArkApiLogWriter? logWriter,
    ApiCooldown? cooldown,
    this.scopeIdentity,
  }) : _apiTokenStore = apiTokenStore,
       cooldown = cooldown ?? ApiCooldown(),
       _dio = dio ?? Dio(_createBaseOptions()) {
    _applyBaseOptions(_dio.options);
    if (logWriter != null) {
      _dio.interceptors.add(LostArkApiLogInterceptor(write: logWriter));
    }
  }

  final ApiTokenStore _apiTokenStore;
  final Dio _dio;
  final ApiCooldown cooldown;
  final Object? Function()? scopeIdentity;

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final scope = scopeIdentity?.call();
    final token = await _apiTokenStore.read();
    void checkScope() {
      if (scopeIdentity != null && scope != scopeIdentity!()) {
        throw const LostArkApiException(type: LostArkApiErrorType.cancelled);
      }
    }

    checkScope();
    if (token == null) {
      throw const LostArkApiException(type: LostArkApiErrorType.missingToken);
    }
    cooldown.bindToken(token.value);

    try {
      if (cooldown.active) {
        throw LostArkApiException(
          type: LostArkApiErrorType.rateLimited,
          retryAt: cooldown.until,
        );
      }
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            Headers.acceptHeader: Headers.jsonContentType,
            'Authorization': token.authorizationHeaderValue,
          },
        ),
      );
      checkScope();
      if (response.headers.value('x-ratelimit-remaining') == '0') {
        cooldown.observe(
          providerRetryAt(
            response.headers.value('x-ratelimit-reset'),
            cooldown.now(),
          ),
        );
      }

      final data = response.data;
      if (data == null) {
        throw const LostArkApiException(
          type: LostArkApiErrorType.invalidResponse,
        );
      }

      return data;
    } on DioException catch (error) {
      checkScope();
      if (error.response?.statusCode == 429) {
        cooldown.observe(
          providerRetryAt(
            error.response?.headers.value('x-ratelimit-reset'),
            cooldown.now(),
          ),
        );
        throw LostArkApiException(
          type: LostArkApiErrorType.rateLimited,
          statusCode: 429,
          retryAt: cooldown.until,
        );
      }
      throw LostArkApiException.fromDio(error);
    }
  }

  static BaseOptions _createBaseOptions() {
    return BaseOptions();
  }

  static void _applyBaseOptions(BaseOptions options) {
    options
      ..baseUrl = LostArkApiConfig.baseUrl
      ..connectTimeout = LostArkApiConfig.connectTimeout
      ..sendTimeout = LostArkApiConfig.sendTimeout
      ..receiveTimeout = LostArkApiConfig.receiveTimeout
      ..responseType = ResponseType.json;
  }
}
