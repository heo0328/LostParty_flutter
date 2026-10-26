import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_action_dialog_route.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/backend_recruitment_detail_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_member_action_widgets.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;

void main() {
  testWidgets(
    'departure closes its root dialog and returns from nested detail once',
    (tester) async {
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final api = base.Api()
        ..respond = (_, _) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
      final gateway = cycles.CycleGateway()
        ..onCycleDetail = (target) async =>
            BackendRecruitmentRepository.parseCycleDetail(
              cycles.detail(target),
              base.roomId,
              target,
            );
      final c = CycleParticipationController(
        gateway: CycleInteractionRepository(api: api, recruitment: gateway),
        session: session,
        changes: changes,
        scopeKey: () => session.userId!,
      );
      final router = GoRouter(
        initialLocation: '/recruitments/${base.roomId}',
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: '/recruitments/:id',
                builder: (_, _) => BackendRecruitmentDetailPage(
                  gateway: gateway,
                  session: session,
                  roomId: base.roomId,
                  target: cycles.c,
                  participation: c,
                  onLogin: () {},
                  onCreateAnother: () {},
                ),
              ),
              GoRoute(
                path: '/raid-status',
                builder: (_, _) => const Scaffold(body: Text('레이드 현황 목록')),
              ),
            ],
          ),
        ],
      );
      addTearDown(() {
        router.dispose();
        c.dispose();
        changes.dispose();
        session.dispose();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BackendRecruitmentDetailPage));
      unawaited(
        showDeparture(
          context,
          c,
          room: base.roomId,
          target: cycles.c,
          raidLabel: (_) => '레이드',
          isCurrent: () => context.mounted,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      c.departureSuccess = ('receipt', base.roomId, cycles.c);
      await c.changed(base.roomId, cycles.c);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/raid-status');
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['target_cycle_key'],
        cycles.c,
      );
      await c.changed(base.roomId, cycles.c);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/raid-status');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'weekly completion ignores unrelated receipts and closes only its own confirmation',
    (tester) async {
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final api = base.Api()
        ..respond = (_, _) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
      final gateway = cycles.CycleGateway()
        ..onCycleDetail = (target) async =>
            BackendRecruitmentRepository.parseCycleDetail(
              cycles.detail(target),
              base.roomId,
              target,
            );
      final c = CycleParticipationController(
        gateway: CycleInteractionRepository(api: api, recruitment: gateway),
        session: session,
        changes: changes,
        scopeKey: () => session.userId!,
      );
      final router = GoRouter(
        initialLocation: '/recruitments/${base.roomId}',
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: '/recruitments/:id',
                builder: (_, _) => BackendRecruitmentDetailPage(
                  gateway: gateway,
                  session: session,
                  roomId: base.roomId,
                  target: cycles.c,
                  participation: c,
                  onLogin: () {},
                  onCreateAnother: () {},
                ),
              ),
              GoRoute(
                path: '/raid-status',
                builder: (_, _) => const Scaffold(body: Text('레이드 현황 목록')),
              ),
            ],
          ),
        ],
      );
      addTearDown(() {
        router.dispose();
        c.dispose();
        changes.dispose();
        session.dispose();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BackendRecruitmentDetailPage));
      unawaited(
        showDeparture(
          context,
          c,
          room: base.roomId,
          target: cycles.c,
          raidLabel: (_) => '레이드',
          isCurrent: () => context.mounted,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      c.completionSuccess = ('other-week', base.roomId, cycles.n);
      await c.changed(base.roomId, cycles.n);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        contains('/recruitments/'),
      );
      c.completionSuccess = ('receipt', base.roomId, cycles.c);
      await c.changed(base.roomId, cycles.c);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/raid-status');
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['target_cycle_key'],
        cycles.c,
      );
      await c.changed(base.roomId, cycles.c);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/raid-status');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'closing an owned confirmation never pops unrelated root dialogs or pages',
    (tester) async {
      late BuildContext page;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold(body: Text('기존 화면'));
            },
          ),
        ),
      );
      unawaited(
        showDialog<void>(
          context: page,
          builder: (_) => const AlertDialog(content: Text('무관한 안내')),
        ),
      );
      await tester.pumpAndSettle();
      closeCycleActionDialogs(page, base.roomId, cycles.c);
      await tester.pumpAndSettle();
      expect(find.text('무관한 안내'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      closeCycleActionDialogs(page, base.roomId, cycles.c);
      expect(find.text('기존 화면'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
