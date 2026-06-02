import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/main.dart';

void main() {
  testWidgets('Recruitment list shows mock recruitments', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Recruitments'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(6));
  });
}
