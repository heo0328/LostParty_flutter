import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/member_manual_completion_result.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import '../../../support/server_account_read_fakes.dart';
import 'member_weekly_test.dart' as old;
import 'member_cycles_test.dart' as f1;

Map<String, dynamic> clone(Map v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late ScopedAccountRuntime runtime;
  late old.WeeklyMember model;
  late old.WeeklyMemoryStore store;
  late MemberWeeklyViewModel weekly;
  late MemberRaidClient client;
  late DateTime clock;
  late List<RequestOptions> calls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  late Map<String, Map<String, dynamic>> states, replays;
  late String current;
  String next() => DateTime.parse(
    '${current}T00:00:00Z',
  ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
  Map<String, dynamic> scope(String t) => {
    ...f1.scope(t),
    'server_now': clock.toIso8601String(),
    'current_cycle_key': current,
    'phase': t == current ? 'current' : 'future',
  };
  Map<String, dynamic> entry(String id, String raid, String t) =>
      states['$t:$id:$raid'] ??
      {
        'character_id': id,
        'raid_id': raid,
        'cycle_key': t,
        'revision': 1,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
        'state': 'incomplete',
        'completion_sources': <dynamic>[],
        'participation': null,
        'can_mark_completed': true,
        'can_clear_manual_completion': false,
        'mark_blocked_reason': null,
      };
  Map<String, dynamic> serve(RequestOptions r) {
    if (r.path == '/v1/raid-catalog') return old.catalogWire();
    if (r.path == '/v2/raid-cycles') {
      return {
        'server_now': clock.toIso8601String(),
        'current': {
          ...f1.meta(current),
          'permissions': {
            for (final k in ['read', 'create', 'admit', 'complete'])
              k: f1.permit(),
          },
        },
        'next': {
          ...f1.meta(next()),
          'permissions': {
            for (final k in ['read', 'create', 'admit', 'complete'])
              k: f1.permit(k != 'complete'),
          },
        },
        'policy_version': 'two-cycle-contract-4',
      };
    }
    if (r.path.endsWith('/raid-weekly-summary')) {
      final b = r.data as Map;
      return {
        'server_now': clock.toIso8601String(),
        'current_cycle_key': current,
        'target_cycle_keys': b['target_cycle_keys'],
        'catalog_version': '2026.08.20',
        'entries': [
          for (final t in b['target_cycle_keys'])
            for (final id in b['character_ids'])
              for (final raid in old.catalogWire()['raids'] as List)
                (() {
                  final e = entry(
                    id as String,
                    raid['raid_id'] as String,
                    t as String,
                  );
                  return {
                    ...f1.summaryEntry(id, raid['raid_id'] as String, t),
                    'weekly_revision': e['revision'],
                    'completion_sources': e['completion_sources'],
                    'permissions': {
                      'mark_completed': f1.permit(
                        t == current && e['can_mark_completed'] == true,
                      ),
                      'clear_manual_completion': f1.permit(
                        t == current &&
                            e['can_clear_manual_completion'] == true,
                      ),
                      'view_participation': f1.permit(false),
                    },
                  };
                })(),
        ],
      };
    }
    if (r.method == 'PUT') {
      final key = r.headers['Idempotency-Key'] as String;
      if (replays.containsKey(key)) return clone(replays[key]!);
      final b = r.data as Map,
          id = r.path.split('/')[4],
          raid = r.path.split('/')[6];
      final target =
          (b['target_cycle_key'] ?? b['expected_cycle_key']) as String;
      final before = entry(id, raid, target);
      final sources = [
        for (final s in before['completion_sources'] as List)
          if (s['source'] != 'manual') s,
      ];
      if (b['completed'] == true) {
        sources.add({
          'source': 'manual',
          'completed_at': clock.toIso8601String(),
          'difficulty_id': b['difficulty_id'],
          'party_id': null,
        });
      }
      final after = {
        ...before,
        'revision': (before['revision'] as int) + 1,
        'state': sources.isEmpty ? 'incomplete' : 'completed',
        'completion_sources': sources,
        'can_clear_manual_completion': b['completed'],
      };
      states['$target:$id:$raid'] = after;
      final result = r.path.startsWith('/v2')
          ? {'scope': scope(target), 'data': after}
          : after;
      return replays[key] = clone(result);
    }
    throw StateError(r.path);
  }

  void createWeekly() {
    weekly = MemberWeeklyViewModel(
      model: model,
      client: client,
      store: store,
      twoCycleEnabled: true,
      now: () => clock,
    );
  }

  setUp(() {
    clock = DateTime.utc(2026, 10, 22, 3);
    current = f1.current;
    calls = [];
    states = {};
    replays = {};
    store = old.WeeklyMemoryStore();
    session = ReadSessionFake()..userId = old.member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final api = DioBackendAccountReadApi(dio, session);
    client = MemberRaidClient(api);
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () => throw StateError('No local DB'),
      enabled: true,
    );
    model = old.WeeklyMember(runtime)..setCount(2);
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
    createWeekly();
  });
  tearDown(() async {
    weekly.dispose();
    model.dispose();
    await runtime.close();
    session.dispose();
    dio.close();
  });
  List<RequestOptions> writes() =>
      calls.where((r) => r.method == 'PUT').toList();
  Future<void> load() async {
    await weekly.refresh();
    expect(weekly.failure, isNull);
  }

  Future<void> change() async {
    final ref = model.sections.single.characters.first.ref;
    await weekly.change(ref, weekly.items(ref).first, true);
  }

  Map<String, dynamic> disk() =>
      jsonDecode(store.data[runtime.scope]!) as Map<String, dynamic>;
  Future<void> restart() async {
    weekly.dispose();
    createWeekly();
    await load();
  }

  test(
    'new command is v2, target-bound, durable before network and invalidates only C',
    () async {
      await load();
      weekly.selectCycle(f1.next);
      weekly.selectCycle(f1.current);
      final ref = model.sections.single.characters.first.ref,
          raid = weekly.items(ref).first;
      respond = (r) {
        if (r.method == 'PUT') {
          final saved = disk();
          expect(saved['schema'], 2);
          expect(saved['pending']['wire_version'], 2);
          expect(saved['pending']['body'], r.data);
          expect(saved['pending']['key'], r.headers['Idempotency-Key']);
        }
        return serve(r);
      };
      calls.clear();
      await change();
      expect(weekly.hasPending, false);
      expect(weekly.entry(ref, raid.raidId)!.manual, true);
      expect(writes().single.path, startsWith('/v2/'));
      expect((writes().single.data as Map)['target_cycle_key'], f1.current);
      final summaries = calls
          .where((r) => r.path.endsWith('/raid-weekly-summary'))
          .toList();
      expect((summaries.last.data as Map)['target_cycle_keys'], [f1.current]);
      weekly.selectCycle(f1.next);
      expect(weekly.entry(ref, raid.raidId)!.manual, false);
    },
  );
  test(
    'lost v2 ACK survives restart with original method path key body',
    () async {
      await load();
      var lose = true;
      respond = (r) {
        final result = serve(r);
        if (r.method == 'PUT' && lose) {
          lose = false;
          throw DioException(requestOptions: r);
        }
        return result;
      };
      await change();
      expect(weekly.hasPending, true);
      final first = writes().single;
      final body = jsonEncode(first.data),
          key = first.headers['Idempotency-Key'];
      await restart();
      await weekly.retry();
      expect(writes().last.path, first.path);
      expect(writes().last.method, 'PUT');
      expect(jsonEncode(writes().last.data), body);
      expect(writes().last.headers['Idempotency-Key'], key);
      expect(weekly.hasPending, false);
    },
  );
  for (final ack in [false, true]) {
    test(
      'schema1 v1 pending (ack=$ack) keeps original transport and display preferences',
      () async {
        await load();
        final ref = model.sections.single.characters.first.ref,
            raid = weekly.items(ref).first;
        final body = {
          'completed': true,
          'difficulty_id': raid.difficultyId,
          'expected_cycle_key': current,
          'expected_catalog_version': '2026.08.20',
          'expected_revision': 1,
          'expected_ownership_revision': 1,
          'expected_lifecycle_revision': 1,
        };
        store.data[runtime.scope] = jsonEncode({
          'schema': 1,
          'pending': {
            'character': ref.characterId,
            'raid': raid.raidId,
            'key': '12345678-1234-4234-8234-123456789012',
            'body': body,
            'started': clock.toIso8601String(),
            'ack': ack,
            'failed': false,
          },
          'display': {
            ref.characterId: {
              'count': 1,
              'raids': [raid.raidId],
            },
          },
        });
        await restart();
        await weekly.retry();
        expect(writes(), hasLength(ack ? 0 : 1));
        if (!ack) {
          expect(writes().single.path, startsWith('/v1/'));
          expect(writes().single.data, body);
          expect(
            (writes().single.data as Map).containsKey('target_cycle_key'),
            false,
          );
        }
        expect(disk()['schema'], 2);
        expect(disk()['pending'], isNull);
        expect(disk()['display'][ref.characterId], {
          'count': 1,
          'raids': [raid.raidId],
        });
      },
    );
  }
  test(
    'legacy schema2 manual false pending preserves party evidence and transport',
    () async {
      await load();
      final ref = model.sections.single.characters.first.ref,
          raid = weekly.items(ref).first;
      await change();
      final k = '$current:${ref.characterId}:${raid.raidId}';
      states[k]!['completion_sources'].add({
        'source': 'party',
        'completed_at': clock.toIso8601String(),
        'difficulty_id': raid.difficultyId,
        'party_id': f1.room,
      });
      await weekly.refreshTarget(current);
      store.data[runtime.scope] = jsonEncode({
        'schema': 2,
        'pending': {
          'character': ref.characterId,
          'raid': raid.raidId,
          'key': '12345678-1234-4234-8234-123456789012',
          'body': {
            'completed': false,
            'difficulty_id': null,
            'expected_cycle_key': current,
            'target_cycle_key': current,
            'expected_catalog_version': '2026.08.20',
            'expected_revision': states[k]!['revision'],
            'expected_ownership_revision': 1,
            'expected_lifecycle_revision': 1,
          },
          'started': clock.toIso8601String(),
          'ack': false,
          'failed': false,
          'wire_version': 2,
        },
        'display': {},
      });
      await restart();
      await weekly.retry();
      expect((writes().last.data as Map)['completed'], false);
      expect((writes().last.data as Map)['difficulty_id'], null);
      final e = weekly.entry(ref, raid.raidId)!;
      expect(e.manual, false);
      expect(e.party, true);
      expect(e.completed, true);
      expect(e.participating, false);
      // A new explicit correction is now available for the remaining party
      // projection, but must not change the original PUT semantics above.
      expect(weekly.canChange(ref, raid.raidId), true);
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong-target': (j) => j['scope']['target_cycle_key'] = f1.next,
    'wrong-policy': (j) => j['scope']['policy_version'] = 'bad',
    'wrong-actor': (j) => j['data']['character_id'] = f1.room,
    'wrong-generation': (j) => j['scope']['target_generation'] = 1,
    'wrong-data-cycle': (j) => j['data']['cycle_key'] = f1.next,
    'missing-scope': (j) => j.remove('scope'),
  }.entries) {
    test(
      'invalid v2 original result retains pending: ${mutation.key}',
      () async {
        await load();
        respond = (r) {
          final result = serve(r);
          if (r.method == 'PUT') mutation.value(result);
          return result;
        };
        await change();
        expect(weekly.failure, 'INVALID_RESPONSE');
        expect(weekly.hasPending, true);
        expect(disk()['pending']['ack'], false);
      },
    );
  }
  test(
    'ACK followed by summary failure retries read only, retaining persisted ACK',
    () async {
      await load();
      var fail = true;
      respond = (r) {
        if (r.path.endsWith('/raid-weekly-summary') &&
            writes().isNotEmpty &&
            fail) {
          throw DioException(requestOptions: r);
        }
        return serve(r);
      };
      await change();
      expect(weekly.hasPending, true);
      expect(disk()['pending']['ack'], true);
      fail = false;
      await restart();
      await weekly.retry();
      expect(writes(), hasLength(1));
      expect(weekly.hasPending, false);
    },
  );
  test(
    'storage failure prevents HTTP and leaves in-memory command for original retry',
    () async {
      await load();
      store.failWrite = true;
      await change();
      expect(writes(), isEmpty);
      expect(weekly.hasPending, true);
      expect(weekly.failure, 'LOCAL_STORAGE_FAILED');
      store.failWrite = false;
      await weekly.retry();
      expect(writes(), hasLength(1));
      expect(weekly.hasPending, false);
    },
  );
  test(
    'rollover retry returns original C ACK without shifting target into new C',
    () async {
      await load();
      clock = DateTime.utc(2026, 10, 27, 20, 59);
      var lose = true;
      respond = (r) {
        final result = serve(r);
        if (r.method == 'PUT' && lose) {
          lose = false;
          throw DioException(requestOptions: r);
        }
        return result;
      };
      await change();
      expect(weekly.hasPending, true);
      final original = clone(writes().single.data as Map);
      clock = DateTime.utc(2026, 10, 27, 21, 1);
      current = f1.next;
      await weekly.retry();
      expect(writes().last.data, original);
      expect(weekly.hasPending, false);
      expect(weekly.selectedCycleKey, f1.next);
    },
  );
  test('N and pre-10:00 checks remain disabled', () async {
    await load();
    final ref = model.sections.single.characters.first.ref;
    weekly.selectCycle(f1.next);
    expect(weekly.canChange(ref, weekly.items(ref).first.raidId), false);
    await change();
    expect(writes(), isEmpty);
    weekly.selectCycle(current);
    clock = DateTime.utc(2026, 10, 21, 0, 59);
    await weekly.refresh();
    expect(weekly.canChange(ref, weekly.items(ref).first.raidId), false);
    await change();
    expect(writes(), isEmpty);
  });
  test(
    'corrupt schema2 pending is not overwritten by a default display/save',
    () async {
      await load();
      store.data[runtime.scope] = jsonEncode({
        'schema': 2,
        'display': {},
        'pending': {'wire_version': 3},
      });
      final original = store.data[runtime.scope];
      weekly.dispose();
      createWeekly();
      await weekly.refresh();
      expect(weekly.failure, 'INVALID_RESPONSE');
      expect(store.data[runtime.scope], original);
      expect(writes(), isEmpty);
    },
  );
  test('future or incomplete scope is rejected directly', () {
    final j = {
      'scope': scope(f1.next),
      'data': entry(f1.room, 'raid_a', f1.next),
    };
    expect(
      () => MemberManualCompletionResult(j, f1.next),
      throwsFormatException,
    );
  });
}
