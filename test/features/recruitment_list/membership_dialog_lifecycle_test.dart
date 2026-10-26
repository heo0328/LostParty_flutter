import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_membership_widgets.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'membership_actions_test.dart' as fixtures;

class _DialogObserver extends NavigatorObserver {
  _DialogObserver(this.onDialog);
  final VoidCallback onDialog;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) onDialog();
  }
}

void main() {
  for (final scenario in ['success', 'cancel', 'stale-view']) {
    testWidgets(
      'dissolve $scenario avoids build notifications and duplicate writes',
      (tester) async {
        final raw = fixtures.fixture('eight-members-two-targets-context');
        final menu = fixtures.context(raw);
        final api = base.Api();
        api.respond = (_, _) async {
          if (api.requests.last['method'] == 'POST') {
            final ack = fixtures.fixture('eight-members-two-targets-result');
            ack['data']['command_id'] = api.requests.last['key'];
            return ack;
          }
          return fixtures.copy(raw);
        };
        final session = ReadSessionFake(), changes = ChangeNotifier();
        final refreshed = <String>[];
        var current = true;
        final c = CycleParticipationController(
          gateway: CycleInteractionRepository(
            api: api,
            recruitment: cycles.CycleGateway(),
          ),
          session: session,
          changes: changes,
          scopeKey: () => session.userId!,
          now: () => DateTime.parse(menu.scope['server_now']),
          onMutation: (t) async => refreshed.add(t),
        );
        addTearDown(() {
          c.dispose();
          changes.dispose();
          session.dispose();
        });
        // Retained pages and the app shell also listen to this app-owned controller.
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: c,
            builder: (_, _) => MaterialApp(
              navigatorObservers: [
                _DialogObserver(() {
                  if (scenario == 'stale-view') current = false;
                }),
              ],
              home: Scaffold(
                body: CycleMembershipActions(
                  controller: c,
                  menu: menu,
                  isCurrent: () => current,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('모집 해산'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          api.requests.where((r) => r['method'] == 'GET'),
          hasLength(scenario == 'stale-view' ? 0 : 1),
        );
        expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
        if (scenario != 'success') {
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();
          expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
          expect(refreshed, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        await tester.tap(find.text('해산'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(api.requests.where((r) => r['method'] == 'POST'), hasLength(1));
        expect(refreshed, menu.select('dissolve_led_targets').affected);
        expect(refreshed.toSet().length, refreshed.length);
        expect(c.membershipSuccess, isNotNull);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
