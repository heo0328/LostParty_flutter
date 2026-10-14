import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_combat_power.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import '../../../support/server_account_read_fakes.dart';

Map<String, dynamic> powerResult() => {
  'server_name': 'fixture',
  'character_name': 'fixture',
  'combat_power': null,
  'power_fetched_at': null,
  'power_checked_at': null,
  'power_stale': true,
  'power_status': 'failed',
  'power_reason': 'UPSTREAM_RATE_LIMITED',
  'status': 'deferred',
  'reason': 'UPSTREAM_RATE_LIMITED',
  'retry_after_seconds': 25,
  'retry_at': '2026-10-15T00:00:25Z',
};
void main() {
  test('power requires both nullable fields and strict integer delay', () {
    expect(
      ServerPowerResult.fromJson(powerResult()).retryAfter,
      const Duration(seconds: 25),
    );
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j.remove('retry_at'),
      (j) => j['retry_after_seconds'] = true,
      (j) => j['retry_after_seconds'] = 0,
      (j) => j['retry_after_seconds'] = null,
      (j) => j['retry_at'] = 'invalid',
    ]) {
      final json = powerResult();
      mutate(json);
      expect(() => ServerPowerResult.fromJson(json), throwsFormatException);
    }
    final okay = powerResult()
      ..['status'] = 'updated'
      ..['reason'] = null
      ..['retry_after_seconds'] = null
      ..['retry_at'] = null;
    expect(ServerPowerResult.fromJson(okay).retryAt, isNull);
  });
  test(
    'server rate metadata reaches UI exception and never rejects member session',
    () async {
      final session = ReadSessionFake();
      addTearDown(session.dispose);
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      final cooldown = ApiCooldown(now: () => DateTime.utc(2026, 10, 15));
      addTearDown(cooldown.dispose);
      adapter.onPost(
        '/v1/game-accounts/preview',
        (server) => server.reply(
          503,
          {
            'error': {
              'code': 'UPSTREAM_RATE_LIMITED',
              'message': 'fixture',
              'request_id': registrationId,
              'retry_after_seconds': 25,
              'retry_at': '2026-10-15T00:00:25Z',
            },
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['25'],
          },
        ),
        data: {'character_name': 'fixture'},
      );
      final api = DioBackendAccountReadApi(dio, session, cooldown: cooldown);
      await expectLater(
        api.request(
          '/v1/game-accounts/preview',
          method: 'POST',
          body: {'character_name': 'fixture'},
        ),
        throwsA(
          isA<AccountReadException>()
              .having((e) => e.code, 'code', 'UPSTREAM_RATE_LIMITED')
              .having(
                (e) => e.retryAfter,
                'delay',
                const Duration(seconds: 25),
              ),
        ),
      );
      expect(cooldown.seconds, 25);
      expect(session.isAuthenticated, isTrue);
      await expectLater(
        api.request('/v1/game-accounts/preview', method: 'POST'),
        throwsA(isA<AccountReadException>()),
      );
    },
  );
  test(
    'provider key rejection is business conflict without session logout',
    () async {
      final session = ReadSessionFake();
      addTearDown(session.dispose);
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      adapter.onPost(
        '/v1/game-accounts/preview',
        (server) => server.reply(409, {
          'error': {
            'code': 'LOSTARK_KEY_REJECTED',
            'message': 'fixture',
            'request_id': registrationId,
          },
        }),
      );
      await expectLater(
        DioBackendAccountReadApi(
          dio,
          session,
        ).request('/v1/game-accounts/preview', method: 'POST'),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'LOSTARK_KEY_REJECTED',
          ),
        ),
      );
      expect(session.isAuthenticated, isTrue);
    },
  );
}
