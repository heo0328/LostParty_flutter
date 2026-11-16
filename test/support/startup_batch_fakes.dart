import 'package:dio/dio.dart';

/// Shared in-memory wire adapter, not an HTTP fallback in application code.
Map<String, dynamic>? startupBatchReply(
  RequestOptions request,
  Map<String, dynamic> Function(RequestOptions) single,
  DateTime now,
) {
  Map<String, dynamic> error(DioException e) {
    final detail = (e.response?.data as Map?)?['error'] as Map?;
    return {
      'code': detail?['code'] ?? 'SERVICE_UNAVAILABLE',
      'message': detail?['code'] ?? 'SERVICE_UNAVAILABLE',
      'request_id': 'fixture-request',
      'retry_after_seconds': null,
    };
  }

  if (request.path == '/v2/me/characters/personal-profiles') {
    return {
      'evaluated_at': now.toUtc().toIso8601String(),
      'items': [
        for (final id in request.queryParameters['character_id'] as List)
          () {
            try {
              return {
                'character_id': id,
                'status': 200,
                'error': null,
                'profile': single(
                  request.copyWith(
                    path: '/v2/me/characters/$id/personal-profile',
                    queryParameters: {},
                  ),
                ),
              };
            } on DioException catch (e) {
              if (e.response == null) rethrow;
              return {
                'character_id': id,
                'status': e.response!.statusCode,
                'profile': null,
                'error': error(e),
              };
            }
          }(),
      ],
    };
  }
  return null;
}
