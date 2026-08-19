import 'package:dio/dio.dart';

enum LostArkApiErrorType {
  missingToken,
  unauthorized,
  notFound,
  rateLimited,
  timeout,
  network,
  cancelled,
  server,
  invalidResponse,
  unknown,
}

class LostArkApiException implements Exception {
  const LostArkApiException({required this.type, this.statusCode});

  factory LostArkApiException.fromDio(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final type = switch (statusCode) {
      401 => LostArkApiErrorType.unauthorized,
      404 => LostArkApiErrorType.notFound,
      429 => LostArkApiErrorType.rateLimited,
      _ when statusCode != null && statusCode >= 500 && statusCode <= 599 =>
        LostArkApiErrorType.server,
      _ => _mapDioExceptionType(exception.type),
    };

    return LostArkApiException(type: type, statusCode: statusCode);
  }

  final LostArkApiErrorType type;
  final int? statusCode;

  static LostArkApiErrorType _mapDioExceptionType(
    DioExceptionType exceptionType,
  ) {
    return switch (exceptionType) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => LostArkApiErrorType.timeout,
      DioExceptionType.connectionError => LostArkApiErrorType.network,
      DioExceptionType.cancel => LostArkApiErrorType.cancelled,
      DioExceptionType.badResponse => LostArkApiErrorType.invalidResponse,
      _ => LostArkApiErrorType.unknown,
    };
  }

  @override
  String toString() {
    return 'LostArkApiException(type: $type, statusCode: $statusCode)';
  }
}
