import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Fits two lines without shrinking below readable text; overflow is explicit.
class RecruitmentErrorText extends StatelessWidget {
  const RecruitmentErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var style = DefaultTextStyle.of(
        context,
      ).style.copyWith(color: AppColors.error, fontSize: 24);
      // Text applies these accessibility overrides while building. Measure the
      // same weight/spacing, otherwise a measured two-line label may paint three.
      style = style.copyWith(
        fontWeight: MediaQuery.boldTextOf(context)
            ? FontWeight.bold
            : style.fontWeight,
        letterSpacing:
            MediaQuery.maybeLetterSpacingOverrideOf(context) ??
            style.letterSpacing,
        wordSpacing:
            MediaQuery.maybeWordSpacingOverrideOf(context) ?? style.wordSpacing,
      );
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
            painter.layout(
              maxWidth: (constraints.maxWidth - 1).clamp(0, double.infinity),
            );
            return !painter.didExceedMaxLines &&
                painter.width <= constraints.maxWidth;
          }

          if (!fits(size)) {
            var low = 12.0, high = size;
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
        overflow: TextOverflow.ellipsis,
        semanticsLabel: message,
      );
    },
  );
}
