import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/lost_party_entry_screen.dart';

void main() {
  testWidgets('entry retains static image without animation layers', (
    tester,
  ) async {
    await tester.pumpWidget(const LostPartyEntryScreen());
    expect(find.byKey(const ValueKey('lostPartyEntryScreen')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('lostPartyEntryGlow')), findsNothing);
    expect(find.byKey(const ValueKey('lostPartyEntryTwinkles')), findsNothing);
    expect(find.byKey(const ValueKey('lostPartyEntryShine')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
