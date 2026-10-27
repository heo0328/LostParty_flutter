import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_search_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;
import 'session_display_fixtures.dart' as sd;

const c = f1.current, n = f1.next, room = v1.roomId, app = v1.membershipId;
final ref = List.filled(64, 'm').join(), token = List.filled(64, 't').join();

Map<String, dynamic> admissionWire(
  String target, {
  String intent = 'join',
  bool required = false,
  bool allowed = true,
  int revision = 1,
}) {
  final selected = f2.creation(v1.draft().copy(targetCycleKey: target));
  final result = f2.envelope(target, {
    'room_id': room,
    'room_revision': revision,
    'members_revision': 1,
    'plan_revision': 1,
    'expected_cycle_key': c,
    'server_time': f2.nowStamp,
    'catalog_version': 'v2',
    'policy_snapshot': 'policy',
    'context_token': 'opaque-context-token',
    'selection': selected['selection'],
    'targets': [
      {
        'item_id': v1.itemId,
        'round_id': target == c ? f2.cycleId : f2.nextCycleId,
        'party_no': 1,
        'expected_round_revision': 1,
        'expected_weekly_revision': 8,
      },
    ],
    'session_choices': [
      if (required)
        {
          'session_id': v1.itemId,
          'required': true,
          'join_deadline': '2026-10-23T03:00:00Z',
          'permission': f1.permit(),
        },
    ],
    'comparison': selected['comparison'],
    'permissions': {
      intent: {
        'allowed': allowed,
        'reason': allowed ? null : 'ROOM_FULL',
        'next_change_at': null,
      },
    },
    'target_cycle_key': target,
    'expected_target_revision': 1,
    'issued_at': f2.nowStamp,
    'expires_at': '2026-10-22T03:05:00Z',
    'leadership': (f2.detail(target)['data'] as Map)['leadership'],
  }, created: true);
  final data = result['data'] as Map;
  data['session_display'] = sd.displayWire(
    result['scope'] as Map,
    sessions: [
      for (final s in data['session_choices'] as List)
        {
          ...sd.actualDisplay(s['session_id'] as String),
          ...s as Map<String, dynamic>,
        },
    ],
  );
  return result;
}

Map<String, dynamic> searchWire(
  String t, {
  String id = room,
  String? cursor,
  String digest = 'd',
}) {
  final card = Map<String, dynamic>.from(f2.detail(t)['data']['room'] as Map);
  card['room_id'] = id;
  return f2.envelope(t, {
    'items': [card],
    'directory_revision': 1,
    'filter_scope_digest': digest,
    'next_cursor': cursor,
    'evaluated_at': f2.nowStamp,
  });
}

Map<String, dynamic> appWire(
  String t, {
  bool leader = false,
  int revision = 1,
}) {
  final application = {
    'application_id': app,
    'room_id': room,
    'revision': revision,
    'state': 'pending',
    'created_at': f2.nowStamp,
    'expires_at': '2026-10-23T03:00:00Z',
    'ended_at': null,
    'display': {'character_name': '신청캐릭터'},
    'character_id': characterId,
    'selected_role': 'dealer',
    'admission_origin': {'scope': 'public', 'group_id': null},
    'target_cycle_key': t,
    'target_generation': 1,
  };
  return f2.envelope(
    t,
    leader
        ? {
            'application': application,
            'room_revision': 1,
            'members_revision': 1,
            'plan_revision': 1,
            'server_time': f2.nowStamp,
            'eligibility': {
              'evaluated_at': f2.nowStamp,
              'state': 'eligible',
              'reasons': [],
              'comparison': null,
            },
            'permissions': {'approve': f1.permit(), 'reject': f1.permit()},
          }
        : application,
    created: true,
  );
}

Map<String, dynamic> filterWire() => {
  'filter_context_token': token,
  'scope_digest': 'digest',
  'evaluated_at': f2.nowStamp,
  'groups': [
    {'group_id': v1.groupId, 'revision': 1, 'members_revision': 1},
  ],
  'members': [
    {
      'member_ref': ref,
      'aliases': [
        {'group_id': v1.groupId, 'group_membership_id': app},
      ],
      'display': {'character_name': '대표캐릭터'},
    },
  ],
};

class TestGateway extends CycleInteractionRepository {
  TestGateway(this.transport, this.source)
    : super(api: transport, recruitment: source);
  final v1.Api transport;
  final f2.CycleGateway source;
  Future<CycleSearchPage> Function(String, CycleSearchFilter, String?)?
  onSearch;
  Future<CycleAdmissionPreview> Function(String)? onAdmission;
  int searches = 0;
  @override
  Future<CycleSearchPage> search(
    String t,
    CycleSearchFilter f, {
    String? cursor,
  }) {
    searches++;
    return onSearch == null
        ? super.search(t, f, cursor: cursor)
        : onSearch!(t, f, cursor);
  }

  @override
  Future<CycleAdmissionPreview> admission(
    String room,
    String target,
    String character,
    String role,
    String intent,
  ) => onAdmission == null
      ? super.admission(room, target, character, role, intent)
      : onAdmission!(target);
}

void main() {
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late v1.Api api;
  late f2.CycleGateway source;
  late TestGateway gateway;
  late CycleParticipationController controller;
  late DateTime instant;
  late List<String> invalidations;
  int authority = 0;
  String scope() => '${session.userId}/${session.generation}/$authority';
  Future<Map<String, dynamic>> respond(
    String path,
    Map<String, dynamic>? query,
  ) async {
    final request = api.requests.last,
        body = request['body'] as Map<String, dynamic>?;
    final target =
        query?['target_cycle_key'] as String? ??
        body?['target_cycle_key'] as String? ??
        c;
    if (path.endsWith('admission-context')) {
      return admissionWire(target, intent: query!['intent'] as String);
    }
    if (path.endsWith('filter-context')) return filterWire();
    if (path.endsWith('/search')) return searchWire(target);
    if (path == '/v2/raid-room-applications/$app') return appWire(target);
    if (path.endsWith('/plan')) {
      final detail = f2.detail(target)['data'] as Map;
      return f2.envelope(target, {
        'room_id': room,
        'revision': 1,
        'members_revision': 1,
        'server_time': f2.nowStamp,
        'app_capacity': 8,
        'game_items': [],
        'schedule_state': 'unscheduled',
        'schedule_groups': [],
        'sessions': [],
        'session_segments': [],
        'my_membership': {
          'membership_id': app,
          'revision': 1,
          'group_member': false,
          'target_role': 'member',
          'cycle_member_id': app,
          'cycle_member_revision': 3,
          'joined_order': '1',
        },
        'my_assignments': [
          {
            'assignment_id': v1.itemId,
            'revision': 7,
            'membership_id': app,
            'item_id': v1.itemId,
            'round_id': target == c ? f2.cycleId : f2.nextCycleId,
            'character_id': secondCharacterId,
            'selected_role': 'dealer',
            'state': 'active',
            'ended_at': null,
            'raid_participation_state': 'confirmed',
            'completion_source': null,
            'completed_at': null,
            'target_cycle_key': target,
          },
        ],
        'my_participations': [],
        'proposals': [],
        'permissions': {
          for (final k in [
            'edit_schedule_groups',
            'cancel_target_participation',
            'transfer_leadership',
            'open_next_cycle',
            'reopen_next_cycle',
            'view_common_context',
            'leave_global',
            'end_global',
          ])
            k: f1.permit(false),
        },
        'leadership': detail['leadership'],
        'my_target_role': 'member',
        'formation_slots': [],
        'formation_history': [],
        'unplaced_assignments': [],
        'target_cycle_key': target,
        'target_state': 'open',
      }, created: true);
    }
    final application =
        path.endsWith('/applications') ||
        path.endsWith('/reject') ||
        path.endsWith('/withdraw');
    final ack = application
        ? {
            'command_id': request['key'],
            'room_id': room,
            'application_id': app,
            'revision': 2,
            'state': path.endsWith('/reject')
                ? 'rejected'
                : path.endsWith('/withdraw')
                ? 'withdrawn'
                : 'pending',
            'executed_at': f2.nowStamp,
            'target_cycle_key': target,
          }
        : {
            'command_id': request['key'],
            'outcome': 'applied',
            'executed_at': f2.nowStamp,
            'room_id': room,
            'target_cycle_key': target,
            'revisions': [
              {'resource': 'room', 'id': room, 'revision': 2},
            ],
          };
    return f2.envelope(target, ack, created: true);
  }

  setUp(() {
    authority = 0;
    session = ReadSessionFake();
    changes = ChangeNotifier();
    api = v1.Api();
    source = f2.CycleGateway();
    gateway = TestGateway(api, source);
    api.respond = respond;
    instant = DateTime.parse(f2.nowStamp);
    invalidations = [];
    controller = CycleParticipationController(
      gateway: gateway,
      session: session,
      changes: changes,
      scopeKey: scope,
      now: () => instant,
      onMutation: (t) async {
        invalidations.add(t);
      },
    );
    source.onCycleDetail = (t) async => BackendRecruitmentDetail.fromJson({
      'room': <String, dynamic>{
        ...f2.detail(t)['data']['room'],
        'cycle_key': t,
      },
      for (final k in [
        'settings',
        'members_revision',
        'my_membership',
        'plan_revision',
        'permissions',
        'access',
      ])
        k: f2.detail(t)['data'][k],
      'members': [],
    }, room);
  });
  tearDown(() {
    controller.dispose();
    changes.dispose();
    session.dispose();
  });

  test(
    'search body keeps multi-OR/sort/slots before server page and no idempotency key',
    () async {
      final f = CycleSearchFilter(
        category: 'group_linked',
        groupId: v1.groupId,
        token: token,
        members: {
          ref: {characterId},
        },
        raids: {'raid_a'},
        difficulties: {'normal', 'hard'},
        experiences: {'clearExp', 'tryLevel', 'unrestricted'},
        remaining: {2, 3},
        descending: false,
      );
      final page = await gateway.search(n, f);
      final request = api.requests.single, b = request['body'] as Map;
      expect(request['path'], '/v2/raid-rooms/search');
      expect(request['key'], null);
      expect(request['method'], 'POST');
      expect(b['target_cycle_key'], n);
      expect(b['remaining_slot_counts'], [2, 3]);
      expect(b['experience_levels'], ['clearExp', 'tryLevel', 'unrestricted']);
      expect(b['sort'], {
        'criterion': 'member_count',
        'direction': 'ascending',
      });
      expect(b['member_conditions'], [
        {
          'member_ref': ref,
          'character_ids': [characterId],
        },
      ]);
      expect(page.rows.single.count, 1);
      expect(CycleSearchFilter().body(c)['experience_levels'], isEmpty);
      expect(CycleSearchFilter().body(c)['remaining_slot_counts'], isEmpty);
    },
  );
  test(
    'filter context uses opaque scoped member refs without inventing character candidates',
    () async {
      final ctx = await gateway.filterContext(v1.groupId);
      expect(ctx.members.single['member_ref'], ref);
      expect(ctx.members.single.containsKey('characters'), false);
      expect(
        api.requests.single['query']['group_ids'],
        jsonEncode([v1.groupId]),
      );
      final invalid = filterWire();
      invalid['members'][0]['aliases'][0]['group_id'] = room;
      expect(
        () => CycleFilterContext(invalid, v1.groupId),
        throwsFormatException,
      );
    },
  );
  test('search rejects other T, duplicate cards and over-limit pages', () {
    expect(() => CycleSearchPage(searchWire(c), n), throwsFormatException);
    final j = searchWire(c);
    j['data']['items'].add(j['data']['items'][0]);
    expect(() => CycleSearchPage(j, c), throwsFormatException);
    final k = searchWire(c);
    k['data']['next_cursor'] = '';
    expect(() => CycleSearchPage(k, c), throwsFormatException);
  });
  test(
    'required sessions need explicit consent, disallowed sessions cannot be inserted',
    () {
      final p = CycleAdmissionPreview(
        admissionWire(n, required: true),
        room: room,
        target: n,
        character: characterId,
        role: 'dealer',
        intent: 'join',
      );
      expect(() => p.body({}), throwsA(isA<AccountReadException>()));
      expect(p.body({v1.itemId})['target_session_ids'], [v1.itemId]);
      expect(() => p.body({app}), throwsFormatException);
      final j = admissionWire(n, required: true);
      j['data']['session_choices'][0]['join_deadline'] = f2.nowStamp;
      j['data']['session_display']['sessions'][0]['join_deadline'] =
          f2.nowStamp;
      final expired = CycleAdmissionPreview(
        j,
        room: room,
        target: n,
        character: characterId,
        role: 'dealer',
        intent: 'join',
      );
      expect(
        () => expired.body({v1.itemId}),
        throwsA(isA<AccountReadException>()),
      );
    },
  );
  for (final intent in ['join', 'apply', 'change_character']) {
    test(
      '$intent wire binds T/context and only explicit change reads own plan',
      () async {
        final p = await controller.preview(
          room,
          n,
          characterId,
          'dealer',
          intent,
        );
        expect(p, isNotNull);
        expect(api.requests.last['query']['include_session_display'], 'true');
        await controller.admit(p!, {});
        expect(controller.hasPending, false);
        expect(controller.failure, null);
        expect(invalidations, [n]);
        final write = api.requests.lastWhere((r) => r['method'] == 'POST');
        expect(write['status'], intent == 'apply' ? 201 : 200);
        expect(write['body']['target_cycle_key'], n);
        expect(write['body']['expected_cycle_key'], c);
        expect(write['body']['target_session_ids'], isEmpty);
        expect(write['key'], isNotNull);
        expect(
          api.requests
              .where((r) => (r['path'] as String).endsWith('/plan'))
              .length,
          intent == 'change_character' ? 1 : 0,
        );
        if (intent == 'change_character') {
          expect(write['body']['assignments'], [
            {'assignment_id': v1.itemId, 'expected_revision': 7},
          ]);
          expect(write['body']['expected_cycle_member_revision'], 3);
        }
      },
    );
  }
  test(
    'fresh context change requires reconfirmation and creates no write',
    () async {
      final p = await controller.preview(
        room,
        c,
        characterId,
        'dealer',
        'join',
      );
      api.respond = (path, q) async => admissionWire(c, revision: 2);
      await controller.admit(p!, {});
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(controller.hasPending, false);
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    },
  );
  test(
    'admission display change and omitted opt-in data block commands',
    () async {
      final p = (await controller.preview(
        room,
        n,
        characterId,
        'dealer',
        'join',
      ))!;
      api.respond = (path, q) async {
        final j = admissionWire(n);
        j['data']['session_display']['display_revision'] = List.filled(
          64,
          'b',
        ).join();
        return j;
      };
      await controller.admit(p, {});
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      api.respond = (path, q) async =>
          admissionWire(n)..['data'].remove('session_display');
      expect(
        await controller.preview(room, n, characterId, 'dealer', 'join'),
        isNull,
      );
      expect(controller.failure, 'INVALID_RESPONSE');
    },
  );
  test(
    'admission freezes selected IDs before a delayed fresh context',
    () async {
      final j = admissionWire(n, required: true);
      api.respond = (path, q) async =>
          api.requests.last['method'] == 'GET' ? j : respond(path, q);
      final p = (await controller.preview(
        room,
        n,
        characterId,
        'dealer',
        'join',
      ))!;
      final gate = Completer<Map<String, dynamic>>();
      api.respond = (path, q) async =>
          api.requests.last['method'] == 'GET' ? gate.future : respond(path, q);
      final chosen = <String>{v1.itemId};
      final task = controller.admit(p, chosen);
      await f1.settled(() => api.requests.length == 2);
      chosen.clear();
      gate.complete(j);
      await task;
      expect(controller.failure, isNull);
      expect(
        api.requests.singleWhere(
          (r) => r['method'] == 'POST',
        )['body']['target_session_ids'],
        [v1.itemId],
      );
    },
  );
  test(
    'semantic confirmation signature ignores object-key serialization order',
    () {
      final a = admissionWire(c), b = admissionWire(c);
      b['data']['selection'] = Map.fromEntries(
        (b['data']['selection'] as Map<String, dynamic>).entries
            .toList()
            .reversed,
      );
      CycleAdmissionPreview parse(Map<String, dynamic> j) =>
          CycleAdmissionPreview(
            j,
            room: room,
            target: c,
            character: characterId,
            role: 'dealer',
            intent: 'join',
          );
      expect(parse(a).confirmationSignature, parse(b).confirmationSignature);
    },
  );
  test(
    'unknown join freezes original key/body; retry does not fetch context or duplicate seats',
    () async {
      final p = await controller.preview(
        room,
        n,
        characterId,
        'dealer',
        'join',
      );
      final originalRespond = api.respond!;
      api.respond = (path, q) async {
        if (api.requests.last['method'] == 'POST') {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return originalRespond(path, q);
      };
      await controller.admit(p!, {});
      expect(controller.hasPending, true);
      expect(controller.pendingTarget, n);
      final original = Map<String, dynamic>.from(api.requests.last),
          reads = api.requests.where((r) => r['method'] == 'GET').length;
      await controller.admit(p, {});
      expect(api.requests.last['key'], original['key']);
      api.respond = originalRespond;
      await controller.retry();
      expect(api.requests.last['key'], original['key']);
      expect(
        jsonEncode(api.requests.last['body']),
        jsonEncode(original['body']),
      );
      expect(api.requests.where((r) => r['method'] == 'GET').length, reads);
      expect(controller.hasPending, false);
      expect(invalidations, [n]);
    },
  );
  test(
    '24h/REQUEST_IN_PROGRESS keep pending and respect Retry-After',
    () async {
      final p = await controller.preview(
        room,
        c,
        characterId,
        'dealer',
        'join',
      );
      api.respond = (path, q) async {
        if (api.requests.last['method'] == 'POST') {
          throw const AccountReadException(
            'REQUEST_IN_PROGRESS',
            status: 409,
            retryAfter: Duration(seconds: 2),
          );
        }
        return respond(path, q);
      };
      await controller.admit(p!, {});
      expect(controller.canRetry, false);
      expect(controller.hasPending, true);
      instant = instant.add(const Duration(seconds: 3));
      expect(controller.canRetry, true);
      instant = instant.add(const Duration(hours: 24));
      expect(controller.canRetry, false);
      expect(controller.hasPending, true);
    },
  );
  test(
    '8-person last-seat rejection clears command and never displays accepted participation',
    () async {
      final p = await controller.preview(
        room,
        c,
        characterId,
        'dealer',
        'join',
      );
      api.respond = (path, q) async {
        if (api.requests.last['method'] == 'POST') {
          throw const AccountReadException('ROOM_FULL', status: 409);
        }
        return respond(path, q);
      };
      await controller.admit(p!, {});
      expect(controller.failure, 'ROOM_FULL');
      expect(controller.hasPending, false);
      expect(invalidations, [c]);
      expect(controller.notice, '현재 상태를 다시 확인한 뒤 시도해 주세요.');
    },
  );
  for (final field in ['room_id', 'target_cycle_key', 'generation']) {
    test('mismatched ACK retains pending ($field)', () async {
      final p = await controller.preview(
        room,
        n,
        characterId,
        'dealer',
        'join',
      );
      api.respond = (path, q) async {
        final j = await respond(path, q);
        if (api.requests.last['method'] == 'POST') {
          if (field == 'generation') {
            j['scope']['target_generation'] = 2;
          } else {
            j['data'][field] = field == 'room_id' ? app : c;
          }
        }
        return j;
      };
      await controller.admit(p!, {});
      expect(controller.hasPending, true);
      expect(invalidations, isEmpty);
    });
  }
  test(
    'logout/authority change discards late write result and prevents mutation callbacks',
    () async {
      final p = await controller.preview(
        room,
        c,
        characterId,
        'dealer',
        'join',
      );
      final response = Completer<Map<String, dynamic>>();
      api.respond = (path, q) async {
        if (api.requests.last['method'] == 'POST') return response.future;
        return respond(path, q);
      };
      final future = controller.admit(p!, {});
      await f1.settled(() => controller.hasPending);
      final ack = await respond('/v2/raid-rooms/$room/join', null);
      session.change(authenticated: false);
      response.complete(ack);
      await future;
      expect(controller.hasPending, false);
      expect(controller.lastTarget, null);
      expect(invalidations, isEmpty);
    },
  );
  for (final action in ['approve', 'reject', 'withdraw']) {
    test(
      '$action uses current application and T-specific authority/CAS',
      () async {
        api.respond = (path, q) async {
          if (path == '/v2/raid-room-applications/$app') {
            return appWire(n, leader: action != 'withdraw');
          }
          return respond(path, q);
        };
        final p = await controller.review(app, n);
        await controller.decide(p!, action);
        expect(controller.failure, null);
        expect(invalidations, [n]);
        final write = api.requests.lastWhere((r) => r['method'] == 'POST');
        expect(write['path'], '/v2/raid-room-applications/$app/$action');
        expect(write['body']['expected_target_revision'], 1);
        expect(write['body']['expected_application_revision'], 1);
        expect(
          write['body'].containsKey('expected_leadership_revision'),
          action != 'withdraw',
        );
      },
    );
  }
  test(
    'approval stale app revision and denied leader permission never write',
    () async {
      api.respond = (path, q) async => appWire(n, leader: true);
      final p = await controller.review(app, n);
      api.respond = (path, q) async => appWire(n, leader: true, revision: 2);
      await controller.decide(p!, 'approve');
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      api.respond = (path, q) async {
        final j = appWire(n, leader: true);
        j['data']['permissions']['approve'] = f1.permit(false);
        return j;
      };
      final denied = await controller.review(app, n);
      await controller.decide(denied!, 'approve');
      expect(controller.hasPending, false);
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    },
  );
  test(
    'application confirmation rejects another room or changed target scope',
    () async {
      api.respond = (path, q) async => appWire(n, leader: true);
      expect(await controller.review(app, n, expectedRoom: v1.itemId), isNull);
      expect(controller.failure, 'INVALID_RESPONSE');
      final preview = await controller.review(app, n, expectedRoom: room);
      api.respond = (path, q) async {
        final j = appWire(n, leader: true);
        j['scope']['target_revision'] = 2;
        return j;
      };
      await controller.decide(preview!, 'approve');
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    },
  );
  group('search state', () {
    late CycleSearchViewModel model;
    setUp(
      () => model = CycleSearchViewModel(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: scope,
        mutations: controller,
      ),
    );
    tearDown(() => model.dispose());
    Future<void> seedCursor() async {
      gateway.onSearch = (t, f, cursor) async =>
          CycleSearchPage(searchWire(t, cursor: 'old'), t);
      await model.load();
    }

    test(
      'server cursor expires: replace once with same target and filters',
      () async {
        await seedCursor();
        model.update(model.filter.copy(descending: false, remaining: {2, 3}));
        await f1.settled(() => !model.loading);
        final signature = model.filter.signature;
        final requests = <String?>[];
        gateway.onSearch = (t, f, cursor) async {
          expect(t, c);
          expect(f.signature, signature);
          requests.add(cursor);
          if (cursor != null) {
            throw const AccountReadException('CURSOR_STALE', status: 409);
          }
          expect(model.rows, isEmpty);
          expect(model.cursor, isNull);
          expect(model.loading, true);
          return CycleSearchPage(searchWire(t, id: app, digest: 'fresh'), t);
        };
        await model.search(more: true);
        expect(requests, ['old', null]);
        expect(model.rows.single.id, app);
        expect(model.failure, isNull);
        gateway.onSearch = (t, f, cursor) async =>
            CycleSearchPage(searchWire(t), t);
        model.selectTarget(n);
        await f1.settled(() => !model.loading);
        final reads = gateway.searches;
        model.selectTarget(c);
        expect(gateway.searches, reads);
        expect(model.rows.single.id, app);
      },
    );

    for (final code in [
      'CURSOR_STALE',
      'NETWORK_ERROR',
      'FILTER_CONTEXT_STALE',
    ]) {
      test(
        'recovery failure $code stops, clears old cache and allows explicit refresh',
        () async {
          await seedCursor();
          var calls = 0;
          gateway.onSearch = (t, f, cursor) async {
            calls++;
            if (cursor != null) {
              throw const AccountReadException('CURSOR_STALE', status: 409);
            }
            throw AccountReadException(code, status: 409);
          };
          await model.search(more: true);
          expect(calls, 2);
          expect(model.failure, code);
          expect(model.rows, isEmpty);
          expect(model.cursor, isNull);
          expect(model.loading, false);
          gateway.onSearch = (t, f, cursor) async {
            expect(cursor, isNull);
            return CycleSearchPage(searchWire(t, id: app), t);
          };
          await model.refresh();
          expect(model.failure, isNull);
          expect(model.rows.single.id, app);
        },
      );
    }

    for (final error in [
      const AccountReadException('INVALID_REQUEST', status: 400),
      const AccountReadException('PERMISSION_DENIED', status: 403),
      const AccountReadException('CYCLE_CHANGED', status: 409),
      const AccountReadException('CURSOR_STALE'),
    ]) {
      test('${error.code}/${error.status} never auto retries', () async {
        await seedCursor();
        var calls = 0;
        gateway.onSearch = (t, f, cursor) async {
          calls++;
          throw error;
        };
        await model.search(more: true);
        expect(calls, 1);
        expect(model.failure, error.code);
      });
    }

    test('first page CURSOR_STALE never retries', () async {
      var calls = 0;
      gateway.onSearch = (t, f, cursor) async {
        calls++;
        throw const AccountReadException('CURSOR_STALE', status: 409);
      };
      await model.load();
      expect(calls, 1);
      expect(model.failure, 'CURSOR_STALE');
    });

    test('local digest mismatch is rejected without recovery', () async {
      await seedCursor();
      var calls = 0;
      gateway.onSearch = (t, f, cursor) async {
        calls++;
        return CycleSearchPage(searchWire(t, id: app, digest: 'changed'), t);
      };
      await model.search(more: true);
      expect(calls, 1);
      expect(model.failure, 'CURSOR_STALE');
      expect(model.rows, isEmpty);
    });

    test(
      'mutation discards every filter of affected target, preserves opposite cache',
      () async {
        await seedCursor();
        model.update(model.filter.copy(remaining: {2}));
        await f1.settled(() => !model.loading);
        model.selectTarget(n);
        await f1.settled(() => !model.loading);
        var calls = 0;
        gateway.onSearch = (t, f, cursor) async {
          calls++;
          return CycleSearchPage(searchWire(t, id: app), t);
        };
        await controller.changed(room, c);
        expect(calls, 0);
        model.selectTarget(c);
        await f1.settled(() => !model.loading);
        expect(calls, 1);
        model.update(CycleSearchFilter());
        await f1.settled(() => !model.loading);
        expect(calls, 2);
        model.selectTarget(n);
        expect(calls, 2);
        expect(model.rows.single.id, room);
        await controller.changed(room, c);
        await controller.changed(room, n);
        await f1.settled(() => !model.loading);
        expect(calls, 3);
        expect(model.rows.single.id, app);
      },
    );

    for (final change in ['target', 'filter', 'scope', 'logout', 'mutation']) {
      test('late cursor recovery cannot overwrite newer $change', () async {
        await seedCursor();
        final wait = Completer<CycleSearchPage>();
        var calls = 0;
        gateway.onSearch = (t, f, cursor) async {
          calls++;
          if (calls == 1) {
            throw const AccountReadException('CURSOR_STALE', status: 409);
          }
          if (calls == 2) return wait.future;
          return CycleSearchPage(searchWire(t, id: app), t);
        };
        final loading = model.search(more: true);
        await f1.settled(() => calls == 2);
        await model.search(more: true);
        await model.refresh();
        expect(calls, 2); // single flight includes the recovery request
        switch (change) {
          case 'target':
            model.selectTarget(n);
          case 'filter':
            model.update(model.filter.copy(remaining: {3}));
          case 'scope':
            authority++;
            changes.notifyListeners();
          case 'logout':
            session.change(authenticated: false);
          case 'mutation':
            await controller.changed(room, c);
        }
        if (change != 'logout') await f1.settled(() => !model.loading);
        wait.complete(CycleSearchPage(searchWire(c), c));
        await loading;
        expect(model.loading, false);
        expect(model.failure, isNull);
        if (change == 'logout') {
          expect(model.rows, isEmpty);
        } else {
          expect(model.rows.single.id, app);
        }
      });
    }

    test(
      'scope invalidation before stale response prevents recovery request',
      () async {
        await seedCursor();
        final wait = Completer<CycleSearchPage>();
        var calls = 0;
        gateway.onSearch = (t, f, cursor) {
          calls++;
          return wait.future;
        };
        final loading = model.search(more: true);
        session.change(authenticated: false);
        wait.completeError(
          const AccountReadException('CURSOR_STALE', status: 409),
        );
        await loading;
        expect(calls, 1);
        expect(model.rows, isEmpty);
        expect(model.failure, isNull);
      },
    );

    test(
      'disposed recovery ignores result and notifies no listeners',
      () async {
        final other = CycleSearchViewModel(
          gateway: gateway,
          session: session,
          changes: changes,
          scopeKey: scope,
        );
        gateway.onSearch = (t, f, cursor) async =>
            CycleSearchPage(searchWire(t, cursor: 'old'), t);
        await other.load();
        final wait = Completer<CycleSearchPage>();
        var calls = 0, notifications = 0;
        gateway.onSearch = (t, f, cursor) async {
          calls++;
          if (cursor != null) {
            throw const AccountReadException('CURSOR_STALE', status: 409);
          }
          return wait.future;
        };
        final loading = other.search(more: true);
        await f1.settled(() => calls == 2);
        other.addListener(() => notifications++);
        other.dispose();
        wait.complete(CycleSearchPage(searchWire(c), c));
        await loading;
        expect(notifications, 0);
        expect(other.rows, isEmpty);
      },
    );
    test(
      'toggle sort/remaining filters reset cursor and preserve server page order',
      () async {
        api.respond = (path, q) async {
          final j = searchWire(c, cursor: 'first');
          return j;
        };
        await model.load();
        expect(model.cursor, 'first');
        model.update(model.filter.copy(descending: false, remaining: {2, 3}));
        await f1.settled(() => !model.loading);
        expect(api.requests.last['body']['cursor'], null);
        expect(api.requests.last['body']['remaining_slot_counts'], [2, 3]);
        expect(model.rows.single.count, 1);
      },
    );
    test('late C cannot overwrite N and target cache/filter isolate', () async {
      final waiting = Completer<CycleSearchPage>();
      gateway.onSearch = (t, f, cursor) async =>
          t == c ? waiting.future : CycleSearchPage(searchWire(n), n);
      final first = model.load();
      await f1.settled(() => model.target == c);
      model.selectTarget(n);
      await f1.settled(() => !model.loading);
      waiting.complete(CycleSearchPage(searchWire(c), c));
      await first;
      expect(model.target, n);
      expect(model.rows.single.wire['target_cycle_key'], n);
    });
    test(
      'repeated cursor/digest mismatch resets page instead of appending duplicates',
      () async {
        gateway.onSearch = (t, f, cursor) async => CycleSearchPage(
          searchWire(t, id: cursor == null ? room : app, cursor: 'loop'),
          t,
        );
        await model.load();
        await model.search(more: true);
        expect(model.failure, 'CURSOR_STALE');
        expect(model.rows, isEmpty);
        expect(model.cursor, null);
      },
    );
    test(
      'group request cannot reinstate group after category change',
      () async {
        await model.load();
        final wait = Completer<Map<String, dynamic>>();
        api.respond = (path, q) async =>
            path.endsWith('filter-context') ? wait.future : respond(path, q);
        final selected = model.selectGroup(v1.groupId);
        model.update(model.filter.copy(category: 'general', clearGroup: true));
        wait.complete(filterWire());
        await selected;
        await f1.settled(() => !model.loading);
        expect(model.filter.category, 'general');
        expect(model.filter.groupIds, isEmpty);
        expect(model.groupContext, null);
      },
    );
    test(
      'mutation invalidates only changed target and ignores late old search',
      () async {
        await model.load();
        model.selectTarget(n);
        await f1.settled(() => !model.loading);
        final reads = gateway.searches;
        await controller.changed(room, c);
        expect(gateway.searches, reads);
        await controller.changed(room, n);
        await f1.settled(() => !model.loading);
        expect(gateway.searches, greaterThan(reads));
      },
    );
    test(
      'ownership/read-generation invalidation fences old account responses',
      () async {
        final wait = Completer<CycleSearchPage>();
        gateway.onSearch = (t, f, cursor) => wait.future;
        final loading = model.load();
        await f1.settled(() => model.target == c);
        session.change(authenticated: false);
        wait.complete(CycleSearchPage(searchWire(c), c));
        await loading;
        expect(model.rows, isEmpty);
        expect(model.target, null);
      },
    );
  });
}
