import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

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

  testWidgets(
    'Missing token dialog can be dismissed without blocking the app',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
      await tester.pumpAndSettle();

      expect(find.text('API 토큰 필요'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('API 토큰 필요'), findsNothing);

      await tester.tap(find.text('파티 모집'));
      await tester.pumpAndSettle();

      expect(find.text('Recruitments'), findsOneWidget);
    },
  );

  testWidgets('Token can be registered without exposing it again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('토큰 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('apiTokenField')),
      'secret-jwt-value',
    );
    await tester.tap(find.text('토큰 저장'));
    await tester.pumpAndSettle();

    expect(find.text('내 계정'), findsNWidgets(2));
    expect(find.text('secret-jwt-value'), findsNothing);

    await tester.tap(find.byTooltip('API 토큰 설정'));
    await tester.pumpAndSettle();

    expect(find.text('토큰 등록됨'), findsOneWidget);
    expect(find.text('secret-jwt-value'), findsNothing);
  });
}
