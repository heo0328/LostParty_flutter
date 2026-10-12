import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/router/cycle_bound_page.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_cycle_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/raid_cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_cycle_runtime.dart';

void main() {
  testWidgets(
    'retained branches replace old query/command cycles without navigation',
    (tester) async {
      var now = DateTime.utc(2026, 10, 11, 5, 59);
      final runtime = PartyCycleRuntime(
        policy: const PartyCyclePolicy(
          schedule: RaidCycleSchedule(
            resetWeekday: DateTime.sunday,
            resetHour: 15,
          ),
        ),
        now: () => now,
        observeLifecycle: false,
        scheduleBoundaryRefresh: false,
      );
      final disposed = <String>[];
      late StatefulNavigationShell shell;
      final router = GoRouter(
        initialLocation: '/account',
        refreshListenable: runtime,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigation) {
              shell = navigation;
              return navigation;
            },
            branches: [
              for (final name in ['account', 'raid-status'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/$name',
                      builder: (context, state) => CycleBoundPage(
                        runtime: runtime,
                        builder: (context, cycle) => _CycleProbe(
                          key: ValueKey('$name-${cycle.key}'),
                          value: '$name-${cycle.key}',
                          disposed: disposed,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      shell.goBranch(1);
      await tester.pumpAndSettle();
      now = DateTime.utc(2026, 10, 11, 6, 1);
      runtime.refresh();
      await tester.pumpAndSettle();
      expect(find.text('raid-status-2026-10-11'), findsOneWidget);
      expect(
        disposed,
        containsAll(['account-2026-10-04', 'raid-status-2026-10-04']),
      );
      shell.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('account-2026-10-11'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/account');
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      runtime.dispose();
    },
  );
}

class _CycleProbe extends StatefulWidget {
  const _CycleProbe({super.key, required this.value, required this.disposed});
  final String value;
  final List<String> disposed;
  @override
  State<_CycleProbe> createState() => _CycleProbeState();
}

class _CycleProbeState extends State<_CycleProbe> {
  late final String queryAndCommandCycle = widget.value;
  @override
  Widget build(BuildContext context) => Text(queryAndCommandCycle);
  @override
  void dispose() {
    widget.disposed.add(queryAndCommandCycle);
    super.dispose();
  }
}
