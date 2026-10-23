import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/membership_actions.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;

Map<String, dynamic> copy(Object? v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
final fixtures =
    (jsonDecode(
              File('test/fixtures/membership_actions.json').readAsStringSync(),
            )
            as Map)['examples']
        as List;
Map<String, dynamic> fixture(String name) =>
    copy(fixtures.singleWhere((v) => v['name'] == name)['value']);
MembershipActionContext context(Map<String, dynamic> raw) =>
    MembershipActionContext(
      raw['data']['room_id'],
      raw['scope']['view_cycle_key'],
      raw,
    );
const key = '00000000-0000-4000-8000-000000000001';

void main() {
  for (final name in [
    'eight-members-two-targets',
    'empty-effects',
    'no-successor',
  ]) {
    test('published PostgreSQL response pair: $name', () {
      final result = fixture('$name-result');
      final c = context(fixture('$name-context'));
      final p = c.select(result['data']['action']);
      final r = MembershipActionResult(result, p, result['data']['command_id']);
      expect(r.affected, p.affected);
      expect(
        p.body().keys,
        unorderedEquals([
          'expected_cycle_key',
          'view_cycle_key',
          'actor_membership_id',
          'expected_actor_membership_revision',
          'action',
          'context_token',
        ]),
      );
      if (name == 'eight-members-two-targets') {
        expect(r.data['effects'].first['members'], hasLength(8));
      }
      if (name == 'empty-effects') {
        expect(r.actorEnded, isTrue);
        expect(r.affected, isEmpty);
      }
      if (name == 'no-successor') {
        expect(r.data['effects'].single['leadership_status'], 'pending_review');
      }
    });
  }
  test(
    'snapshot is deep immutable and only selected option is confirmation evidence',
    () {
      final raw = fixture('eight-members-two-targets-context'),
          c = context(raw);
      final signature = c.select('leave_all').signature;
      raw['data']['options']['leave_all']['impact']['targets'].clear();
      expect(c.select('leave_all').signature, signature);
      expect(
        () => c.options['leave_all']['impact']['targets'].clear(),
        throwsUnsupportedError,
      );
      final refreshed = fixture('eight-members-two-targets-context');
      refreshed['data']['options']['leave_all']['confirmation']['context_token'] =
          'new-token';
      refreshed['data']['options']['recover_leadership']['permission']['reason'] =
          'DIFFERENT_UNSELECTED_OPTION';
      expect(context(refreshed).select('leave_all').signature, signature);
    },
  );

  final contextMutations = <String, void Function(Map<String, dynamic>)>{
    'extra root field': (v) => v['unexpected'] = true,
    'wrong room': (v) => v['data']['room_id'] = key,
    'foreign view': (v) => v['scope']['view_cycle_key'] = '2026-11-04',
    'calendar overflow': (v) =>
        v['scope']['server_now'] = '2026-02-30T00:00:00Z',
    'denied impact': (v) =>
        v['data']['options']['recover_leadership']['impact'] = {},
    'token byte overflow': (v) =>
        v['data']['options']['leave_all']['confirmation']['context_token'] =
            List.filled(1400, '가').join(),
    'expired token': (v) =>
        v['data']['options']['leave_all']['confirmation']['expires_at'] =
            v['scope']['server_now'],
    'target order': (v) {
      final i = v['data']['options']['leave_all']['impact'];
      i['affected_cycle_keys'] = (i['affected_cycle_keys'] as List).reversed
          .toList();
    },
    'revision rule': (v) =>
        v['data']['options']['leave_all']['impact']['targets'][0]['revision_rules']['target']['before'] =
            999,
    'duplicate member': (v) {
      final a =
          v['data']['options']['dissolve_led_targets']['impact']['targets'][0]['affected_members'];
      a[1] = a[0];
    },
    'completed assignment cancelled': (v) {
      final a =
          v['data']['options']['dissolve_led_targets']['impact']['targets'][0]['affected_members'][0];
      a['preserved_completed_assignment_ids'] = a['cancelled_assignment_ids'];
    },
  };
  for (final e in contextMutations.entries) {
    test('context rejects ${e.key}', () {
      final raw = fixture('eight-members-two-targets-context');
      final room = raw['data']['room_id'] as String,
          view = raw['scope']['view_cycle_key'] as String;
      e.value(raw);
      expect(
        () => MembershipActionContext(room, view, raw),
        throwsFormatException,
      );
    });
  }
  final ackMutations = <String, void Function(Map<String, dynamic>)>{
    'wrong key': (v) => v['data']['command_id'] = key,
    'wrong action': (v) => v['data']['action'] = 'leave_target',
    'wrong room': (v) => v['data']['room_id'] = key,
    'wrong actor': (v) => v['data']['actor_membership_id'] = key,
    'wrong C': (v) => v['scope']['current_cycle_key'] = '2026-10-28',
    'wrong room revision': (v) => v['data']['room_revision'] = 999,
    'wrong actor revision': (v) => v['data']['actor_membership_revision'] = 999,
    'wrong ended flag': (v) => v['data']['actor_membership_ended'] = false,
    'missing effect': (v) => v['data']['effects'].removeLast(),
    'target order': (v) =>
        v['data']['effects'] = (v['data']['effects'] as List).reversed.toList(),
    'generation': (v) => v['data']['effects'][0]['target_generation'] = 2,
    'target state': (v) => v['data']['effects'][0]['target_state'] = 'open',
    'non-increased target': (v) =>
        v['data']['effects'][0]['target_revision'] = 1,
    'exact members revision': (v) =>
        v['data']['effects'][0]['members_revision'] = 999,
    'leadership ID': (v) =>
        v['data']['effects'][0]['leadership']['leader_membership_id'] = key,
    'member state': (v) =>
        v['data']['effects'][0]['members'][0]['state'] = 'completed',
    'assignment loss': (v) =>
        v['data']['effects'][0]['members'][0]['cancelled_assignment_ids'] = [],
    'extra result field': (v) => v['data']['extra'] = false,
  };
  for (final e in ackMutations.entries) {
    test('ACK rejects ${e.key}', () {
      final p = context(
        fixture('eight-members-two-targets-context'),
      ).select('dissolve_led_targets');
      final raw = fixture('eight-members-two-targets-result');
      final commandKey = raw['data']['command_id'] as String;
      e.value(raw);
      expect(
        () => MembershipActionResult(raw, p, commandKey),
        throwsFormatException,
      );
    });
  }

  late base.Api api;
  late CycleInteractionRepository repo;
  late CycleParticipationController controller;
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late Map<String, dynamic> wire;
  late String scenario;
  late DateTime now;
  late bool loseAck, wrongAck, refreshFail;
  Completer<void>? pause;
  final refreshed = <String>[];
  List<Map<String, dynamic>> writes() =>
      api.requests.where((r) => r['method'] == 'POST').toList();
  setUp(() {
    scenario = 'eight-members-two-targets';
    wire = fixture('$scenario-context');
    now = DateTime.parse(wire['scope']['server_now']);
    loseAck = wrongAck = refreshFail = false;
    pause = null;
    refreshed.clear();
    api = base.Api();
    session = ReadSessionFake();
    changes = ChangeNotifier();
    api.respond = (path, q) async {
      if (api.requests.last['method'] == 'GET') {
        await pause?.future;
        return copy(wire);
      }
      if (loseAck) {
        loseAck = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final r = fixture('$scenario-result');
      r['data']['command_id'] = wrongAck ? key : api.requests.last['key'];
      return r;
    };
    repo = CycleInteractionRepository(
      api: api,
      recruitment: cycles.CycleGateway(),
    );
    controller = CycleParticipationController(
      gateway: repo,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => now,
      onMutation: (t) async {
        refreshed.add(t);
        if (refreshFail) throw StateError('refresh');
      },
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });

  test(
    'context read has no key; exact six-field HTTP and target notifications',
    () async {
      final p = (await controller.membershipContext(
        wire['data']['room_id'],
        wire['scope']['view_cycle_key'],
      ))!.select('dissolve_led_targets');
      expect(api.requests.single['key'], isNull);
      expect(api.requests.single['query'], {'target_cycle_key': p.view});
      await controller.performMembershipAction(p, isCurrent: () => true);
      expect(writes().single['path'], p.path);
      expect(writes().single['body'], p.body());
      expect(controller.membershipSuccess!.$2.affected, [
        '2026-10-21',
        '2026-10-28',
      ]);
      expect(refreshed, ['2026-10-21', '2026-10-28']);
      expect(controller.hasPending, isFalse);
      expect(controller.failure, isNull);
    },
  );
  test(
    'empty effects succeeds and publishes result without phantom target',
    () async {
      scenario = 'empty-effects';
      wire = fixture('$scenario-context');
      await controller.performMembershipAction(
        context(wire).select('leave_all'),
        isCurrent: () => true,
      );
      expect(controller.membershipSuccess!.$2.actorEnded, isTrue);
      expect(refreshed, isEmpty);
      expect(controller.hasPending, isFalse);
      expect(controller.failure, isNull);
    },
  );
  test('no qualified successor still acknowledges leave', () async {
    scenario = 'no-successor';
    wire = fixture('$scenario-context');
    await controller.performMembershipAction(
      context(wire).select('leave_target'),
      isCurrent: () => true,
    );
    expect(controller.membershipSuccess, isNotNull);
    expect(controller.failure, isNull);
  });
  for (final badAck in [false, true]) {
    test(
      'unknown result preserves original HTTP/body/key/Impact without GET ($badAck)',
      () async {
        loseAck = !badAck;
        wrongAck = badAck;
        final p = context(wire).select('dissolve_led_targets');
        await controller.performMembershipAction(p, isCurrent: () => true);
        expect(controller.hasPending, isTrue);
        expect(controller.membershipSuccess, isNull);
        final original = copy(writes().single), count = api.requests.length;
        wire['data']['room_revision'] = 999;
        wrongAck = false;
        now = now.add(const Duration(hours: 6));
        await controller.retry();
        expect(api.requests.length, count + 1);
        expect(writes().last, original);
        expect(controller.hasPending, isFalse);
        expect(controller.membershipSuccess!.$1, original['key']);
      },
    );
  }
  test('24 hour pending expires without replay', () async {
    loseAck = true;
    await controller.performMembershipAction(
      context(wire).select('dissolve_led_targets'),
      isCurrent: () => true,
    );
    final count = api.requests.length;
    now = now.add(const Duration(hours: 24));
    expect(controller.canRetry, isFalse);
    await controller.retry();
    expect(api.requests.length, count);
  });
  test('selected impact changed after confirmation sends no command', () async {
    final p = context(wire).select('dissolve_led_targets');
    wire['data']['options']['dissolve_led_targets']['impact']['display_revision'] =
        List.filled(64, 'a').join();
    await controller.performMembershipAction(p, isCurrent: () => true);
    expect(writes(), isEmpty);
    expect(controller.failure, 'REVISION_CONFLICT');
  });
  test(
    'only refreshed selected token is used and unrelated option is isolated',
    () async {
      final p = context(wire).select('dissolve_led_targets');
      wire['data']['options']['dissolve_led_targets']['confirmation']['context_token'] =
          'fresh-token';
      wire['data']['options']['recover_leadership']['permission']['reason'] =
          'DIFFERENT_OPTION';
      await controller.performMembershipAction(p, isCurrent: () => true);
      expect(writes().single['body']['context_token'], 'fresh-token');
    },
  );
  for (final changeUser in [false, true]) {
    test(
      'view/member changes during recheck block POST ($changeUser)',
      () async {
        final p = context(wire).select('dissolve_led_targets');
        var current = true;
        pause = Completer<void>();
        final work = controller.performMembershipAction(
          p,
          isCurrent: () => current,
        );
        if (changeUser) {
          session.change(authenticated: true, user: 'other');
        } else {
          current = false;
        }
        pause!.complete();
        await work;
        expect(writes(), isEmpty);
        expect(controller.membershipSuccess, isNull);
      },
    );
  }
  test('duplicate command during recheck is ignored', () async {
    final p = context(wire).select('dissolve_led_targets');
    pause = Completer<void>();
    final work = controller.performMembershipAction(p, isCurrent: () => true);
    await controller.performMembershipAction(p, isCurrent: () => true);
    pause!.complete();
    await work;
    expect(writes(), hasLength(1));
  });
  test('successful ACK remains final if subsequent refresh fails', () async {
    refreshFail = true;
    await controller.performMembershipAction(
      context(wire).select('dissolve_led_targets'),
      isCurrent: () => true,
    );
    expect(controller.membershipSuccess, isNotNull);
    expect(controller.hasPending, isFalse);
    expect(controller.failure, isNull);
    await controller.retry();
    expect(writes(), hasLength(1));
  });
  test(
    'denied option does not hide allowed option; mutated body never sends',
    () async {
      scenario = 'empty-effects';
      wire = fixture('$scenario-context');
      final c = context(wire);
      expect(
        () => c.select('leave_target'),
        throwsA(isA<AccountReadException>()),
      );
      final p = c.select('leave_all'),
          body = p.body()..['action'] = 'leave_target';
      await expectLater(
        repo.writeMembershipAction(p, key, body),
        throwsA(isA<AccountReadException>()),
      );
      expect(api.requests, isEmpty);
    },
  );
}
