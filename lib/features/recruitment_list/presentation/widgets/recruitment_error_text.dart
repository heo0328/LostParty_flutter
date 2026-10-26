import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Fits the complete error to two lines using the actual available card width.
class RecruitmentErrorText extends StatelessWidget {
  const RecruitmentErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(
        context,
      ).style.copyWith(color: AppColors.error, fontSize: 24);
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      var size = 24.0;
      if (constraints.hasBoundedWidth && constraints.maxWidth > 0) {
        final painter = TextPainter(
          maxLines: 2,
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
        );
        try {
          bool fits(double fontSize) {
            painter.text = TextSpan(
              text: message,
              style: style.copyWith(fontSize: fontSize),
            );
            painter.layout(maxWidth: constraints.maxWidth);
            return !painter.didExceedMaxLines &&
                painter.width <= constraints.maxWidth;
          }

          if (!fits(size)) {
            var low = 0.5, high = size;
            while (high - low > 0.1) {
              final middle = (low + high) / 2;
              if (fits(middle)) {
                low = middle;
              } else {
                high = middle;
              }
            }
            size = low;
          }
        } finally {
          painter.dispose();
        }
      }
      return Text(
        message,
        style: style.copyWith(fontSize: size),
        textScaler: scaler,
        locale: locale,
        textDirection: direction,
        maxLines: 2,
        softWrap: true,
      );
    },
  );
}
