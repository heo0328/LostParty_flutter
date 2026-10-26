import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/recruitment_time_picker.dart';

void main() {
  for (final initial in [0, 720, 1083]) {
    testWidgets(
      'localized dial preserves minute $initial and cancel is unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? result = -1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(0.8),
                alwaysUse24HourFormat: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await showRecruitmentTimePicker(
                        context,
                        initial: initial,
                      ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        final picker = tester.widget<TimePickerDialog>(
          find.byType(TimePickerDialog),
        );
        expect(picker.initialEntryMode, TimePickerEntryMode.dial);
        expect(
          picker.initialTime.hour * 60 + picker.initialTime.minute,
          initial,
        );
        expect(find.text('시간 선택'), findsOneWidget);
        expect(find.text('오전'), findsOneWidget);
        expect(find.text('오후'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('시간'), findsOneWidget);
        expect(find.text('분'), findsOneWidget);
        await tester.tap(find.text('선택'));
        await tester.pumpAndSettle();
        expect(result, initial);
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
