import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/role_batch_client.dart';
import 'package:lost_party/features/account/data/role_summary_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';

import '../../../support/server_account_read_fakes.dart';

String uuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> empty() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
  'detail': null,
};
Map<String, dynamic> profile(String id) => {
  'character_id': id,
  'game_account_id': uuid(900),
  'ownership_revision': 1,
  'lifecycle_revision': 1,
  'lifecycle_state': 'active',
  'dealer': empty(),
  'support': empty(),
  'preferences': {
    'version': 1,
    'preferred_role': null,
    'visible': true,
    'display_order': null,
    'saved_at': null,
  },
};
Map<String, dynamic> failure(String code, {int? retry}) => {
  'code': code,
  'message': code,
  'request_id': 'batch-test',
  'retry_after_seconds': retry,
};

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late RoleBatchClient client;
  late StorageScope scope;
  late List<RequestOptions> calls;
  late Map<String, dynamic> Function(RequestOptions) respond;
  ScopedCharacterRef ref(int n) =>
      ScopedCharacterRef(scope, accountId: uuid(900), characterId: uuid(n));
  setUp(() {
    session = ReadSessionFake()..userId = uuid(999);
    dio = Dio(BaseOptions(baseUrl: 'https://batch.test'));
    client = RoleBatchClient(
      RoleSummaryClient(DioBackendAccountReadApi(dio, session)),
    );
    scope = StorageScope(baseUrl: 'https://batch.test', userId: uuid(999));
    calls = [];
    respond = (_) => throw StateError('Unexpected request');
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          calls.add(r);
          h.resolve(
            Response(requestOptions: r, statusCode: 200, data: respond(r)),
          );
        },
      ),
    );
  });
  tearDown(() {
    dio.close(force: true);
    session.dispose();
  });

  test(
    'GET uses repeated parameters, chunks fifty and matches reversed items',
    () async {
      respond = (r) {
        final ids = r.queryParameters['character_id'] as List;
        expect(r.uri.queryParametersAll['character_id'], ids);
        return {
          'evaluated_at': serverTime,
          'items': ids.reversed
              .map(
                (id) => {
                  'character_id': id,
                  'status': 200,
                  'profile': profile(id as String),
                  'error': null,
                },
              )
              .toList(),
        };
      };
      final result = await client.profiles(
        List.generate(51, (i) => ref(i + 1)),
      );
      expect(calls, hasLength(2));
      expect(result, hasLength(51));
      expect(result[uuid(1)]!.profile!.characterId, uuid(1));
    },
  );

  test(
    'GET preserves an unavailable item instead of inventing a profile',
    () async {
      respond = (_) => {
        'evaluated_at': serverTime,
        'items': [
          {
            'character_id': uuid(1),
            'status': 200,
            'profile': profile(uuid(1)),
            'error': null,
          },
          {
            'character_id': uuid(2),
            'status': 403,
            'profile': null,
            'error': failure('OWNERSHIP_REQUIRED'),
          },
        ],
      };
      final result = await client.profiles([ref(1), ref(2)]);
      expect(result[uuid(2)]!.profile, isNull);
      expect(result[uuid(2)]!.failure!.code, 'OWNERSHIP_REQUIRED');
    },
  );

  for (final kind in [
    'missing',
    'duplicate',
    'foreign',
    'null',
    'wrong-owner',
    'extra',
  ]) {
    test('GET rejects $kind without fallback HTTP', () async {
      respond = (_) {
        final item = <String, dynamic>{
          'character_id': uuid(1),
          'status': 200,
          'profile': profile(uuid(1)),
          'error': null,
        };
        final items = <Object>[item];
        if (kind == 'missing') items.clear();
        if (kind == 'duplicate') items.add(item);
        if (kind == 'foreign') item['character_id'] = uuid(2);
        if (kind == 'null') item['profile'] = null;
        if (kind == 'wrong-owner') {
          (item['profile'] as Map)['game_account_id'] = uuid(901);
        }
        if (kind == 'extra') item['extra'] = true;
        return {'evaluated_at': serverTime, 'items': items};
      };
      await expectLater(
        client.profiles([ref(1)]),
        throwsA(isA<AccountReadException>()),
      );
      expect(calls, hasLength(1));
    });
  }
}
