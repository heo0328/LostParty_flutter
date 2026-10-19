import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/account_session_view.dart';
import 'package:lost_party/app/bootstrap/startup_entry_gate.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import 'package:lost_party/features/auth/domain/backend_auth_models.dart';
import 'package:lost_party/features/auth/presentation/login_page.dart';

import '../features/auth/auth_session_controller_test.dart'
    show FakeApi, FakeGoogle, MemoryStore;

void main() {
  late FakeApi api;
  late AuthSessionController auth;
  late GoRouter router;
  var routeBuilds = 0;

  Future<void> mount(WidgetTester tester, {bool memberEnabled = true}) async {
    api = FakeApi();
    auth = AuthSessionController(
      api: api,
      google: FakeGoogle(),
      store: MemoryStore(),
      serverClientId: 'web',
      clock: () => api.now,
    );
    await auth.restore();
    routeBuilds = 0;
    router = GoRouter(
      initialLocation: '/account',
      refreshListenable: auth,
      routes: [
        GoRoute(
          path: '/account',
          builder: (context, _) {
            routeBuilds++;
            return AccountSessionView(
              session: AuthAccountReadSession(auth),
              localBuilder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('local-login'),
                ),
              ),
              memberBuilder: memberEnabled
                  ? (_) => Scaffold(body: Text('member-${auth.userId}'))
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(auth: auth),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  }

  testWidgets(
    'pushed login returns to member view and logout restores local view',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('local-login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('member-user-1'), findsOneWidget);
      expect(find.text('local-login'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/account');
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('local-login'), findsOneWidget);
      expect(find.text('member-user-1'), findsNothing);
      await close(tester);
    },
  );

  testWidgets(
    'late authentication after four seconds updates unchanged route without API from view',
    (tester) async {
      await mount(tester);
      final gate = StartupEntryGate()..start();
      final pending = Completer<AuthLogin>();
      api.loginResult = pending.future;
      final login = auth.login(remember: false);
      await tester.pump(const Duration(seconds: 4));
      expect(gate.canEnter, isTrue);
      expect(find.text('local-login'), findsOneWidget);
      final builds = routeBuilds;
      // Preserve the fake API's normal response, releasing only its timing.
      api.loginResult = null;
      pending.complete(
        await api.login(
          transactionId: 'fixture',
          secret: 'fixture',
          proof: 'fixture',
          remember: false,
        ),
      );
      await login;
      await tester.pumpAndSettle();
      expect(find.text('member-user-1'), findsOneWidget);
      expect(routeBuilds, builds);
      final calls = (api.logins, api.meCalls, api.refreshCalls);
      auth.notifyListeners();
      auth.notifyListeners();
      await tester.pumpAndSettle();
      expect((api.logins, api.meCalls, api.refreshCalls), calls);
      expect(routeBuilds, builds);
      gate.dispose();
      await close(tester);
    },
  );

  testWidgets(
    'disabled member binding retains local fallback after authentication',
    (tester) async {
      await mount(tester, memberEnabled: false);
      await auth.login(remember: false);
      await tester.pumpAndSettle();
      expect(find.text('local-login'), findsOneWidget);
      expect(find.text('member-user-1'), findsNothing);
      await close(tester);
    },
  );
}
