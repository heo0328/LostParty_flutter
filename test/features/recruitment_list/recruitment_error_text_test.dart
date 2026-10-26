import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/recruitment_error_text.dart';

void main() {
  const message =
      '이전 요청의 결과를 확인하지 못했습니다. 잠시 후 같은 요청을 다시 확인해 주세요. 자리 중복과 파티별 직업·역할 구성을 확인해 주세요.';
  for (final width in [160.0, 320.0]) {
    for (final scale in [0.8, 1.8]) {
      testWidgets(
        'complete error fits two lines at width $width scale $scale',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: const RecruitmentErrorText(message),
                  ),
                ),
              ),
            ),
          );
          final text = tester.widget<Text>(find.text(message));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(message),
          );
          expect(text.maxLines, 2);
          expect(text.style!.fontSize, lessThan(24));
          expect(paragraph.didExceedMaxLines, false);
          expect(paragraph.size.width, lessThanOrEqualTo(width));
          expect(text.data, message);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'short error keeps emphasis and refits when available width changes',
    (tester) async {
      var width = 160.0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return SizedBox(
                  width: width,
                  child: const RecruitmentErrorText('다시 시도해 주세요.'),
                );
              },
            ),
          ),
        ),
      );
      final small = tester
          .widget<Text>(find.text('다시 시도해 주세요.'))
          .style!
          .fontSize!;
      update(() => width = 500);
      await tester.pump();
      expect(tester.widget<Text>(find.text('다시 시도해 주세요.')).style!.fontSize, 24);
      expect(small, lessThanOrEqualTo(24));
      expect(tester.takeException(), isNull);
    },
  );
}
