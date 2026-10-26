import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_member_action_widgets.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_departure_test.dart' as fixture;

// Only the schedule display is stubbed; context, command and ACK use real readers.
class _Plan implements CycleScheduleView {
  _Plan(String round)
    : data = {
        'game_items': [
          {'round_id': round, 'round_state': 'active'},
        ],
        'my_assignments': [
          {'round_id': round, 'state': 'active'},
        ],
      };
  @override
  final Map<String, dynamic> data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends CycleParticipationController {
  _Controller({
    required super.gateway,
    required super.session,
    required super.changes,
    required super.scopeKey,
    required super.now,
    required super.onMutation,
    required this.round,
  });
  final String round;
  @override
  Future<CycleScheduleView?> scheduleRead(
    String room,
    String target,
    String kind, {
    String? id,
    String? cursor,
  }) async => _Plan(round);
}

void main() {
  for (final scenario in ['success', 'different-character', 'cancel']) {
    testWidgets(
      'account departure $scenario preserves exact identity and closes only own success',
      (tester) async {
        final session = ReadSessionFake(), changes = ChangeNotifier();
        final raw = fixture.context('personal_automatic_successor');
        raw['data']['room_id'] = base.roomId;
        final subject = raw['data']['subject'] as Map;
        final api = base.Api();
        api.respond = (_, _) async {
          if (api.requests.last['method'] == 'POST') {
            final ack = fixture.ack('personal_automatic_successor');
            ack['data']['room_id'] = base.roomId;
            ack['data']['command_id'] = api.requests.last['key'];
            return ack;
          }
          return fixture.copy(raw);
        };
        final refresh = Completer<void>();
        final c = _Controller(
          gateway: CycleInteractionRepository(
            api: api,
            recruitment: cycles.CycleGateway(),
          ),
          session: session,
          changes: changes,
          scopeKey: () => session.userId!,
          now: () => DateTime.parse(raw['scope']['server_now']),
          onMutation: (_) => refresh.future,
          round: subject['round_id'],
        );
        addTearDown(() {
          c.dispose();
          changes.dispose();
          session.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => unawaited(
                    showDeparture(
                      context,
                      c,
                      room: base.roomId,
                      target: cycles.c,
                      raidLabel: (_) => '선택한 레이드',
                      isCurrent: () => context.mounted,
                      initialRound: subject['round_id'],
                      expectedCharacter: scenario == 'different-character'
                          ? '00000000-0000-4000-8000-000000000001'
                          : subject['character_id'],
                      closeOnSuccess: true,
                    ),
                  ),
                  child: const Text('내 계정'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('내 계정'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '완료 후 탈퇴'),
        );
        if (scenario == 'different-character') {
          expect(button.onPressed, isNull);
        } else if (scenario == 'cancel') {
          await tester.tap(find.text('취소'));
        } else {
          await tester.tap(find.text('완료 후 탈퇴'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(c.departureSuccess, isNotNull);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('내 계정'), findsOneWidget);
        }
        expect(
          api.requests.where((r) => r['method'] == 'POST'),
          hasLength(scenario == 'success' ? 1 : 0),
        );
        refresh.complete();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
