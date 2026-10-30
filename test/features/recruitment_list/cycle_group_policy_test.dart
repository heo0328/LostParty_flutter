import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/beta/cycle_group_policy.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_creation_gateway.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_management.dart';
import 'package:lost_party/features/recruitment_list/data/membership_actions.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_management_widgets.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_management_test.dart' as management;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_interaction_test.dart' as search;
import 'membership_actions_test.dart' as membership;
import 'beta_creation_test.dart' as creation;
import 'beta_schedule_management_test.dart' as schedule;
import 'package:lost_party/features/recruitment_list/data/beta/beta_interaction_api.dart';

const groupA = '10000000-0000-4000-8000-000000000001';
const groupB = '10000000-0000-4000-8000-000000000002';
Map<String, dynamic> copy(Object? v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
Map<String, dynamic> policy({
  String target = cycles.c,
  String? group = groupA,
  int generation = 1,
}) => {
  'room_id': base.roomId,
  'target_cycle_key': target,
  'room_cycle_id': target == cycles.c ? cycles.cycleId : cycles.nextCycleId,
  'generation': generation,
  'scope': group == null ? 'public' : 'group',
  'group_id': group,
  'revision': 5,
  'state': 'known',
};
Map<String, dynamic> effect(
  Map<String, dynamic> before,
  String? after, {
  bool ack = false,
}) => {
  for (final k in [
    'room_id',
    'target_cycle_key',
    'room_cycle_id',
    'generation',
  ])
    k: before[k],
  'before': {
    for (final k in ['scope', 'group_id', 'revision']) k: before[k],
  },
  'after': {
    'scope': after == null ? 'public' : 'group',
    'group_id': after,
    if (ack)
      'revision': before['group_id'] == after
          ? before['revision']
          : (before['revision'] as int) + 1,
  },
};
Map<String, dynamic> settings(Map<String, dynamic> p) {
  final r = management.managementWire(
    'settings',
    target: p['target_cycle_key'],
  );
  r['data']['scope'] = p['scope'];
  r['data']['group_id'] = p['group_id'];
  return {
    ...r,
    'group_policy_version': BetaContract.groupPolicyVersion,
    'group_policy': p,
  };
}

Map<String, dynamic> review(Map<String, dynamic> p, String? after) => {
  'scope': settings(p)['scope'],
  'data': {
    'room_id': base.roomId,
    'context_token': 'group-review-token',
    'issued_at': cycles.nowStamp,
    'expires_at': '2026-10-22T03:02:00Z',
    'permission': {'allowed': true, 'reason': null, 'next_change_at': null},
  },
  'group_policy_version': BetaContract.groupPolicyVersion,
  'group_policy': p,
  'group_policy_effect': effect(p, after),
};
Map<String, dynamic> input(CycleManagementPreview p) => {
  'experience_level': p.data['experience_level'],
  'combat_requirement': p.data['combat_requirement'],
  'admission_mode': p.data['admission_mode'],
};

class GroupChoices extends cycles.CycleGateway {
  @override
  Future<List<RecruitmentGroupChoice>> groups() async => const [
    RecruitmentGroupChoice(groupA, 'A그룹'),
    RecruitmentGroupChoice(groupB, 'B그룹'),
  ];
}

void main() {
  testWidgets(
    'group review keeps edited combat draft and cancel sends no write',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = base.Api();
      final current = policy();
      api.respond = (path, _) async => path.endsWith('command-context')
          ? review(current, groupB)
          : settings(current);
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final controller = CycleParticipationController(
        gateway: CycleInteractionRepository(
          api: api,
          recruitment: GroupChoices(),
          contractMode: RecruitmentContractMode.betaWire2,
        ),
        session: session,
        changes: changes,
        scopeKey: () => '${session.userId}/${session.generation}',
        now: () => DateTime.parse(cycles.nowStamp),
        onMutation: (_) async {},
      );
      addTearDown(() {
        controller.dispose();
        session.dispose();
        changes.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCycleManagement(
                  context,
                  controller,
                  room: base.roomId,
                  target: cycles.c,
                  action: 'settings',
                ),
                child: const Text('편집'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      final dealer = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '딜러 최소 전투력',
      );
      await tester.enterText(dealer, '123');
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == '공개범위 · 연결 그룹',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('B그룹').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(dealer).controller!.text, '123');
      expect(
        api.requests.where(
          (r) => r['path'].toString().endsWith('command-context'),
        ),
        hasLength(1),
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r['method'] != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test('new public creation cannot retain a selected group', () async {
    final draft = creation.draft().copy(groupId: groupA, groupOnly: false);
    final api = base.Api();
    await expectLater(
      BetaCreationReader(api).context(draft),
      throwsFormatException,
    );
    expect(api.requests, isEmpty);
  });

  test(
    'transfer retains only selected candidate effect among eight participants',
    () async {
      final raw = management.managementWire('transfer');
      final current = policy(target: cycles.n);
      final candidates = raw['data']['candidates'] as List;
      for (var i = 0; i < candidates.length; i++) {
        candidates[i]['group_policy_effect'] = effect(
          current,
          i == 0 ? groupA : null,
        );
      }
      raw['group_policy_version'] = BetaContract.groupPolicyVersion;
      raw['group_policy'] = current;
      final api = base.Api()..respond = (_, _) async => raw;
      final preview = await CycleManagementReader(
        BetaInteractionApi(api),
      ).preview(base.roomId, cycles.n, 'transfer');
      expect(
        preview
            .effectsFor(candidates.first['cycle_member_id'])
            .single['after']['group_id'],
        groupA,
      );
      expect(
        preview
            .effectsFor(candidates.last['cycle_member_id'])
            .single['after']['scope'],
        'public',
      );
      expect(preview.effectsFor('missing'), isEmpty);
    },
  );

  test(
    'opening preserves server inheritance or public fallback and prospective generation',
    () async {
      for (final selected in [groupA, null]) {
        final raw = schedule.openingWire('open');
        final current = policy(target: cycles.n, generation: 2);
        raw['data']['group_policy_effect'] = effect(current, selected);
        raw['group_policy_version'] = BetaContract.groupPolicyVersion;
        final api = base.Api()..respond = (_, _) async => raw;
        final preview = await CycleManagementReader(
          BetaInteractionApi(api),
        ).preview(base.roomId, cycles.n, 'open', query: schedule.config);
        expect(preview.effectsFor().single['generation'], 2);
        expect(preview.effectsFor().single['after']['group_id'], selected);
        expect(
          preview.body({'beta_schedule': schedule.config})['target_cycle_key'],
          cycles.n,
        );
        expect(preview.groupPolicy, isNull);
      }
    },
  );
  test(
    'policy identity binds actual target/generation and never fabricates unknown',
    () {
      final p = CycleGroupPolicy(policy());
      p.bind(base.roomId, cycles.c, {
        'room_cycle_id': cycles.cycleId,
        'target_generation': 1,
      });
      expect(() => p.bind(base.roomId, cycles.n), throwsFormatException);
      expect(
        () => p.bind(base.roomId, cycles.c, {'target_generation': 2}),
        throwsFormatException,
      );
      expect(
        () => CycleGroupPolicy({...policy(), 'scope': 'public'}),
        throwsFormatException,
      );
      expect(
        () => CycleGroupPolicy({...policy(), 'revision': 0}),
        throwsFormatException,
      );
      final unknown = {
        ...policy(),
        'state': 'unavailable',
        'scope': null,
        'group_id': null,
        'revision': null,
      };
      expect(CycleGroupPolicy(unknown).known, false);
      expect(retainedGroupLabel({'group_policy': unknown}), contains('확인 불가'));
      expect(
        () => CycleGroupPolicy({...unknown, 'group_id': groupA}),
        throwsFormatException,
      );
    },
  );

  test('root read policy must match response target and generation', () {
    for (final field in ['target_cycle_key', 'generation', 'room_id']) {
      final raw = settings(policy());
      raw['group_policy'][field] = field == 'generation'
          ? 2
          : field == 'target_cycle_key'
          ? cycles.n
          : groupB;
      expect(
        () => BetaResponse.parse(
          method: 'GET',
          path: '/v2/me/raid-rooms/${base.roomId}/settings',
          status: 200,
          json: raw,
          parseLegacy: (value) => value,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'new operation policy query is explicit, original requests and unrelated APIs unchanged',
    () {
      const current = BetaContract(mode: RecruitmentContractMode.betaWire2);
      const original = BetaContract(
        mode: RecruitmentContractMode.betaWire2,
        original: true,
      );
      expect(
        current.query(
          'PUT',
          '/v2/raid-rooms/${base.roomId}/settings',
        )['group_policy_version'],
        BetaContract.groupPolicyVersion,
      );
      expect(
        original
            .query('PUT', '/v2/raid-rooms/${base.roomId}/settings')
            .containsKey('group_policy_version'),
        false,
      );
      expect(
        current.query('GET', '/v2/me/application-message-presets'),
        isEmpty,
      );
      expect(
        () => current.query('GET', '/v2/me/application-message-presets', {
          'group_policy_version': BetaContract.groupPolicyVersion,
        }),
        throwsFormatException,
      );
      expect(
        () => current.query('PUT', '/v2/raid-rooms/${base.roomId}/settings', {
          'group_policy_version': 'wrong',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'same room C/N and historical generation retain independent directory entries',
    () {
      final raw = search.searchWire(cycles.c);
      final card = raw['data']['items'][0] as Map<String, dynamic>;
      final next = {
        ...card,
        'target_cycle_key': cycles.n,
        'room_cycle_id': cycles.nextCycleId,
        'group_id': groupB,
        'scope': 'group',
      };
      final past = {
        ...card,
        'target_generation': 2,
        'group_id': null,
        'scope': 'public',
      };
      card['group_id'] = groupA;
      card['scope'] = 'group';
      raw['data']['items'] = [card, next, past];
      raw['group_states'] = [
        for (final id in [groupA, groupB])
          {
            'group_id': id,
            'name': id == groupA ? 'A그룹' : 'B그룹',
            'state': 'active',
          },
      ];
      raw['cycle_groups'] = [
        policy(),
        policy(target: cycles.n, group: groupB),
        policy(group: null, generation: 2),
      ];
      final directory = groupListStates(raw);
      final meta = {'room_group_states': directory};
      expect(
        retainedGroupLabel(listDisplayData(meta, card, base.roomId)),
        'A그룹',
      );
      expect(
        retainedGroupLabel(listDisplayData(meta, next, base.roomId)),
        'B그룹',
      );
      expect(
        retainedGroupLabel(listDisplayData(meta, past, base.roomId)),
        isNull,
      );
      (raw['cycle_groups'] as List).removeLast();
      expect(() => groupListStates(raw), throwsFormatException);
    },
  );

  for (final change in [(null, groupA), (groupA, groupB), (groupA, null)]) {
    test(
      'target settings ${change.$1} to ${change.$2} sends one atomic write and preserves other settings',
      () async {
        final api = base.Api();
        final p = policy(target: cycles.n, group: change.$1);
        final repo = CycleInteractionRepository(
          api: api,
          recruitment: cycles.CycleGateway(),
          contractMode: RecruitmentContractMode.betaWire2,
        );
        final session = ReadSessionFake(), changes = ChangeNotifier();
        final refreshed = <String>[];
        var groupRefreshes = 0;
        final controller = CycleParticipationController(
          gateway: repo,
          session: session,
          changes: changes,
          now: () => DateTime.parse(cycles.nowStamp),
          scopeKey: () => '${session.userId}/${session.generation}',
          onMutation: (t) async {
            refreshed.add(t);
          },
          onGroupConnectionChanged: () => groupRefreshes++,
        );
        addTearDown(() {
          controller.dispose();
          changes.dispose();
          session.dispose();
        });
        api.respond = (path, query) async {
          final request = api.requests.last;
          if (request['method'] == 'GET') {
            return path.endsWith('/command-context')
                ? review(p, change.$2)
                : settings(p);
          }
          return {
            ...cycles.envelope(cycles.n, {
              'command_id': request['key'],
              'outcome': 'applied',
              'executed_at': cycles.nowStamp,
              'room_id': base.roomId,
              'target_cycle_key': cycles.n,
              'revisions': [
                {'resource': 'target', 'id': cycles.nextCycleId, 'revision': 2},
              ],
            }, created: true),
            'group_policy_version': BetaContract.groupPolicyVersion,
            'group_policy_effects': [effect(p, change.$2, ack: true)],
          };
        };
        final preview = await repo.management(
          base.roomId,
          cycles.n,
          'settings',
          query: {
            'review_group_policy': true,
            if (change.$2 != null) 'target_group_id': change.$2,
          },
        );
        final body = preview.body(input(preview));
        expect(body['group_policy'], {
          'scope': change.$2 == null ? 'public' : 'group',
          'group_id': change.$2,
          'expected_revision': 5,
        });
        expect(body['combat_requirement'], preview.data['combat_requirement']);
        expect(body['target_cycle_key'], cycles.n);
        expect(body.containsKey('title'), false);
        expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
        await controller.manage(preview, input(preview));
        expect(controller.failure, isNull);
        expect(api.requests.where((r) => r['method'] == 'PUT'), hasLength(1));
        expect(refreshed, [cycles.n]);
        expect(groupRefreshes, 1);
        expect(
          api.requests.last['query']['group_policy_version'],
          BetaContract.groupPolicyVersion,
        );
      },
    );
  }

  test(
    'ordinary settings omit policy and group-review reads, common settings are title-only',
    () async {
      final api = base.Api()..respond = (_, _) async => settings(policy());
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      final p = await repo.management(base.roomId, cycles.c, 'settings');
      expect(p.body(input(p)).containsKey('group_policy'), false);
      expect(api.requests, hasLength(1));
      final common = management.managementWire('common');
      common['data']['current_settings'] = {'title': '기존 제목'};
      common['group_policy_version'] = BetaContract.groupPolicyVersion;
      api.respond = (_, _) async => common;
      final title = await repo.management(base.roomId, cycles.c, 'common');
      expect(
        title.body({'title': '새 제목'}).keys,
        unorderedEquals([
          'expected_cycle_key',
          'expected_room_revision',
          'context_token',
          'title',
        ]),
      );
    },
  );

  test(
    'stale group policy/review, denial and changed impact prohibit writes',
    () async {
      final api = base.Api();
      var p = policy();
      var context = review(p, groupB);
      api.respond = (path, _) async =>
          path.endsWith('command-context') ? copy(context) : settings(p);
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      Future<CycleManagementPreview> read() => repo.management(
        base.roomId,
        cycles.c,
        'settings',
        query: {'review_group_policy': true, 'target_group_id': groupB},
      );
      final before = await read();
      context['data']['permission'] = {
        'allowed': false,
        'reason': 'GROUP_MEMBERSHIP_REQUIRED',
        'next_change_at': null,
      };
      final denied = await read();
      expect(denied.signature, isNot(before.signature));
      expect(
        () => denied.body(input(denied)),
        throwsA(isA<AccountReadException>()),
      );
      context = review(p, groupB)
        ..['group_policy_effect']['before']['revision'] = 4;
      final stale = await read();
      expect(() => stale.body(input(stale)), throwsFormatException);
      context = review(p, groupB)..['data']['expires_at'] = cycles.nowStamp;
      final expired = await read();
      expect(() => expired.body(input(expired)), throwsFormatException);
      expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
    },
  );

  test(
    'eight-member departure effect is selected-option evidence, not client-calculated succession',
    () {
      final raw = membership.fixture('eight-members-two-targets-context');
      final option = raw['data']['options']['leave_all'];
      final enriched = copy(raw);
      final targets =
          enriched['data']['options']['leave_all']['impact']['targets'] as List;
      for (final t in targets) {
        final source = {
          ...policy(target: t['target_cycle_key']),
          'room_id': raw['data']['room_id'],
          'room_cycle_id': t['room_cycle_id'],
          'generation': t['generation'] ?? t['target_generation'],
        };
        t['group_policy_effect'] = effect(
          source,
          t == targets.first ? groupA : null,
        );
      }
      final ctx = MembershipActionContext(
        raw['data']['room_id'],
        raw['scope']['view_cycle_key'],
        raw,
        groupPolicyData: enriched,
      );
      final preview = ctx.select('leave_all');
      expect(preview.groupEffects, hasLength(2));
      expect(preview.impact, option['impact']);
      expect(
        CycleGroupEffect(preview.groupEffects.last).description,
        contains('연결 해제'),
      );
      final changed = copy(enriched);
      changed['data']['options']['leave_all']['impact']['targets'][0]['group_policy_effect']['after'] =
          {'scope': 'public', 'group_id': null};
      final other = MembershipActionContext(
        ctx.room,
        ctx.view,
        raw,
        groupPolicyData: changed,
      ).select('leave_all');
      expect(other.signature, isNot(preview.signature));
    },
  );

  test(
    'ACK policy effects cannot change the confirmed target, group, or generation',
    () {
      final before = policy();
      final expected = CycleGroupEffect(effect(before, null));
      final ack = effect(before, null, ack: true);
      expected.validateAck(ack);
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (x) => x['generation'] = 2,
        (x) => x['target_cycle_key'] = cycles.n,
        (x) =>
            x['after'] = {'scope': 'group', 'group_id': groupB, 'revision': 6},
        (x) => x['after']['revision'] = 0,
      ]) {
        final bad = copy(ack);
        mutate(bad);
        expect(() => expected.validateAck(bad), throwsFormatException);
      }
    },
  );

  test(
    'original pending creation recovers its old ACK without query/body/key conversion',
    () async {
      final d = creation.draft();
      final context = await creation.Gateway().context(d);
      final prepared = BetaCreationReader.prepare(
        d,
        context,
        '복구',
        membership.key,
        DateTime.parse(cycles.nowStamp),
      );
      final original = RecruitmentCommand.decode(
        jsonEncode({
          ...prepared.toJson(),
          'raw_query': jsonEncode({'contract_profile': BetaContract.profile}),
        }),
      );
      final db = RecruitmentCommandDatabase(NativeDatabase.memory());
      final session = ReadSessionFake()..userId = base.membershipId;
      final writes = <RecruitmentCommand>[];
      final t = RecruitmentCommandTransport(
        store: DriftRecruitmentCommandStore(databaseFactory: () => db),
        session: session,
        baseUrl: () => 'https://example.test',
        mode: RecruitmentContractMode.betaWire2,
        clock: () => DateTime.parse(cycles.nowStamp),
        send: (cmd, _) async {
          writes.add(cmd);
          if (writes.length == 1) {
            throw const AccountReadException('NETWORK_UNAVAILABLE');
          }
          return cycles.envelope(
            d.targetCycleKey!,
            cycles.ack(cmd.key, jsonDecode(cmd.rawBody)),
            created: true,
          );
        },
      );
      addTearDown(() async {
        await t.dispose();
        await db.close();
        session.dispose();
      });
      void validate(Map<String, dynamic> raw) {
        validateBetaCreationAck(original, raw);
      }

      await expectLater(
        t.submit(original, validateAck: validate),
        throwsA(isA<AccountReadException>()),
      );
      final saved = await t.restore(RecruitmentCommandOwner.creation);
      expect(saved!.usesCycleGroupPolicy, false);
      final ack = await t.submit(saved, validateAck: validate);
      expect(ack.containsKey('group_policy_version'), false);
      expect(writes, hasLength(2));
      expect(writes[0].rawQuery, original.rawQuery);
      expect(writes[1].rawQuery, original.rawQuery);
      expect(writes[1].rawBody, original.rawBody);
      expect(writes[1].key, original.key);
      await t.submit(saved, validateAck: validate);
      expect(writes, hasLength(2));
    },
  );

  test(
    'member transition during second group-review read drops late result and cannot write',
    () async {
      final api = base.Api();
      final gate = Completer<Map<String, dynamic>>();
      final current = policy();
      api.respond = (path, _) async =>
          path.endsWith('command-context') ? gate.future : settings(current);
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final controller = CycleParticipationController(
        gateway: CycleInteractionRepository(
          api: api,
          recruitment: cycles.CycleGateway(),
          contractMode: RecruitmentContractMode.betaWire2,
        ),
        session: session,
        changes: changes,
        scopeKey: () => '${session.userId}/${session.generation}',
        now: () => DateTime.parse(cycles.nowStamp),
        onMutation: (_) async {},
      );
      addTearDown(() {
        controller.dispose();
        changes.dispose();
        session.dispose();
      });
      final pending = controller.management(
        base.roomId,
        cycles.c,
        'settings',
        query: {'review_group_policy': true, 'target_group_id': groupB},
      );
      for (var i = 0; i < 100 && api.requests.length < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(api.requests, hasLength(2));
      session.generation++;
      session.notifyListeners();
      gate.complete(review(current, groupB));
      expect(await pending, isNull);
      expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
    },
  );
}
