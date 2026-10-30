import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_interaction_api.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_management.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/beta_schedule_draft.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/beta_schedule_editor.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_schedule_widgets.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_management_test.dart' as management;
import 'cycle_schedule_test.dart' as schedule;
import 'beta_foundation_test.dart' as foundation;
import 'session_display_fixtures.dart' as display;

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value));
final config = BetaScheduleEditor.config(
  cycles.n,
  const BetaScheduleInput(
    weekday: 6,
    minute: 1083,
    enabled: true,
    additional: 2,
  ),
);
Map<String, dynamic> openingWire(String action) {
  final raw = clone(management.managementWire(action));
  raw['data']['beta_schedule_config'] = clone(config);
  return raw;
}

Map<String, dynamic> betaPlan() {
  final raw = schedule.planWire();
  final view = foundation.schedule();
  final start = DateTime.parse(schedule.start(0));
  view.addAll({
    'session_id': schedule.id(10),
    'base_starts_at': start.toIso8601String(),
    'base_ends_at': start.add(const Duration(minutes: 20)).toIso8601String(),
    'base_deadline_at': start
        .subtract(const Duration(minutes: 30))
        .toIso8601String(),
    'effective_starts_at': start.toIso8601String(),
    'effective_ends_at': start
        .add(const Duration(minutes: 20))
        .toIso8601String(),
    'admission_deadline': start
        .subtract(const Duration(minutes: 30))
        .toIso8601String(),
  });
  raw['data']['beta_schedule'] = view;
  raw['data']['recruitment_identity'] = null;
  return raw;
}

void main() {
  test(
    'beta proposal preserves explicit minute, rejects seconds and legacy stays five-minute',
    () async {
      final api = base.Api()..respond = (_, _) async => betaPlan();
      final plan = await CycleScheduleReader(
        BetaInteractionApi(api),
      ).read(base.roomId, cycles.n, 'plan');
      final input = schedule.targets();
      input[0]['starts_at'] = DateTime.parse(
        input[0]['starts_at'],
      ).add(const Duration(minutes: 3)).toIso8601String();
      final preview = CycleSchedulePreview(plan, 'propose');
      expect(
        preview.body({'targets': input})['targets'][0]['starts_at'],
        input[0]['starts_at'],
      );
      final legacy = CycleScheduleView(
        base.roomId,
        cycles.n,
        'plan',
        schedule.planWire(),
      );
      expect(
        () => CycleSchedulePreview(legacy, 'propose').body({'targets': input}),
        throwsFormatException,
      );
      input[0]['starts_at'] = DateTime.parse(
        input[0]['starts_at'],
      ).add(const Duration(seconds: 1)).toIso8601String();
      expect(() => preview.body({'targets': input}), throwsFormatException);
      expect(
        () => BetaScheduleConfig({
          ...config,
          'base_starts_at': input[0]['starts_at'],
        }),
        throwsFormatException,
      );
    },
  );
  for (final action in ['open', 'reopen']) {
    test('$action binds explicit N config to context and command', () async {
      final api = base.Api()..respond = (_, q) async => openingWire(action);
      final preview = await CycleManagementReader(
        BetaInteractionApi(api),
      ).preview(base.roomId, cycles.n, action, query: config);
      final body = preview.body({'beta_schedule': config});
      expect(body['beta_schedule'], config);
      expect(body['target_cycle_key'], cycles.n);
      expect(body['target_session_ids'], isEmpty);
      expect(body.containsKey('next_base_starts_at'), isFalse);
      expect(
        api.requests.single['query']['contract_profile'],
        BetaContract.profile,
      );
      expect(preview.betaData!['beta_schedule_config'], config);
      expect(
        () => preview.body({
          'beta_schedule': {...config, 'early_additional_members': 3},
        }),
        throwsFormatException,
      );
      expect(() => preview.body({}), throwsFormatException);
      final changed = openingWire(action);
      changed['data']['beta_schedule_config']['early_additional_members'] = 3;
      api.respond = (_, q) async => changed;
      final fresh = await CycleManagementReader(
        BetaInteractionApi(api),
      ).preview(base.roomId, cycles.n, action, query: config);
      expect(fresh.signature, isNot(preview.signature));
    });
  }
  test('opening context without date cannot issue HTTP', () async {
    final api = base.Api();
    await expectLater(
      CycleManagementReader(
        BetaInteractionApi(api),
      ).preview(base.roomId, cycles.n, 'open'),
      throwsFormatException,
    );
    expect(api.requests, isEmpty);
  });
  test(
    'beta plan metadata is immutable and affects fresh comparison',
    () async {
      final api = base.Api()..respond = (_, q) async => betaPlan();
      final plan = await CycleScheduleReader(
        BetaInteractionApi(api),
      ).read(base.roomId, cycles.n, 'plan');
      expect(plan.betaData!['beta_schedule'], isNotNull);
      expect(
        () => plan.betaData!['beta_schedule']['revision'] = 2,
        throwsUnsupportedError,
      );
      final other = betaPlan();
      other['data']['beta_schedule']['revision'] = 2;
      api.respond = (_, q) async => other;
      final fresh = await CycleScheduleReader(
        BetaInteractionApi(api),
      ).read(base.roomId, cycles.n, 'plan');
      expect(
        CycleSchedulePreview(plan, 'groups').signature,
        isNot(CycleSchedulePreview(fresh, 'groups').signature),
      );
    },
  );
  test(
    'coordination sends only beta settings and requires immediate consent',
    () async {
      final api = base.Api()..respond = (_, q) async => betaPlan();
      final plan = await CycleScheduleReader(
        BetaInteractionApi(api),
      ).read(base.roomId, cycles.n, 'plan');
      final p = CycleSchedulePreview(plan, 'groups');
      final input = {
        'early_coordination_enabled': true,
        'early_additional_members': 7,
        'accept_immediate_confirmation': true,
      };
      final body = p.body(input);
      expect(body['early_additional_members'], 7);
      expect(body.containsKey('groups'), isFalse);
      expect(body.containsKey('base_starts_at'), isFalse);
      expect(
        () => p.body({...input, 'early_additional_members': 8}),
        throwsFormatException,
      );
      expect(
        () => p.body({...input, 'accept_immediate_confirmation': false}),
        throwsException,
      );
      expect(
        p.body({
          ...input,
          'early_coordination_enabled': false,
          'early_additional_members': null,
          'accept_immediate_confirmation': false,
        })['early_additional_members'],
        isNull,
      );
    },
  );
  test('already-open N still rejects changed metadata before POST', () async {
    final api = base.Api();
    var reads = 0;
    api.respond = (_, q) async {
      final raw = openingWire('open');
      raw['scope'] = cycles.envelope(cycles.n, {}, created: true)['scope'];
      raw['data']['opening_effect'] = 'already_open';
      raw['data']['session_display'] = display.displayWire(
        raw['scope'],
        kind: 'none',
      );
      if (reads++ > 0) {
        raw['data']['beta_schedule_config']['early_additional_members'] = 3;
      }
      return raw;
    };
    final repo = CycleInteractionRepository(
      api: api,
      recruitment: cycles.CycleGateway(),
      contractMode: RecruitmentContractMode.betaWire2,
    );
    final session = ReadSessionFake(), changes = ChangeNotifier();
    final c = CycleParticipationController(
      gateway: repo,
      session: session,
      changes: changes,
      scopeKey: () => 'fixed',
    );
    final preview = await c.management(
      base.roomId,
      cycles.n,
      'open',
      query: config,
    );
    expect(preview, isNotNull);
    await c.manage(preview!, {'beta_schedule': config});
    expect(c.failure, 'REVISION_CONFLICT');
    expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
    c.dispose();
    changes.dispose();
    session.dispose();
  });
  test(
    'opening ACK refreshes only N and unknown result retries original config',
    () async {
      final api = base.Api();
      var fail = true;
      api.respond = (path, q) async {
        if (path.endsWith('opening-context')) return openingWire('open');
        if (fail) throw const AccountReadException('NETWORK_UNAVAILABLE');
        final request = api.requests.last;
        final ack = cycles.envelope(cycles.n, {
          'command_id': request['key'],
          'outcome': 'applied',
          'executed_at': cycles.nowStamp,
          'room_id': base.roomId,
          'target_cycle_key': cycles.n,
          'revisions': [
            {'resource': 'room', 'id': base.roomId, 'revision': 2},
          ],
        }, created: true);
        ack['scope']['target_generation'] = 2;
        return ack;
      };
      final session = ReadSessionFake(),
          changes = ChangeNotifier(),
          refreshed = <String>[];
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      final c = CycleParticipationController(
        gateway: repo,
        session: session,
        changes: changes,
        scopeKey: () => 'fixed',
        onMutation: (t) async {
          refreshed.add(t);
        },
      );
      final p = (await c.management(
        base.roomId,
        cycles.n,
        'open',
        query: config,
      ))!;
      await c.manage(p, {'beta_schedule': config});
      expect(c.hasPending, isTrue);
      final original = api.requests.last;
      fail = false;
      await c.retry();
      expect(c.hasPending, isFalse);
      expect(refreshed, [cycles.n]);
      expect(api.requests.last['body'], original['body']);
      expect(api.requests.last['query'], original['query']);
      expect(api.requests.last['key'], original['key']);
      c.dispose();
      changes.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'beta coordination dialog replaces multi-day controls and cancel sends no PUT',
    (tester) async {
      final api = base.Api()..respond = (_, q) async => betaPlan();
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      final c = CycleParticipationController(
        gateway: repo,
        session: session,
        changes: changes,
        scopeKey: () => 'fixed',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showCycleScheduleCommand(
                  context,
                  c,
                  room: base.roomId,
                  target: cycles.n,
                  action: 'groups',
                ),
                child: const Text('설정 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('설정 열기'));
      await tester.pumpAndSettle();
      expect(find.text('출발 상한'), findsNothing);
      expect(find.text('더 일찍 출발할 수 있으면 자동으로 조율'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '확인'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
      c.dispose();
      changes.dispose();
      session.dispose();
    },
  );

  test(
    'local date policy excludes missing input, invalid counts and time windows',
    () {
      final now = DateTime.parse(cycles.nowStamp);
      expect(
        BetaScheduleEditor.valid(
          cycles.n,
          now,
          20,
          4,
          const BetaScheduleInput(),
        ),
        isFalse,
      );
      expect(
        BetaScheduleEditor.valid(
          cycles.n,
          now,
          20,
          4,
          const BetaScheduleInput(
            weekday: 6,
            minute: 1080,
            enabled: true,
            additional: 3,
          ),
        ),
        isTrue,
      );
      expect(
        BetaScheduleEditor.valid(
          cycles.n,
          now,
          20,
          4,
          const BetaScheduleInput(
            weekday: 6,
            minute: 1080,
            enabled: true,
            additional: 4,
          ),
        ),
        isFalse,
      );
      expect(
        BetaScheduleEditor.valid(
          cycles.n,
          now,
          20,
          8,
          const BetaScheduleInput(weekday: 3, minute: 540),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'opening editor starts empty and provides one selected day, no reset',
    (tester) async {
      var input = const BetaScheduleInput();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BetaScheduleEditor(
                target: cycles.n,
                now: DateTime.parse(cycles.nowStamp),
                duration: 20,
                capacity: 4,
                value: input,
                onChanged: (v) => setState(() => input = v),
              ),
            ),
          ),
        ),
      );
      expect(find.text('출발 시각 선택'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      final chips = find.byType(ChoiceChip);
      await tester.tap(chips.at(1));
      await tester.pump();
      await tester.tap(chips.at(2));
      await tester.pump();
      expect(
        tester.widgetList<ChoiceChip>(chips).where((c) => c.selected),
        hasLength(1),
      );
      expect(input.minute, isNull);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(find.text('공대장 외 추가 참가 인원'), findsOneWidget);
      expect(find.text('미정'), findsNothing);
    },
  );
}
