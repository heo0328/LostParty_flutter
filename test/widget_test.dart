import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/main.dart';

void main() {
  testWidgets('My account is the initial tab', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('내 계정'), findsNWidgets(2));
    expect(find.text('파티 모집'), findsOneWidget);
    expect(find.text('Recruitments'), findsNothing);
  });

  testWidgets('Navigation bar opens the recruitment tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('파티 모집'));
    await tester.pumpAndSettle();

    expect(find.text('Recruitments'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(6));
  });

  testWidgets('Horizontal swipe changes the selected tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Recruitments'), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);
  });
}
