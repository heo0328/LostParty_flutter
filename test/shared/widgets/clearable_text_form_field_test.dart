import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/widgets/clearable_text_form_field.dart';

void main() {
  testWidgets('값이 있을 때만 지우기 버튼을 표시하고 전체 입력을 지운다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClearableTextFormField(
            controller: controller,
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    expect(find.byTooltip('입력 지우기'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '테스트');
    await tester.pump();
    expect(find.byTooltip('입력 지우기'), findsOneWidget);

    await tester.tap(find.byTooltip('입력 지우기'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changedValue, isEmpty);
    expect(find.byTooltip('입력 지우기'), findsNothing);
  });

  testWidgets('기존 후행 동작과 지우기 버튼을 함께 표시한다', (tester) async {
    final controller = TextEditingController(text: 'token');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClearableTextFormField(
            controller: controller,
            trailing: IconButton(
              tooltip: '내용 표시',
              onPressed: () {},
              icon: const Icon(Icons.visibility),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('입력 지우기'), findsOneWidget);
    expect(find.byTooltip('내용 표시'), findsOneWidget);
  });
}
