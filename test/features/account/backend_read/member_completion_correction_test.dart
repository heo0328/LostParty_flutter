import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/member_completion_correction.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import '../../../support/server_account_read_fakes.dart';
import 'member_weekly_test.dart' as old;
import 'member_cycles_test.dart' as cycles;

Map<String, dynamic> copy(Object v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
final samples =
    (jsonDecode(
              File(
                'test/fixtures/member_completion_correction.json',
              ).readAsStringSync(),
            )
            as Map)['examples']
        as Map;
MemberCompletionCorrection preview(Map<String, dynamic> j) =>
    MemberCompletionCorrection(
      j['data']['character_id'],
      j['data']['raid_id'],
      j['data']['target_cycle_key'],
      j,
    );

void main() {
  test('published ready/no-completion contexts and exact command/ACK', () {
    final p = preview(copy(samples['ready_context']));
    expect(p.body(), samples['correction_command']);
    final result = copy(samples['correction_result']);
    MemberCompletionCorrectionResult(result, p, result['data']['command_id']);
    expect(preview(copy(samples['no_completion_context'])).allowed, false);
    expect(() => p.data['weekly_revision'] = 10, throwsUnsupportedError);
  });
  test(
    'manual/party/both, nullable difficulty, inactive raid records and offset timestamps',
    () {
      for (final kinds in [
        ['manual'],
        ['party'],
        ['manual', 'party'],
      ]) {
        final j = copy(samples['ready_context']);
        j['data']['completion_sources'] = [
          for (final kind in kinds)
            {
              'source': kind,
              'completed_at': '2026-10-23T16:40:45+09:00',
              'difficulty_id': null,
              'party_id': kind == 'party'
                  ? '00000000-0000-4000-8000-000000000001'
                  : null,
            },
        ];
        j['data']['raid_id'] = 'retired_raid';
        expect(preview(j).allowed, true);
      }
      expect(
        () => correctionTime('2026-02-30T00:00:00Z'),
        throwsFormatException,
      );
      expect(
        () => correctionTime('2026-10-23T24:00:00Z'),
        throwsFormatException,
      );
    },
  );
  test(
    'past target and C Wednesday06-10 correction do not use completion creation gate',
    () {
      for (final target in ['2026-10-14', '2026-10-21']) {
        final j = copy(samples['ready_context']);
        j['server_now'] = '2026-10-20T22:00:00Z';
        j['data']['target_cycle_key'] = target;
        j['data']['confirmation']['issued_at'] = j['server_now'];
        j['data']['confirmation']['expires_at'] = '2026-10-20T22:02:00Z';
        expect(preview(j).body()['expected_cycle_key'], '2026-10-21');
        expect(preview(j).body()['target_cycle_key'], target);
      }
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'future target': (j) => j['data']['target_cycle_key'] = '2026-10-28',
    'extra field': (j) => j['data']['unexpected'] = true,
    'revision overflow': (j) => j['data']['weekly_revision'] = 2147483648,
    'source unknown': (j) =>
        j['data']['completion_sources'][0]['source'] = 'other',
    'duplicate source': (j) => j['data']['completion_sources'].add(
      copy(j['data']['completion_sources'][0]),
    ),
    'denied with token': (j) => j['data']['permission']['allowed'] = false,
    'missing token': (j) => j['data']['confirmation'] = null,
    'oversized token': (j) =>
        j['data']['confirmation']['context_token'] = '가' * 1366,
    'expired token': (j) =>
        j['data']['confirmation']['expires_at'] = j['server_now'],
  }.entries) {
    test('reject context ${mutation.key}', () {
      final j = copy(samples['ready_context']);
      mutation.value(j);
      expect(() => preview(j), throwsFormatException);
    });
  }
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong command': (j) => j['data']['command_id'] = 'wrong',
    'wrong C': (j) => j['current_cycle_key'] = '2026-10-28',
    'wrong T': (j) => j['data']['target_cycle_key'] = '2026-10-14',
    'revision': (j) => j['data']['weekly_revision']++,
    'source still present': (j) => j['data']['completion_sources'] =
        samples['ready_context']['data']['completion_sources'],
    'participation restored': (j) => j['data']['participation_restored'] = true,
  }.entries) {
    test('reject ACK ${mutation.key}', () {
      final j = copy(samples['correction_result']),
          key = j['data']['command_id'] as String;
      mutation.value(j);
      expect(
        () => MemberCompletionCorrectionResult(
          j,
          preview(copy(samples['ready_context'])),
          key,
        ),
        throwsFormatException,
      );
    });
  }

  late ReadSessionFake session;
  late Dio dio;
  late ScopedAccountRuntime runtime;
  late old.WeeklyMember model;
  late old.WeeklyMemoryStore store;
  late MemberWeeklyViewModel weekly;
  late MemberRaidClient client;
  late DateTime clock;
  late Map<String, dynamic> wire;
  late List<RequestOptions> calls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  var completed = true, lose = false, readFail = false, badAck = false;
  final replays = <String, Map<String, dynamic>>{};
  ScopedCharacterRef ref() => model.sections.single.characters.first.ref;
  Map<String, dynamic> disk() =>
      jsonDecode(store.data[runtime.scope]!) as Map<String, dynamic>;
  List<RequestOptions> posts() =>
      calls.where((r) => r.path.endsWith('/completion-corrections')).toList();
  Map<String, dynamic> serve(RequestOptions r) {
    if (r.path == '/v1/raid-catalog') return old.catalogWire();
    if (r.path == '/v2/raid-cycles') {
      return {
        'server_now': clock.toIso8601String(),
        'current': cycles.meta(cycles.current),
        'next': cycles.meta(cycles.next),
        'policy_version': 'two-cycle-contract-4',
      };
    }
    if (r.path.endsWith('/raid-weekly-summary')) {
      if (readFail) throw DioException(requestOptions: r);
      final b = r.data as Map;
      return {
        'server_now': clock.toIso8601String(),
        'current_cycle_key': cycles.current,
        'target_cycle_keys': b['target_cycle_keys'],
        'catalog_version': '2026.08.20',
        'entries': [
          for (final t in b['target_cycle_keys'])
            for (final id in b['character_ids'])
              for (final raid in old.catalogWire()['raids'] as List)
                {
                  ...cycles.summaryEntry(id, raid['raid_id'], t),
                  'weekly_revision': completed ? 3 : 4,
                  'completion_sources': t == cycles.current && completed
                      ? wire['data']['completion_sources']
                      : [],
                  'permissions': {
                    'mark_completed': cycles.permit(false),
                    'clear_manual_completion': cycles.permit(false),
                    'view_participation': cycles.permit(false),
                  },
                },
        ],
      };
    }
    if (r.path.endsWith('/completion-correction-context')) return copy(wire);
    if (r.path.endsWith('/completion-corrections')) {
      final saved = disk()['pending'];
      expect(saved['wire_version'], 3);
      expect(saved['body'], r.data);
      expect(saved['key'], r.headers['Idempotency-Key']);
      final key = r.headers['Idempotency-Key'] as String;
      final result = replays.putIfAbsent(key, () {
        completed = false;
        final v = copy(samples['correction_result']);
        v['data']['character_id'] = wire['data']['character_id'];
        v['data']['raid_id'] = wire['data']['raid_id'];
        v['data']['command_id'] = key;
        return v;
      });
      if (lose) {
        lose = false;
        throw DioException(requestOptions: r);
      }
      final ack = copy(result);
      if (badAck) ack['data']['weekly_revision']++;
      return ack;
    }
    throw StateError(r.path);
  }

  void create() {
    weekly = MemberWeeklyViewModel(
      model: model,
      client: client,
      store: store,
      twoCycleEnabled: true,
      now: () => clock,
    );
  }

  Future<void> load() async {
    await weekly.refresh();
    expect(weekly.failure, null);
  }

  Future<void> clear() async {
    final p = await weekly.prepareCorrection(ref(), wire['data']['raid_id']);
    expect(p, isNotNull);
    await weekly.correct(p!);
    weekly.cancelCorrection(p);
  }

  setUp(() {
    clock = DateTime.parse(samples['ready_context']['server_now']);
    session = ReadSessionFake()..userId = old.member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final api = DioBackendAccountReadApi(dio, session);
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () => throw StateError('No DB'),
      enabled: true,
    );
    model = old.WeeklyMember(runtime)..setCount(1);
    store = old.WeeklyMemoryStore();
    client = MemberRaidClient(api);
    wire = copy(samples['ready_context']);
    wire['data']['character_id'] = ref().characterId;
    calls = [];
    replays.clear();
    completed = true;
    lose = readFail = badAck = false;
    respond = serve;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          calls.add(r);
          try {
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: await respond(r),
              ),
            );
          } catch (e) {
            h.reject(
              e is DioException ? e : DioException(requestOptions: r, error: e),
            );
          }
        },
      ),
    );
    create();
  });
  tearDown(() async {
    weekly.dispose();
    model.dispose();
    await runtime.close();
    session.dispose();
    dio.close();
  });
  test(
    'party-only clear uses context even though manual permission is false; one POST and exactT refresh',
    () async {
      wire['data']['completion_sources'][0]['source'] = 'party';
      await load();
      expect(weekly.canChange(ref(), wire['data']['raid_id']), true);
      await clear();
      expect(posts(), hasLength(1));
      expect(
        calls.where((r) => r.path.endsWith('/completion-correction-context')),
        hasLength(2),
      );
      expect(weekly.hasPending, false);
      expect(weekly.entry(ref(), wire['data']['raid_id'])!.completed, false);
      final summaries = calls
          .where((r) => r.path.endsWith('/raid-weekly-summary'))
          .toList();
      expect((summaries.last.data as Map)['target_cycle_keys'], [
        cycles.current,
      ]);
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      for (final call in calls.where(
        (r) => r.path.contains('completion-correction'),
      )) {
        expect(
          call.queryParameters['group_policy_version'],
          'cycle-group-policy-1',
        );
        expect(call.queryParameters.containsKey('contract_profile'), false);
        expect(
          call.queryParameters.containsKey('participation_profile'),
          false,
        );
      }
    },
  );
  void rejectUpgrade(
    RequestOptions r, {
    int status = 409,
    String code = 'CLIENT_UPGRADE_REQUIRED',
  }) {
    throw DioException(
      requestOptions: r,
      response: Response(
        requestOptions: r,
        statusCode: status,
        data: {
          'error': {'code': code},
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> restoreBlockedOriginal() async {
    await load();
    lose = true;
    await clear();
    final raw = disk();
    raw['pending']['query'] = null;
    raw['pending']['blocked_code'] = 'CLIENT_UPGRADE_REQUIRED';
    store.data[runtime.scope] = jsonEncode(raw);
    completed = true;
    weekly.dispose();
    create();
    await load();
    calls.clear();
    expect(weekly.canUseCurrent, false);
    expect(weekly.canRetry, true);
  }

  test(
    'current refusal then failed target GET preserves request and retries only reads',
    () async {
      await restoreBlockedOriginal();
      var fail = true;
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        if (fail && r.path.endsWith('/completion-correction-context')) {
          throw DioException(requestOptions: r);
        }
        return serve(r);
      };
      await weekly.retry();
      expect(weekly.canUseCurrent, false);
      expect(weekly.pendingCurrentState, null);
      expect(weekly.canRetry, false);
      await weekly.useCurrent();
      expect(weekly.hasPending, true);
      fail = false;
      await weekly.refresh();
      expect(weekly.canUseCurrent, true);
      expect(posts(), hasLength(1));
      await weekly.useCurrent();
      expect(weekly.hasPending, false);
      expect(completed, true);
    },
  );

  for (final refusal in [
    (503, 'CLIENT_UPGRADE_REQUIRED'),
    (409, 'REQUEST_IN_PROGRESS'),
    (503, 'SERVER_ERROR'),
    (409, 'IDEMPOTENCY_CONFLICT'),
  ]) {
    test(
      'nonqualifying current refusal $refusal cannot adopt historical state',
      () async {
        await restoreBlockedOriginal();
        respond = (r) {
          if (r.path.endsWith('/completion-corrections')) {
            rejectUpgrade(r, status: refusal.$1, code: refusal.$2);
          }
          return serve(r);
        };
        await weekly.retry();
        await weekly.refresh();
        expect(weekly.pendingCurrentState, null);
        expect(weekly.canUseCurrent, false);
        await weekly.useCurrent();
        expect(weekly.hasPending, true);
        expect(completed, true);
      },
    );
  }

  test('profiled pending cannot use unprofiled adoption rule', () async {
    await load();
    lose = true;
    await clear();
    respond = (r) {
      if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
      return serve(r);
    };
    await weekly.retry();
    await weekly.refresh();
    expect(weekly.canUseCurrent, false);
    expect(weekly.canRetry, false);
    expect(weekly.pendingCurrentState, null);
    expect(weekly.hasPending, true);
  });

  test(
    'adoption persistence failure preserves original, then explicit retry releases restrictions',
    () async {
      await restoreBlockedOriginal();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await weekly.retry();
      final original = store.data[runtime.scope];
      store.failWrite = true;
      await weekly.useCurrent();
      expect(weekly.hasPending, true);
      expect(store.data[runtime.scope], original);
      expect(weekly.failure, 'LOCAL_STORAGE_FAILED');
      store.failWrite = false;
      await weekly.useCurrent();
      expect(weekly.hasPending, false);
      expect(completed, true);
      expect(posts(), hasLength(1));
    },
  );

  test(
    'read generation change invalidates adoption until a new original refusal',
    () async {
      await restoreBlockedOriginal();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await weekly.retry();
      expect(weekly.canUseCurrent, true);
      runtime.invalidateReads();
      expect(weekly.pendingCurrentState, null);
      expect(weekly.canUseCurrent, false);
      await weekly.useCurrent();
      expect(weekly.hasPending, true);
      await weekly.refresh();
      expect(weekly.canUseCurrent, false);
      await weekly.retry();
      expect(weekly.canUseCurrent, true);
      expect(posts(), hasLength(2));
    },
  );

  test(
    'current incomplete state may be adopted without asserting past command outcome',
    () async {
      await restoreBlockedOriginal();
      completed = false;
      wire = copy(samples['no_completion_context']);
      wire['data']['character_id'] = ref().characterId;
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await weekly.retry();
      expect(weekly.canUseCurrent, true);
      expect(weekly.pendingCurrentState!.allowed, false);
      expect(weekly.pendingFailed, false);
      expect(disk()['pending']['ack'], false);
      await weekly.useCurrent();
      expect(weekly.hasPending, false);
      expect(completed, false);
      expect(posts(), hasLength(1));
    },
  );

  test('late target GET after member switch grants no adoption', () async {
    await restoreBlockedOriginal();
    final read = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    respond = (r) {
      if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
      if (r.path.endsWith('/completion-correction-context')) {
        started.complete();
        return read.future;
      }
      return serve(r);
    };
    final task = weekly.retry();
    await started.future;
    final oldScope = runtime.scope;
    final original = store.data[oldScope];
    session.change(
      authenticated: true,
      user: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    read.complete(copy(wire));
    await task;
    expect(weekly.canUseCurrent, false);
    expect(weekly.pendingCurrentState, null);
    expect(store.data[oldScope], original);
  });

  test(
    'overlapping retry taps send once and target mismatch never grants adoption',
    () async {
      await restoreBlockedOriginal();
      final read = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        if (r.path.endsWith('/completion-correction-context')) {
          started.complete();
          return read.future;
        }
        return serve(r);
      };
      final task = weekly.retry();
      await started.future;
      await weekly.retry();
      await weekly.useCurrent();
      final wrong = copy(wire);
      wrong['data']['target_cycle_key'] = '2026-10-14';
      read.complete(wrong);
      await task;
      expect(posts(), hasLength(1));
      expect(weekly.canUseCurrent, false);
      expect(weekly.pendingCurrentState, null);
      expect(weekly.hasPending, true);
    },
  );

  test(
    'tracked first unprofiled gate refusal uses existing current-state cleanup then a fresh profiled command',
    () async {
      weekly.dispose();
      client = MemberRaidClient(
        DioBackendAccountReadApi(dio, session),
        commandQuery: const {},
      );
      create();
      await load();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await clear();
      expect(weekly.pendingFailed, false);
      expect(weekly.canUseCurrent, true);
      expect(weekly.canRetry, false);
      final oldKey = posts().single.headers['Idempotency-Key'];
      await weekly.refresh();
      expect(posts(), hasLength(1), reason: 'Refresh is read-only');
      expect(weekly.canUseCurrent, true);
      await weekly.useCurrent();
      expect(weekly.hasPending, false);
      expect(
        completed,
        true,
        reason: 'Cleanup does not clear server completion',
      );
      weekly.dispose();
      client = MemberRaidClient(DioBackendAccountReadApi(dio, session));
      create();
      await load();
      respond = serve;
      await clear();
      expect(posts().last.headers['Idempotency-Key'], isNot(oldKey));
      expect(posts().last.queryParameters, MemberRaidClient.groupPolicyQuery);
      expect(completed, false);
    },
  );

  test(
    'restored v3 adopts current state after a fresh refusal, and restart requires fresh evidence',
    () async {
      await load();
      lose = true;
      await clear();
      final raw = disk();
      raw['schema'] = 3;
      for (final field in ['query', 'uncertain', 'blocked_code']) {
        (raw['pending'] as Map).remove(field);
      }
      final originalBody = copy(raw['pending']['body']);
      final originalKey = raw['pending']['key'];
      store.data[runtime.scope] = jsonEncode(raw);
      completed = true;
      weekly.dispose();
      create();
      await load();
      calls.clear();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await weekly.retry();
      expect(posts().single.queryParameters, isEmpty);
      expect(posts().single.data, originalBody);
      expect(posts().single.headers['Idempotency-Key'], originalKey);
      expect(weekly.pendingReview, true);
      expect(weekly.pendingFailed, false);
      expect(weekly.canRetry, false);
      await weekly.refresh();
      await weekly.retry();
      expect(posts(), hasLength(1));
      expect(weekly.hasPending, true);
      expect(weekly.canUseCurrent, true);
      expect(weekly.pendingCurrentState!.allowed, true);
      weekly.dispose();
      create();
      await load();
      expect(weekly.pendingReview, true);
      expect(weekly.canRetry, true);
      expect(weekly.canUseCurrent, false);
      expect(disk()['pending']['query'], null);
      expect(disk()['pending']['body'], originalBody);
      await weekly.retry();
      expect(posts(), hasLength(2));
      expect(posts().last.data, originalBody);
      expect(posts().last.headers['Idempotency-Key'], originalKey);
      expect(posts().last.queryParameters, isEmpty);
      expect(weekly.canUseCurrent, true);
      await weekly.useCurrent();
      expect(weekly.hasPending, false);
      expect(disk()['pending'], null);
      expect(completed, true);
      expect(weekly.entry(ref(), wire['data']['raid_id'])!.completed, true);
      expect(weekly.canChange(ref(), wire['data']['raid_id']), true);
      weekly.selectCycle(cycles.next);
      expect(weekly.selectedCycleKey, cycles.next);
    },
  );

  test(
    'unknown historical outcome stays unknown while current state may be adopted',
    () async {
      weekly.dispose();
      client = MemberRaidClient(
        DioBackendAccountReadApi(dio, session),
        commandQuery: const {},
      );
      create();
      await load();
      lose = true;
      await clear();
      respond = (r) {
        if (r.path.endsWith('/completion-corrections')) rejectUpgrade(r);
        return serve(r);
      };
      await weekly.retry();
      expect(weekly.pendingReview, true);
      expect(weekly.pendingFailed, false);
      expect(weekly.canUseCurrent, true);
      expect(disk()['pending']['uncertain'], true);
    },
  );

  test(
    'legacy v3 ACK recovery stays no-query even when fresh client defaults have group options',
    () async {
      await load();
      lose = true;
      await clear();
      final raw = disk();
      raw['schema'] = 3;
      for (final field in ['query', 'uncertain', 'blocked_code']) {
        (raw['pending'] as Map).remove(field);
      }
      store.data[runtime.scope] = jsonEncode(raw);
      weekly.dispose();
      create();
      await load();
      calls.clear();
      await weekly.retry();
      expect(posts().single.queryParameters, isEmpty);
      expect(weekly.hasPending, false);
    },
  );

  test(
    'schema4 rejects unsupported stored query without replacing the original',
    () async {
      await load();
      lose = true;
      await clear();
      final raw = disk();
      raw['pending']['query'] = {'contract_profile': 'beta-recruitment-1'};
      final saved = jsonEncode(raw);
      store.data[runtime.scope] = saved;
      weekly.dispose();
      create();
      calls.clear();
      await weekly.refresh();
      expect(weekly.failure, 'INVALID_RESPONSE');
      expect(posts(), isEmpty);
      expect(store.data[runtime.scope], saved);
    },
  );
  test(
    'cancel and duplicate prepare produce no POST or durable pending; selector stays fixed',
    () async {
      await load();
      final p = await weekly.prepareCorrection(ref(), wire['data']['raid_id']);
      expect(
        await weekly.prepareCorrection(ref(), wire['data']['raid_id']),
        null,
      );
      weekly.selectCycle(cycles.next);
      expect(weekly.selectedCycleKey, cycles.current);
      weekly.cancelCorrection(p!);
      expect(posts(), isEmpty);
      expect(weekly.hasPending, false);
    },
  );
  test('no completion never writes or pretends to succeed', () async {
    await load();
    wire['data']['completion_sources'] = [];
    wire['data']['permission']['allowed'] = false;
    wire['data']['permission']['reason'] = 'COMPLETION_NOT_FOUND';
    wire['data']['confirmation'] = null;
    expect(
      await weekly.prepareCorrection(ref(), wire['data']['raid_id']),
      null,
    );
    expect(weekly.failure, 'COMPLETION_NOT_FOUND');
    expect(posts(), isEmpty);
  });
  test(
    'confirmation source change requires fresh consent and sends nothing',
    () async {
      await load();
      final p = await weekly.prepareCorrection(ref(), wire['data']['raid_id']);
      wire['data']['weekly_revision']++;
      await weekly.correct(p!);
      weekly.cancelCorrection(p);
      expect(posts(), isEmpty);
      expect(weekly.failure, 'COMPLETION_CONTEXT_CHANGED');
    },
  );
  test('disk failure prevents POST and preserves pending for retry', () async {
    await load();
    store.failWrite = true;
    await clear();
    expect(posts(), isEmpty);
    expect(weekly.hasPending, true);
    expect(weekly.failure, 'LOCAL_STORAGE_FAILED');
    store.failWrite = false;
    await weekly.retry();
    expect(posts(), hasLength(1));
    expect(weekly.hasPending, false);
  });
  test(
    'lost ACK schema4 survives restart; original POST query/token/body/key without context',
    () async {
      await load();
      lose = true;
      await clear();
      expect(weekly.hasPending, true);
      final first = posts().single;
      expect(disk()['schema'], 4);
      expect(disk()['pending']['query'], MemberRaidClient.groupPolicyQuery);
      weekly.dispose();
      create();
      await load();
      calls.clear();
      await weekly.retry();
      expect(posts().single.path, first.path);
      expect(posts().single.method, 'POST');
      expect(posts().single.data, first.data);
      expect(posts().single.queryParameters, first.queryParameters);
      expect(
        posts().single.headers['Idempotency-Key'],
        first.headers['Idempotency-Key'],
      );
      expect(
        calls.where((r) => r.path.endsWith('/completion-correction-context')),
        isEmpty,
      );
      expect(weekly.hasPending, false);
    },
  );
  test(
    'successful ACK with summary failure clears durable pending and prevents another POST',
    () async {
      await load();
      readFail = true;
      await clear();
      expect(posts(), hasLength(1));
      expect(weekly.hasPending, false);
      expect(disk()['pending'], null);
      expect(weekly.failure, 'CORRECTION_REFRESH_FAILED');
      await weekly.retry();
      expect(posts(), hasLength(1));
    },
  );
  test(
    'malformed ACK stays pending and retry recovers original success',
    () async {
      await load();
      badAck = true;
      await clear();
      expect(weekly.hasPending, true);
      badAck = false;
      await weekly.retry();
      expect(weekly.hasPending, false);
    },
  );
  test(
    'expired unknown command cannot obtain new token/key automatically',
    () async {
      await load();
      lose = true;
      await clear();
      clock = clock.add(const Duration(hours: 24));
      await weekly.retry();
      expect(posts(), hasLength(1));
      expect(weekly.pendingFailed, true);
    },
  );
  test(
    'member switch while context read discards response and never writes',
    () async {
      await load();
      final gate = Completer<Map<String, dynamic>>();
      respond = (r) => r.path.endsWith('/completion-correction-context')
          ? gate.future
          : serve(r);
      final task = weekly.prepareCorrection(ref(), wire['data']['raid_id']);
      await Future<void>.delayed(Duration.zero);
      session.change(
        authenticated: true,
        user: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      gate.complete(copy(wire));
      expect(await task, null);
      expect(posts(), isEmpty);
    },
  );

  test(
    'token-only refresh uses latest token, stable regardless of JSON key ordering',
    () async {
      await load();
      final p = await weekly.prepareCorrection(ref(), wire['data']['raid_id']);
      wire['data']['confirmation']['context_token'] = 'latest-token';
      wire = {for (final e in wire.entries.toList().reversed) e.key: e.value};
      await weekly.correct(p!);
      expect(
        (posts().single.data as Map)['correction_context_token'],
        'latest-token',
      );
      expect(weekly.hasPending, false);
    },
  );
  test(
    'ACK-persisted schema3 restart clears pending without another POST',
    () async {
      await load();
      lose = true;
      await clear();
      final saved = disk();
      saved['pending']['ack'] = true;
      store.data[runtime.scope] = jsonEncode(saved);
      weekly.dispose();
      create();
      await load();
      calls.clear();
      await weekly.retry();
      expect(posts(), isEmpty);
      expect(weekly.hasPending, false);
    },
  );
  test(
    'corrupt schema3 body cannot be replaced or treated as a new request',
    () async {
      await load();
      lose = true;
      await clear();
      final saved = disk();
      saved['pending']['body']['target_cycle_key'] = '2026-10-14';
      final original = jsonEncode(saved);
      store.data[runtime.scope] = original;
      weekly.dispose();
      create();
      await weekly.refresh();
      expect(weekly.failure, 'INVALID_RESPONSE');
      expect(store.data[runtime.scope], original);
      expect(
        await weekly.prepareCorrection(ref(), wire['data']['raid_id']),
        null,
      );
      expect(posts(), hasLength(1));
    },
  );
  test(
    'original ACK is independent of the caller current week after rollover',
    () {
      final original = preview(copy(samples['ready_context']));
      final ack = copy(samples['correction_result']);
      // There is no current-clock argument: replay validation uses frozen C/T.
      MemberCompletionCorrectionResult(
        ack,
        original,
        ack['data']['command_id'],
      );
      final changed = copy(samples['ready_context']);
      changed['current_cycle_key'] = '2026-10-28';
      changed['server_now'] = '2026-10-27T22:00:00Z';
      changed['data']['confirmation']['issued_at'] = changed['server_now'];
      changed['data']['confirmation']['expires_at'] = '2026-10-27T22:02:00Z';
      expect(preview(changed).body()['target_cycle_key'], '2026-10-21');
      expect(preview(changed).body()['expected_cycle_key'], '2026-10-28');
    },
  );
  test(
    'source order, empty allowed context and forged ACK target are rejected',
    () {
      final j = copy(samples['ready_context']);
      final s = copy(j['data']['completion_sources'][0]);
      j['data']['completion_sources'] = [
        {...s, 'source': 'party'},
        s,
      ];
      expect(() => preview(j), throwsFormatException);
      j['data']['completion_sources'] = [];
      expect(() => preview(j), throwsFormatException);
    },
  );
  test(
    'ownership observation change after confirmation blocks correction',
    () async {
      await load();
      final p = await weekly.prepareCorrection(ref(), wire['data']['raid_id']);
      model.setCount(2);
      expect(weekly.correctionCurrent(p!), false);
      await weekly.correct(p);
      weekly.cancelCorrection(p);
      expect(posts(), isEmpty);
    },
  );
}
