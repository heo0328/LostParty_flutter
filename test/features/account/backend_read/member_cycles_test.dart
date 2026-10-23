import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/member_cycle_models.dart';
import 'package:lost_party/features/account/domain/member_raid_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_read_view_model.dart';
import '../../../support/server_account_read_fakes.dart';
import 'member_weekly_test.dart'
    show WeeklyMember, WeeklyMemoryStore, member, catalogWire;

const current = '2026-10-21', next = '2026-10-28';
const room = '99999999-9999-4999-8999-999999999999';
Future<void> settled(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Read did not settle');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Map<String, dynamic> membership({String id = room, Object? order}) => {
  'membership_id': id,
  'revision': 1,
  'room_id': room,
  'state': 'current',
  'joined_at': '2026-10-21T03:00:00Z',
  'ended_at': null,
  'assignments': [],
  'room': null,
  'recovery_only': false,
  'history_only': false,
  'permissions': {'view_plan': permit(false)},
  'target_role': 'none',
  'cycle_member_id': null,
  'cycle_member_revision': null,
  'joined_order': order,
  'target_participation_state': 'not_selected',
  'target_cycle_key': current,
  'room_cycle_id': null,
  'target_generation': null,
  'target_revision': null,
};
Map<String, dynamic> permit([bool allowed = true]) => {
  'allowed': allowed,
  'reason': allowed ? null : 'PLAY_NOT_STARTED',
  'next_change_at': null,
};
Map<String, dynamic> meta(String key) => {
  'cycle_key': key,
  'starts_at': DateTime.parse(
    '${key}T00:00:00Z',
  ).subtract(const Duration(hours: 3)).toIso8601String(),
  'ends_at': DateTime.parse('${key}T00:00:00Z')
      .add(const Duration(days: 7))
      .subtract(const Duration(hours: 3))
      .toIso8601String(),
  'playable_from': '${key}T01:00:00Z',
  'permissions': {
    for (final k in ['read', 'create', 'admit', 'complete'])
      k: permit(k != 'complete' || key == current),
  },
};
Map<String, dynamic> cycles() => {
  'server_now': '2026-10-22T03:00:00Z',
  'current': meta(current),
  'next': meta(next),
  'policy_version': twoCyclePolicy,
};
Map<String, dynamic> summaryEntry(
  String id,
  String raid,
  String target, {
  bool joined = false,
  bool completed = false,
}) => {
  'character_id': id,
  'raid_id': raid,
  'target_cycle_key': target,
  'weekly_revision': 1,
  'ownership_revision': 1,
  'lifecycle_revision': 1,
  'completion_sources': [
    if (completed)
      {
        'source': 'manual',
        'completed_at': '2026-10-22T01:00:00Z',
        'difficulty_id': null,
        'party_id': null,
      },
  ],
  'participation': joined
      ? {
          'room_id': room,
          'round_id': room,
          'assignment_id': room,
          'difficulty_id': 'normal',
          'status': 'confirmed',
          'room_title': '합성 모집',
          'can_view_detail': true,
        }
      : null,
  'continuation_state': joined ? 'confirmed' : 'not_selected',
  'permissions': {
    'mark_completed': permit(target == current),
    'clear_manual_completion': permit(target == current && completed),
    'view_participation': permit(joined),
  },
};
Map<String, dynamic> scope(String t) => {
  'server_now': '2026-10-22T03:00:00Z',
  'current_cycle_key': current,
  'target_cycle_key': t,
  'playable_from': '${t}T01:00:00Z',
  'phase': t == current ? 'current' : 'future',
  'target_revision': null,
  'policy_version': twoCyclePolicy,
  'room_cycle_id': null,
  'target_generation': null,
};

Map<String, dynamic> roomCard() => {
  'room_id': room,
  'revision': 1,
  'title': '합성 모집',
  'scope': 'public',
  'group_id': null,
  'admission_mode': 'leader_only',
  'experience_level': null,
  'app_capacity': 8,
  'app_member_count': 1,
  'state': 'active',
  'items': [
    {
      'item_id': room,
      'raid_id': 'sample_raid',
      'difficulty_id': 'normal',
      'game_party_size': 8,
      'round_id': room,
    },
  ],
  'game_items': [],
  'leader_display': null,
  'created_at': '2026-10-21T03:00:00Z',
  'phase': 'current',
  'restricted': false,
  'schedule_summary': {
    'mode': 'manual',
    'occurrence_mode': null,
    'confirmed_starts_at': [],
    'earliest_start': null,
    'latest_start': null,
  },
  'combat_requirement': {
    'input_mode': 'shared',
    'dealer_min': null,
    'support_min': null,
  },
  'continuation_enabled': false,
  'permissions': {'view_detail': permit(), 'view_plan': permit(false)},
  'leadership': {
    'leader_cycle_member_id': room,
    'leadership_revision': 1,
    'leader_membership_id': room,
  },
  'my_target_role': 'member',
  'target_cycle_key': current,
  'target_state': 'open',
  'target_revision': 1,
  'room_cycle_id': room,
  'target_generation': 1,
};

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late ScopedAccountRuntime runtime;
  late WeeklyMember model;
  late MemberWeeklyViewModel weekly;
  late List<RequestOptions> calls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  Map<String, dynamic> serve(RequestOptions r) {
    if (r.path == '/v1/raid-catalog') return catalogWire();
    if (r.path == '/v2/raid-cycles') return cycles();
    if (r.path == '/v2/me/raid-weekly-summary') {
      final body = r.data as Map;
      return {
        'server_now': '2026-10-22T03:00:00Z',
        'current_cycle_key': current,
        'target_cycle_keys': body['target_cycle_keys'],
        'catalog_version': '2026.08.20',
        'entries': [
          for (final t in body['target_cycle_keys'])
            for (final id in body['character_ids'])
              for (final raid in catalogWire()['raids'] as List)
                summaryEntry(
                  id as String,
                  raid['raid_id'] as String,
                  t as String,
                ),
        ],
      };
    }
    if (r.path.endsWith('/raid-room-memberships')) {
      return {
        'scope': scope(r.queryParameters['target_cycle_key'] as String),
        'data': {
          'items': [],
          'membership_head': 1,
          'next_cursor': null,
          'evaluated_at': '2026-10-22T03:00:00Z',
        },
      };
    }
    throw StateError(r.path);
  }

  setUp(() {
    session = ReadSessionFake()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    api = DioBackendAccountReadApi(dio, session);
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () => throw StateError('No local DB'),
      enabled: true,
    );
    model = WeeklyMember(runtime)..setCount(2);
    weekly = MemberWeeklyViewModel(
      model: model,
      client: MemberRaidClient(api),
      store: WeeklyMemoryStore(),
      twoCycleEnabled: true,
      now: () => DateTime.utc(2026, 10, 22, 3),
    );
    calls = [];
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
  });
  test(
    'mutation refresh reads only affected actual T without moving selected account week',
    () async {
      await weekly.refresh();
      final before = calls.length;
      await weekly.refreshTarget(next);
      final summaries = calls
          .skip(before)
          .where((r) => r.path == '/v2/me/raid-weekly-summary')
          .toList();
      expect(summaries.length, 1);
      expect((summaries.single.data as Map)['target_cycle_keys'], [next]);
      expect(weekly.selectedCycleKey, current);
    },
  );
  tearDown(() async {
    weekly.dispose();
    model.dispose();
    await runtime.close();
    session.dispose();
    dio.close();
  });
  test(
    'authenticated C/N metadata and read POST; tab switch reuses batch and blocks N completion',
    () async {
      await weekly.refresh();
      expect(weekly.failure, isNull);
      expect(weekly.cycles?.next.key, next);
      final post = calls.singleWhere(
        (r) => r.path.endsWith('/raid-weekly-summary'),
      );
      expect(post.method, 'POST');
      expect(post.headers['Authorization'], 'Bearer test-access');
      expect(post.headers.containsKey('Idempotency-Key'), false);
      final ref = model.sections.single.characters.first.ref;
      final raid = weekly.items(ref).first;
      weekly.selectCycle(next);
      expect(weekly.entry(ref, raid.raidId)?.cycleKey, next);
      expect(weekly.canChange(ref, raid.raidId), false);
      expect(
        calls.where((r) => r.path.endsWith('/raid-weekly-summary')).length,
        1,
      );
    },
  );
  test(
    'more than 50 characters split with no extra bootstrap/provider reads',
    () async {
      model.setCount(51);
      await weekly.refresh();
      expect(weekly.failure, isNull);
      expect(
        calls.where((r) => r.path.endsWith('/raid-weekly-summary')).length,
        2,
      );
      expect(
        calls.every(
          (r) => {
            '/v1/raid-catalog',
            '/v2/raid-cycles',
            '/v2/me/raid-weekly-summary',
          }.contains(r.path),
        ),
        true,
      );
    },
  );
  test('zero characters does not send invalid empty summary', () async {
    model.setCount(0);
    await weekly.refresh();
    expect(weekly.failure, isNull);
    expect(calls.any((r) => r.path.endsWith('/raid-weekly-summary')), false);
  });
  test(
    'missing or duplicate entry is rejected, not projected as incomplete',
    () async {
      respond = (r) {
        final j = serve(r);
        if (r.path.endsWith('/raid-weekly-summary')) {
          final entries = j['entries'] as List;
          entries.removeLast();
        }
        return j;
      };
      await weekly.refresh();
      expect(weekly.failure, 'INVALID_RESPONSE');
      expect(weekly.ready, false);
    },
  );
  test(
    'one target refresh failure keeps confirmed other target snapshot',
    () async {
      await weekly.refresh();
      final ref = model.sections.single.characters.first.ref;
      final raid = weekly.items(ref).first;
      weekly.selectCycle(next);
      respond = (r) {
        if (r.path.endsWith('/raid-weekly-summary')) {
          throw StateError('offline');
        }
        return serve(r);
      };
      await weekly.refresh();
      expect(weekly.failure, isNotNull);
      weekly.selectCycle(current);
      expect(weekly.entry(ref, raid.raidId)?.cycleKey, current);
      expect(weekly.canChange(ref, raid.raidId), false);
    },
  );
  test(
    'logout fences delayed summary and clears C/N selection and participation',
    () async {
      final blocked = Completer<Map<String, dynamic>>();
      respond = (r) =>
          r.path.endsWith('/raid-weekly-summary') ? blocked.future : serve(r);
      weekly.initialize();
      await settled(
        () => calls.any((r) => r.path.endsWith('/raid-weekly-summary')),
      );
      final pending = weekly.refresh();
      await Future<void>.delayed(Duration.zero);
      final req = calls.lastWhere(
        (r) => r.path.endsWith('/raid-weekly-summary'),
      );
      session.change(authenticated: false);
      blocked.complete(serve(req));
      await pending;
      expect(weekly.cycles, isNull);
      expect(weekly.ready, false);
    },
  );
  test(
    'summary preserves independent completion and real participation; future has no clear permission',
    () {
      final j = summaryEntry(
        room,
        'sample_raid',
        next,
        joined: true,
        completed: true,
      );
      final e = MemberWeeklyEntry.fromSummary(j);
      expect(e.completed, true);
      expect(e.participating, true);
      expect(e.roomId, room);
      expect(e.canViewParticipation, true);
      expect(e.canClear, false);
      j['participation'] = null;
      j['completion_sources'] = [];
      j['continuation_state'] = 'legacy_intent';
      expect(MemberWeeklyEntry.fromSummary(j).participating, false);
    },
  );
  test('invalid C/N boundary and target date are rejected', () {
    final j = cycles();
    (j['next'] as Map)['cycle_key'] = current;
    expect(() => MemberCycles.fromJson(j), throwsFormatException);
    final s = summaryEntry(room, 'sample_raid', '2026-10-22');
    expect(() => MemberWeeklyEntry.fromSummary(s), throwsFormatException);
  });
  test(
    'own page is explicit target, cursor scoped; late old target response cannot overwrite',
    () async {
      final changed = ChangeNotifier();
      final m = CycleReadViewModel(
        repository: CycleReadRepository(api),
        changes: changed,
        scopeKey: () => '${session.userId}/${session.generation}',
      );
      final old = Completer<Map<String, dynamic>>();
      respond = (r) => r.queryParameters['target_cycle_key'] == current
          ? old.future
          : serve(r);
      m.select(current);
      await Future<void>.delayed(Duration.zero);
      m.select(next);
      await Future<void>.delayed(Duration.zero);
      old.complete({
        'scope': scope(current),
        'data': {
          'items': [],
          'membership_head': 1,
          'next_cursor': null,
          'evaluated_at': '2026-10-22T03:00:00Z',
        },
      });
      await settled(() => !m.loading);
      expect(m.target, next);
      expect(m.failure, isNull);
      expect(m.loading, false);
      expect(calls.every((r) => r.queryParameters['limit'] == 20), true);
      m.dispose();
      changed.dispose();
    },
  );

  test(
    'summary read from another user/session cannot survive a session switch',
    () async {
      weekly.initialize();
      await settled(() => weekly.ready);
      session.change(
        authenticated: true,
        user: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      expect(weekly.cycles, isNull);
      expect(weekly.ready, false);
      await settled(() => !weekly.loading);
      expect(weekly.failure, isNotNull);
    },
  );
  test(
    '10:00 temporal guard applies even if stale summary permission says allowed',
    () async {
      respond = (r) {
        final j = serve(r);
        if (r.path == '/v2/raid-cycles') {
          j['server_now'] = '2026-10-21T00:30:00Z';
        }
        return j;
      };
      await weekly.refresh();
      expect(weekly.failure, isNull);
      final ref = model.sections.single.characters.first.ref;
      expect(weekly.canChange(ref, weekly.items(ref).first.raidId), false);
    },
  );
  test(
    '06:00 relabel keeps selected actual N as new C without moving data',
    () async {
      await weekly.refresh();
      weekly.selectCycle(next);
      respond = (r) {
        final j = serve(r);
        if (r.path == '/v2/raid-cycles') {
          return {
            'server_now': '2026-10-29T03:00:00Z',
            'current': meta(next),
            'next': meta('2026-11-04'),
            'policy_version': twoCyclePolicy,
          };
        }
        if (r.path.endsWith('/raid-weekly-summary')) {
          j['current_cycle_key'] = next;
        }
        return j;
      };
      await weekly.refresh();
      expect(weekly.failure, isNull);
      expect(weekly.cycles!.current.key, next);
      expect(weekly.selectedCycleKey, next);
      expect(weekly.selectedIsCurrent, true);
    },
  );
  test(
    'selection changed while C read is pending remains N after response',
    () async {
      await weekly.refresh();
      final blocked = Completer<Map<String, dynamic>>();
      respond = (r) =>
          r.path.endsWith('/raid-weekly-summary') ? blocked.future : serve(r);
      final flight = weekly.refresh();
      await settled(
        () =>
            calls
                .where((r) => r.path.endsWith('/raid-weekly-summary'))
                .length ==
            2,
      );
      weekly.selectCycle(next);
      blocked.complete(serve(calls.last));
      await flight;
      expect(weekly.selectedCycleKey, next);
    },
  );
  test(
    'persistent-only relation and lossless join order, numeric and overflow rejected',
    () {
      final j = membership(order: '9007199254740993');
      final row = CycleOwnRow(j, current, false);
      expect(row.participationState, 'not_selected');
      expect(row.canView, false);
      j['joined_order'] = 9007199254740993;
      expect(() => CycleOwnRow(j, current, false), throwsFormatException);
      j['joined_order'] = '9223372036854775808';
      expect(() => CycleOwnRow(j, current, false), throwsFormatException);
    },
  );
  test(
    'own page refresh accepts same first cursor, repeated more cursor is rejected',
    () async {
      final changed = ChangeNotifier();
      final m = CycleReadViewModel(
        repository: CycleReadRepository(api),
        changes: changed,
        scopeKey: () => '${session.userId}/${session.generation}',
      );
      respond = (r) => {
        'scope': scope(current),
        'data': {
          'items': [
            membership(
              id: r.queryParameters['cursor'] == null
                  ? room
                  : '88888888-8888-4888-8888-888888888888',
            ),
          ],
          'membership_head': 1,
          'next_cursor': 'page2',
          'evaluated_at': '2026-10-22T03:00:00Z',
        },
      };
      m.select(current);
      await settled(() => !m.loading);
      expect(m.failure, isNull);
      await m.load();
      expect(m.failure, isNull);
      await m.load(more: true);
      expect(m.failure, 'INVALID_RESPONSE');
      expect(m.rows.length, 1);
      m.dispose();
      changed.dispose();
    },
  );
  test(
    'target detail request validates generation and does not request private plan',
    () async {
      respond = (r) => {
        'scope': {
          ...scope(current),
          'room_cycle_id': room,
          'target_generation': 1,
          'target_revision': 1,
        },
        'data': roomCard(),
      };
      final value = await CycleReadRepository(api).room(room, current);
      expect(value.title, '합성 모집');
      expect(value.canView, true);
      expect(calls.single.path, '/v2/raid-rooms/$room');
      expect(calls.single.queryParameters, {'target_cycle_key': current});
      respond = (r) => {
        'scope': {
          ...scope(current),
          'room_cycle_id': room,
          'target_generation': 2,
          'target_revision': 1,
        },
        'data': roomCard(),
      };
      await expectLater(
        CycleReadRepository(api).room(room, current),
        throwsA(isA<Exception>()),
      );
    },
  );
  test('summary validates view permission even without participation', () {
    final j = summaryEntry(room, 'sample_raid', current);
    j['permissions'] = {
      ...j['permissions'] as Map<String, dynamic>,
      'view_participation': null,
    };
    expect(() => MemberWeeklyEntry.fromSummary(j), throwsFormatException);
  });
  test('read wrapper cannot claim an out of range target or wrong phase', () {
    final j = scope(next);
    j['phase'] = 'current';
    expect(() => CycleReadScope(j, next), throwsFormatException);
    final far = scope('2026-11-04');
    expect(() => CycleReadScope(far, '2026-11-04'), throwsFormatException);
  });
  test(
    'new current manual completion uses target v2 command and refreshes its summary only',
    () async {
      var saved = false;
      await weekly.refresh();
      final ref = model.sections.single.characters.first.ref;
      final raid = weekly.items(ref).first;
      respond = (r) {
        if (r.path.endsWith('/manual-completion')) {
          saved = true;
          return {
            'scope': scope(current),
            'data': {
              'character_id': ref.characterId,
              'raid_id': raid.raidId,
              'cycle_key': current,
              'revision': 2,
              'ownership_revision': 1,
              'lifecycle_revision': 1,
              'state': 'completed',
              'completion_sources': [
                {
                  'source': 'manual',
                  'completed_at': '2026-10-22T03:00:00Z',
                  'difficulty_id': raid.difficultyId,
                  'party_id': null,
                },
              ],
              'participation': null,
              'can_mark_completed': true,
              'can_clear_manual_completion': true,
              'mark_blocked_reason': null,
            },
          };
        }
        final j = serve(r);
        if (saved && r.path.endsWith('/raid-weekly-summary')) {
          j['entries'] = [
            for (final raw in j['entries'] as List)
              if ((raw as Map)['character_id'] == ref.characterId &&
                  raw['raid_id'] == raid.raidId &&
                  raw['target_cycle_key'] == current)
                {
                  ...summaryEntry(
                    ref.characterId,
                    raid.raidId,
                    current,
                    completed: true,
                  ),
                  'weekly_revision': 2,
                }
              else
                raw,
          ];
        }
        return j;
      };
      await weekly.change(ref, raid, true);
      expect(weekly.failure, isNull);
      expect(weekly.hasPending, false);
      expect(weekly.entry(ref, raid.raidId)?.manual, true);
      final writes = calls.where((r) => r.method == 'PUT').toList();
      expect(writes.length, 1);
      expect((writes.single.data as Map)['expected_cycle_key'], current);
      expect((writes.single.data as Map)['target_cycle_key'], current);
      expect(writes.single.path, startsWith('/v2/me/characters/'));
      expect(writes.single.headers['Idempotency-Key'], isNotEmpty);
      weekly.selectCycle(next);
      expect(weekly.entry(ref, raid.raidId)?.manual, false);
      expect(weekly.canChange(ref, raid.raidId), false);
    },
  );
  for (final always in [false, true]) {
    test(
      'cycle boundary refresh is retried only once (persistent=$always)',
      () async {
        var requests = 0;
        respond = (r) {
          if (r.path.endsWith('/raid-weekly-summary') &&
              (++requests == 1 || always)) {
            throw DioException(
              requestOptions: r,
              response: Response(
                requestOptions: r,
                statusCode: 409,
                data: {
                  'error': {'code': 'CYCLE_CHANGED', 'request_id': 'test'},
                },
              ),
            );
          }
          return serve(r);
        };
        await weekly.refresh();
        expect(requests, 2);
        expect(weekly.failure, always ? 'CYCLE_CHANGED' : null);
        expect(calls.where((r) => r.path == '/v2/raid-cycles').length, 2);
      },
    );
  }
  test(
    '10:00 permission change refreshes C even while N is selected',
    () async {
      respond = (r) {
        final j = serve(r);
        if (r.path == '/v2/raid-cycles') {
          j['server_now'] = '2026-10-21T00:30:00Z';
          ((j['current'] as Map)['permissions'] as Map)['complete'] = permit(
            false,
          );
        }
        return j;
      };
      await weekly.refresh();
      weekly.selectCycle(next);
      respond = serve;
      await weekly.refresh();
      expect(weekly.failure, isNull);
      final body =
          calls.lastWhere((r) => r.path.endsWith('/raid-weekly-summary')).data
              as Map;
      expect(body['target_cycle_keys'], [current, next]);
      expect(weekly.selectedCycleKey, next);
      weekly.selectCycle(current);
      final ref = model.sections.single.characters.first.ref;
      expect(weekly.canChange(ref, weekly.items(ref).first.raidId), true);
    },
  );
}
