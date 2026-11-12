import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/cycle_recruitment_list_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/recruitment_filter_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_interaction_test.dart' as f;
import 'discovery_fixtures.dart';

void main() {
  testWidgets(
    'detail URL and width transitions preserve editor and search ownership',
    (tester) async {
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final gateway = f.TestGateway(base.Api(), cycles.CycleGateway());
      gateway.onSearch = (t, filter, cursor) async {
        final raw = discoveryWire(f.searchWire(t));
        raw['data']['items'][0]['title'] = '탐색 테스트';
        return CycleSearchPage.discovery(raw, t, groups: false);
      };
      final mutations = CycleParticipationController(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: () => 'scope',
      );
      final router = GoRouter(
        initialLocation: '/recruitments',
        routes: [
          ShellRoute(
            builder: (context, state, child) => CycleRecruitmentListPage(
              key: const ValueKey('explorer'),
              gateway: gateway,
              session: session,
              changes: changes,
              scopeKey: () => 'scope',
              mutations: mutations,
              onLogin: () {},
              onCreate: (_) {},
              onRoom: (id, t) =>
                  context.go('/recruitments/$id?target_cycle_key=$t'),
              selectedRoom: state.pathParameters['id'],
              selectedTarget: state.uri.queryParameters['target_cycle_key'],
              onClearSelection: () => context.go('/recruitments'),
              detail: state.pathParameters['id'] == null ? null : child,
            ),
            routes: [
              GoRoute(
                path: '/recruitments',
                builder: (_, _) => const SizedBox(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => const Scaffold(
                      body: TextField(key: ValueKey('detailInput')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(gateway.searches, 1);
      await tester.tap(find.text('탐색 테스트'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/recruitments/${f.room}',
      );
      await tester.enterText(find.byKey(const ValueKey('detailInput')), '작성 중');
      for (final width in [840.0, 600.0, 650.0, 390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpAndSettle();
        expect(find.text('작성 중'), findsOneWidget);
        expect(gateway.searches, 1);
        expect(tester.takeException(), isNull);
      }
      final draft = tester
          .widget<RecruitmentFilterPage>(
            find.byType(RecruitmentFilterPage).first,
          )
          .draft!;
      draft.update(draft.filter.copy(raids: {'raid_a'}));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '일반'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(draft.filter.raids, {'raid_a'});
      expect(router.routeInformationProvider.value.uri.path, '/recruitments');
      expect(find.text('작성 중'), findsNothing);
      expect(gateway.searches, 2);
      tester.view.physicalSize = const Size(840, 260);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '필터'));
      await tester.pumpAndSettle();
      final openFilter = find.byType(RecruitmentFilterPage);
      expect(openFilter, findsOneWidget);
      final filterScaffold = find.descendant(
        of: openFilter,
        matching: find.byType(Scaffold),
      );
      expect(
        tester.widget<Scaffold>(filterScaffold).bottomNavigationBar,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, '적용'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, '적용'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.widgetWithText(FilledButton, '적용')).bottom,
        lessThanOrEqualTo(260),
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(650, 900);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RecruitmentFilterPage>(openFilter).draft,
        same(draft),
      );
      expect(draft.filter.raids, {'raid_a'});
      expect(gateway.searches, 2);
      await tester.pageBack();
      await tester.pumpAndSettle();
      router.go('/recruitments');
      await tester.pumpAndSettle();
      expect(gateway.searches, 2);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      mutations.dispose();
      changes.dispose();
      session.dispose();
    },
  );
}
