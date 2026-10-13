import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/backend_app.dart';

void main() {
  testWidgets(
    'Backend debug startup keeps entry background behind URL dialog',
    (tester) async {
      await tester.pumpWidget(const BackendApp());
      await tester.pump();
      expect(
        find.byKey(const ValueKey('lostPartyEntryScreen')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('lostPartyEntryGlow')), findsOneWidget);
      expect(find.byKey(const ValueKey('lostPartyEntryShine')), findsNothing);
      expect(find.text('개발 서버 Base URL'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      final background = tester.widgetList<Image>(find.byType(Image)).single;
      expect(
        (background.image as AssetImage).assetName,
        'assets/images/lost_party_loading_screen.png',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
