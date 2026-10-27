import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_outcome.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import '../../support/retained_weekly_interruption_controller.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;
import 'cycle_schedule_test.dart' as f5;

const c = f1.current, n = f1.next, room = v1.roomId, round = f2.nextCycleId;
Map<String, dynamic> copy(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
Map<String, dynamic> planWire() {
  final j =
      jsonDecode(jsonEncode(f5.planWire()).replaceAll(n, c))
          as Map<String, dynamic>;
  j['scope'] = f2.envelope(c, {}, created: true)['scope'];
  return j;
}

Map<String, dynamic> contextWire(Map<String, dynamic> plan, String action) {
  final d = plan['data'] as Map;
  final mine = d['my_membership'] as Map;
  return {
    'scope': copy(plan['scope']),
    'data': <String, dynamic>{
      'room_id': room,
      'command': action,
      'actor_membership_id': mine['membership_id'],
      'actor_membership_revision': mine['revision'],
      'actor_cycle_member_id': mine['cycle_member_id'],
      'actor_cycle_member_revision': mine['cycle_member_revision'],
      'room_revision': 2,
      'members_revision': d['members_revision'],
      'plan_revision': d['revision'],
      'target_round_id': action == 'close_weekly' ? null : round,
      'effect_scope': {
        'complete_item': 'item_round',
        'personal_completion': 'personal_item',
        'close_weekly': 'target_cycle',
      }[action],
      'impact': <String, dynamic>{
        'round_ids': [round],
        'membership_count': action == 'personal_completion' ? 1 : 8,
        'assignment_count': action == 'personal_completion' ? 1 : 8,
        'reservation_segment_count': action == 'personal_completion' ? 2 : 16,
        'completed_preserved_count': 3,
      },
      'permission': f1.permit(),
      'issued_at': f2.nowStamp,
      'expires_at': '2026-10-22T03:05:00Z',
      'context_token': 'opaque',
      'target_cycle_key': c,
      'leadership': copy(d['leadership']),
    },
  };
}

void main() {
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late v1.Api api;
  late CycleInteractionRepository repository;
  late CycleParticipationController controller;
  late Map<String, dynamic> plan;
  late List<String> refreshes;
  late Map<String, Map<String, dynamic>> recorded;
  late bool loseAck;
  Map<String, dynamic> Function(Map<String, dynamic>)? changeContext;
  Map<String, dynamic> Function(Map<String, dynamic>)? changeAck;
  Completer<void>? pauseRead;
  List<Map<String, dynamic>> getWrites() =>
      api.requests.where((r) => r['method'] == 'POST').toList();
  setUp(() {
    session = ReadSessionFake();
    changes = ChangeNotifier();
    api = v1.Api();
    repository = CycleInteractionRepository(
      api: api,
      recruitment: f2.CycleGateway(),
    );
    plan = planWire();
    refreshes = [];
    recorded = {};
    loseAck = false;
    changeContext = null;
    changeAck = null;
    pauseRead = null;
    api.respond = (path, query) async {
      if (api.requests.last['method'] == 'GET') {
        if (path.endsWith('/plan')) {
          await pauseRead?.future;
          return copy(plan);
        }
        if (path.endsWith('/command-context')) {
          expect(query!['target_cycle_key'], c);
          expect(
            query['round_id'],
            query['command'] == 'close_weekly' ? null : round,
          );
          final j = contextWire(plan, query['command'] as String);
          return changeContext?.call(j) ?? j;
        }
        throw StateError(path);
      }
      final request = api.requests.last;
      final key = request['key'] as String;
      recorded.putIfAbsent(
        key,
        () => {
          'scope': copy(plan['scope']),
          'data': <String, dynamic>{
            'command_id': key,
            'room_id': room,
            'target_cycle_key': c,
            'outcome': 'applied',
            'executed_at': f2.nowStamp,
            'revisions': [
              {'resource': 'target', 'id': f2.nextCycleId, 'revision': 2},
            ],
          },
        },
      );
      if (loseAck) {
        loseAck = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final j = copy(recorded[key]!);
      return changeAck?.call(j) ?? j;
    };
    controller = RetainedWeeklyInterruptionController(
      gateway: repository,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => DateTime.parse(f2.nowStamp),
      onMutation: (t) async => refreshes.add(t),
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });
  Future<CycleOutcomePreview> preview(String action) => repository.outcome(
    room,
    c,
    action,
    round: action == 'close_weekly' ? null : round,
  );

  test(
    'only validated weekly completion publishes the current-page receipt',
    () async {
      final value = await preview('complete_item');
      changeAck = (raw) {
        raw['data']['command_id'] = v1.membershipId;
        return raw;
      };
      await controller.complete(value);
      expect(controller.completionSuccess, isNull);
      expect(controller.hasPending, true);
      changeAck = null;
      await controller.retry();
      expect(controller.completionSuccess, isNotNull);
      expect(controller.completionSuccess!.$2, room);
      expect(controller.completionSuccess!.$3, c);
      final key = controller.completionSuccess!.$1;
      await controller.retry();
      expect(controller.completionSuccess!.$1, key);
    },
  );
  test(
    'production blocks closure reads and stale submission but keeps completion',
    () async {
      final stale = await preview('close_weekly');
      controller.dispose();
      controller = CycleParticipationController(
        gateway: repository,
        session: session,
        changes: changes,
        scopeKey: () => '${session.userId}/${session.generation}',
        now: () => DateTime.parse(f2.nowStamp),
      );
      api.requests.clear();
      expect(controller.weeklyInterruptionEnabled, isFalse);
      expect(await controller.outcome(room, c, 'close_weekly'), isNull);
      await controller.complete(stale);
      expect(api.requests, isEmpty);
      expect(controller.hasPending, isFalse);
      final completion = await controller.outcome(
        room,
        c,
        'complete_item',
        round: round,
      );
      expect(completion, isNotNull);
      await controller.complete(completion!);
      expect(getWrites(), hasLength(1));
      expect(controller.hasPending, isFalse);
      expect(controller.failure, isNull);
    },
  );

  for (final action in cycleOutcomeLabels.keys) {
    test(
      '$action binds server impact, four-field body and actual target refresh',
      () async {
        final p = await preview(action);
        expect(
          p.impact['membership_count'],
          action == 'personal_completion' ? 1 : 8,
        );
        expect(p.impact['completed_preserved_count'], 3);
        expect(p.body(), {
          'expected_cycle_key': c,
          'target_cycle_key': c,
          'expected_target_revision': 1,
          'context_token': 'opaque',
        });
        await controller.complete(p);
        expect(controller.failure, isNull);
        expect(controller.hasPending, isFalse);
        expect(getWrites().single['path'], p.path);
        expect(refreshes, [c]);
        expect(refreshes, isNot(contains(n)));
      },
    );
  }
  test(
    'ordinary member can close weekly, but cannot complete entire item',
    () async {
      plan['data']['my_target_role'] = 'member';
      plan['data']['leadership']['leader_cycle_member_id'] = f5.id(99);
      await controller.complete(await preview('close_weekly'));
      expect(getWrites(), hasLength(1));
      changeContext = (j) {
        j['data']['permission'] = f1.permit(false);
        return j;
      };
      final p = await preview('complete_item');
      await controller.complete(p);
      expect(getWrites(), hasLength(1));
    },
  );
  for (final change in [
    'impact',
    'leader',
    'actor',
    'revision',
    'raid',
    'round',
  ]) {
    test('$change changes after confirmation: POST zero', () async {
      final p = await preview('complete_item');
      if (change == 'leader') {
        plan['data']['leadership']['leadership_revision']++;
      } else if (change == 'revision') {
        plan['data']['revision']++;
      } else if (change == 'raid') {
        plan['data']['game_items'][0]['difficulty_id'] = 'normal';
      } else if (change == 'round') {
        plan['data']['game_items'][0]['round_id'] = f5.id(99);
      } else {
        changeContext = (j) {
          if (change == 'impact') {
            j['data']['impact']['reservation_segment_count']++;
          } else {
            j['data']['actor_membership_revision']++;
          }
          return j;
        };
      }
      await controller.complete(p);
      expect(getWrites(), isEmpty);
      expect(controller.failure, isNotNull);
    });
  }
  test('permission revoked after confirmation: POST zero', () async {
    final p = await preview('complete_item');
    changeContext = (j) {
      j['data']['permission'] = f1.permit(false);
      return j;
    };
    await controller.complete(p);
    expect(getWrites(), isEmpty);
  });
  test(
    'unknown result retry uses original path body key token without new reads',
    () async {
      final p = await preview('personal_completion');
      loseAck = true;
      await controller.complete(p);
      expect(controller.hasPending, isTrue);
      expect(refreshes, isEmpty);
      final first = copy(getWrites().single),
          requestCount = api.requests.length;
      plan['data']['revision']++;
      await controller.retry();
      expect(api.requests.length, requestCount + 1);
      expect(getWrites().last, first);
      expect(controller.hasPending, isFalse);
      expect(refreshes, [c]);
    },
  );
  for (final change in ['key', 'room', 'target', 'generation', 'recorded']) {
    test(
      'wrong $change ACK stays pending and never announces completion',
      () async {
        final p = await preview('complete_item');
        changeAck = (j) {
          if (change == 'generation') {
            j['scope']['target_generation'] = 2;
          } else if (change == 'recorded') {
            j['data']['outcome'] = 'recorded';
          } else {
            j['data'][{
              'key': 'command_id',
              'room': 'room_id',
              'target': 'target_cycle_key',
            }[change]!] = change == 'target'
                ? n
                : f5.id(99);
          }
          return j;
        };
        await controller.complete(p);
        expect(controller.hasPending, isTrue);
        expect(refreshes, isEmpty);
        expect(controller.notice, isNull);
      },
    );
  }
  test(
    'duplicate submit is ignored; signout during recheck cannot POST',
    () async {
      final p = await preview('close_weekly');
      pauseRead = Completer<void>();
      final pending = controller.complete(p);
      await controller.complete(p);
      session.change(authenticated: false);
      pauseRead!.complete();
      await pending;
      expect(getWrites(), isEmpty);
      expect(controller.hasPending, isFalse);
    },
  );
  for (final stamp in ['2026-10-21T00:59:59Z', '2026-10-27T21:00:00Z']) {
    test(
      'pre10 or next06 permission cannot enable current completion: $stamp',
      () async {
        plan['scope']['server_now'] = stamp;
        changeContext = (j) {
          j['data']['issued_at'] = stamp;
          j['data']['expires_at'] = DateTime.parse(
            stamp,
          ).add(const Duration(minutes: 5)).toIso8601String();
          return j;
        };
        expect(
          await controller.outcome(room, c, 'complete_item', round: round),
          isNull,
        );
        expect(getWrites(), isEmpty);
      },
    );
  }
  test('future target refuses forged allowed permission', () {
    final future = f5.planWire();
    final j = contextWire(plan, 'complete_item');
    j['scope'] = copy(future['scope']);
    j['data']['target_cycle_key'] = n;
    expect(
      () => CycleOutcomePreview(
        CycleScheduleView(room, n, 'plan', future),
        'complete_item',
        round,
        j,
      ),
      throwsFormatException,
    );
  });
  test(
    'fresh token with identical meaning can be used; preview evidence is immutable',
    () async {
      final p = await preview('complete_item');
      expect(
        () => p.data['context_token'] = 'tampered',
        throwsUnsupportedError,
      );
      expect(
        () => (p.impact['round_ids'] as List).clear(),
        throwsUnsupportedError,
      );
      changeContext = (j) {
        j['data']['context_token'] = 'fresh';
        return j;
      };
      await controller.complete(p);
      expect(controller.failure, isNull);
      expect(getWrites().single['body']['context_token'], 'fresh');
    },
  );
  test(
    'member switch during recheck cannot use previous actor confirmation',
    () async {
      final p = await preview('personal_completion');
      pauseRead = Completer<void>();
      final pending = controller.complete(p);
      session.change(authenticated: true, user: 'other-user');
      pauseRead!.complete();
      await pending;
      expect(getWrites(), isEmpty);
      expect(refreshes, isEmpty);
    },
  );
  test(
    'definite server rejection clears pending and refreshes only actual target',
    () async {
      final p = await preview('close_weekly');
      changeAck = (_) =>
          throw const AccountReadException('ROUND_NOT_ACTIVE', status: 409);
      await controller.complete(p);
      expect(controller.hasPending, isFalse);
      expect(controller.failure, 'ROUND_NOT_ACTIVE');
      expect(refreshes, [c]);
      expect(controller.notice, isNot(contains('반영되었습니다')));
    },
  );
  test('read failure before confirmation submission sends nothing', () async {
    final p = await preview('complete_item');
    changeContext = (_) =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    await controller.complete(p);
    expect(getWrites(), isEmpty);
    expect(controller.hasPending, isFalse);
  });
  test(
    'old original ACK can finish after device week rollover without retargeting',
    () async {
      final p = await preview('close_weekly');
      loseAck = true;
      await controller.complete(p);
      plan['scope']['server_now'] = '2026-10-27T21:00:00Z';
      (controller as RetainedWeeklyInterruptionController).enabled = false;
      await controller.retry();
      expect(controller.hasPending, isFalse);
      expect(getWrites().map((r) => r['body']['target_cycle_key']), [c, c]);
      expect(refreshes, [c]);
    },
  );
  test(
    'partial item history is bound; unrelated item is never added to body',
    () async {
      final other = copy(plan['data']['game_items'][0]);
      other['item_id'] = f5.id(98);
      other['round_id'] = f5.id(99);
      other['round_state'] = 'completed';
      plan['data']['game_items'].add(other);
      final p = await preview('complete_item');
      expect(p.impact['round_ids'], [round]);
      await controller.complete(p);
      expect(getWrites().single['path'], '/v2/raid-rounds/$round/completion');
      expect(
        (getWrites().single['body'] as Map).keys,
        unorderedEquals([
          'expected_cycle_key',
          'context_token',
          'target_cycle_key',
          'expected_target_revision',
        ]),
      );
    },
  );
  test(
    'closed DTO rejects unknown fields, duplicate impact rounds, wrong scope and expired token',
    () async {
      for (final change in ['extra', 'duplicate', 'scope', 'expired']) {
        changeContext = (j) {
          if (change == 'extra') {
            j['data']['extra'] = true;
          }
          if (change == 'duplicate') {
            j['data']['impact']['round_ids'].add(round);
          }
          if (change == 'scope') {
            j['data']['effect_scope'] = 'target_cycle';
          }
          if (change == 'expired') {
            j['data']['issued_at'] = '2026-10-22T02:00:00Z';
            j['data']['expires_at'] = f2.nowStamp;
          }
          return j;
        };
        expect(
          await controller.outcome(room, c, 'complete_item', round: round),
          isNull,
        );
      }
      expect(getWrites(), isEmpty);
    },
  );
}
