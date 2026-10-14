import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_exception.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';

class Store implements ApiTokenStore {
  @override
  Future<ApiToken?> read() async => ApiToken('synthetic.header.signature');
  @override
  Future<void> write(ApiToken token) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  test(
    'UNIX seconds and bounded fallback, never interpret milliseconds as seconds',
    () {
      final now = DateTime.utc(2026, 10, 15);
      for (final raw in [
        null,
        'bad',
        '-1',
        '0',
        '${now.millisecondsSinceEpoch}',
        '${now.millisecondsSinceEpoch ~/ 1000 - 1}',
        '${now.millisecondsSinceEpoch ~/ 1000 + 301}',
      ]) {
        expect(providerRetryAt(raw, now), now.add(const Duration(seconds: 60)));
      }
      expect(
        providerRetryAt('${now.millisecondsSinceEpoch ~/ 1000 + 23}', now),
        now.add(const Duration(seconds: 23)),
      );
    },
  );
  test('deadline max, same token keeps cooldown, changed token clears it', () {
    final now = DateTime.utc(2026, 10, 15);
    final limit = ApiCooldown(now: () => now);
    addTearDown(limit.dispose);
    limit.bindToken('synthetic-a');
    limit.observe(now.add(const Duration(seconds: 30)));
    limit.observe(now.add(const Duration(seconds: 10)));
    expect(limit.seconds, 30);
    limit.bindToken('synthetic-a');
    expect(limit.seconds, 30);
    limit.bindToken('synthetic-b');
    expect(limit.active, isFalse);
  });
  test(
    'success with remaining zero stays success and blocks next call without HTTP',
    () async {
      var now = DateTime.utc(2026, 10, 15);
      final limit = ApiCooldown(now: () => now);
      addTearDown(limit.dispose);
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      var requests = 0;
      adapter.onGet(
        '/fixture',
        (server) => server.replyCallback(
          200,
          (options) {
            requests++;
            return {'ok': true};
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-ratelimit-remaining': ['0'],
            'x-ratelimit-reset': ['${now.millisecondsSinceEpoch ~/ 1000 + 20}'],
          },
        ),
      );
      final client = LostArkApiClient(
        apiTokenStore: Store(),
        dio: dio,
        cooldown: limit,
      );
      expect(await client.get<Map<String, dynamic>>('/fixture'), {'ok': true});
      await expectLater(
        client.get<Map<String, dynamic>>('/fixture'),
        throwsA(
          isA<LostArkApiException>().having(
            (e) => e.type,
            'type',
            LostArkApiErrorType.rateLimited,
          ),
        ),
      );
      expect(requests, 1);
      now = now.add(const Duration(seconds: 21));
      expect(limit.active, isFalse);
    },
  );
  test(
    '429 missing reset gives sixty seconds without automatic HTTP retry',
    () async {
      final now = DateTime.utc(2026, 10, 15);
      final limit = ApiCooldown(now: () => now);
      addTearDown(limit.dispose);
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/fixture', (server) => server.reply(429, {}));
      final client = LostArkApiClient(
        apiTokenStore: Store(),
        dio: dio,
        cooldown: limit,
      );
      await expectLater(
        client.get<Object>('/fixture'),
        throwsA(
          isA<LostArkApiException>().having(
            (e) => e.retryAt,
            'retry time',
            now.add(const Duration(seconds: 60)),
          ),
        ),
      );
      expect(limit.seconds, 60);
    },
  );
  test(
    'response from previous member discarded before returning provider data',
    () async {
      var generation = 1;
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      final limit = ApiCooldown();
      addTearDown(limit.dispose);
      adapter.onGet(
        '/fixture',
        (server) => server.replyCallback(200, (options) {
          generation++;
          return {'ok': true};
        }),
      );
      final client = LostArkApiClient(
        apiTokenStore: Store(),
        dio: dio,
        cooldown: limit,
        scopeIdentity: () => generation,
      );
      await expectLater(
        client.get<Object>('/fixture'),
        throwsA(
          isA<LostArkApiException>().having(
            (e) => e.type,
            'type',
            LostArkApiErrorType.cancelled,
          ),
        ),
      );
    },
  );
}
