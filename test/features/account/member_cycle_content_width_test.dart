import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/member_cycle_models.dart';
import 'package:lost_party/features/account/presentation/widgets/member_cycle_selector.dart';
import 'backend_read/member_cycles_test.dart' as fixture;

void main() {
  testWidgets(
    'account week selector is compact on wide displays and retains selection',
    (tester) async {
      final cycles = MemberCycles.fromJson(fixture.cycles());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      for (final width in [320.0, 720.0, 1600.0, 2560.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: MemberCycleSelector(
                    contentWidth: true,
                    cycles: cycles,
                    value: cycles.current.key,
                    onChanged: (v) => selected = v,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.byType(SegmentedButton<String>));
          expect(rect.center.dx, closeTo(width / 2, 1));
          if (width > 600) expect(rect.width, lessThan(width));
          await tester.tap(find.text('다음 주'));
          expect(selected, cycles.next.key);
        }
      }
    },
  );
}
