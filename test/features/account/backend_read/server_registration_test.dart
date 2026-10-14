import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_registration_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

void main() {
  late Dio dio;
  late ReadSessionFake session;
  late ServerRegistrationViewModel model;
  late DateTime clock;
  late List<RequestOptions> requests;
  late void Function(RequestOptions, RequestInterceptorHandler) handle;
  setUp(() {
    clock = DateTime.utc(2026, 10, 14);
    dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'));
    session = ReadSessionFake();
    requests = [];
    final api = DioBackendAccountReadApi(dio, session);
    model = ServerRegistrationViewModel(
      api,
      ServerAccountReadRepository(api, session),
      session,
      now: () => clock,
    );
    handle = (o, h) => h.resolve(
      Response(requestOptions: o, statusCode: 200, data: registrationJson()),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          requests.add(o);
          handle(o, h);
        },
      ),
    );
  });
  tearDown(() {
    model.dispose();
    dio.close();
    session.dispose();
  });
  final account = ServerAccountRegistration.fromJson(registrationJson());
  Map<String, dynamic> preview() => {
    'characters': [
      {
        'server_name': 'sample-server',
        'character_name': 'sample',
        'class_name': 'sample-class',
        'character_level': 70,
        'item_level': null,
      },
    ],
    'server_fetched_at': serverTime,
    'expires_at': '2026-10-14T00:10:00Z',
  };
  Map<String, dynamic> refreshResult() => {
    'registration': registrationJson()..['version'] = 2,
    'added_count': 0,
    'suspect_count': 0,
    'requires_refresh': false,
  };
  Map<String, dynamic> powerResult() => {
    'server_name': 'sample-server',
    'character_name': 'sample',
    'combat_power': '0',
    'power_fetched_at': serverTime,
    'power_checked_at': serverTime,
    'power_stale': false,
    'power_status': 'available',
    'power_reason': null,
    'retry_after_seconds': null,
    'retry_at': null,
    'status': 'updated',
    'reason': null,
  };
  const powerTargets = [
    {'server_name': 'sample-server', 'character_name': 'sample'},
  ];
  test(
    'power timeout and replay keep immutable key/body and accept real zero',
    () async {
      handle = (o, h) {
        if (requests.length == 1) {
          h.reject(DioException(requestOptions: o));
        } else {
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'items': [powerResult()],
              },
            ),
          );
        }
      };
      await model.refreshPower(account, powerTargets);
      expect(requests.single.receiveTimeout, const Duration(seconds: 30));
      expect(requests.single.data, {'characters': powerTargets});
      await model.edit(account, 'blocked', false);
      expect(requests.length, 1);
      await model.retry();
      expect(requests[0].data, requests[1].data);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(model.powerResults.single.power.value, 0);
      expect(model.hasPending, false);
      expect(model.failure, isNull);
      await model.refresh(account);
      expect(requests.last.receiveTimeout, isNot(const Duration(seconds: 30)));
    },
  );
  for (final scenario in [
    'wrong_name',
    'extra',
    'missing',
    'negative',
    'infinite',
    'null_status',
  ]) {
    test('invalid power response $scenario remains unresolved', () async {
      final row = powerResult();
      if (scenario == 'wrong_name') row['character_name'] = 'other';
      if (scenario == 'extra') row['other'] = true;
      if (scenario == 'missing') row.remove('power_checked_at');
      if (scenario == 'negative') row['combat_power'] = '-1';
      if (scenario == 'infinite') row['combat_power'] = 'Infinity';
      if (scenario == 'null_status') row['power_status'] = null;
      handle = (o, h) => h.resolve(
        Response(
          requestOptions: o,
          statusCode: 200,
          data: {
            'items': [row],
          },
        ),
      );
      await model.refreshPower(account, powerTargets);
      expect(model.failure?.code, 'INVALID_RESPONSE');
      expect(model.hasPending, true);
      expect(model.powerResults, isEmpty);
      expect(model.notice, isNull);
    });
  }
  test(
    'power partial result has explicit failed/deferred counts and no automatic new request',
    () async {
      final targets = [
        ...powerTargets,
        {'server_name': 'sample-server', 'character_name': 'next'},
      ];
      final failed = powerResult()
        ..['status'] = 'failed'
        ..['power_status'] = 'failed'
        ..['power_stale'] = true
        ..['reason'] = 'UPSTREAM_UNAVAILABLE'
        ..['power_reason'] = 'UPSTREAM_UNAVAILABLE';
      final deferred = powerResult()
        ..['character_name'] = 'next'
        ..['status'] = 'deferred'
        ..['reason'] = 'TIME_BUDGET_EXCEEDED';
      handle = (o, h) => h.resolve(
        Response(
          requestOptions: o,
          statusCode: 200,
          data: {
            'items': [failed, deferred],
          },
        ),
      );
      await model.refreshPower(account, targets);
      expect(model.failure, isNull);
      expect(model.notice, contains('실패 1명'));
      expect(model.notice, contains('다음에 확인 1명'));
      expect(requests.length, 1);
    },
  );
  test(
    'refresh decodes wrapper, accepts zero added count and completes command',
    () async {
      handle = (o, h) => h.resolve(
        Response(requestOptions: o, statusCode: 200, data: refreshResult()),
      );
      await model.refresh(account);
      expect(model.failure, isNull);
      expect(model.hasPending, false);
      expect(model.notice, contains('정보 갱신 완료'));
      expect(model.notice, contains('새 캐릭터 0명 · 확인 필요 0명'));
      expect(
        model.notice,
        contains(serverRegistrationTimeLabel(DateTime.parse(serverTime))),
      );
      model.clearCompletedNotice();
      expect(model.notice, isNull);
      expect(requests.single.data, <String, dynamic>{});
    },
  );
  test('entry notice reset does not erase an unresolved request', () async {
    handle = (o, h) => h.reject(DioException(requestOptions: o));
    await model.remove(account);
    clock = clock.add(const Duration(hours: 24));
    await model.retry();
    final before = model.notice;
    model.clearCompletedNotice();
    expect(model.notice, before);
    expect(model.hasPending, true);
    expect(model.failure?.code, 'NETWORK_UNAVAILABLE');
  });
  for (final scenario in [
    'missing',
    'count_type',
    'flag_type',
    'extra',
    'registration_type',
    'wrong_target',
  ]) {
    test('invalid refresh wrapper $scenario never completes command', () async {
      final result = refreshResult();
      switch (scenario) {
        case 'missing':
          result.remove('added_count');
        case 'count_type':
          result['suspect_count'] = '0';
        case 'flag_type':
          result['requires_refresh'] = 'false';
        case 'extra':
          result['unexpected'] = true;
        case 'registration_type':
          result['registration'] = null;
        case 'wrong_target':
          (result['registration'] as Map)['registration_id'] =
              '99999999-9999-4999-8999-999999999999';
      }
      handle = (o, h) =>
          h.resolve(Response(requestOptions: o, statusCode: 200, data: result));
      await model.refresh(account);
      expect(model.failure?.code, 'INVALID_RESPONSE');
      expect(model.hasPending, true);
      expect(model.notice, isNull);
    });
  }
  void fail(
    RequestOptions o,
    RequestInterceptorHandler h,
    int status,
    String code, {
    String? retry,
  }) => h.reject(
    DioException(
      requestOptions: o,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: o,
        statusCode: status,
        headers: retry == null
            ? Headers()
            : Headers.fromMap({
                'retry-after': [retry],
              }),
        data: {
          'error': {
            'code': code,
            'request_id': 'safe-id',
            'message': 'private upstream data',
          },
        },
      ),
    ),
  );
  test('guest cannot search or write', () async {
    session.change(authenticated: false);
    await model.search('sample');
    await model.remove(account);
    expect(requests, isEmpty);
    expect(model.preview, isNull);
  });
  test(
    'preview has no idempotency header; registration uses selected name and own key',
    () async {
      handle = (o, h) => h.resolve(
        Response(
          requestOptions: o,
          statusCode: o.path.endsWith('preview') ? 200 : 201,
          data: o.path.endsWith('preview') ? preview() : registrationJson(),
        ),
      );
      await model.search('sample');
      await model.register('', true);
      expect(requests[0].headers.containsKey('Idempotency-Key'), false);
      expect(requests[1].data, {
        'lookup_character_name': 'sample',
        'label': '',
        'is_main': true,
      });
      expect(
        requests[1].headers['Idempotency-Key'],
        matches(r'^[0-9a-f-]{14}4[0-9a-f-]{21}$'),
      );
      expect(model.hasPending, false);
      expect(model.preview, isNull);
    },
  );
  test('expired preview never sends registration', () async {
    handle = (o, h) => h.resolve(
      Response(requestOptions: o, statusCode: 200, data: preview()),
    );
    await model.search('sample');
    clock = clock.add(const Duration(minutes: 10));
    await model.register('label', false);
    expect(requests.length, 1);
    expect(model.failure!.code, 'PREVIEW_EXPIRED');
  });
  test(
    'blank PATCH retries identical empty label and accepts empty response',
    () async {
      handle = (o, h) {
        if (requests.length == 1) {
          h.reject(DioException(requestOptions: o));
        } else {
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: registrationJson()..['label'] = '',
            ),
          );
        }
      };
      await model.edit(account, '   ', false);
      expect(requests.single.data, {
        'expected_version': 1,
        'label': '',
        'is_main': false,
      });
      expect(model.hasPending, true);
      await model.retry();
      expect(requests[1].data, requests[0].data);
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[0].headers['Idempotency-Key'],
      );
      expect(model.failure, isNull);
      expect(model.hasPending, false);
    },
  );
  for (final scenario in ['duplicate', 'unknown', 'missing', 'null']) {
    test('malformed preview $scenario cannot enable registration', () async {
      final data = preview();
      if (scenario == 'duplicate') {
        (data['characters'] as List).add((data['characters'] as List).first);
      }
      if (scenario == 'unknown') data['unexpected'] = true;
      if (scenario == 'missing') data.remove('expires_at');
      if (scenario == 'null') data['characters'] = null;
      handle = (o, h) =>
          h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
      await model.search('sample');
      expect(model.preview, isNull);
      expect(model.failure!.code, 'INVALID_RESPONSE');
    });
  }
  test(
    'lost DELETE response retries same key/query without request body',
    () async {
      handle = (o, h) {
        if (requests.length == 1) {
          h.reject(DioException(requestOptions: o));
        } else {
          h.resolve(Response(requestOptions: o, statusCode: 204));
        }
      };
      await model.remove(account);
      expect(model.hasPending, true);
      await model.refresh(account);
      expect(requests.length, 1);
      await model.retry();
      expect(requests.length, 2);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(requests[1].queryParameters, {'expected_version': 1});
      expect(requests[1].data, isNull);
      expect(model.hasPending, false);
    },
  );
  test(
    'PATCH retry holds immutable body even when caller changes inputs',
    () async {
      handle = (o, h) => fail(o, h, 503, 'UPSTREAM_UNAVAILABLE');
      await model.edit(account, 'first', false);
      await model.edit(account, 'second', true);
      await model.retry();
      expect(requests.length, 2);
      expect(requests[0].data, {
        'expected_version': 1,
        'label': 'first',
        'is_main': false,
      });
      expect(requests[1].data, requests[0].data);
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[0].headers['Idempotency-Key'],
      );
      expect(
        () => (requests[0].data as Map)['label'] = 'new',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'progress retry observes Retry-After, refresh sends strict empty object',
    () async {
      handle = (o, h) {
        if (requests.length == 1) {
          fail(o, h, 409, 'REQUEST_IN_PROGRESS', retry: '2');
        } else {
          h.resolve(
            Response(requestOptions: o, statusCode: 200, data: refreshResult()),
          );
        }
      };
      await model.refresh(account);
      await model.retry();
      expect(requests.length, 1);
      clock = clock.add(const Duration(seconds: 2));
      await model.retry();
      expect(requests.length, 2);
      expect(model.hasPending, false);
      expect(model.failure, isNull);
      expect(requests.last.data, <String, dynamic>{});
    },
  );
  test('rate limit prevents new key during backoff', () async {
    handle = (o, h) => fail(o, h, 429, 'RATE_LIMITED', retry: '2');
    await model.remove(account);
    await model.edit(account, 'new', true);
    expect(requests.length, 1);
    expect(model.hasPending, false);
    clock = clock.add(const Duration(seconds: 2));
    expect(model.canWrite, true);
  });
  test(
    'auth expiry retries mutation once with identical key and payload',
    () async {
      handle = (o, h) {
        if (requests.length == 1) {
          fail(o, h, 401, 'ACCESS_EXPIRED');
        } else {
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: registrationJson(),
            ),
          );
        }
      };
      await model.edit(account, 'label', false);
      expect(requests.length, 2);
      expect(session.refreshCalls, 1);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(requests[0].data, requests[1].data);
    },
  );
  test('business forbidden does not revoke Google session', () async {
    handle = (o, h) => fail(o, h, 403, 'OWNERSHIP_REQUIRED');
    await model.refresh(account);
    expect(session.isAuthenticated, true);
    expect(session.rejects, 0);
    expect(model.failure!.code, 'OWNERSHIP_REQUIRED');
    expect(model.hasPending, false);
  });
  test('old session late success cannot alter a new session', () async {
    final gate = Completer<void>();
    handle = (o, h) {
      gate.future.then(
        (_) => h.resolve(
          Response(
            requestOptions: o,
            statusCode: 200,
            data: registrationJson(),
          ),
        ),
      );
    };
    final run = model.edit(account, 'private', false);
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    session.change(authenticated: true);
    gate.complete();
    await run;
    expect(model.hasPending, false);
    expect(model.notice, isNull);
    expect(model.failure, isNull);
  });
  test(
    '24h key cannot be retried and request requires successful GET review',
    () async {
      handle = (o, h) => h.reject(DioException(requestOptions: o));
      await model.remove(account);
      clock = clock.add(const Duration(hours: 24));
      await model.retry();
      expect(requests.length, 1);
      model.finishReviewedRequest();
      expect(model.hasPending, true);
      handle = (o, h) => h.resolve(
        Response(
          requestOptions: o,
          statusCode: 200,
          data: registrationPageJson(empty: true),
        ),
      );
      await model.review();
      expect(model.canFinishReview, true);
      model.finishReviewedRequest();
      expect(model.hasPending, false);
    },
  );
  test('wrong registration mutation response remains uncertain', () async {
    final result = registrationJson()
      ..['registration_id'] = '99999999-9999-4999-8999-999999999999';
    handle = (o, h) =>
        h.resolve(Response(requestOptions: o, statusCode: 200, data: result));
    await model.edit(account, 'label', false);
    expect(model.hasPending, true);
    expect(model.failure!.code, 'INVALID_RESPONSE');
    expect(model.notice, isNull);
  });
  test(
    'malformed success preserves uncertain command and no success notice',
    () async {
      handle = (o, h) => h.resolve(
        Response(requestOptions: o, statusCode: 200, data: <String, dynamic>{}),
      );
      await model.edit(account, 'label', false);
      expect(model.hasPending, true);
      expect(model.failure!.code, 'INVALID_RESPONSE');
      expect(model.notice, isNull);
    },
  );
}
