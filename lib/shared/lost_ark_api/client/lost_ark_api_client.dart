import 'package:dio/dio.dart';

import '../auth/api_token_store.dart';
import 'lost_ark_api_config.dart';
import 'lost_ark_api_exception.dart';
import 'lost_ark_api_log_interceptor.dart';

class LostArkApiClient {
  LostArkApiClient({
    required ApiTokenStore apiTokenStore,
    Dio? dio,
    LostArkApiLogWriter? logWriter,
  }) : _apiTokenStore = apiTokenStore,
       _dio = dio ?? Dio(_createBaseOptions()) {
    _applyBaseOptions(_dio.options);
    if (logWriter != null) {
      _dio.interceptors.add(LostArkApiLogInterceptor(write: logWriter));
    }
  }

  final ApiTokenStore _apiTokenStore;
  final Dio _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final token = await _apiTokenStore.read();
    if (token == null) {
      throw const LostArkApiException(type: LostArkApiErrorType.missingToken);
    }

    try {
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

      final data = response.data;
      if (data == null) {
        throw const LostArkApiException(
          type: LostArkApiErrorType.invalidResponse,
        );
      }

      return data;
    } on DioException catch (error) {
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
