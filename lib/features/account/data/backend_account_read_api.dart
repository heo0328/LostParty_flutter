import '../../../../shared/diagnostics/load_timing.dart';
import 'package:dio/dio.dart';
import '../../../../shared/lost_ark_api/client/api_cooldown.dart';

import '../../auth/domain/backend_auth_models.dart';
import '../domain/account_read_session.dart';
import '../domain/server_account_models.dart';
import '../domain/server_account_read_repository.dart';
import '../domain/server_registration_api.dart';

class DioBackendAccountReadApi
    implements BackendAccountReadApi, BackendRegistrationApi {
  const DioBackendAccountReadApi(this.dio, this.session, {this.cooldown});
  final ApiCooldown? cooldown;
  final Dio dio;
  final AccountReadSession session;

  @override
  Future<ServerRegistrationPage> registrations({String? cursor}) => _decode(
    () async => ServerRegistrationPage.fromJson(
      await _get('/v1/me/game-accounts', cursor: cursor),
    ),
  );

  @override
  Future<ServerCharactersResponse> characters(
    String registrationId, {
    String? cursor,
  }) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(registrationId)) {
      throw const AccountReadException('INVALID_REGISTRATION_ID');
    }
    return _decode(
      () async => ServerCharactersResponse.fromJson(
        await _get(
          '/v1/me/game-accounts/$registrationId/characters',
          cursor: cursor,
        ),
      ),
    );
  }

  Future<T> _decode<T>(Future<T> Function() decode) async {
    try {
      return await decode();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<Map<String, dynamic>> _get(String path, {String? cursor}) async =>
      (await request(path, query: {'limit': 100, 'cursor': ?cursor}))!;

  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    final scope = accountReadScope(session);
    if (cooldown?.active == true &&
        (path.endsWith('/refresh') || path.endsWith('/preview'))) {
      throw AccountReadException(
        'UPSTREAM_RATE_LIMITED',
        status: 503,
        retryAfter: Duration(seconds: cooldown!.seconds),
        retryAt: cooldown!.until,
      );
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final access = await session.accessToken();
        requireAccountReadScope(session, scope);
        final response = await LoadTiming.http(
          () => dio.request<Object?>(
            path,
            queryParameters: query,
            data: body,
            options: Options(
              followRedirects: false,
              method: method,
              receiveTimeout: path.endsWith('/combat-power/refresh')
                  ? const Duration(seconds: 30)
                  : null,
              headers: {
                'Authorization': 'Bearer $access',
                'Idempotency-Key': ?idempotencyKey,
              },
            ),
          ),
        );
        requireAccountReadScope(session, scope);
        if (response.statusCode == 204 && expectedStatus == 204) return null;
        if (response.statusCode != expectedStatus ||
            response.data is! Map<String, dynamic>) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        return response.data! as Map<String, dynamic>;
      } on DioException catch (error) {
        requireAccountReadScope(session, scope);
        final response = error.response;
        final data = response?.data;
        final detail = data is Map ? data['error'] : null;
        final rawCode = detail is Map ? detail['code'] : null;
        final code =
            rawCode is String &&
                RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(rawCode)
            ? rawCode
            : response == null
            ? 'NETWORK_UNAVAILABLE'
            : 'INVALID_RESPONSE';
        if (attempt == 0 &&
            response?.statusCode == 401 &&
            code == 'ACCESS_EXPIRED') {
          try {
            await session.refresh();
          } on AuthApiException catch (failure) {
            throw AccountReadException(
              failure.code,
              status: failure.status,
              retryAfter: failure.retryAfter,
            );
          }
          requireAccountReadScope(session, scope);
          continue;
        }
        if ((response?.statusCode == 401 && code != 'INVALID_RESPONSE') ||
            (response?.statusCode == 403 && code == 'ACCOUNT_DISABLED')) {
          await session.reject(
            scope.generation,
            AuthApiException(code, status: response?.statusCode),
          );
        }
        final rawId = detail is Map ? detail['request_id'] : null;
        final id =
            rawId is String && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(rawId)
            ? rawId
            : null;
        final headerSeconds = int.tryParse(
          response?.headers.value('retry-after') ?? '',
        );
        final bodySeconds = detail is Map
            ? detail['retry_after_seconds']
            : null;
        final candidateSeconds =
            bodySeconds is int && bodySeconds >= 1 && bodySeconds <= 86400
            ? bodySeconds
            : headerSeconds;
        final seconds =
            candidateSeconds != null &&
                candidateSeconds >= 0 &&
                candidateSeconds <= 86400
            ? candidateSeconds
            : null;
        final rawTime = detail is Map ? detail['retry_at'] : null;
        final retryAt = rawTime is String
            ? DateTime.tryParse(rawTime)?.toUtc()
            : null;
        if (code == 'UPSTREAM_RATE_LIMITED') {
          cooldown?.observe(
            retryAt ?? DateTime.now().add(Duration(seconds: seconds ?? 60)),
          );
        }
        throw AccountReadException(
          code,
          status: response?.statusCode,
          requestId: id,
          retryAt: retryAt,
          retryAfter: seconds != null && seconds >= 0 && seconds <= 86400
              ? Duration(seconds: seconds)
              : null,
        );
      } on AuthApiException catch (error) {
        throw AccountReadException(
          error.code,
          status: error.status,
          retryAfter: error.retryAfter,
        );
      }
    }
    throw const AccountReadException('ACCESS_EXPIRED', status: 401);
  }
}
