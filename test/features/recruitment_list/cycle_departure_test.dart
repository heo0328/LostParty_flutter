import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_member_actions.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;

Map<String, dynamic> copy(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
final examples =
    (jsonDecode(File('test/fixtures/cycle_departure.json').readAsStringSync())
            as Map)['examples']
        as Map;
Map<String, dynamic> context(String name) =>
    copy(examples[name]['responses'][0]);
DeparturePreview preview(Map<String, dynamic> raw) => DeparturePreview(
  raw['data']['room_id'],
  raw['scope']['target_cycle_key'],
  raw['data']['subject']['round_id'],
  raw,
);
Map<String, dynamic> ack(String name) => copy(
  (examples[name]['responses'] as List).firstWhere(
    (v) => v['data']['outcome'] == 'applied',
  ),
);

void main() {
  for (final name in examples.keys.cast<String>()) {
    test('published context and exact ACK: $name', () {
      final p = preview(context(name));
      if (!p.permission.allowed) {
        expect(p.confirmation, null);
        expect(p.body, throwsA(isA<AccountReadException>()));
      } else {
        final raw = ack(name);
        validateDepartureResult(raw, p, raw['data']['command_id']);
        expect(p.body().length, 9);
      }
    });
  }
  test(
    'time/token refresh is stable, display and ownership evidence are not',
    () {
      final raw = context('personal_automatic_successor'), p = preview(raw);
      raw['data']['confirmation']['context_token'] = 'new-token';
      expect(preview(raw).signature, p.signature);
      raw['data']['display']['character_name'] = 'changed';
      expect(preview(raw).signature, isNot(p.signature));
      expect(() => p.data['room_id'] = 'other', throwsUnsupportedError);
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'extra field': (j) => j['data']['extra'] = 1,
    'effect mismatch': (j) =>
        j['data']['display']['assignments'][0]['effect'] = 'cancel',
    'duplicate assignment': (j) =>
        j['data']['impact']['cancel_assignment_ids'] = [
          j['data']['subject']['assignment_id'],
        ],
    'unexpected null': (j) =>
        j['data']['display']['assignments'][0]['raid_name'] = null,
    'denied with token': (j) => j['data']['permission']['allowed'] = false,
    'different character': (j) => j['data']['display']['character_id'] =
        '00000000-0000-4000-8000-000000000001',
    'revision overflow': (j) =>
        j['data']['subject']['assignment_revision'] = 2147483648,
    'next target': (j) => j['scope']['target_cycle_key'] = '2026-10-28',
    'no successor': (j) => j['data']['impact']['successor'] = null,
  }.entries) {
    test('reject ${mutation.key}', () {
      final raw = context('personal_automatic_successor');
      mutation.value(raw);
      expect(() => preview(raw), throwsFormatException);
    });
  }
  test('ACK cannot substitute another subject, effect, or current cycle', () {
    final p = preview(context('personal_member'));
    for (final field in [
      'subject_membership_id',
      'action',
      'affected_cycle_keys',
    ]) {
      final raw = ack('personal_member');
      raw['data'][field] = field == 'affected_cycle_keys'
          ? ['2026-10-28']
          : 'wrong';
      expect(
        () => validateDepartureResult(raw, p, raw['data']['command_id']),
        throwsFormatException,
      );
    }
  });

  test('offset timestamps normalize without accepting calendar overflow', () {
    expect(
      actionTime('2026-10-23T18:00:00+09:00'),
      DateTime.parse('2026-10-23T09:00:00Z'),
    );
    expect(() => actionTime('2026-02-30T00:00:00Z'), throwsFormatException);
    expect(() => actionTime('2026-10-23T24:00:00Z'), throwsFormatException);
    expect(() => actionTime('2026-10-23T18:00:00'), throwsFormatException);
  });

  late base.Api api;
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late CycleParticipationController controller;
  late Map<String, dynamic> wire;
  var failAck = false, refreshFail = false;
  final refreshed = <String>[];
  setUp(() {
    wire = context('personal_automatic_successor');
    api = base.Api();
    session = ReadSessionFake();
    changes = ChangeNotifier();
    failAck = refreshFail = false;
    refreshed.clear();
    api.respond = (path, query) async {
      if (api.requests.last['method'] == 'GET') return copy(wire);
      if (failAck) {
        failAck = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final result = ack('personal_automatic_successor');
      result['data']['command_id'] = api.requests.last['key'];
      return result;
    };
    controller = CycleParticipationController(
      gateway: CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
      ),
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => DateTime.parse(wire['scope']['server_now']),
      onMutation: (t) async {
        refreshed.add(t);
        if (refreshFail) {
          throw const AccountReadException(
            'ROOM_MEMBERSHIP_REQUIRED',
            status: 403,
          );
        }
      },
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });
  test(
    'context read is keyless; success clears pending before read failure and emits departure',
    () async {
      final p = preview(wire);
      final observed = <bool>[];
      controller.addListener(
        () => observed.add(
          controller.departureSuccess != null && !controller.hasPending,
        ),
      );
      refreshFail = true;
      await controller.depart(p);
      expect(api.requests.where((r) => r['method'] == 'POST'), hasLength(1));
      expect(
        api.requests
            .where((r) => r['method'] == 'GET')
            .every((r) => r['key'] == null),
        true,
      );
      expect(controller.hasPending, false);
      expect(controller.failure, null);
      expect(controller.departureSuccess?.$2, p.room);
      expect(refreshed, [p.target]);
      expect(observed, contains(true));
      expect(
        api.requests.where((r) => (r['path'] as String).endsWith('/plan')),
        isEmpty,
      );
    },
  );
  test(
    'unknown result retries the original method path body key token without context',
    () async {
      final p = preview(wire);
      failAck = true;
      await controller.depart(p);
      expect(controller.hasPending, true);
      expect(controller.departureSuccess, null);
      final first = copy(api.requests.last);
      wire['data']['confirmation']['context_token'] = 'must-not-replace';
      final gets = api.requests.where((r) => r['method'] == 'GET').length;
      await controller.retry();
      expect(api.requests.last, first);
      expect(api.requests.where((r) => r['method'] == 'GET'), hasLength(gets));
      expect(controller.hasPending, false);
      expect(refreshed, [p.target]);
    },
  );
  test('changed display requires confirmation and sends no command', () async {
    final p = preview(wire);
    wire['data']['display']['character_name'] = 'changed';
    await controller.depart(p);
    expect(controller.failure, 'REVISION_CONFLICT');
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
  });
  test('page cycle changed during context read blocks POST', () async {
    final p = preview(wire);
    final gate = Completer<Map<String, dynamic>>();
    api.respond = (_, _) => gate.future;
    var current = true;
    final task = controller.depart(p, isCurrent: () => current);
    current = false;
    gate.complete(copy(wire));
    await task;
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    expect(controller.hasPending, false);
  });
  test(
    'incorrect ACK stays pending and successful retry emits only once',
    () async {
      final p = preview(wire);
      api.respond = (path, query) async {
        if (api.requests.last['method'] == 'GET') return copy(wire);
        final result = ack('personal_automatic_successor');
        result['data']['command_id'] = '00000000-0000-4000-8000-000000000001';
        return result;
      };
      await controller.depart(p);
      expect(controller.failure, 'INVALID_RESPONSE');
      expect(controller.hasPending, true);
      expect(controller.departureSuccess, null);
      expect(refreshed, isEmpty);
      api.respond = (_, _) async {
        final result = ack('personal_automatic_successor');
        result['data']['command_id'] = api.requests.last['key'];
        return result;
      };
      await controller.retry();
      final success = controller.departureSuccess;
      await controller.retry();
      expect(controller.departureSuccess, success);
      expect(refreshed, [p.target]);
    },
  );
  test('duplicate departure is ignored while confirming', () async {
    final p = preview(wire);
    final gate = Completer<Map<String, dynamic>>();
    api.respond = (_, _) => gate.future;
    final first = controller.depart(p);
    await controller.depart(p);
    expect(api.requests, hasLength(1));
    session.change(authenticated: false);
    gate.complete(copy(wire));
    await first;
    expect(controller.hasPending, false);
  });
  test('logout discards a late permission read', () async {
    final p = preview(wire);
    final gate = Completer<Map<String, dynamic>>();
    api.respond = (_, _) => gate.future;
    final task = controller.depart(p);
    session.change(authenticated: false);
    gate.complete(copy(wire));
    await task;
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    expect(controller.departureSuccess, null);
  });
}
