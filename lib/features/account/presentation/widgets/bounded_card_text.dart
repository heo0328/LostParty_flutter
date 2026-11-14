import 'package:flutter/material.dart';

/// Shrinks text only, never its surrounding padding or interactive target.
class BoundedCardText extends StatelessWidget {
  const BoundedCardText(
    this.text, {
    required this.style,
    this.preserveValue = false,
    super.key,
  });
  final String text;
  final TextStyle? style;
  final bool preserveValue;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final effective = DefaultTextStyle.of(context).style.merge(style);
      final base = effective.fontSize ?? 14;
      final scaler = MediaQuery.textScalerOf(context);
      bool fits(double size) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: effective.copyWith(fontSize: size),
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: box.maxWidth);
        final result =
            !painter.didExceedMaxLines && painter.width <= box.maxWidth;
        painter.dispose();
        return result;
      }

      var low = base * .7, high = base;
      if (fits(base)) {
        low = base;
      } else {
        for (var i = 0; i < 10; i++) {
          final middle = (low + high) / 2;
          if (fits(middle)) {
            low = middle;
          } else {
            high = middle;
          }
        }
      }
      final wrap = preserveValue && !fits(low);
      return Tooltip(
        message: text,
        child: Semantics(
          label: text,
          excludeSemantics: true,
          child: Text(
            text,
            style: effective.copyWith(fontSize: low),
            maxLines: wrap ? null : 1,
            softWrap: wrap,
            overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      );
    },
  );
}
