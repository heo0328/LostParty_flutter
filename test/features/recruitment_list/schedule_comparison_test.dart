import 'dart:async';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/account/domain/play_availability.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_interaction_api.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/data/schedule_notice_store.dart';
import 'package:lost_party/features/recruitment_list/domain/schedule_comparison.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/schedule_comparison_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_schedule_widgets.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/schedule_timeline.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as member;
import '../account/backend_read/play_availability_test.dart' as personal;
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/schedule_command_page.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_schedule_test.dart' as old;
import 'beta_schedule_management_test.dart' as beta;

List<(int, int)> spans(List<TimeSpan>? value) =>
    value!.map((s) => (s.start, s.end)).toList();
ScheduleMemberRow row(
  String id, {
  TimetableState state = TimetableState.configured,
  List<PlayTimeRow> times = const [],
  List<(DateTime, DateTime)> busy = const [],
  bool busyAvailable = true,
}) => ScheduleMemberRow(
  id: id,
  name: '공대원 $id',
  state: state,
  intervals: times,
  busy: busy,
  busyAvailable: busyAvailable,
);

Map<String, dynamic> contextWire() => old.copy(
  cycles.envelope(cycles.n, {
    'room_id': base.roomId,
    'beta_schedule': beta.betaPlan()['data']['beta_schedule'],
    'members_revision': 4,
    'plan_revision': 5,
    'evaluated_at': cycles.nowStamp,
    'members': [
      for (var i = 0; i < 8; i++)
        {
          'membership_id': i == 0 ? base.membershipId : old.id(40 + i),
          'cycle_member_id': i == 0 ? base.membershipId : old.id(40 + i),
          'display': {'character_name': '공대원$i'},
          'submission': {
            ...old.submissionWire()['data'],
            'membership_id': i == 0 ? base.membershipId : old.id(40 + i),
            'cycle_member_id': i == 0 ? base.membershipId : old.id(40 + i),
            'state': 'ready',
            'revision': 2,
            'source_personal_version': 1,
            'submitted_at': cycles.nowStamp,
            'intervals': [
              {
                'weekday': 3,
                'start': '18:00',
                'end': '23:00',
                'end_day_offset': 0,
              },
            ],
            'normalized_intervals': <Map<String, dynamic>>[],
            'availability_copy': {
              'state': 'configured',
              'source_personal_version': 1,
              'copied_at': cycles.nowStamp,
            },
          },
          'anonymous_busy': {
            'state': 'ready',
            'revision': 1,
            'intervals': <Map<String, dynamic>>[],
          },
        },
    ],
    'target_session_id': null,
    'permissions': {'view_schedule_context': member.permit()},
    'target_cycle_key': cycles.n,
  }, created: true),
);

void main() {
  test('beta context reader preserves per-member copy metadata', () async {
    final api = base.Api()..respond = (_, q) async => contextWire();
    final view = await CycleScheduleReader(
      BetaInteractionApi(api),
    ).read(base.roomId, cycles.n, 'context');
    expect(view.betaData!['availability_copies'], hasLength(8));
  });
  test('midnight and week wrap preserve only registered intervals', () {
    final member = row(
      'a',
      times: const [
        PlayTimeRow(weekday: 2, start: 1380, end: 60, endDayOffset: 1),
      ],
    );
    expect(spans(member.availableOn(2)), [(1380, 1440)]);
    expect(spans(member.availableOn(3)), [(0, 60)]);
    expect(member.availableOn(4), isEmpty);
    expect(member.availableFor(2, 1410, 90), isTrue);
    expect(member.availableFor(2, 1410, 120), isFalse);
  });
  test('unset differs from unavailable and partial days', () {
    final comparison = ScheduleComparison(cycles.n, [
      row('a', state: TimetableState.unset),
      row('b', times: const [PlayTimeRow(weekday: 4, start: 1200, end: 1320)]),
      row('c', state: TimetableState.unavailable),
    ]);
    expect(spans(comparison.common(4, {'a', 'b'})), [(1200, 1320)]);
    expect(comparison.common(3, {'b'}), isEmpty);
    expect(comparison.common(4, {'c'}), isNull);
    expect(comparison.common(4, {}), isEmpty);
  });
  test(
    'anonymous busy clips at midnight and common time subtracts reservations',
    () {
      final comparison = ScheduleComparison(cycles.n, [
        row(
          'a',
          state: TimetableState.unset,
          busy: [
            (
              DateTime.parse('${cycles.n}T14:00:00Z'),
              DateTime.parse('${cycles.n}T16:00:00Z'),
            ),
          ],
        ),
      ]);
      expect(spans(comparison.common(3, {'a'})), [(0, 1380)]);
      expect(spans(comparison.common(4, {'a'})), [(60, 1440)]);
      expect(
        ScheduleComparison(cycles.n, [
          row('x', state: TimetableState.unset, busyAvailable: false),
        ]).common(3, {'x'}),
        isNull,
      );
    },
  );
  test('merge/intersection/subtraction keep disjoint segments exact', () {
    expect(
      spans(
        mergeSpans(const [TimeSpan(10, 20), TimeSpan(0, 10), TimeSpan(25, 30)]),
      ),
      [(0, 20), (25, 30)],
    );
    expect(
      spans(
        subtractSpans(
          const [TimeSpan(0, 60)],
          const [TimeSpan(10, 20), TimeSpan(30, 45)],
        ),
      ),
      [(0, 10), (20, 30), (45, 60)],
    );
    expect(
      spans(
        intersectSpans(
          const [TimeSpan(0, 60)],
          const [TimeSpan(5, 10), TimeSpan(55, 70)],
        ),
      ),
      [(5, 10), (55, 60)],
    );
  });
  test(
    'daily preference uses member/environment and KST, across process store instances',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = ScheduleNoticeStore(),
          today = DateTime.parse('2026-10-25T14:59:00Z');
      expect(await store.shouldShow('env/user-one', today), isTrue);
      expect(await store.shouldShow('env/user-one', today), isTrue);
      await store.acknowledge('env/user-one', today, hide: true);
      expect(
        await store.storage.read(key: store.key('env/user-one')),
        ScheduleNoticeStore.day(today),
      );
      expect(
        await ScheduleNoticeStore().shouldShow('env/user-one', today),
        isFalse,
      );
      expect(await store.shouldShow('env/user-two', today), isTrue);
      expect(await store.shouldShow('other-env/user-one', today), isTrue);
      expect(
        await store.shouldShow(
          'env/user-one',
          DateTime.parse('2026-10-25T15:00:00Z'),
        ),
        isTrue,
      );
    },
  );

  group('real beta repository and screen-owned snapshot', () {
    late base.Api api;
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late CycleParticipationController controller;
    late ScheduleComparisonViewModel model;
    String binding = 'env/member/1';
    setUp(() {
      api = base.Api()
        ..respond = (path, q) async =>
            path.endsWith('/plan') ? beta.betaPlan() : contextWire();
      session = ReadSessionFake();
      changes = ChangeNotifier();
      controller = CycleParticipationController(
        gateway: CycleInteractionRepository(
          api: api,
          recruitment: cycles.CycleGateway(),
          contractMode: RecruitmentContractMode.betaWire2,
        ),
        session: session,
        changes: changes,
        scopeKey: () => binding,
        now: () => DateTime.parse(cycles.nowStamp),
      );
      model = ScheduleComparisonViewModel(
        controller: controller,
        room: base.roomId,
        target: cycles.n,
      );
    });
    tearDown(() {
      model.dispose();
      controller.dispose();
      changes.dispose();
      session.dispose();
      binding = 'env/member/1';
    });
    test(
      'loads once then all 8 member toggles and days perform zero HTTP',
      () async {
        await model.load();
        expect(model.failure, isNull);
        expect(model.comparison!.members, hasLength(8));
        expect(api.requests, hasLength(2));
        for (final row in model.comparison!.members) {
          model.toggle(row.id, false);
        }
        model.selectDay(4);
        model.selectDay(3);
        expect(api.requests, hasLength(2));
        expect(model.selected, isEmpty);
        expect(model.common, isEmpty);
      },
    );
    test(
      'snapshot changed between plan/context is rejected, not combined',
      () async {
        api.respond = (path, q) async {
          if (path.endsWith('/plan')) return beta.betaPlan();
          final raw = contextWire();
          raw['data']['plan_revision'] = 6;
          return raw;
        };
        await model.load();
        expect(model.failure, 'REVISION_CONFLICT');
        expect(model.comparison, isNull);
      },
    );
    test('context permission denial never exposes comparison rows', () async {
      api.respond = (path, q) async {
        if (path.endsWith('/plan')) return beta.betaPlan();
        final raw = contextWire();
        raw['data']['permissions']['view_schedule_context'] = {
          'allowed': false,
          'reason': 'FORBIDDEN',
          'next_change_at': null,
        };
        return raw;
      };
      await model.load();
      expect(model.failure, 'FORBIDDEN');
      expect(model.comparison, isNull);
    });
    test('old member response cannot repopulate cleared UI', () async {
      final reply = Completer<Map<String, dynamic>>();
      api.respond = (path, q) => reply.future;
      final work = model.load();
      binding = 'env/other/2';
      changes.notifyListeners();
      reply.complete(beta.betaPlan());
      await work;
      expect(model.plan, isNull);
      expect(model.comparison, isNull);
      expect(model.failure, 'SESSION_CHANGED');
    });
    test('dispose ignores late request and does not fetch context', () async {
      final reply = Completer<Map<String, dynamic>>();
      api.respond = (path, q) => reply.future;
      final work = model.load();
      model.dispose();
      reply.complete(beta.betaPlan());
      await work;
      expect(api.requests, hasLength(1));
      model = ScheduleComparisonViewModel(
        controller: controller,
        room: base.roomId,
        target: cycles.n,
      );
    });
    test('read-only access reads no participant context', () async {
      model.dispose();
      model = ScheduleComparisonViewModel(
        controller: controller,
        room: base.roomId,
        target: cycles.n,
        forceReadOnly: true,
      );
      await model.load();
      expect(model.readOnly, isTrue);
      expect(api.requests, hasLength(1));
      expect(model.comparison, isNull);
    });

    test(
      'unset copy is all-day, failed copy is unknown, and empty beta personal table can be submitted',
      () async {
        final raw = contextWire();
        raw['data']['members'][0]['submission'].addAll({
          'intervals': <Map<String, dynamic>>[],
          'availability_copy': {
            'state': 'unset',
            'source_personal_version': 1,
            'copied_at': cycles.nowStamp,
          },
        });
        raw['data']['members'][1]['submission']['state'] = 'unavailable';
        api.respond = (path, q) async =>
            path.endsWith('/plan') ? beta.betaPlan() : raw;
        await model.load();
        expect(model.failure, isNull);
        expect(model.comparison!.members[0].state, TimetableState.unset);
        expect(spans(model.comparison!.members[0].availableOn(6)), [(0, 1440)]);
        expect(model.comparison!.members[1].state, TimetableState.unavailable);
        api.respond = (path, q) async {
          if (path.endsWith('/plan')) return beta.betaPlan();
          if (path.endsWith('/play-availability')) return personal.response();
          final submission = old.submissionWire();
          submission['data']['availability_copy'] = null;
          return submission;
        };
        final preview = await controller.schedulePreview(
          base.roomId,
          cycles.n,
          'submission',
        );
        expect(preview, isNotNull);
        expect(preview!.personal!.exists, isFalse);
        expect(preview.body({})['expected_personal_version'], 1);
        expect(api.requests.where((r) => r['method'] != 'GET'), isEmpty);
      },
    );
    test(
      'own ACK survives failed refresh; unknown response retains exact request until retry',
      () async {
        var lose = true;
        Map<String, dynamic>? recorded;
        api.respond = (path, q) async {
          final req = api.requests.last;
          if (req['method'] == 'GET') return beta.betaPlan();
          recorded ??= cycles.envelope(cycles.n, {
            'command_id': req['key'],
            'outcome': 'applied',
            'executed_at': cycles.nowStamp,
            'room_id': base.roomId,
            'target_cycle_key': cycles.n,
            'revisions': [
              {'resource': 'target', 'id': cycles.nextCycleId, 'revision': 2},
            ],
          }, created: true);
          if (lose) {
            lose = false;
            throw const AccountReadException('NETWORK_UNAVAILABLE');
          }
          return old.copy(recorded!);
        };
        final c = CycleParticipationController(
          gateway: CycleInteractionRepository(
            api: api,
            recruitment: cycles.CycleGateway(),
            contractMode: RecruitmentContractMode.betaWire2,
          ),
          session: session,
          changes: changes,
          scopeKey: () => binding,
          now: () => DateTime.parse(cycles.nowStamp),
          onMutation: (_) async {
            throw StateError('read failed');
          },
        );
        addTearDown(c.dispose);
        final preview = await c.schedulePreview(
          base.roomId,
          cycles.n,
          'respond',
          id: old.id(3),
        );
        await c.scheduleCommand(preview!, {'response': 'accept'});
        expect(c.scheduleSuccess, isNull);
        final key = c.pendingRequestKey;
        expect(key, isNotNull);
        await c.retry();
        expect(c.scheduleSuccess!.$1, key);
        expect(c.scheduleSuccess!.$2, base.roomId);
        expect(c.scheduleSuccess!.$3, cycles.n);
        expect(c.pendingRequestKey, isNull);
        final writes = api.requests
            .where((r) => r['method'] == 'POST')
            .toList();
        expect(writes, hasLength(2));
        expect(writes[0]['body'], writes[1]['body']);
        expect(writes[0]['key'], writes[1]['key']);
        await c.retry();
        expect(api.requests.where((r) => r['method'] == 'POST'), hasLength(2));
      },
    );
    test('fresh plan revision changes prevent proposal writes', () async {
      final p = await controller.schedulePreview(
        base.roomId,
        cycles.n,
        'propose',
      );
      api.respond = (_, q) async {
        final raw = beta.betaPlan();
        raw['data']['revision'] = 6;
        return raw;
      };
      await controller.scheduleCommand(p!, {'targets': old.targets()});
      expect(controller.failure, 'REVISION_CONFLICT');
      expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      expect(controller.scheduleSuccess, isNull);
    });
    testWidgets(
      'outside-table proposal warns but can reach confirmation; cancellation sends zero writes',
      (tester) async {
        final preview = await controller.schedulePreview(
          base.roomId,
          cycles.n,
          'propose',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: ScheduleCommandPage(
              controller: controller,
              preview: preview!,
              initialDay: 4,
              initialMinute: 1200,
              comparison: ScheduleComparison(cycles.n, [
                row(
                  'a',
                  times: const [
                    PlayTimeRow(weekday: 3, start: 1080, end: 1380),
                  ],
                ),
              ]),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('제안 내용 확인'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('제안 내용 확인'));
        await tester.pumpAndSettle();
        expect(find.text('이 일정으로 제안할까요?'), findsOneWidget);
        expect(find.textContaining('등록한 가능 시간 밖입니다.'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '제안 보내기'))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('시간 다시 고르기'));
        await tester.pumpAndSettle();
        expect(api.requests.where((r) => r['method'] != 'GET'), isEmpty);
        expect(controller.pendingRequestKey, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'proposal review back preserves draft; send closes only after its ACK',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preview = await controller.schedulePreview(
          base.roomId,
          cycles.n,
          'propose',
        );
        final writes = <Map<String, dynamic>>[];
        api.respond = (path, q) async {
          final req = api.requests.last;
          if (req['method'] == 'GET') return beta.betaPlan();
          writes.add(req);
          return cycles.envelope(cycles.n, {
            'command_id': req['key'],
            'outcome': 'applied',
            'executed_at': cycles.nowStamp,
            'room_id': base.roomId,
            'target_cycle_key': cycles.n,
            'revisions': [
              {'resource': 'target', 'id': cycles.nextCycleId, 'revision': 2},
            ],
          }, created: true);
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ScheduleCommandPage(
                        controller: controller,
                        preview: preview!,
                        initialDay: 4,
                        initialMinute: 1200,
                      ),
                    ),
                  ),
                  child: const Text('제안 열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('제안 열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('제안 내용 확인'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('이 일정으로 제안할까요?'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('제안할 일정'), findsOneWidget);
        expect(writes, isEmpty);
        await tester.tap(find.text('제안 내용 확인'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('제안 보내기'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(1));
        expect(
          writes.single['body']['targets'][0]['starts_at'],
          '2026-10-29T11:00:00.000Z',
        );
        expect(controller.scheduleSuccess!.$1, writes.single['key']);
        expect(find.text('제안 열기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'member response displays server vote counts and closes once after matching ACK',
      (tester) async {
        final preview = await controller.schedulePreview(
          base.roomId,
          cycles.n,
          'respond',
          id: old.id(3),
        );
        final writes = <Map<String, dynamic>>[];
        api.respond = (path, q) async {
          final req = api.requests.last;
          if (req['method'] == 'GET') return beta.betaPlan();
          writes.add(req);
          return cycles.envelope(cycles.n, {
            'command_id': req['key'],
            'outcome': 'applied',
            'executed_at': cycles.nowStamp,
            'room_id': base.roomId,
            'target_cycle_key': cycles.n,
            'revisions': [
              {'resource': 'target', 'id': cycles.nextCycleId, 'revision': 2},
            ],
          }, created: true);
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ScheduleCommandPage(
                        controller: controller,
                        preview: preview!,
                      ),
                    ),
                  ),
                  child: const Text('응답 열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('응답 열기'));
        await tester.pumpAndSettle();
        expect(find.text('일정 제안 확인'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('참가할게요'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('필요한 동의 6'), findsWidgets);
        await tester.ensureVisible(find.widgetWithText(FilledButton, '참가할게요'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '참가할게요'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(1));
        expect(writes.single['body']['response'], 'accept');
        expect(find.text('응답 열기'), findsOneWidget);
        expect(find.text('일정 제안 확인'), findsNothing);
        expect(controller.scheduleSuccess!.$1, writes.single['key']);
        expect(tester.takeException(), isNull);
      },
    );
    for (final width in [320.0, 390.0, 720.0]) {
      testWidgets(
        'dedicated schedule page at $width opens, compares locally, and returns to detail',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: FilledButton(
                    onPressed: () => showCycleSchedule(
                      ctx,
                      controller,
                      room: base.roomId,
                      target: cycles.n,
                    ),
                    child: const Text('상세에서 일정 열기'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('상세에서 일정 열기'));
          await tester.pumpAndSettle();
          expect(find.text('공대원 일정 전체 확인'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(ScheduleTimeline), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(api.requests, hasLength(2));
          await tester.tap(find.byKey(const ValueKey('schedule-day-3')));
          await tester.pump();
          expect(api.requests, hasLength(2));
          await tester.drag(
            find.byKey(const ValueKey('schedule-overview')),
            const Offset(-100, 0),
          );
          await tester.pumpAndSettle();
          expect(api.requests, hasLength(2));
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('상세에서 일정 열기'), findsOneWidget);
        },
      );
    }
  });
}
