import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/bounded_card_text.dart';

void main() {
  testWidgets(
    'shrink is bounded, whole text stays accessible, numeric overflow wraps',
    (tester) async {
      for (final scale in [1.0, 1.5, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 75,
                      child: BoundedCardText(
                        '긴캐릭터이름LongName123',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    SizedBox(
                      width: 75,
                      child: BoundedCardText(
                        '전투력 12345678901234567890',
                        style: TextStyle(fontSize: 16),
                        preserveValue: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final name = tester.widget<Text>(find.text('긴캐릭터이름LongName123'));
        expect(name.style!.fontSize, inInclusiveRange(12.6 - .0001, 18));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(find.byTooltip('긴캐릭터이름LongName123'), findsOneWidget);
        final number = tester.widget<Text>(
          find.text('전투력 12345678901234567890'),
        );
        expect(number.maxLines, isNull);
        expect(number.overflow, TextOverflow.visible);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
