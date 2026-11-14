import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/account_session_view.dart';
import '../support/server_account_read_fakes.dart';

void main() {
  testWidgets(
    'unchanged recruitment shell observes delayed restore and hidden-tab session changes',
    (tester) async {
      final session = ReadSessionFake()..change(authenticated: false);
      var shellBuilds = 0, memberMounts = 0;
      late StatefulNavigationShell tabs;
      final router = GoRouter(
        initialLocation: '/recruitments',
        refreshListenable: session,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) {
              tabs = shell;
              return shell;
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/account',
                    builder: (_, _) => const Scaffold(body: Text('account')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  ShellRoute(
                    builder: (context, state, child) {
                      shellBuilds++;
                      return AccountSessionView(
                        session: session,
                        localBuilder: (_) => state.uri.path == '/recruitments'
                            ? const Scaffold(body: Text('guest'))
                            : child,
                        memberBuilder: (_) => state.uri.path == '/recruitments'
                            ? _MemberProbe(onMount: () => memberMounts++)
                            : child,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: '/recruitments',
                        builder: (_, _) => const SizedBox(),
                        routes: [
                          GoRoute(
                            path: 'create',
                            builder: (_, state) => Scaffold(
                              body: Text(
                                'create:${state.uri.queryParameters['target_cycle_key']}',
                              ),
                            ),
                          ),
                          GoRoute(
                            path: ':room',
                            builder: (_, state) => Scaffold(
                              body: Text(
                                'detail:${state.uri.queryParameters['target_cycle_key']}:${state.uri.queryParameters['return_to']}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(() {
        router.dispose();
        session.dispose();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('guest'), findsOneWidget);
      final builds = shellBuilds;
      session.change(authenticated: true, user: 'first');
      await tester.pumpAndSettle();
      expect(find.byType(_MemberProbe), findsOneWidget);
      expect(shellBuilds, builds);
      await tester.enterText(find.byType(TextField), 'draft');
      session.notifyListeners();
      session.notifyListeners();
      await tester.pumpAndSettle();
      expect(memberMounts, 1);
      expect(find.text('draft'), findsOneWidget);
      tabs.goBranch(0);
      await tester.pumpAndSettle();
      session.change(authenticated: false);
      await tester.pumpAndSettle();
      tabs.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('guest'), findsOneWidget);
      session.change(authenticated: true, user: 'second');
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsNothing);
      expect(memberMounts, 2);
      router.push('/recruitments/create?target_cycle_key=2026-11-18');
      await tester.pumpAndSettle();
      expect(find.text('create:2026-11-18'), findsOneWidget);
      session.change(authenticated: false);
      await tester.pumpAndSettle();
      expect(find.text('create:2026-11-18'), findsOneWidget);
      router.go(
        '/recruitments/sample?target_cycle_key=2026-11-18&return_to=raid-status',
      );
      await tester.pumpAndSettle();
      session.change(authenticated: true, user: 'third');
      await tester.pumpAndSettle();
      expect(find.text('detail:2026-11-18:raid-status'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(session.accessCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _MemberProbe extends StatefulWidget {
  const _MemberProbe({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_MemberProbe> createState() => _MemberProbeState();
}

class _MemberProbeState extends State<_MemberProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: TextField());
}
