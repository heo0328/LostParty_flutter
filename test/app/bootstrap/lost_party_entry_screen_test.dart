import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/lost_party_entry_screen.dart';

void main() {
  testWidgets('진입 연출은 한 번 완료된 뒤 반복하지 않는다', (tester) async {
    var completionCount = 0;

    await tester.pumpWidget(
      LostPartyEntryScreen(onAnimationCompleted: () => completionCount += 1),
    );

    expect(find.byKey(const ValueKey('lostPartyEntryScreen')), findsOneWidget);
    expect(find.byKey(const ValueKey('lostPartyEntryGlow')), findsOneWidget);
    expect(find.byKey(const ValueKey('lostPartyEntryShine')), findsNothing);

    await tester.pump(lostPartyEntryAnimationDuration);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completionCount, 1);

    await tester.pump(lostPartyEntryAnimationDuration);
    expect(completionCount, 1);
  });
}
