import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import '../account/backend_read/play_availability_test.dart' as personal_test;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;
import 'cycle_management_test.dart' as f4;

const c = f1.current, n = f1.next, room = v1.roomId;
String id(int i) => f4.id(100 + i);
Map<String, dynamic> copy(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
String start(int i) =>
    DateTime.parse('${n}T11:00:00Z').add(Duration(days: i)).toIso8601String();
Map<String, dynamic> segment(int i) => {
  'segment_id': id(30 + i),
  'item_id': v1.itemId,
  'round_id': f2.nextCycleId,
  'starts_at': start(i),
  'ends_at': DateTime.parse(
    start(i),
  ).add(const Duration(minutes: 20)).toIso8601String(),
  'duration_minutes': 20,
  'duration_source': 'explicit',
  'policy_version': 'v1',
  'state': 'planned',
  'released_reason': null,
};
Map<String, dynamic> planWire() => f2.envelope(n, {
  'room_id': room,
  'revision': 5,
  'members_revision': 4,
  'server_time': f2.nowStamp,
  'app_capacity': 8,
  'game_items': [
    {
      'item_id': v1.itemId,
      'revision': 1,
      'raid_id': 'raid_a',
      'difficulty_id': 'hard',
      'catalog_version': 'v2',
      'game_party_size': 8,
      'round_id': f2.nextCycleId,
      'round_revision': 1,
      'round_state': 'active',
    },
  ],
  'schedule_state': 'confirmed',
  'schedule_groups': [
    {
      'group_id': id(1),
      'revision': 2,
      'client_group_key': 'first',
      'occurrence_mode': 'one_of',
      'planning_mode': 'coordinated',
      'day_scope': 'any_current_cycle',
      'required': true,
      'auto_confirm_additional_members': 7,
      'alternatives': [],
      'selected_session_id': null,
      'resolution': 'unresolved',
      'candidate_state': 'ready',
      'permissions': {'select': f1.permit()},
    },
  ],
  'sessions': [
    for (var i = 0; i < 2; i++)
      {
        'session_id': id(10 + i),
        'revision': 1,
        'round_ids': [f2.nextCycleId],
        'required': true,
        'mode': 'manual',
        'state': 'confirmed',
        'schedule_revision': 3,
        'starts_at': start(i),
        'ends_at': segment(i)['ends_at'],
        'duration_minutes': 20,
        'duration_source': 'item_sum',
        'duration_policy_version': 'v1',
        'earliest_start': start(i),
        'latest_start': start(i),
        'join_deadline': DateTime.parse(
          start(i),
        ).subtract(const Duration(minutes: 30)).toIso8601String(),
        'candidate_state': 'ready',
        'permissions': {'propose_schedule': f1.permit()},
      },
  ],
  'session_segments': [
    for (var i = 0; i < 2; i++)
      {
        'session_id': id(10 + i),
        'segments': [segment(i)],
      },
  ],
  'my_membership': {
    'membership_id': v1.membershipId,
    'revision': 1,
    'group_member': false,
    'target_role': 'leader',
    'cycle_member_id': v1.membershipId,
    'cycle_member_revision': 7,
    'joined_order': '1',
  },
  'my_assignments': [
    {
      'assignment_id': v1.itemId,
      'revision': 2,
      'membership_id': v1.membershipId,
      'item_id': v1.itemId,
      'round_id': f2.nextCycleId,
      'character_id': characterId,
      'selected_role': 'dealer',
      'state': 'active',
      'ended_at': null,
      'raid_participation_state': 'confirmed',
      'completion_source': null,
      'completed_at': null,
      'target_cycle_key': n,
    },
  ],
  'my_participations': [
    for (var i = 0; i < 2; i++)
      {
        'participation_id': id(20 + i),
        'revision': 4,
        'session_id': id(10 + i),
        'assignment_ids': [v1.itemId],
        'state': 'active',
        'required': true,
        'participating': true,
        'confirmation_state': 'confirmation_pending',
        'confirmed_at': null,
        'confirmed_schedule_revision': null,
        'reservation_state': 'none',
        'overlap_warning': false,
        'warnings': ['OUTSIDE_AVAILABILITY'],
        'permissions': {'confirm_participation': f1.permit()},
      },
  ],
  'proposals': [
    {
      'proposal_id': id(3),
      'revision': 2,
      'proposal_plan_revision': 3,
      'created_from_plan_revision': 4,
      'state': 'pending',
      'target_session_ids': [id(10), id(11)],
      'base_schedules': [
        for (var i = 0; i < 2; i++)
          {'session_id': id(10 + i), 'schedule_revision': 3},
      ],
      'proposed_sessions': [
        for (var i = 0; i < 2; i++)
          {
            'session_id': id(10 + i),
            'segments': [segment(i)],
          },
      ],
      'votes': [
        for (var i = 0; i < 2; i++)
          {
            'session_id': id(10 + i),
            'eligible_count': 8,
            'accepted_count': 5,
            'required_votes': 6,
            'satisfied': false,
          },
      ],
      'my_response': {
        'proposal_id': id(3),
        'proposal_plan_revision': 3,
        'membership_id': v1.membershipId,
        'membership_generation': 1,
        'response': 'pending',
        'response_revision': 1,
        'responded_at': null,
        'response_set': 'existing',
      },
      'permissions': {'respond_proposal': f1.permit()},
    },
  ],
  'permissions': {
    for (final key in [
      'edit_schedule_groups',
      'cancel_target_participation',
      'transfer_leadership',
      'open_next_cycle',
      'reopen_next_cycle',
      'view_common_context',
      'leave_global',
      'end_global',
    ])
      key: f1.permit(),
  },
  'leadership': f4.leadership(),
  'my_target_role': 'leader',
  'formation_slots': [],
  'formation_history': [],
  'unplaced_assignments': [],
  'target_cycle_key': n,
  'target_state': 'open',
}, created: true);
Map<String, dynamic> submissionWire() => f2.envelope(n, {
  'membership_id': v1.membershipId,
  'state': 'missing',
  'revision': 1,
  'source_personal_version': null,
  'intervals': <Map<String, dynamic>>[],
  'normalized_intervals': <Map<String, dynamic>>[],
  'submitted_at': null,
  'target_cycle_key': n,
  'cycle_member_id': v1.membershipId,
  'cycle_member_revision': 7,
}, created: true);
List<Map<String, dynamic>> targets() => [
  for (var i = 0; i < 2; i++)
    {
      'session_id': id(10 + i),
      'expected_schedule_revision': 3,
      'starts_at': start(i),
      'item_durations': [
        {'item_id': v1.itemId, 'duration_minutes': 20},
      ],
    },
];
Map<String, dynamic> editGroup() => {
  'client_group_key': 'first',
  'existing_group_id': id(1),
  'expected_group_revision': 2,
  'occurrence_mode': 'each',
  'planning_mode': 'manual',
  'required': true,
  'auto_confirm_additional_members': null,
  'day_scope': 'selected_weekdays',
  'alternatives': [
    for (var i = 0; i < 2; i++)
      {
        'client_alternative_key': 'choice$i',
        'existing_session_id': null,
        'expected_session_revision': null,
        'weekday': 3 + i,
        'starts_local': '20:00',
        'leader_latest_start_local': null,
        'item_ids': [v1.itemId],
      },
  ],
};
void main() {
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late v1.Api api;
  late CycleInteractionRepository gateway;
  late CycleParticipationController controller;
  late Map<String, dynamic> plan, submission, personal, candidate;
  late List<String> refreshed;
  late bool lost, wrongAck;
  late Map<String, Map<String, dynamic>> recorded;
  Map<String, dynamic> ack() {
    final req = api.requests.last, b = req['body'] as Map;
    if ((req['path'] as String).endsWith('availability-submission')) {
      final j = copy(submission);
      j['data'].addAll({
        'state': 'ready',
        'revision':
            submission['data']['source_personal_version'] == personal['version']
            ? submission['data']['revision']
            : (submission['data']['revision'] as int) + 1,
        'source_personal_version': personal['version'],
        'intervals': personal['intervals'],
        'submitted_at': f2.nowStamp,
      });
      return j;
    }
    return f2.envelope(n, {
      'command_id': req['key'],
      'outcome': (req['path'] as String).endsWith('/schedule-proposals')
          ? 'recorded'
          : 'applied',
      'executed_at': f2.nowStamp,
      'room_id': room,
      'target_cycle_key': b['target_cycle_key'],
      'revisions': [
        {'resource': 'target', 'id': f2.nextCycleId, 'revision': 2},
      ],
    }, created: true);
  }

  setUp(() {
    session = ReadSessionFake();
    changes = ChangeNotifier();
    api = v1.Api();
    gateway = CycleInteractionRepository(
      api: api,
      recruitment: f2.CycleGateway(),
    );
    plan = planWire();
    submission = submissionWire();
    personal = personal_test.response(
      version: 3,
      rows: [personal_test.row.toJson()],
    );
    refreshed = [];
    lost = wrongAck = false;
    recorded = {};
    candidate = f2.envelope(n, {
      'group_id': id(1),
      'revision': 2,
      'plan_revision': 5,
      'evaluated_at': f2.nowStamp,
      'state': 'ready',
      'earliest_start': start(0),
      'latest_start': start(1),
    }, created: true);
    api.respond = (path, q) async {
      if (api.requests.last['method'] == 'GET') {
        if (path.endsWith('/plan')) return copy(plan);
        if (path.endsWith('/play-availability')) return copy(personal);
        if (path.endsWith('/candidates')) return copy(candidate);
        if (path.endsWith('/availability-submission')) return copy(submission);
        throw StateError('Unexpected read $path');
      }
      final key = api.requests.last['key'] as String;
      recorded.putIfAbsent(key, ack);
      if (lost) {
        lost = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final j = copy(recorded[key]!);
      if (wrongAck) j['scope']['target_generation'] = 2;
      return j;
    };
    controller = CycleParticipationController(
      gateway: gateway,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => DateTime.parse(f2.nowStamp),
      onMutation: (t) async => refreshed.add(t),
    );
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });
  Future<CycleSchedulePreview> preview(
    String action, {
    String? resource,
  }) async =>
      (await controller.schedulePreview(room, n, action, id: resource))!;
  List<Map<String, dynamic>> writes() =>
      api.requests.where((r) => r['method'] != 'GET').toList();
  test(
    'submission copies original overnight rows/version to N without writing personal or consent endpoints',
    () async {
      final p = await preview('submission');
      await controller.scheduleCommand(p, {});
      final r = writes().single;
      expect(r['method'], 'PUT');
      expect(r['path'], '/v2/me/raid-rooms/$room/availability-submission');
      expect(r['body'], {
        'expected_cycle_key': c,
        'target_cycle_key': n,
        'expected_target_revision': 1,
        'expected_personal_version': 3,
        'expected_submission_revision': 1,
        'expected_cycle_member_revision': 7,
      });
      expect(refreshed, [n]);
      expect(controller.hasPending, false);
      expect(p.personal!.intervals.single.endDayOffset, 1);
      expect(personal['version'], 3);
    },
  );
  test(
    'lost submission ACK retries exact method/key/body despite newer personal table',
    () async {
      final p = await preview('submission');
      lost = true;
      await controller.scheduleCommand(p, {});
      final request = jsonEncode(writes().single);
      personal['version'] = 4;
      expect(controller.hasPending, true);
      expect(refreshed, isEmpty);
      await controller.retry();
      expect(jsonEncode(writes().last), request);
      expect(refreshed, [n]);
      expect(controller.hasPending, false);
    },
  );
  test(
    'wrong original submission scope keeps pending and a matching GET never resolves it',
    () async {
      final p = await preview('submission');
      wrongAck = true;
      await controller.scheduleCommand(p, {});
      expect(controller.hasPending, true);
      expect(await controller.scheduleRead(room, n, 'submission'), isNotNull);
      expect(controller.hasPending, true);
      expect(controller.canAct, false);
      expect(refreshed, isEmpty);
      wrongAck = false;
      await controller.retry();
      expect(refreshed, [n]);
    },
  );
  test(
    'submission with different rows cannot acknowledge copied data',
    () async {
      final p = await preview('submission');
      api.respond = (path, q) async {
        if (api.requests.last['method'] == 'GET') {
          return path.endsWith('/plan')
              ? copy(plan)
              : path.endsWith('play-availability')
              ? copy(personal)
              : copy(submission);
        }
        final value = ack();
        value['data']['intervals'] = [];
        return value;
      };
      await controller.scheduleCommand(p, {});
      expect(controller.hasPending, true);
      expect(refreshed, isEmpty);
    },
  );
  test(
    'changed personal version requires explicit refresh; missing personal never writes',
    () async {
      var p = await preview('submission');
      personal['version'] = 4;
      await controller.scheduleCommand(p, {});
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(writes(), isEmpty);
      personal = personal_test.response();
      p = await preview('submission');
      await controller.scheduleCommand(p, {});
      expect(writes(), isEmpty);
    },
  );
  test(
    'confirmation binds actual session/schedule/participation and cycle-member revisions',
    () async {
      final p = await preview('confirm', resource: id(10));
      await controller.scheduleCommand(p, {});
      expect(writes().single['body'], {
        'expected_cycle_key': c,
        'target_cycle_key': n,
        'expected_target_revision': 1,
        'expected_schedule_revision': 3,
        'expected_participation_revision': 4,
        'expected_cycle_member_revision': 7,
      });
      expect(
        writes().single['path'],
        endsWith('${id(10)}/participation-confirmations'),
      );
      expect(refreshed, [n]);
    },
  );
  test(
    'rejoin or schedule change after confirmation view does not inherit old consent',
    () async {
      final p = await preview('confirm', resource: id(10));
      plan['data']['my_membership']['cycle_member_revision'] = 8;
      plan['data']['my_participations'][0]['revision'] = 5;
      await controller.scheduleCommand(p, {});
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(writes(), isEmpty);
    },
  );
  test(
    'ended participation or denied permission cannot confirm future session',
    () async {
      plan['data']['my_participations'][0]['permissions']['confirm_participation'] =
          f1.permit(false);
      final p = await preview('confirm', resource: id(10));
      await controller.scheduleCommand(p, {});
      expect(writes(), isEmpty);
    },
  );
  test(
    'all selected session proposals form one immutable command with all item durations',
    () async {
      final p = await preview('propose');
      await controller.scheduleCommand(p, {'targets': targets()});
      expect(writes(), hasLength(1));
      expect(writes().single['body']['targets'], targets());
      expect(writes().single['body']['expected_leadership_revision'], 3);
      expect(refreshed, [n]);
    },
  );
  test(
    'missing, duplicate or foreign proposal sessions/items cannot create command',
    () async {
      final p = await preview('propose');
      expect(
        () => p.body({
          'targets': [targets()[0], targets()[0]],
        }),
        throwsFormatException,
      );
      final missing = targets();
      missing[0]['item_durations'] = [];
      expect(() => p.body({'targets': missing}), throwsFormatException);
      final foreign = targets();
      foreign[0]['session_id'] = id(99);
      expect(() => p.body({'targets': foreign}), throwsStateError);
      expect(writes(), isEmpty);
    },
  );
  test(
    '8-person vote accepts or rejects one proposal with proposal-plan and membership CAS',
    () async {
      final p = await preview('respond', resource: id(3));
      await controller.scheduleCommand(p, {'response': 'accept'});
      expect(writes().single['body'], {
        'expected_cycle_key': c,
        'target_cycle_key': n,
        'expected_target_revision': 1,
        'expected_proposal_revision': 2,
        'expected_proposal_plan_revision': 3,
        'response': 'accept',
        'expected_cycle_member_revision': 7,
      });
      expect(p.plan.data['proposals'][0]['votes'][0]['required_votes'], 6);
      expect(refreshed, [n]);
    },
  );
  test('obsolete proposal is displayed but never accepts a new vote', () async {
    plan['data']['proposals'][0]['state'] = 'obsolete';
    plan['data']['proposals'][0]['target_session_ids'] = [id(98), id(99)];
    for (var i = 0; i < 2; i++) {
      plan['data']['proposals'][0]['proposed_sessions'][i]['session_id'] = id(
        98 + i,
      );
    }
    final p = await preview('respond', resource: id(3));
    await controller.scheduleCommand(p, {'response': 'accept'});
    expect(writes(), isEmpty);
  });
  test(
    'member cannot edit/select/propose even if stale local editor offers controls',
    () async {
      plan['data']['my_target_role'] = 'member';
      final p = await preview('groups');
      await controller.scheduleCommand(p, {
        'groups': [editGroup()],
      });
      expect(writes(), isEmpty);
    },
  );
  test(
    'group edit keeps source group revision and multi-day semantics with single PUT',
    () async {
      final p = await preview('groups');
      await controller.scheduleCommand(p, {
        'groups': [editGroup()],
      });
      expect(writes().single['method'], 'PUT');
      expect(writes().single['body']['groups'][0]['occurrence_mode'], 'each');
      expect(
        writes().single['body']['groups'][0]['alternatives'],
        hasLength(2),
      );
      expect(refreshed, [n]);
    },
  );
  test(
    'group constraints protect required schedule, threshold, unique keys, full item set',
    () async {
      final p = await preview('groups');
      final g = editGroup();
      g['required'] = false;
      expect(
        () => p.body({
          'groups': [g],
        }),
        throwsFormatException,
      );
      g['required'] = true;
      expect(
        () => p.body({
          'groups': [g, g],
        }),
        throwsFormatException,
      );
      g['planning_mode'] = 'coordinated';
      g['auto_confirm_additional_members'] = 8;
      expect(
        () => p.body({
          'groups': [g],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'candidate selection checks state and matching group/plan before N-only write',
    () async {
      final p = await preview('select', resource: id(1));
      await controller.scheduleCommand(p, {'alternative_id': null});
      expect(writes().single['body']['expected_group_revision'], 2);
      expect(writes().single['path'], endsWith('${id(1)}/selections'));
      expect(refreshed, [n]);
    },
  );
  test(
    'no candidate and changed candidate or leader revision never silently selects',
    () async {
      var p = await preview('select', resource: id(1));
      candidate['data']['earliest_start'] = start(1);
      await controller.scheduleCommand(p, {});
      expect(writes(), isEmpty);
      expect(controller.failure, 'REVISION_CONFLICT');
      candidate['data']['state'] = 'no_candidate';
      candidate['data']['earliest_start'] = null;
      candidate['data']['latest_start'] = null;
      p = await preview('select', resource: id(1));
      await controller.scheduleCommand(p, {});
      expect(writes(), isEmpty);
    },
  );
  test(
    'manual selection never calls coordinated candidates endpoint',
    () async {
      final group = plan['data']['schedule_groups'][0];
      group['planning_mode'] = 'manual';
      group['day_scope'] = 'selected_weekdays';
      group['auto_confirm_additional_members'] = null;
      group['alternatives'] = [
        {
          'alternative_id': id(2),
          'session_id': null,
          'weekday': 3,
          'starts_local': '20:00',
          'leader_latest_start_local': null,
          'item_ids': [v1.itemId],
        },
      ];
      final p = await preview('select', resource: id(1));
      await controller.scheduleCommand(p, {'alternative_id': id(2)});
      expect(
        api.requests.any((r) => (r['path'] as String).endsWith('/candidates')),
        false,
      );
      expect(refreshed, [n]);
    },
  );
  test(
    'selected-cycle maintenance/floor are rejected but final Wednesday before 06 belongs to N',
    () async {
      final p = await preview('propose');
      var t = targets();
      t[0]['starts_at'] = '${n}T00:00:00Z';
      expect(
        () => p.body({'targets': t}),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'MAINTENANCE_WINDOW',
          ),
        ),
      );
      t = targets();
      t[0]['starts_at'] = DateTime.parse(
        '${n}T20:00:00Z',
      ).add(const Duration(days: 6)).toIso8601String();
      expect(() => p.body({'targets': t}), returnsNormally);
      t[0]['starts_at'] = DateTime.parse(
        '${n}T22:00:00Z',
      ).add(const Duration(days: 7)).toIso8601String();
      expect(
        () => p.body({'targets': t}),
        throwsA(isA<AccountReadException>()),
      );
    },
  );
  test(
    'time context keeps unavailable/missing/anonymous busy distinct and exposes no busy room identity',
    () async {
      final context = f2.envelope(n, {
        'room_id': room,
        'members_revision': 4,
        'plan_revision': 5,
        'evaluated_at': f2.nowStamp,
        'members': [
          for (var i = 0; i < 8; i++)
            {
              'membership_id': id(40 + i),
              'cycle_member_id': id(40 + i),
              'display': {'character_name': '캐릭터$i'},
              'submission': {
                ...submission['data'] as Map,
                'membership_id': id(40 + i),
                'cycle_member_id': id(40 + i),
              },
              'anonymous_busy': {
                'state': i == 7 ? 'unavailable' : 'ready',
                'revision': 1,
                'intervals': i == 0
                    ? [
                        {
                          'starts_at': start(0),
                          'ends_at': segment(0)['ends_at'],
                        },
                      ]
                    : [],
              },
            },
        ],
        'target_session_id': id(10),
        'permissions': {'view_schedule_context': f1.permit()},
        'target_cycle_key': n,
      }, created: true);
      final v = CycleScheduleView(room, n, 'context', context, id: id(10));
      expect(v.data['members'], hasLength(8));
      expect(v.data['members'][7]['anonymous_busy']['state'], 'unavailable');
      context['data']['members'][0]['anonymous_busy']['room_id'] = room;
      expect(
        () => CycleScheduleView(room, n, 'context', context, id: id(10)),
        throwsFormatException,
      );
    },
  );
  test(
    'overlap read has actual T/explicit cursor/limit and no command key, no room-specific scope required',
    () async {
      api.respond = (path, q) async => f2.envelope(n, {
        'items': [],
        'pair_count': 0,
        'affected_room_count': 0,
        'reservation_count': 0,
        'revision': 'digest',
        'next_cursor': null,
        'evaluated_at': f2.nowStamp,
        'target_cycle_key': n,
      });
      await controller.scheduleRead(room, n, 'overlaps', cursor: 'next-page');
      expect(api.requests.single['query'], {
        'target_cycle_key': n,
        'limit': 20,
        'cursor': 'next-page',
      });
      expect(api.requests.single['key'], null);
      expect(writes(), isEmpty);
    },
  );
  test(
    'wrong T, generation mixing, malformed closed nested payload are rejected',
    () async {
      final bad = planWire();
      bad['scope']['target_cycle_key'] = c;
      expect(
        () => CycleScheduleView(room, n, 'plan', bad),
        throwsFormatException,
      );
      final changed = planWire();
      changed['data']['my_assignments'][0]['target_cycle_key'] = c;
      expect(
        () => CycleScheduleView(room, n, 'plan', changed),
        throwsFormatException,
      );
      final extra = planWire();
      extra['data']['sessions'][0]['made_up'] = 'x';
      expect(
        () => CycleScheduleView(room, n, 'plan', extra),
        throwsFormatException,
      );
    },
  );
  test(
    'logout during preview or write discards late schedule payload and original ACK',
    () async {
      final p = await preview('confirm', resource: id(10)),
          reply = Completer<Map<String, dynamic>>();
      api.respond = (path, q) async =>
          api.requests.last['method'] == 'GET' ? copy(plan) : reply.future;
      final command = controller.scheduleCommand(p, {});
      await Future<void>.delayed(Duration.zero);
      session.change(authenticated: false);
      reply.complete(ack());
      await command;
      expect(controller.hasPending, false);
      expect(refreshed, isEmpty);
    },
  );
  test(
    'same-T retry never refreshes C and definitive rejection releases pending',
    () async {
      final p = await preview('respond', resource: id(3));
      lost = true;
      await controller.scheduleCommand(p, {'response': 'reject'});
      api.respond = (_, _) async =>
          throw const AccountReadException('PROPOSAL_NOT_PENDING', status: 409);
      await controller.retry();
      expect(controller.hasPending, false);
      expect(refreshed, [n]);
    },
  );
  test(
    'input is frozen before fresh plan read, not only before HTTP retry',
    () async {
      final p = await preview('propose'),
          reply = Completer<Map<String, dynamic>>(),
          input = {'targets': targets()};
      api.respond = (_, _) async =>
          api.requests.last['method'] == 'GET' ? reply.future : ack();
      final sending = controller.scheduleCommand(p, input);
      (input['targets'] as List)[0]['item_durations'][0]['duration_minutes'] =
          60;
      reply.complete(copy(plan));
      await sending;
      expect(
        writes()
            .single['body']['targets'][0]['item_durations'][0]['duration_minutes'],
        20,
      );
      expect(refreshed, [n]);
    },
  );
  test(
    '06:00 rollover requires new confirmation of same actual date, never shifts command to new N',
    () async {
      final p = await preview('confirm', resource: id(10));
      plan['scope'].addAll({
        'server_now': '${n}T02:00:00Z',
        'current_cycle_key': n,
        'phase': 'current',
      });
      await controller.scheduleCommand(p, {});
      expect(writes(), isEmpty);
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(refreshed, isEmpty);
    },
  );
  test(
    'single participant proposal is only recorded; no automatic response or local quorum application',
    () async {
      final votes = plan['data']['proposals'][0]['votes'] as List;
      for (final vote in votes) {
        vote.addAll({
          'eligible_count': 1,
          'accepted_count': 0,
          'required_votes': 1,
        });
      }
      final p = await preview('propose');
      await controller.scheduleCommand(p, {'targets': targets()});
      expect(writes(), hasLength(1));
      expect(writes().single['path'], endsWith('/schedule-proposals'));
      expect(p.plan.data['proposals'][0]['state'], 'pending');
      expect(p.plan.data['proposals'][0]['votes'][0]['accepted_count'], 0);
      expect(refreshed, [n]);
    },
  );
}
