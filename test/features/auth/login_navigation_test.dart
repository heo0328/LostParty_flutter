import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import 'package:lost_party/features/auth/presentation/login_page.dart';

import 'auth_session_controller_test.dart'
    show FakeApi, FakeGoogle, MemoryStore;

void main() {
  testWidgets(
    'successful pushed login returns to original screen after router refresh',
    (tester) async {
      final auth = AuthSessionController(
        api: FakeApi(),
        google: FakeGoogle(),
        store: MemoryStore(),
        serverClientId: 'web',
      );
      await auth.restore();
      final router = GoRouter(
        initialLocation: '/original',
        refreshListenable: auth,
        routes: [
          GoRoute(
            path: '/original',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('open-login'),
              ),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => LoginPage(auth: auth),
          ),
          GoRoute(
            path: '/account',
            builder: (_, _) => const Scaffold(body: Text('account-screen')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('open-login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('open-login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
    },
  );

  testWidgets('successful direct login opens account screen', (tester) async {
    final auth = AuthSessionController(
      api: FakeApi(),
      google: FakeGoogle(),
      store: MemoryStore(),
      serverClientId: 'web',
    );
    await auth.restore();
    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(auth: auth),
        ),
        GoRoute(
          path: '/account',
          builder: (_, _) => const Scaffold(body: Text('account-screen')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isTrue);
    expect(find.text('account-screen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
}
