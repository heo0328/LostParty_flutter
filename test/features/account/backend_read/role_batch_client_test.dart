import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/role_batch_client.dart';
import 'package:lost_party/features/account/data/role_summary_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';

import '../../../support/server_account_read_fakes.dart';
import 'scoped_role_sync_test.dart' as fixture show summaryJson;

String uuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> empty() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
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
  RoleBatchWrite write(int n, {Map<String, dynamic>? summary}) =>
      RoleBatchWrite(ref(n), CharacterBuildRole.dealer, uuid(1000 + n), {
        'expected_version': 1,
        'expected_ownership_revision': 1,
        'expected_lifecycle_revision': 1,
        'summary': summary ?? fixture.summaryJson(),
      });
  Map<String, dynamic> reply(RoleBatchWrite command) => {
    'character_id': command.ref.characterId,
    'role': command.role.name,
    'command_id': command.commandId,
    'status': 200,
    'error': null,
    'result': {
      'character_id': command.ref.characterId,
      'role': command.role.name,
      'ownership_revision': 1,
      'lifecycle_revision': 1,
      'version': 2,
      'summary': command.body['summary'],
      'saved_at': serverTime,
    },
  };
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

  test(
    'POST matches reversed partial results and retains unknown vs unattempted',
    () async {
      final commands = [write(1), write(2), write(3)];
      respond = (r) {
        expect(r.receiveTimeout, const Duration(seconds: 60));
        expect(r.headers.containsKey('Idempotency-Key'), isFalse);
        expect(r.data, {'items': commands.map((c) => c.wire).toList()});
        return {
          'items': [
            {
              ...reply(commands[2]),
              'status': 503,
              'result': null,
              'error': failure('BATCH_NOT_PROCESSED'),
            },
            {
              ...reply(commands[1]),
              'status': 503,
              'result': null,
              'error': failure('SERVICE_UNAVAILABLE', retry: 2),
            },
            reply(commands[0]),
          ],
        };
      };
      final result = await client.put(commands);
      expect(result[commands[0].commandId]!.ack, isNotNull);
      expect(
        result[commands[1].commandId]!.failure!.retryAfter,
        const Duration(seconds: 2),
      );
      expect(
        result[commands[2].commandId]!.failure!.code,
        'BATCH_NOT_PROCESSED',
      );
      expect(calls, hasLength(1));
    },
  );

  for (final kind in [
    'missing',
    'duplicate',
    'foreign',
    'role',
    'wrong-summary',
    'both',
    'bad-error',
  ]) {
    test('POST validates all $kind results before exposing any ACK', () async {
      final command = write(1);
      respond = (_) {
        final item = reply(command), items = <Object>[];
        if (kind != 'missing') items.add(item);
        if (kind == 'duplicate') items.add(item);
        if (kind == 'foreign') item['character_id'] = uuid(3);
        if (kind == 'role') item['role'] = 'support';
        if (kind == 'wrong-summary') {
          ((item['result'] as Map)['summary']
                  as Map)['analysis_rules_version'] =
              'other';
        }
        if (kind == 'both') item['error'] = failure('REVISION_CONFLICT');
        if (kind == 'bad-error') {
          item['status'] = 503;
          item['result'] = null;
          item['error'] = {'code': 'SERVICE_UNAVAILABLE'};
        }
        return {'items': items};
      };
      await expectLater(
        client.put([command]),
        throwsA(isA<AccountReadException>()),
      );
      expect(calls, hasLength(1));
    });
  }

  test('chunks exact UTF8 envelopes and isolates fifty and byte limits', () {
    final summaries = List.generate(
      40,
      (i) => write(
        i + 1,
        summary: {
          ...fixture.summaryJson(),
          'analyzed_at': '2026-11-03T09:00:00.${'0' * 20000}Z',
        },
      ),
    );
    final chunks = RoleBatchClient.chunks(summaries);
    expect(chunks.length, greaterThan(1));
    expect(chunks.expand((c) => c).length, 40);
    for (final chunk in chunks) {
      expect(RoleBatchClient.encodedSize(chunk), lessThanOrEqualTo(524288));
      expect(
        RoleBatchClient.encodedSize(chunk),
        utf8
            .encode(jsonEncode({'items': chunk.map((c) => c.wire).toList()}))
            .length,
      );
    }
    expect(
      RoleBatchClient.chunks(
        List.generate(51, (i) => write(i + 1)),
      ).map((p) => p.length),
      [50, 1],
    );
    expect(
      () => RoleBatchClient.chunks([write(1), write(1)]),
      throwsFormatException,
    );
  });
  test('item byte limit applies to the original timestamp representation', () {
    Map<String, dynamic> body(int digits) => {
      'expected_version': 1,
      'expected_ownership_revision': 1,
      'expected_lifecycle_revision': 1,
      'summary': {
        ...fixture.summaryJson(),
        'analyzed_at': '2026-11-03T09:00:00.${'0' * digits}Z',
      },
    };
    final digits = 32768 - utf8.encode(jsonEncode(body(1))).length + 1;
    expect(utf8.encode(jsonEncode(body(digits))).length, 32768);
    RoleBatchWrite(ref(1), CharacterBuildRole.dealer, uuid(1001), body(digits));
    expect(
      () => RoleBatchWrite(
        ref(1),
        CharacterBuildRole.dealer,
        uuid(1001),
        body(digits + 1),
      ),
      throwsA(
        isA<AccountReadException>().having((e) => e.status, 'status', 413),
      ),
    );
  });
}
