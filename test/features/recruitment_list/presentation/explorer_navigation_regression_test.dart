import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'group detail then explorer selection keeps navigator layout valid',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/groups',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => Scaffold(body: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  ShellRoute(
                    builder: (_, state, child) => LayoutBuilder(
                      builder: (_, box) => Stack(
                        children: [
                          Positioned.fill(
                            child: Offstage(
                              offstage: state.uri.path == '/rooms',
                              child: state.uri.path == '/rooms'
                                  ? const SizedBox()
                                  : child,
                            ),
                          ),
                        ],
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: '/rooms',
                        builder: (_, _) => const SizedBox(),
                        routes: [
                          GoRoute(
                            path: ':id',
                            builder: (_, state) =>
                                Text(state.pathParameters['id']!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/groups',
                    builder: (_, _) => const Text('groups'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      router.go('/rooms/group');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      router.go('/rooms/other');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      router.go('/groups');
      await tester.pumpAndSettle();
      router.go('/rooms/group');
      await tester.pumpAndSettle();
      router.go('/rooms/other');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
