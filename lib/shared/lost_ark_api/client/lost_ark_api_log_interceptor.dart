import 'package:dio/dio.dart';

typedef LostArkApiLogWriter = void Function(String message);

class LostArkApiLogInterceptor extends Interceptor {
  LostArkApiLogInterceptor({required LostArkApiLogWriter write})
    : _write = write;

  final LostArkApiLogWriter _write;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _write('Lost Ark API request: ${options.method}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _write('Lost Ark API response: ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _write('Lost Ark API error: ${err.response?.statusCode ?? err.type.name}');
    handler.next(err);
  }
}
