import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/member_cycle_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/recruitment_start_policy.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_detail_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;

const c = f1.current, n = f1.next;
const cycleId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const nextCycleId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const nowStamp = '2026-10-22T03:00:00Z';

Map<String, dynamic> creation(RecruitmentDraft d) {
  final j = v1.contextJson(d);
  j['expected_cycle_key'] = c;
  j['server_time'] = nowStamp;
  j['permissions'] = {'create': f1.permit()};
  Map<String, dynamic> prospective(String target) => {
    'target_cycle_key': target,
    'room_cycle_id': target == c ? cycleId : nextCycleId,
    'generation': 1,
    'initial_target_revision': 1,
    'selection': j['selection'],
    'targets': [
      for (final item in d.items)
        {
          ...item.choice,
          'item_id': v1.itemId,
          'round_id': target == c ? cycleId : nextCycleId,
          'party_no': 1,
          'expected_round_revision': 1,
          'expected_weekly_revision': 8,
        },
    ],
    'permission': f1.permit(),
    'conflicts': [],
  };
  j.addAll({
    'target_cycle_key': d.targetCycleKey,
    'expected_target_revision': null,
    'issued_at': nowStamp,
    'expires_at': '2026-10-22T03:05:00Z',
    'prospective_room_id': v1.roomId,
    'target_creation': prospective(d.targetCycleKey!),
    'next_cycle_creation': d.continueTogether ? prospective(n) : null,
    'continuation_effect': d.continueTogether
        ? 'target_and_next'
        : 'target_only',
  });
  return j;
}

Map<String, dynamic> ack(String key, Map<String, dynamic> body) => {
  'command_id': key,
  'outcome': 'applied',
  'executed_at': nowStamp,
  'room_id': v1.roomId,
  'target_cycle_key': body['target_cycle_key'],
  'revisions': [
    {'resource': 'room', 'id': v1.roomId, 'revision': 1},
  ],
  'created_cycles': [
    for (final t in [
      body['target_cycle_key'],
      if ((body['continuation'] as Map)['enabled'] == true) n,
    ])
      {
        'target_cycle_key': t,
        'room_cycle_id': t == c ? cycleId : nextCycleId,
        'generation': 1,
        'target_revision': 1,
        'leader_cycle_member_id': v1.membershipId,
      },
  ],
  'continuation_effect': (body['continuation'] as Map)['enabled'] == true
      ? 'target_and_next'
      : 'target_only',
};
Map<String, dynamic> envelope(
  String t,
  Map<String, dynamic> data, {
  bool created = false,
}) => {
  'scope': {
    ...f1.scope(t),
    if (created) ...{
      'room_cycle_id': t == c ? cycleId : nextCycleId,
      'target_generation': 1,
      'target_revision': 1,
    },
  },
  'data': data,
};
Map<String, dynamic> detail(String t) {
  final j = v1.detailJson();
  j['room'] = {
    ...f1.roomCard(),
    'room_id': v1.roomId,
    'room_cycle_id': t == c ? cycleId : nextCycleId,
    'target_cycle_key': t,
    'title': '레이드 A 모집',
    'phase': t == c ? 'current' : 'future',
    'items': [
      {
        'item_id': v1.itemId,
        'raid_id': 'raid_a',
        'difficulty_id': 'hard',
        'game_party_size': 8,
        'round_id': t == c ? cycleId : nextCycleId,
      },
    ],
    'my_target_role': 'leader',
    'leadership': {
      'leader_cycle_member_id': v1.membershipId,
      'leadership_revision': 1,
      'leader_membership_id': v1.membershipId,
    },
  };
  final members = j['members'] as List;
  for (final m in members) {
    m.remove('room_role');
    m.addAll({
      'target_role': 'leader',
      'cycle_member_id': v1.membershipId,
      'cycle_member_revision': 1,
      'joined_order': '1',
      'target_state': 'participating',
    });
    m['assignments'] = [
      {
        'assignment_id': v1.itemId,
        'item_id': v1.itemId,
        'round_id': t == c ? cycleId : nextCycleId,
        'state': 'confirmed',
        'party_no': 1,
        'slot_no': 1,
      },
    ];
  }
  j.addAll({
    'leadership': (j['room'] as Map)['leadership'],
    'my_target_role': 'leader',
    'formation_slots': [
      {
        'target_cycle_key': t,
        'round_id': t == c ? cycleId : nextCycleId,
        'party_no': 1,
        'slot_no': 1,
        'assignment_id': v1.itemId,
        'status': 'participating',
        'is_leader': true,
      },
    ],
    'formation_history': [],
    'unplaced_assignments': [],
  });
  return envelope(t, j, created: true);
}

class CycleGateway extends v1.Gateway implements CycleRecruitmentGateway {
  @override
  bool get twoCycleEnabled => true;
  Map<String, dynamic> meta = f1.cycles();
  Future<BackendRecruitmentDetail> Function(String)? onCycleDetail;
  @override
  Future<MemberCycles> cycles() async => MemberCycles.fromJson(meta);
  @override
  Future<RecruitmentCreationContext> context(RecruitmentDraft d) async {
    contexts++;
    return onContext == null
        ? RecruitmentCreationContext.fromCycleJson(creation(d), d)
        : onContext!(d);
  }

  @override
  Future<RecruitmentCreationAck> create(
    String key,
    Map<String, dynamic> body,
  ) async {
    writes.add((key: key, body: jsonEncode(body)));
    return onWrite == null
        ? RecruitmentCreationAck.fromCycleJson(ack(key, body), key, body)
        : onWrite!(key, body);
  }

  @override
  Future<List<String>> roomIdsFor(String target) async => [v1.roomId];
  @override
  Future<BackendRecruitmentDetail> cycleDetail(
    String id,
    String target,
  ) async => onCycleDetail!(target);
}

void main() {
  late ReadSessionFake session;
  late v1.Access access;
  late CycleGateway gateway;
  late BackendRecruitmentCreateViewModel model;
  late DateTime instant;
  setUp(() {
    session = ReadSessionFake();
    access = v1.Access();
    gateway = CycleGateway();
    instant = DateTime.parse(nowStamp);
    model = BackendRecruitmentCreateViewModel(
      gateway: gateway,
      session: session,
      accessChanges: access,
      hasVerifiedAccount: () => access.verified,
      now: () => instant,
    );
  });
  tearDown(() {
    model.dispose();
    access.dispose();
    session.dispose();
  });

  test(
    'C together sends one create with both server selections, N sends only N',
    () async {
      await model.activate();
      model.update(model.draft.copy(title: '초안', continueTogether: true));
      await model.submit();
      final body = jsonDecode(gateway.writes.single.body) as Map;
      expect(body['target_cycle_key'], c);
      expect(body['expected_target_revision'], null);
      expect(
        body['continuation']['next_selection']['character_id'],
        characterId,
      );
      expect(body['continuation'].containsKey('auto_open_enabled'), false);
      expect(model.createdTargetKey, c);
      expect(model.createdTargetKeys, [c, n]);
      expect(model.createdRoomId, v1.roomId);
      await model.activate(target: n);
      expect(model.draft.targetCycleKey, n);
      expect(model.draft.continueTogether, false);
      await model.submit();
      final nextBody = jsonDecode(gateway.writes.last.body) as Map;
      expect(nextBody['continuation'], {
        'enabled': false,
        'next_selection': null,
      });
      expect(model.createdTargetKey, n);
      expect(model.createdTargetKeys, [n]);
    },
  );
  test(
    'target change retains editor and rejects C+14 and future together',
    () async {
      await model.activate();
      model.update(
        model.draft.copy(
          title: '그대로',
          weekdays: {3},
          startMinute: 600,
          continueTogether: true,
        ),
      );
      await model.selectCycle(n);
      expect(model.draft.title, '그대로');
      expect(model.draft.weekdays, {3});
      expect(model.draft.continueTogether, false);
      await model.selectCycle('2026-11-04');
      expect(model.draft.targetCycleKey, n);
      model.update(model.draft.copy(continueTogether: true));
      expect(model.draft.continueTogether, false);
    },
  );
  test(
    'N without continuation rejects the checked-N effect in context and ACK',
    () {
      final d = v1.draft().copy(targetCycleKey: n, continueTogether: false);
      final context = creation(d)..['continuation_effect'] = 'target_only';
      final parsed = RecruitmentCreationContext.fromCycleJson(context, d);
      final body = d.body(parsed, '모집');
      final result = ack(characterId, body)
        ..['continuation_effect'] = 'target_only';
      expect(
        RecruitmentCreationAck.fromCycleJson(
          result,
          characterId,
          body,
        ).targetKey,
        n,
      );
      context['continuation_effect'] = 'target_is_next';
      expect(
        () => RecruitmentCreationContext.fromCycleJson(context, d),
        throwsFormatException,
      );
      result['continuation_effect'] = 'target_is_next';
      expect(
        () => RecruitmentCreationAck.fromCycleJson(result, characterId, body),
        throwsFormatException,
      );
    },
  );
  test(
    'unknown response freezes T and key/body across 06:00, only ACK clears',
    () async {
      instant = DateTime.parse('2026-10-27T20:50:00Z');
      gateway.meta['server_now'] = '2026-10-27T20:50:00Z';
      gateway.onContext = (d) async =>
          RecruitmentCreationContext.fromCycleJson({
            ...creation(d),
            'server_time': '2026-10-27T20:50:00Z',
            'issued_at': '2026-10-27T20:50:00Z',
            'expires_at': '2026-10-27T20:55:00Z',
          }, d);
      await model.activate();
      model.update(model.draft.copy(continueTogether: true));
      gateway.onWrite = (key, body) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.submit();
      final original = gateway.writes.single;
      expect(model.hasPending, true);
      await model.selectCycle(n);
      expect(model.draft.targetCycleKey, c);
      instant = DateTime.parse('2026-10-28T00:00:00Z');
      gateway.onWrite = (key, body) async =>
          RecruitmentCreationAck.fromCycleJson(ack(key, body), key, body);
      await model.retry();
      expect(gateway.writes.last, original);
      expect(model.hasPending, false);
      expect(model.createdTargetKey, c);
    },
  );
  for (final issue in [
    'missing_next',
    'wrong_cycle_id',
    'generation',
    'room',
  ]) {
    test('malformed atomic ACK keeps original pending ($issue)', () async {
      await model.activate();
      model.update(model.draft.copy(continueTogether: true));
      gateway.onWrite = (key, body) async {
        final j = ack(key, body),
            rows = ack(key, body)['created_cycles'] as List;
        if (issue == 'missing_next') rows.removeLast();
        if (issue == 'wrong_cycle_id') rows[0]['room_cycle_id'] = v1.itemId;
        if (issue == 'generation') rows[0]['generation'] = 2;
        if (issue == 'room') {
          j['room_id'] = v1.itemId;
          (j['revisions'] as List)[0]['id'] = v1.itemId;
        }
        j['created_cycles'] = rows;
        return RecruitmentCreationAck.fromCycleJson(j, key, body);
      };
      await model.submit();
      expect(model.hasPending, true);
      expect(model.createdRoomId, null);
    });
  }
  test(
    'next conflict denies whole command, no C write and no reserved seat',
    () async {
      await model.activate();
      model.update(model.draft.copy(continueTogether: true));
      gateway.onContext = (d) async {
        final j = creation(d);
        j['next_cycle_creation']['permission'] = {
          'allowed': false,
          'reason': 'WEEKLY_ALREADY_PARTICIPATING',
          'next_change_at': null,
        };
        return RecruitmentCreationContext.fromCycleJson(j, d);
      };
      await model.submit();
      expect(gateway.writes, isEmpty);
      expect(model.failure, 'WEEKLY_ALREADY_PARTICIPATING');
    },
  );
  test('stale context T and missing prospective evidence rejected', () {
    final d = v1.draft().copy(targetCycleKey: c, continueTogether: true);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['target_cycle_key'] = n,
      (j) => j['next_cycle_creation'] = null,
      (j) => j['next_cycle_creation']['selection'] = {
        ...j['selection'],
        'character_id': secondCharacterId,
      },
      (j) => j['expires_at'] = nowStamp,
    ]) {
      final j = creation(d);
      mutate(j);
      expect(
        () => RecruitmentCreationContext.fromCycleJson(j, d),
        throwsFormatException,
      );
    }
  });
  test(
    'target time checks use future week and maintenance/duration limits',
    () {
      const p = RecruitmentStartPolicy();
      bool allowed(String t, int minute, {int duration = 20}) => p.allows(
        now: instant,
        weekday: 3,
        minute: minute,
        durationMinutes: duration,
        targetCycleKey: t,
      );
      expect(allowed(c, 600), false);
      expect(allowed(n, 600), true);
      expect(allowed(n, 595), false);
      expect(allowed(n, 600, duration: 1445), false);
      expect(allowed('2026-11-04', 600), false);
    },
  );
  test(
    '06:00 metadata change keeps actual stale draft; explicit new T required',
    () async {
      await model.activate();
      model.update(model.draft.copy(title: '유지'));
      gateway.meta = {
        'server_now': '2026-10-28T03:00:00Z',
        'current': f1.meta(n),
        'next': f1.meta('2026-11-04'),
        'policy_version': twoCyclePolicy,
      };
      await model.refreshCycles();
      expect(model.draft.targetCycleKey, c);
      expect(model.validationMessage, isNotNull);
      await model.submit();
      expect(gateway.writes, isEmpty);
      await model.selectCycle(n);
      expect(model.draft.title, '유지');
      expect(model.validationMessage, null);
    },
  );
  test(
    'v2 approximate room match never releases unknown atomic command',
    () async {
      await model.activate();
      gateway.onWrite = (k, b) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.submit();
      await model.checkCurrentRooms();
      await model.confirmRecoveredRoom(v1.roomId);
      expect(model.hasPending, true);
      expect(model.createdRoomId, null);
    },
  );

  test('old C context cannot replace N after target switch', () async {
    await model.activate();
    await f1.settled(() => !model.contextLoading);
    final waiting = Completer<RecruitmentCreationContext>();
    final old = model.draft;
    gateway.onContext = (d) async => d.targetCycleKey == c
        ? waiting.future
        : RecruitmentCreationContext.fromCycleJson(creation(d), d);
    final read = model.refreshContext();
    await model.selectCycle(n);
    await f1.settled(() => model.selection?.targetKey == n);
    waiting.complete(
      RecruitmentCreationContext.fromCycleJson(creation(old), old),
    );
    await read;
    expect(model.selection?.targetKey, n);
  });
  test(
    'invalid target deep link requires explicit choice and sends no command',
    () async {
      await model.activate(target: '2026-11-04');
      expect(model.draft.targetCycleKey, '2026-11-04');
      expect(model.validationMessage, isNotNull);
      await model.submit();
      expect(gateway.writes, isEmpty);
    },
  );
  group('repository wire and target detail', () {
    late v1.Api api;
    late Dio dio;
    late BackendRecruitmentRepository repo;
    setUp(() {
      api = v1.Api();
      dio = Dio();
      repo = BackendRecruitmentRepository(
        api: api,
        accounts: ServerAccountReadRepository(ReadApiFake(), session),
        raids: MemberRaidClient(DioBackendAccountReadApi(dio, session)),
        twoCycleEnabled: true,
      );
    });
    tearDown(() => dio.close(force: true));
    test(
      'end button waits for global permission and discards old cycle result',
      () async {
        api.respond = (_, query) async =>
            detail(query!['target_cycle_key'] as String);
        gateway.onCycleDetail = (t) => repo.cycleDetail(v1.roomId, t);
        var allowed = false;
        Completer<bool>? gate;
        var permissionReads = 0;
        final state = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: v1.roomId,
          target: c,
          loadEndPermission: (_, target) async {
            permissionReads++;
            return target == c && gate != null ? gate.future : allowed;
          },
        );
        addTearDown(state.dispose);
        await state.load();
        expect(state.endAvailable, false);
        allowed = true;
        await state.load();
        expect(state.endAvailable, true);
        gate = Completer<bool>();
        final old = state.load();
        await f1.settled(() => permissionReads == 3);
        allowed = false;
        state.selectCycle(n);
        expect(state.endAvailable, false);
        gate.complete(true);
        await old;
        await f1.settled(() => !state.loading);
        expect(state.endAvailable, false);
        expect(state.target, n);
        expect(state.failure, null);
      },
    );
    test(
      'next participation shortcut requires opened next target and no existing participation',
      () async {
        var enabled = false;
        var nextRole = 'none';
        api.respond = (path, query) async {
          final t = query!['target_cycle_key'] as String;
          final value = detail(t);
          (value['data']['room'] as Map)['continuation_enabled'] = enabled;
          if (t == n) {
            (value['data']['room'] as Map)['my_target_role'] = nextRole;
            value['data']['my_target_role'] = nextRole;
          }
          return value;
        };
        gateway.onCycleDetail = (t) => repo.cycleDetail(v1.roomId, t);
        final state = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: v1.roomId,
          target: c,
        );
        addTearDown(state.dispose);
        await state.load();
        expect(state.nextParticipationAvailable, false);
        expect(
          api.requests.where(
            (r) => (r['query'] as Map?)?['target_cycle_key'] == n,
          ),
          isEmpty,
        );
        enabled = true;
        await state.load();
        expect(state.nextParticipationAvailable, true);
        nextRole = 'member';
        await state.load();
        expect(state.nextParticipationAvailable, false);
      },
    );
    test(
      'v2 context query, read no idempotency, create201 and bound scope',
      () async {
        final d = v1.draft().copy(targetCycleKey: c, continueTogether: true);
        api.respond = (p, q) async {
          if (p.endsWith('creation-context')) return envelope(c, creation(d));
          final request = api.requests.last;
          return envelope(
            c,
            ack(
              request['key'] as String,
              request['body'] as Map<String, dynamic>,
            ),
            created: true,
          );
        };
        final context = await repo.context(d);
        expect(api.requests.single['query']['target_cycle_key'], c);
        expect(api.requests.single['query']['continuation_enabled'], true);
        expect(api.requests.single['key'], null);
        await repo.create(characterId, d.body(context, '모집'));
        expect(api.requests.last['path'], '/v2/raid-rooms');
        expect(api.requests.last['status'], 201);
      },
    );
    test(
      'N-only repository accepts server target_only context and 201 ACK without C or third week',
      () async {
        // Backend 0eed67c4 cycle_creation.preflight / test_n_target_does_not_create_third_week:
        // unchecked future target uses target_only; target_is_next requires enabled=true.
        final d = v1.draft().copy(targetCycleKey: n, continueTogether: false);
        api.respond = (p, q) async {
          if (p.endsWith('creation-context')) {
            return envelope(
              n,
              creation(d)..['continuation_effect'] = 'target_only',
            );
          }
          final request = api.requests.last;
          return envelope(
            n,
            ack(
              request['key'] as String,
              request['body'] as Map<String, dynamic>,
            )..['continuation_effect'] = 'target_only',
            created: true,
          );
        };
        final context = await repo.context(d);
        expect(api.requests.single['query']['target_cycle_key'], n);
        expect(api.requests.single['query']['continuation_enabled'], false);
        expect(api.requests.single['key'], null);
        final result = await repo.create(
          characterId,
          d.body(context, '다음주 모집'),
        );
        expect(result.targetKey, n);
        expect(result.created!.map((row) => row['target_cycle_key']), [n]);
        expect(result.effect, 'target_only');
        expect(api.requests.last['body']['continuation'], {
          'enabled': false,
          'next_selection': null,
        });
      },
    );
    test(
      'detail isolates leadership/formation and rejects generation mixing',
      () async {
        api.respond = (p, q) async => detail(q!['target_cycle_key'] as String);
        final value = await repo.cycleDetail(v1.roomId, n);
        expect(value.targetKey, n);
        expect(value.members.single['room_role'], 'leader');
        expect(value.formation.single['target_cycle_key'], n);
        expect(
          api.requests.single['path'],
          '/v2/raid-rooms/${v1.roomId}/detail',
        );
        api.respond = (p, q) async {
          final j = detail(n);
          j['data']['room']['target_generation'] = 2;
          return j;
        };
        await expectLater(
          repo.cycleDetail(v1.roomId, n),
          throwsA(isA<AccountReadException>()),
        );
      },
    );
    test(
      'late old target detail cannot replace selected N; unopened N stays uncreated',
      () async {
        final waiting = Completer<BackendRecruitmentDetail>();
        gateway.onCycleDetail = (t) async {
          if (t == c) return waiting.future;
          throw const AccountReadException('TARGET_NOT_OPEN');
        };
        final m = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: v1.roomId,
          target: c,
        );
        final load = m.load();
        await f1.settled(() => m.cycles != null);
        m.selectCycle(n);
        await f1.settled(() => !m.loading);
        api.respond = (p, q) async => detail(c);
        waiting.complete(await repo.cycleDetail(v1.roomId, c));
        await load;
        expect(m.target, n);
        expect(m.value, null);
        expect(m.failure, 'TARGET_NOT_OPEN');
        expect(m.notOpen, {n});
        expect(gateway.writes, isEmpty);
        m.dispose();
      },
    );
  });
}
