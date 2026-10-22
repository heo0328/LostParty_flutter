import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_management.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;

const c = f1.current, n = f1.next, room = v1.roomId;
String id(int i) => '12345678-1234-4234-8234-${i.toString().padLeft(12, '0')}';
Map<String, dynamic> copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> leadership() => {
  'leader_cycle_member_id': v1.membershipId,
  'leader_membership_id': v1.membershipId,
  'leadership_revision': 3,
};
Map<String, dynamic> candidate(int i) => {
  'cycle_member_id': id(i),
  'revision': i,
  'joined_order': '${9007199254740992 + i}',
  'character_id': characterId,
  'character_name': '참가자$i',
  'permission': f1.permit(),
};
Map<String, dynamic> globalScope() => {
  'server_now': f2.nowStamp,
  'current_cycle_key': c,
  'policy_version': 'two-cycle-contract-4',
};
Map<String, dynamic> managementWire(String action, {String target = n}) {
  final detail = f2.detail(target),
      source = {
        'source_cycle_key': c,
        'membership_id': v1.membershipId,
        'membership_revision': 2,
        'assignment_ids': [v1.itemId],
        'source_cycle_member_id': v1.membershipId,
        'source_cycle_member_revision': 4,
      };
  final context = <String, dynamic>{
    'room_id': room,
    'context_token': 'opaque-token',
    'issued_at': f2.nowStamp,
    'expires_at': '2026-10-22T03:05:00Z',
    'permission': f1.permit(),
  };
  if ({'continue', 'decline', 'open', 'reopen'}.contains(action)) {
    final d = f2.creation(v1.draft().copy(targetCycleKey: n));
    context.addAll({
      'source': source,
      'selection': d['selection'],
      'targets': [
        {
          'item_id': v1.itemId,
          'round_id': f2.nextCycleId,
          'party_no': 1,
          'expected_round_revision': 1,
          'expected_weekly_revision': 8,
        },
      ],
      'target_session_ids': <String>[],
      'conflicts': <Map<String, dynamic>>[],
    });
    if ({'open', 'reopen'}.contains(action)) {
      context.addAll({
        'leadership': null,
        'opening_effect': action == 'open'
            ? 'create_and_join'
            : 'reopen_and_join',
        'prospective_room_cycle_id': f2.nextCycleId,
        'prospective_generation': 2,
        'prospective_target_revision': 1,
        'item_settings': [
          {
            'item_id': v1.itemId,
            'difficulty_id': 'hard',
            'catalog_version': 'v2',
            'duration_minutes': null,
          },
        ],
      });
    } else {
      context['action'] = action == 'continue' ? 'join' : 'decline';
    }
  } else if (action == 'cancel') {
    context.addAll({
      'impact': {
        'effect_scope': 'target_bundle',
        'assignment_count': 1,
        'reservation_count': 1,
        'preserves_other_cycles': true,
        'preserves_global_membership': true,
      },
      'leadership': leadership(),
      'members_revision': 5,
      'mode': 'close_target',
      'successor': null,
    });
  } else if (action == 'transfer') {
    context.addAll({
      'leadership': leadership(),
      'members_revision': 5,
      'candidates': [for (var i = 1; i <= 8; i++) candidate(i)],
      'preserves_other_cycles': true,
      'changes_formation': false,
    });
  } else if ({'common', 'leave', 'end'}.contains(action)) {
    context.addAll({
      'command': action == 'common' ? 'edit_common_settings' : action,
      'room_revision': 2,
      'persistent_membership_revision': 3,
      'expected_cycle_key': c,
      'authorization_cycle_key': c,
      'current_settings': <String, dynamic>{
        'title': '기존 제목',
        'scope': 'public',
        'group_id': null,
        'group_revision': null,
      },
      'impact_cycles': [
        for (final t in [c, n])
          {
            'target_cycle_key': t,
            'room_cycle_id': t == c ? f2.cycleId : f2.nextCycleId,
            'generation': 1,
            'target_revision': 1,
            'leadership': leadership(),
            'member_count': 1,
            'assignment_count': 1,
            'reservation_count': 1,
            'members_revision': 2,
            'plan_revision': 3,
            'actor_cycle_member_id': v1.membershipId,
            'actor_cycle_member_revision': 4,
          },
      ],
    });
    return {'scope': globalScope(), 'data': context};
  } else if (action == 'settings') {
    return f2.envelope(target, {
      'room_id': room,
      'revision': 2,
      'room_revision': 3,
      'experience_level': null,
      'combat_requirement': {
        'input_mode': 'shared',
        'dealer_min': null,
        'support_min': null,
      },
      'continuation': {
        'enabled': true,
        'opening_mode': 'explicit',
        'revision': 1,
      },
      'scope': 'public',
      'group_id': null,
      'admission_mode': 'leader_only',
      'permissions': {
        'edit_settings': f1.permit(),
        'edit_common_settings': f1.permit(),
        'open_next_cycle': f1.permit(),
        'reopen_next_cycle': f1.permit(),
      },
      'leadership': leadership(),
      'my_target_role': 'leader',
    }, created: true);
  } else {
    final data = detail['data'] as Map<String, dynamic>;
    data['permissions'] = {'view_detail': f1.permit()};
    data['leadership'] = leadership();
    data['room']['leadership'] = leadership();
    final member = data['members'][0] as Map;
    member['target_state'] = 'participating';
    member['cycle_member_revision'] = 7;
    member['assignments'][0]['state'] = 'active';
    data['my_membership'] = {
      'membership_id': v1.membershipId,
      'revision': 1,
      'group_member': false,
      'target_role': 'leader',
      'cycle_member_id': v1.membershipId,
      'cycle_member_revision': 7,
      'joined_order': '1',
    };
    return detail;
  }
  return f2.envelope(
    target,
    context,
    created: !{'open', 'reopen'}.contains(action),
  );
}

void main() {
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late v1.Api api;
  late CycleInteractionRepository gateway;
  late CycleParticipationController controller;
  late List<String> refresh;
  late Map<String, dynamic> wire;
  late String action;
  late bool loseAck, badAck;
  Map<String, dynamic> ack() {
    final req = api.requests.last, b = req['body'] as Map;
    final global = {'common', 'leave', 'end'}.contains(action);
    if (global) {
      return {
        'scope': globalScope(),
        'data': {
          'command_id': req['key'],
          'outcome': 'applied',
          'executed_at': f2.nowStamp,
          'room_id': room,
          'affected_cycle_keys': badAck ? [c] : [c, n],
          if (action == 'common')
            'room_revision': 4
          else ...{
            'membership_id': v1.membershipId,
            'persistent_membership_revision': 4,
            'room_ended': action == 'end',
            'revisions': [
              {'resource': 'room', 'id': room, 'revision': 4},
            ],
          },
        },
      };
    }
    final t = b['target_cycle_key'] as String;
    final j = f2.envelope(t, {
      'command_id': req['key'],
      'outcome': 'applied',
      'executed_at': f2.nowStamp,
      'room_id': room,
      'target_cycle_key': badAck ? c : t,
      'revisions': [
        {'resource': 'target', 'id': f2.nextCycleId, 'revision': 2},
      ],
    }, created: true);
    if ({'open', 'reopen'}.contains(action)) {
      j['scope']['target_generation'] = badAck ? 1 : 2;
    }
    return j;
  }

  setUp(() {
    session = ReadSessionFake();
    changes = ChangeNotifier();
    api = v1.Api();
    refresh = [];
    loseAck = badAck = false;
    action = 'cancel';
    wire = managementWire(action);
    gateway = CycleInteractionRepository(
      api: api,
      recruitment: f2.CycleGateway(),
    );
    api.respond = (path, query) async {
      if (api.requests.last['method'] == 'GET') return copy(wire);
      if (loseAck) {
        loseAck = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      return ack();
    };
    controller = CycleParticipationController(
      gateway: gateway,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => DateTime.parse(f2.nowStamp),
      onMutation: (t) async {
        refresh.add(t);
      },
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });
  Future<CycleManagementPreview> preview(
    String a, {
    Map<String, dynamic> query = const {},
  }) async {
    action = a;
    wire = managementWire(a);
    return (await controller.management(room, n, a, query: query))!;
  }

  List<Map<String, dynamic>> writes() =>
      api.requests.where((r) => r['method'] != 'GET').toList();
  test(
    'last next participant cancels N only and preserves C/global relationship',
    () async {
      final p = await preview('cancel');
      await controller.manage(p, {});
      expect(writes().single['body'], {
        'expected_cycle_key': c,
        'target_cycle_key': n,
        'expected_target_revision': 1,
        'context_token': 'opaque-token',
        'expected_leadership_revision': 3,
      });
      expect(refresh, [n]);
      expect(controller.hasPending, false);
    },
  );
  test(
    'automatic successor is server chosen and exact wide joined order survives',
    () async {
      action = 'cancel';
      wire = managementWire(action);
      wire['data']['mode'] = 'auto_successor';
      wire['data']['successor'] = candidate(8);
      final p = (await controller.management(room, n, action))!;
      expect(p.data['successor']['joined_order'], '9007199254741000');
      await controller.manage(p, {});
      expect(refresh, [n]);
    },
  );
  test(
    '8-person transfer chooses same-T candidate revision without leaving or formation',
    () async {
      final p = await preview('transfer');
      await controller.manage(p, {'candidate': id(8)});
      final b = writes().single['body'] as Map;
      expect(b['candidate_cycle_member_id'], id(8));
      expect(b['expected_candidate_revision'], 8);
      expect(b['expected_leadership_revision'], 3);
      expect(b.containsKey('placements'), false);
      expect(refresh, [n]);
    },
  );
  test(
    'leader or candidate revision change requires new explicit confirmation without write',
    () async {
      final p = await preview('transfer');
      wire['data']['candidates'][7]['revision'] = 9;
      await controller.manage(p, {'candidate': id(8)});
      expect(writes(), isEmpty);
      expect(controller.failure, 'REVISION_CONFLICT');
    },
  );
  test(
    'denied candidate cannot be transferred and denied context cannot cancel',
    () async {
      action = 'transfer';
      wire = managementWire(action);
      wire['data']['candidates'][7]['permission'] = f1.permit(false);
      var p = (await controller.management(room, n, action))!;
      await controller.manage(p, {'candidate': id(8)});
      expect(writes(), isEmpty);
      action = 'cancel';
      wire = managementWire(action);
      wire['data']['permission'] = f1.permit(false);
      p = (await controller.management(room, n, action))!;
      await controller.manage(p, {});
      expect(writes(), isEmpty);
    },
  );
  test(
    'continuation bypasses approval using original selection and only checked sessions',
    () async {
      action = 'continue';
      wire = managementWire(action);
      wire['data']['target_session_ids'] = [v1.itemId];
      final p = (await controller.management(room, n, action))!;
      await controller.manage(p, {});
      expect(writes(), isEmpty);
      await controller.manage(p, {
        'sessions': [v1.itemId],
      });
      final r = writes().single;
      expect(r['path'], '/v2/raid-rooms/$room/continuation-participations');
      expect(r['body']['selection'], wire['data']['selection']);
      expect(r['body']['target_session_ids'], [v1.itemId]);
      expect(refresh, [n]);
    },
  );
  test(
    'decline has no selection or session joins and changes N only',
    () async {
      final p = await preview('decline');
      await controller.manage(p, {});
      final b = writes().single['body'] as Map;
      expect(b.keys.toSet(), {
        'expected_cycle_key',
        'target_cycle_key',
        'expected_target_revision',
        'context_token',
      });
      expect(refresh, [n]);
    },
  );
  test(
    'occupancy conflict keeps B intact; alternative uses continuation privilege',
    () async {
      action = 'continue';
      wire = managementWire(action);
      wire['data']['permission'] = f1.permit(false);
      wire['data']['conflicts'] = [
        {
          'room_id': id(9),
          'target_cycle_key': n,
          'raid_id': 'raid_a',
          'character_id': characterId,
          'can_view_detail': true,
          'room_title': 'B방',
        },
      ];
      final p = (await controller.management(room, n, action))!;
      await controller.manage(p, {});
      expect(writes(), isEmpty);
      expect(refresh, isEmpty);
      wire = managementWire(action);
      wire['data']['selection']['character_id'] = secondCharacterId;
      final alt = (await controller.management(
        room,
        n,
        action,
        query: {'character_id': secondCharacterId, 'selected_role': 'dealer'},
      ))!;
      await controller.manage(alt, {});
      expect(writes().single['path'], endsWith('continuation-participations'));
      expect(
        writes().single['body']['selection']['character_id'],
        secondCharacterId,
      );
      expect(refresh, [n]);
    },
  );
  for (final a in ['open', 'reopen']) {
    test(
      '$a uses prospective generation and no C participation copying',
      () async {
        final p = await preview(a);
        await controller.manage(p, {});
        final b = writes().single['body'] as Map;
        expect(b['intent'], a);
        expect(b['expected_target_revision'], null);
        expect(b['target_cycle_key'], n);
        expect(b['target_items'], hasLength(1));
        expect(refresh, [n]);
        expect(controller.hasPending, false);
      },
    );
  }
  test(
    'opening ACK from old generation is not success and retains original request',
    () async {
      final p = await preview('reopen');
      badAck = true;
      await controller.manage(p, {});
      expect(controller.hasPending, true);
      expect(refresh, isEmpty);
      final first = jsonEncode(writes().single);
      badAck = false;
      await controller.retry();
      expect(jsonEncode(writes().last), first);
      expect(refresh, [n]);
    },
  );
  test(
    'expired context, forged target/source or extra query cannot issue a write',
    () async {
      wire['data']['expires_at'] = f2.nowStamp;
      expect(await controller.management(room, n, 'cancel'), null);
      action = 'continue';
      wire = managementWire(action);
      wire['data']['source']['source_cycle_key'] = n;
      expect(await controller.management(room, n, action), null);
      wire = managementWire(action);
      wire['scope']['target_cycle_key'] = c;
      expect(await controller.management(room, n, action), null);
      final before = api.requests.length;
      expect(
        await controller.management(
          room,
          n,
          action,
          query: {'target_cycle_key': c},
        ),
        null,
      );
      expect(api.requests.length, before);
      expect(writes(), isEmpty);
    },
  );
  final settingsInput = {
    'experience_level': 'experienced',
    'admission_mode': 'direct_join',
    'combat_requirement': {
      'input_mode': 'per_role',
      'dealer_min': '3000.123456789012345678',
      'support_min': null,
    },
  };
  test(
    'PUT target settings retries original method/key/body after lost ACK',
    () async {
      final p = await preview('settings');
      loseAck = true;
      await controller.manage(p, settingsInput);
      expect(controller.hasPending, true);
      expect(refresh, isEmpty);
      final first = jsonEncode(writes().single);
      wire['data']['revision'] = 99;
      await controller.retry();
      expect(jsonEncode(writes().last), first);
      expect(writes().last['method'], 'PUT');
      expect(
        writes().last['body']['combat_requirement']['dealer_min'],
        '3000.123456789012345678',
      );
      expect(refresh, [n]);
    },
  );
  test(
    'common G1 denied permission is honored even if locally C leader',
    () async {
      action = 'common';
      wire = managementWire(action);
      wire['data']['permission'] = f1.permit(false);
      final p = (await controller.management(room, n, action))!;
      await controller.manage(p, {'title': '제목'});
      expect(writes(), isEmpty);
    },
  );
  for (final a in ['common', 'leave', 'end']) {
    test(
      '$a global ACK refreshes exact impacted C/N and writes no target',
      () async {
        final p = await preview(a);
        await controller.manage(p, {
          'title': '공통 변경',
          'scope': 'public',
          'group_id': null,
        });
        final b = writes().single['body'] as Map;
        expect(b.containsKey('target_cycle_key'), false);
        expect(refresh, [c, n]);
        expect(controller.hasPending, false);
        expect(writes().single['method'], a == 'common' ? 'PUT' : 'POST');
      },
    );
  }
  test(
    'changed global impact requires reconfirmation before writing',
    () async {
      final p = await preview('leave');
      wire['data']['impact_cycles'].removeLast();
      await controller.manage(p, {});
      expect(writes(), isEmpty);
      expect(controller.failure, 'REVISION_CONFLICT');
    },
  );
  test(
    'incomplete global ACK retains immutable command; retry refreshes both only after exact ACK',
    () async {
      final p = await preview('leave');
      badAck = true;
      await controller.manage(p, {});
      expect(controller.hasPending, true);
      expect(refresh, isEmpty);
      final first = jsonEncode(writes().single);
      badAck = false;
      await controller.retry();
      expect(jsonEncode(writes().last), first);
      expect(refresh, [c, n]);
    },
  );
  test(
    'logout discards late management preview and cannot create command',
    () async {
      final reply = Completer<Map<String, dynamic>>();
      api.respond = (_, _) => reply.future;
      final pending = controller.management(room, n, 'cancel');
      session.change(authenticated: false);
      reply.complete(wire);
      expect(await pending, null);
      expect(controller.hasPending, false);
      expect(writes(), isEmpty);
      expect(refresh, isEmpty);
    },
  );
  test('logout during write discards late ACK refresh', () async {
    final p = await preview('cancel'),
        reply = Completer<Map<String, dynamic>>();
    api.respond = (path, q) async =>
        api.requests.last['method'] == 'GET' ? copy(wire) : reply.future;
    final sending = controller.manage(p, {});
    await Future<void>.delayed(Duration.zero);
    session.change(authenticated: false);
    reply.complete(ack());
    await sending;
    expect(refresh, isEmpty);
    expect(controller.hasPending, false);
  });
  test(
    'formation consumes cycle-member CAS, all active assignments and rejects duplicate spots',
    () async {
      final p = await preview('formation');
      final place = {
        'cycle_member_id': v1.membershipId,
        'expected_cycle_member_revision': 7,
        'item_id': v1.itemId,
        'party_no': 2,
        'slot_no': 4,
      };
      expect(
        () => p.body({
          'placements': [place, place],
        }),
        throwsFormatException,
      );
      expect(
        () => p.body({
          'placements': [
            {...place, 'expected_cycle_member_revision': 6},
          ],
        }),
        throwsFormatException,
      );
      await controller.manage(p, {
        'placements': [place],
      });
      expect(writes().single['body']['placements'], [place]);
      expect(refresh, [n]);
    },
  );
  test(
    '4-player raid cannot accept second party even in 8-player app room',
    () async {
      action = 'formation';
      wire = managementWire(action);
      wire['data']['room']['items'][0]['game_party_size'] = 4;
      final p = (await controller.management(room, n, action))!;
      expect(
        () => p.body({
          'placements': [
            {
              'cycle_member_id': v1.membershipId,
              'expected_cycle_member_revision': 7,
              'item_id': v1.itemId,
              'party_no': 2,
              'slot_no': 1,
            },
          ],
        }),
        throwsFormatException,
      );
      expect(writes(), isEmpty);
    },
  );
  test(
    'removal sends actor/target cycle CAS and never permits self-removal',
    () async {
      final p = await preview('remove');
      expect(
        () => p.body({'candidate': v1.membershipId}),
        throwsFormatException,
      );
      final other = copy(wire['data']['members'][0] as Map<String, dynamic>);
      other.addAll({
        'membership_id': id(9),
        'cycle_member_id': id(9),
        'cycle_member_revision': 8,
        'is_me': false,
        'target_role': 'member',
      });
      wire['data']['members'].add(other);
      final fresh = (await controller.management(room, n, 'remove'))!;
      await controller.manage(fresh, {'candidate': id(9)});
      final b = writes().single['body'] as Map;
      expect(b['expected_cycle_member_revision'], 7);
      expect(b['expected_removed_cycle_member_revision'], 8);
      expect(b['target_cycle_member_id'], id(9));
      expect(refresh, [n]);
    },
  );
  test(
    'common cannot relink group and preserves group revision with empty title fallback',
    () async {
      action = 'common';
      wire = managementWire(action);
      wire['data']['current_settings'].addAll({
        'group_id': v1.groupId,
        'group_revision': 5,
      });
      final p = (await controller.management(room, n, action))!;
      expect(
        () => p.body({'title': '제목', 'scope': 'public', 'group_id': null}),
        throwsFormatException,
      );
      final b = p.body({'title': '', 'scope': 'public'});
      expect(b['title'], '기존 제목');
      expect(b['group_id'], v1.groupId);
      expect(b['expected_group_revision'], 5);
    },
  );
  test(
    'common noop with zero changed cycles is a valid ACK and refreshes confirmed scope',
    () async {
      final p = await preview('common');
      api.respond = (_, _) async {
        if (api.requests.last['method'] == 'GET') return copy(wire);
        final j = ack();
        j['data']['outcome'] = 'noop';
        j['data']['affected_cycle_keys'] = <String>[];
        return j;
      };
      await controller.manage(p, {'title': '기존 제목'});
      expect(controller.hasPending, false);
      expect(refresh, [c, n]);
    },
  );
  test(
    'detail authorization evaluation time refresh alone does not invalidate CAS confirmation',
    () async {
      final p = await preview('formation');
      wire['data']['access']['evaluated_at'] = '2026-10-22T03:00:01Z';
      await controller.manage(p, {
        'placements': [
          {
            'cycle_member_id': v1.membershipId,
            'expected_cycle_member_revision': 7,
            'item_id': v1.itemId,
            'party_no': 1,
            'slot_no': 1,
          },
        ],
      });
      expect(writes(), hasLength(1));
      expect(refresh, [n]);
    },
  );
  test(
    'wrong T ACK holds cancellation; definite leadership rejection clears only pending N',
    () async {
      final p = await preview('cancel');
      badAck = true;
      await controller.manage(p, {});
      expect(controller.hasPending, true);
      expect(refresh, isEmpty);
      api.respond = (_, _) async =>
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
      await controller.retry();
      expect(controller.hasPending, false);
      expect(refresh, [n]);
      expect(controller.failure, 'REVISION_CONFLICT');
    },
  );
}
