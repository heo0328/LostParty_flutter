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
    (jsonDecode(File('test/fixtures/cycle_removal.json').readAsStringSync())
            as Map)['examples']
        as Map;
Map<String, dynamic> context(String name) =>
    copy(examples[name]['responses'][0]);
RemovalPreview preview(Map<String, dynamic> j) => RemovalPreview(
  j['data']['room_id'],
  j['scope']['target_cycle_key'],
  j['data']['source']['target_cycle_member_id'],
  j,
);
Map<String, dynamic> ack(String name) => copy(examples[name]['responses'][1]);

void main() {
  for (final name in examples.keys.cast<String>()) {
    test('published removal context: $name', () {
      final p = preview(context(name));
      for (final mode in ['current_only', 'both']) {
        if (p.permission(mode).allowed) {
          expect(p.body(mode).length, 10);
        } else {
          expect(p.option(mode)['confirmation'], null);
          expect(p.option(mode)['impact'], null);
          expect(() => p.body(mode), throwsA(isA<AccountReadException>()));
        }
      }
      if ((examples[name]['responses'] as List).length > 1) {
        final result = ack(name);
        final mode = (result['data']['affected_cycle_keys'] as List).length == 2
            ? 'both'
            : 'current_only';
        validateRemovalResult(result, p, mode, result['data']['command_id']);
      }
    });
  }
  test('current-only ignores unrelated opposite evidence and both option', () {
    final raw = context('removal_both'), p = preview(raw);
    raw['data']['opposite_relation']['target']['target_revision']++;
    raw['data']['options']['both']['confirmation']['context_token'] = 'changed';
    final next = preview(raw);
    expect(next.signature('current_only'), p.signature('current_only'));
    expect(next.signature('both'), isNot(p.signature('both')));
    expect(() => p.source['target_revision'] = 2, throwsUnsupportedError);
  });
  test(
    'token and observed-time-only refresh does not change option semantics',
    () {
      final raw = context('removal_both'), p = preview(raw);
      raw['scope']['server_now'] = '2026-10-23T09:50:49Z';
      for (final mode in ['current_only', 'both']) {
        raw['data']['options'][mode]['confirmation']['issued_at'] =
            raw['scope']['server_now'];
        raw['data']['options'][mode]['confirmation']['context_token'] =
            'new-$mode';
      }
      final next = preview(raw);
      for (final mode in ['current_only', 'both']) {
        expect(next.signature(mode), p.signature(mode));
      }
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'extra field': (j) => j['data']['extra'] = true,
    'missing source': (j) => j['data']['source'] = null,
    'wrong source generation': (j) =>
        j['data']['source']['target_generation']++,
    'revision overflow': (j) =>
        j['data']['source']['target_cycle_member_revision'] = 2147483648,
    'none with target': (j) =>
        j['data']['opposite_relation']['status'] = 'none',
    'both without target': (j) =>
        j['data']['opposite_relation']['target'] = null,
    'denied with impact': (j) => j['data']['options']['both']['permission'] = {
      'allowed': false,
      'reason': 'TARGET_LEADER_REQUIRED',
      'next_change_at': null,
    },
    'effect order': (j) => j['data']['options']['both']['impact']['targets'] =
        (j['data']['options']['both']['impact']['targets'] as List).reversed
            .toList(),
    'duplicate assignments': (j) =>
        j['data']['options']['current_only']['impact']['targets'][0]['cancel_assignment_ids'] =
            j['data']['options']['current_only']['impact']['targets'][0]['preserved_completed_assignment_ids'],
    'overlong token': (j) =>
        j['data']['options']['both']['confirmation']['context_token'] =
            '가' * 1366,
    'expired token': (j) =>
        j['data']['options']['both']['confirmation']['expires_at'] =
            j['data']['options']['both']['confirmation']['issued_at'],
    'self as target': (j) => j['data']['source']['actor_cycle_member_id'] =
        j['data']['source']['target_cycle_member_id'],
  }.entries) {
    test('reject malformed ${mutation.key}', () {
      final raw = context('removal_both');
      final original = preview(raw);
      mutation.value(raw);
      expect(
        () => RemovalPreview(
          original.room,
          original.target,
          original.member,
          raw,
        ),
        throwsFormatException,
      );
    });
  }
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong subject': (j) => j['data']['subject_membership_id'] = 'wrong',
    'wrong action': (j) =>
        j['data']['action'] = 'personal_completion_departure',
    'missing second effect': (j) => (j['data']['effects'] as List).removeLast(),
    'reverse effects': (j) =>
        j['data']['effects'] = (j['data']['effects'] as List).reversed.toList(),
    'duplicate keys': (j) => j['data']['affected_cycle_keys'][1] =
        j['data']['affected_cycle_keys'][0],
    'wrong target CM': (j) => j['data']['effects'][1]['cycle_member_id'] =
        j['data']['effects'][0]['cycle_member_id'],
    'completed assignment': (j) =>
        j['data']['effects'][0]['completed_assignment_ids'] =
            j['data']['effects'][0]['cancelled_assignment_ids'],
    'wrong revision': (j) => j['data']['effects'][1]['cycle_member_revision']++,
    'changed leadership': (j) =>
        j['data']['effects'][0]['leadership']['leadership_revision']++,
  }.entries) {
    test('reject mismatched ACK ${mutation.key}', () {
      final raw = ack('removal_both');
      mutation.value(raw);
      expect(
        () => validateRemovalResult(
          raw,
          preview(context('removal_both')),
          'both',
          raw['data']['command_id'],
        ),
        throwsFormatException,
      );
    });
  }

  late base.Api api;
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late CycleParticipationController controller;
  late Map<String, dynamic> wire;
  var name = 'removal_both',
      failAck = false,
      badAck = false,
      refreshFail = false;
  final refreshed = <String>[];
  setUp(() {
    name = 'removal_both';
    wire = context(name);
    api = base.Api();
    session = ReadSessionFake();
    changes = ChangeNotifier();
    failAck = badAck = refreshFail = false;
    refreshed.clear();
    api.respond = (path, query) async {
      if (api.requests.last['method'] == 'GET') return copy(wire);
      if (failAck) {
        failAck = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final result = ack(name);
      result['data']['command_id'] = badAck
          ? 'wrong'
          : api.requests.last['key'];
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
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
      },
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });
  Future<String?> submit(
    RemovalPreview p, {
    String mode = 'both',
    bool Function()? isCurrent,
  }) => controller.removeMember(
    p,
    mode,
    membership: p.membership,
    isCurrent: isCurrent ?? () => true,
  );

  test(
    'both is one POST; exact effect T notifications survive downstream GET failure',
    () async {
      refreshFail = true;
      final p = preview(wire);
      final key = await submit(p);
      final posts = api.requests.where((r) => r['method'] == 'POST').toList();
      expect(posts, hasLength(1));
      expect(posts.single['path'], p.path);
      expect(controller.removalSuccess, (key, p.room, p.target, p.member));
      expect(controller.departureSuccess, null);
      expect(controller.hasPending, false);
      expect(refreshed, p.affected('both'));
      expect(controller.failure, null);
      expect(controller.notice, contains('반영되었습니다'));
    },
  );
  test('N source preserves N,C ACK order and notification order', () async {
    name = 'removal_n_source';
    wire = context(name);
    final p = preview(wire);
    await submit(p);
    expect(refreshed, ['2026-10-28', '2026-10-21']);
    expect(controller.hasPending, false);
  });
  test(
    'current-only tolerates unrelated opposite change and invalidates only source',
    () async {
      name = 'removal_current_only';
      wire = context(name);
      final p = preview(wire);
      wire['data']['opposite_relation']['target']['target_revision']++;
      await submit(p, mode: 'current_only');
      expect(controller.hasPending, false);
      expect(refreshed, [p.target]);
    },
  );
  test('denied both never falls back to single/legacy API', () async {
    wire = context('opposite_review');
    await submit(preview(wire));
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    expect(controller.failure, 'ROOM_REVIEW_REQUIRED');
    expect(refreshed, isEmpty);
  });
  test(
    'changed selection evidence, membership or rejoined CM cannot write',
    () async {
      final p = preview(wire);
      wire['data']['source']['character_name'] = 'changed';
      await submit(p);
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      await controller.removeMember(
        preview(wire),
        'both',
        membership: 'wrong',
        isCurrent: () => true,
      );
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      wire['data']['source']['target_cycle_member_id'] =
          '00000000-0000-4000-8000-000000000001';
      await submit(p);
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    },
  );
  test(
    'unknown result retries exact original token/body/key without fresh context',
    () async {
      final p = preview(wire);
      failAck = true;
      await submit(p);
      expect(controller.hasPending, true);
      final request = copy(api.requests.last);
      wire['data']['options']['both']['confirmation']['context_token'] =
          'not-original';
      final reads = api.requests.where((r) => r['method'] == 'GET').length;
      await controller.retry();
      expect(api.requests.last, request);
      expect(api.requests.where((r) => r['method'] == 'GET').length, reads);
      expect(controller.hasPending, false);
      expect(controller.removalSuccess?.$1, request['key']);
    },
  );
  test('bad ACK keeps pending and emits no success or mutations', () async {
    badAck = true;
    await submit(preview(wire));
    expect(controller.hasPending, true);
    expect(controller.removalSuccess, null);
    expect(refreshed, isEmpty);
    badAck = false;
    await controller.retry();
    expect(controller.hasPending, false);
  });
  test('pending and busy block duplicate commands', () async {
    final gate = Completer<Map<String, dynamic>>();
    api.respond = (_, _) => gate.future;
    final p = preview(wire);
    final first = submit(p);
    await submit(p);
    expect(api.requests, hasLength(1));
    gate.complete(copy(wire));
    // Use the regular fake response for the POST once the GET resumes.
    api.respond = (_, _) async {
      final result = ack(name);
      result['data']['command_id'] = api.requests.last['key'];
      return result;
    };
    await first;
    expect(api.requests.where((r) => r['method'] == 'POST'), hasLength(1));
  });
  test(
    'origin page T change during confirmation refresh blocks write',
    () async {
      var valid = true;
      api.respond = (_, _) async {
        valid = false;
        return copy(wire);
      };
      await submit(preview(wire), isCurrent: () => valid);
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      expect(controller.hasPending, false);
    },
  );
  test('old member response is ignored and no POST follows', () async {
    api.respond = (_, _) async {
      session.change(authenticated: true, user: 'another');
      return copy(wire);
    };
    await submit(preview(wire));
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    expect(controller.removalSuccess, null);
  });
}
