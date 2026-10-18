import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/startup_entry_gate.dart';

void main() {
  testWidgets(
    'fixed four seconds without readiness or animation dependencies',
    (tester) async {
      final gate = StartupEntryGate()..start();
      addTearDown(gate.dispose);
      await tester.pump(const Duration(milliseconds: 3999));
      expect(gate.canEnter, isFalse);
      gate.start(); // Re-entry must not extend the original deadline.
      await tester.pump(const Duration(milliseconds: 1));
      expect(gate.canEnter, isTrue);
    },
  );

  testWidgets('not started stays closed and completed gate notifies once', (
    tester,
  ) async {
    final gate = StartupEntryGate();
    addTearDown(gate.dispose);
    var notifications = 0;
    gate.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 5));
    expect(gate.canEnter, isFalse);
    gate.start();
    await tester.pump(const Duration(seconds: 4));
    gate.start();
    await tester.pump(const Duration(seconds: 4));
    expect(gate.canEnter, isTrue);
    expect(notifications, 1);
  });

  testWidgets('disposing presentation neither notifies late nor cancels work', (
    tester,
  ) async {
    final result = Completer<int>();
    final work = result.future;
    var notifications = 0;
    final gate = StartupEntryGate()..start();
    gate.addListener(() => notifications++);
    gate.dispose();
    await tester.pump(const Duration(seconds: 5));
    result.complete(7);
    expect(await work, 7);
    expect(notifications, 0);
  });
}
