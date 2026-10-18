import '../../../../shared/diagnostics/load_timing.dart';
import 'package:dio/dio.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../domain/account_read_session.dart';
import '../domain/member_raid_models.dart';
import '../domain/role_summary.dart';
import 'backend_account_read_api.dart';

class MemberRaidClient {
  MemberRaidClient(this.api);
  final DioBackendAccountReadApi api;
  Future<T> _decode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  // Public endpoints: never call accessToken, refresh, or attach a Bearer token.
  Future<Map<String, dynamic>> _public(String path) async {
    try {
      final response = await LoadTiming.http(
        () => api.dio.get<Object?>(
          path,
          options: Options(
            headers: {'Authorization': null},
            followRedirects: false,
          ),
        ),
      );
      if (response.statusCode != 200) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      return roleMap(response.data);
    } on DioException catch (e) {
      throw AccountReadException(
        e.response == null ? 'NETWORK_UNAVAILABLE' : 'SERVICE_UNAVAILABLE',
        status: e.response?.statusCode,
      );
    }
  }

  Future<RaidCatalog> catalog() =>
      _decode(() async => memberRaidCatalog(await _public('/v1/raid-catalog')));
  Future<MemberRaidCycle> cycle() => _decode(
    () async => MemberRaidCycle.fromJson(await _public('/v1/raid-cycle')),
  );
  Future<MemberWeeklyBatch> states(List<String> ids) => _decode(() async {
    roleCheck(
      ids.isNotEmpty && ids.length <= 50 && ids.toSet().length == ids.length,
    );
    for (final id in ids) {
      roleId(id);
    }
    return MemberWeeklyBatch.fromJson(
      (await api.request(
        '/v1/me/raid-weekly-states',
        query: {'character_id': ids},
      ))!,
    );
  });
  Future<MemberWeeklyEntry> put(
    String character,
    String raid,
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(character);
    raidIdentifier(raid);
    roleId(key);
    return MemberWeeklyEntry.fromJson(
      (await api.request(
        '/v1/me/characters/$character/raid-weekly-states/$raid/manual-completion',
        method: 'PUT',
        body: body,
        idempotencyKey: key,
      ))!,
    );
  });
}
