import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/departure_search_selection.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_search_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_filter_page.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_interaction_test.dart' as f;
import 'cycle_recruitment_test.dart' as cycles;

Future<void> drain() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'no selection omits optional filter keys; state groups are explicit OR sets',
    () {
      final plain = CycleSearchFilter().body(f.n);
      expect(plain.containsKey('departure_windows'), isFalse);
      expect(plain.containsKey('schedule_states'), isFalse);
      final states =
          DepartureSearchSelection(
                groups: {'coordinating', 'confirmed'},
              ).wire(f.n)['schedule_states']
              as List;
      expect(states.toSet(), {
        'coordinating',
        ...DepartureSearchSelection.confirmedStates,
      });
      expect(states, isNot(contains('needs_review')));
      expect(states, isNot(contains('legacy')));
    },
  );
  test(
    'KST actual Saturday windows and next-day range convert to UTC, C/N differs',
    () {
      final selected = DepartureSearchSelection(
        weekday: 6,
        timeEnabled: true,
        from: 1020,
        to: 1200,
      );
      final window = (selected.wire(f.n)['departure_windows'] as List).single;
      expect(window, {
        'starts_at': '2026-10-31T08:00:00.000Z',
        'ends_at': '2026-10-31T11:00:00.000Z',
      });
      final overnight =
          (selected.copy(from: 1320, to: 120).wire(f.n)['departure_windows']
                  as List)
              .single;
      expect(overnight, {
        'starts_at': '2026-10-31T13:00:00.000Z',
        'ends_at': '2026-10-31T17:00:00.000Z',
      });
      final c = (selected.wire(f.c)['departure_windows'] as List).single;
      expect(
        DateTime.parse(
          window['starts_at'],
        ).difference(DateTime.parse(c['starts_at'])),
        const Duration(days: 7),
      );
    },
  );
  test(
    'day-only, time-only and clipping retain selected-week boundaries; no empty becomes unfiltered',
    () {
      final day =
          (DepartureSearchSelection(weekday: 3).wire(f.n)['departure_windows']
                  as List)
              .single;
      expect(day['starts_at'], '2026-10-27T21:00:00.000Z');
      expect(day['ends_at'], '2026-10-28T15:00:00.000Z');
      expect(
        DepartureSearchSelection(
          timeEnabled: true,
          from: 1320,
          to: 120,
        ).wire(f.n)['departure_windows'],
        hasLength(7),
      );
      final clipped =
          (DepartureSearchSelection(
                    weekday: 2,
                    timeEnabled: true,
                    from: 1380,
                    to: 600,
                  ).wire(f.n)['departure_windows']
                  as List)
              .single;
      expect(clipped['ends_at'], '2026-11-03T21:00:00.000Z');
      final outside = DepartureSearchSelection(
        weekday: 3,
        timeEnabled: true,
        from: 0,
        to: 120,
      );
      expect(outside.validFor(f.n), isFalse);
      expect(() => outside.wire(f.n), throwsFormatException);
      final mornings =
          DepartureSearchSelection(
                timeEnabled: true,
                from: 120,
                to: 600,
              ).wire(f.n)['departure_windows']
              as List;
      expect(mornings, hasLength(8));
      expect(mornings.first['starts_at'], '2026-10-27T21:00:00.000Z');
      expect(mornings.last['ends_at'], '2026-11-03T21:00:00.000Z');
      for (final selection in [
        DepartureSearchSelection(timeEnabled: true),
        DepartureSearchSelection(timeEnabled: true, from: 600, to: 600),
        DepartureSearchSelection(timeEnabled: true, from: 602, to: 1200),
        DepartureSearchSelection(groups: {'unrecognized'}),
      ]) {
        expect(selection.valid, isFalse);
        expect(() => selection.wire(f.n), throwsFormatException);
      }
    },
  );
  test('new filter keys participate in signature with old conditions kept', () {
    final original = CycleSearchFilter(
      remaining: {2, 3},
      experiences: {'tryLevel', 'clearExp'},
      descending: false,
    );
    final filtered = original.copy(
      departure: DepartureSearchSelection(weekday: 6, groups: {'coordinating'}),
    );
    expect(filtered.signature, isNot(original.signature));
    final body = filtered.body(f.n, cursor: 'next');
    expect(body['remaining_slot_counts'], [2, 3]);
    expect(body['experience_levels'], ['clearExp', 'tryLevel']);
    expect(body['sort']['direction'], 'ascending');
    expect(body['cursor'], 'next');
    expect(body['schedule_states'], ['coordinating']);
  });
  test(
    'real beta repository sends filtering before cursor, not per-card reads',
    () async {
      final api = base.Api()
        ..respond = (_, _) async {
          final raw = f.searchWire(f.n);
          for (final item in raw['data']['items']) {
            item['beta_schedule'] = null;
          }
          return raw;
        };
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      await repo.search(
        f.n,
        CycleSearchFilter(
          departure: DepartureSearchSelection(
            weekday: 6,
            timeEnabled: true,
            from: 1020,
            to: 1200,
            groups: {'confirmed'},
          ),
        ),
        cursor: 'page-two',
      );
      expect(api.requests, hasLength(1));
      final request = api.requests.single;
      expect(request['query']['contract_profile'], BetaContract.profile);
      expect(request['body']['cursor'], 'page-two');
      expect(request['body']['departure_windows'], hasLength(1));
      expect(request['body']['schedule_states'], hasLength(4));
    },
  );
  group('owned filter draft', () {
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late base.Api api;
    late f.TestGateway gateway;
    late CycleSearchViewModel m;
    var binding = 'env/member/1';
    setUp(() async {
      binding = 'env/member/1';
      session = ReadSessionFake();
      changes = ChangeNotifier();
      api = base.Api();
      api.respond = (_, q) async =>
          f.searchWire(api.requests.last['body']['target_cycle_key']);
      gateway = f.TestGateway(api, cycles.CycleGateway());
      m = CycleSearchViewModel(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: () => binding,
      );
      await m.load();
      expect(m.failure, isNull);
      api.requests.clear();
    });
    tearDown(() {
      m.dispose();
      changes.dispose();
      session.dispose();
    });
    test(
      'draft toggles/week switches/cancel cause search0; apply atomically searches once',
      () async {
        final d = m.draft();
        final original = m.filter.signature;
        d.update(
          d.filter.copy(
            experiences: {'tryLevel', 'clearExp'},
            departure: DepartureSearchSelection(
              weekday: 6,
              groups: {'coordinating'},
            ),
          ),
        );
        d.selectTarget(f.n);
        d.update(
          d.filter.copy(departure: DepartureSearchSelection(weekday: 5)),
        );
        expect(api.requests, isEmpty);
        expect(m.filter.signature, original);
        expect(m.target, f.c);
        expect(m.applyDraft(d), isTrue);
        await drain();
        expect(api.requests, hasLength(1));
        expect(m.target, f.n);
        expect(m.filter.departure.weekday, 5);
        d.dispose();
        final cancel = m.draft();
        cancel.update(cancel.filter.copy(remaining: {7}));
        cancel.dispose();
        expect(m.filter.remaining, isEmpty);
        expect(api.requests, hasLength(1));
        expect(m.applyDraft(cancel), isFalse);
      },
    );
    test('late pre-apply page cannot replace new conditions/result', () async {
      final old = Completer<CycleSearchPage>();
      var requests = 0;
      gateway.onSearch = (t, filter, cursor) async {
        requests++;
        if (requests == 1) return old.future;
        return CycleSearchPage(f.searchWire(t, id: f.app), t);
      };
      m.update(m.filter.copy(remaining: {2}));
      final d = m.draft();
      d.update(d.filter.copy(departure: DepartureSearchSelection(weekday: 6)));
      expect(m.applyDraft(d), isTrue);
      await drain();
      expect(m.rows.single.id, f.app);
      old.complete(CycleSearchPage(f.searchWire(f.c), f.c));
      await drain();
      expect(m.rows.single.id, f.app);
      d.dispose();
    });
    test('member/environment change rejects an old draft', () async {
      final d = m.draft();
      d.update(d.filter.copy(remaining: {3}));
      binding = 'other-env/member/2';
      changes.notifyListeners();
      expect(m.applyDraft(d), isFalse);
      expect(d.filter.remaining, isEmpty);
      d.dispose();
      await drain();
    });
    for (final width in [320.0, 390.0, 720.0]) {
      testWidgets(
        'approved filter page $width: local choices, cancel, explicit apply',
        (tester) async {
          tester.view.physicalSize = Size(width, 1300);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light.copyWith(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  alwaysUse24HourFormat: true,
                  textScaler: const TextScaler.linear(0.8),
                ),
                child: child!,
              ),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: FilledButton(
                    onPressed: () => openRecruitmentFilter(ctx, m),
                    child: const Text('필터 열기'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('필터 열기'));
          await tester.pumpAndSettle();
          expect(find.text('레이드 모집 · 필터'), findsOneWidget);
          expect(find.byType(FilterChip), findsNothing);
          await tester.scrollUntilVisible(
            find.text('시간대 지정'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('시간대 지정'));
          await tester.pump();
          await tester.scrollUntilVisible(
            find.text('선택').first,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('선택').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(TimePickerDialog), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('departure-day-6')));
          await tester.pump();
          expect(api.requests, isEmpty);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(m.filter.departure.weekday, isNull);
          await tester.tap(find.text('필터 열기'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('departure-day-6')));
          await tester.pump();
          await tester.scrollUntilVisible(
            find.text('조건 적용'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('조건 적용'));
          await tester.pumpAndSettle();
          expect(m.filter.departure.weekday, 6);
          expect(api.requests, hasLength(1));
          expect(find.text('필터 열기'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
