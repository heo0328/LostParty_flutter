import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/startup_entry_gate.dart';

void main() {
  testWidgets(
    'ready cache enters after animation without waiting for network',
    (tester) async {
      final gate = StartupEntryGate()..start();
      addTearDown(gate.dispose);
      gate.update(sessionResolved: true, displayReady: true);
      expect(gate.canEnter, isFalse);
      gate.animationCompleted();
      expect(gate.canEnter, isTrue);
      gate.update(sessionResolved: false, displayReady: false);
      await tester.pump(const Duration(seconds: 10));
      expect(gate.canEnter, isTrue);
    },
  );

  testWidgets(
    'deadline releases presentation even when session is unresolved',
    (tester) async {
      final gate = StartupEntryGate()..start();
      addTearDown(gate.dispose);
      gate.animationCompleted();
      gate.update(sessionResolved: false, displayReady: true);
      await tester.pump(const Duration(milliseconds: 5999));
      expect(gate.canEnter, isFalse);
      gate.start(); // Re-entry must not extend the original deadline.
      await tester.pump(const Duration(milliseconds: 1));
      expect(gate.canEnter, isTrue);
    },
  );

  testWidgets('member change invalidates ready cache before entry', (
    tester,
  ) async {
    final gate = StartupEntryGate()..start();
    addTearDown(gate.dispose);
    gate.update(sessionResolved: true, displayReady: true);
    gate.update(sessionResolved: false, displayReady: false);
    gate.animationCompleted();
    expect(gate.canEnter, isFalse);
    gate.update(sessionResolved: true, displayReady: true);
    expect(gate.canEnter, isTrue);
  });

  testWidgets(
    'animation completed before service setup does not skip readiness',
    (tester) async {
      final gate = StartupEntryGate()..animationCompleted();
      addTearDown(gate.dispose);
      await tester.pump(const Duration(seconds: 10));
      expect(gate.canEnter, isFalse);
      gate.start();
      gate.update(
        sessionResolved: true,
        displayReady: true,
      ); // Guest is ready too.
      expect(gate.canEnter, isTrue);
    },
  );

  testWidgets('disposing presentation neither notifies late nor cancels work', (
    tester,
  ) async {
    final result = Completer<int>();
    final work = result.future;
    var notifications = 0;
    final gate = StartupEntryGate()..start();
    gate.addListener(() => notifications++);
    gate.animationCompleted();
    gate.dispose();
    await tester.pump(const Duration(seconds: 10));
    gate.update(sessionResolved: true, displayReady: true);
    result.complete(7);
    expect(await work, 7);
    expect(notifications, 0);
  });
}
