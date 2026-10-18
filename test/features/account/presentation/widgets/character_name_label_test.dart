import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/character_name_label.dart';

void main() {
  testWidgets(
    'twelve-character name fits two lines beside crown at large text scale',
    (tester) async {
      const name = '가나다라마바사아자차카타';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: const Scaffold(
              body: SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Expanded(child: CharacterNameLabel(name)),
                    Icon(Icons.star, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(name));
      expect(text.maxLines, 2);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2.5),
        maxLines: 2,
      )..layout(maxWidth: 76);
      expect(painter.didExceedMaxLines, isFalse);
      painter.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
