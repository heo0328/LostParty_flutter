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
  if (request.path == '/v2/me/role-summary-batches') {
    return {
      'items': [
        for (final item in (request.data as Map)['items'] as List)
          () {
            final id = item['character_id'],
                role = item['role'],
                command = item['command_id'];
            final body = Map<String, dynamic>.from(item as Map)
              ..remove('character_id')
              ..remove('role')
              ..remove('command_id');
            final identity = {
              'character_id': id,
              'role': role,
              'command_id': command,
            };
            try {
              return {
                ...identity,
                'status': 200,
                'error': null,
                'result': single(
                  request.copyWith(
                    path: '/v2/me/characters/$id/role-summaries/$role',
                    method: 'PUT',
                    data: body,
                    queryParameters: {},
                    headers: {...request.headers, 'Idempotency-Key': command},
                  ),
                ),
              };
            } on DioException catch (e) {
              if (e.response == null) rethrow;
              return {
                ...identity,
                'status': e.response!.statusCode,
                'result': null,
                'error': error(e),
              };
            }
          }(),
      ],
    };
  }
  return null;
}
