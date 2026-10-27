import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/beta_schedule_draft.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/beta_schedule_editor.dart';
import 'cycle_recruitment_test.dart' as cycles;

void main() {
  for (final changedScope in [false, true]) {
    testWidgets(
      'invalid time remains editable; stale scope $changedScope cannot replace draft',
      (tester) async {
        var input = const BetaScheduleInput(weekday: 4, minute: 1083);
        var scope = 'member1';
        final now = DateTime.parse(cycles.nowStamp);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => BetaScheduleEditor(
                  target: cycles.c,
                  now: now,
                  duration: 20,
                  capacity: 8,
                  value: input,
                  scopeKey: () => scope,
                  onChanged: (v) => update(() => input = v),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '1');
        await tester.enterText(find.byType(TextField).last, '03');
        await tester.tap(find.text('오전'));
        if (changedScope) scope = 'member2';
        await tester.tap(find.text('선택'));
        await tester.pumpAndSettle();
        expect(input.minute, changedScope ? 1083 : 63);
        if (!changedScope) {
          expect(find.textContaining('30분 이후'), findsOneWidget);
          expect(BetaScheduleEditor.valid(cycles.c, now, 20, 8, input), false);
          expect(find.text('01:03 · KST'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
