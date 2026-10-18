import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/presentation/widgets/roster_account_header.dart';
import 'package:lost_party/features/account/presentation/widgets/server_registration_edit_dialog.dart';
import '../../../support/server_account_read_fakes.dart';

void main() {
  testWidgets(
    'compact authentication stays next to short name and long names fit at large scale',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        for (final label in ['본계정', List.filled(40, '가').join()]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: 320,
                    child: RosterAccountHeader(
                      label: label,
                      onVerify: () {},
                      onEdit: () {},
                      onCharacters: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final name = tester.getRect(find.text(label));
          final button = tester.getRect(find.byType(FilledButton));
          expect(button.left - name.right, closeTo(6, 0.1));
          expect(button.height, greaterThanOrEqualTo(48));
          expect(tester.widget<Text>(find.text(label)).maxLines, 2);
        }
      }
    },
  );

  testWidgets(
    'registration editor closes on member change and cannot return approval',
    (tester) async {
      final session = ReadSessionFake();
      addTearDown(session.dispose);
      var completed = false;
      (String, bool)? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showServerRegistrationEditDialog(
                    ctx,
                    account: ServerAccountRegistration.fromJson(
                      registrationJson(),
                    ),
                    displayLabel: '본계정',
                    session: session,
                  );
                  completed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'changed');
      session.change(
        authenticated: true,
        user: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.text('저장'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );
}
