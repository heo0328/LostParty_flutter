import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Compact account utilities; callbacks retain their existing command owners.
class AccountToolsGrid extends StatelessWidget {
  const AccountToolsGrid({
    required this.onVerify,
    required this.onKey,
    required this.onHistory,
    required this.onRefresh,
    super.key,
  });

  final VoidCallback onVerify, onKey, onHistory;
  final VoidCallback? onRefresh;

  static const labels = [
    '원정대 인증',
    '로스트아크 API 관리',
    '사라진 캐릭터명 기록',
    '서버 정보 다시 불러오기',
  ];

  /// Two buttons plus fixed padding/gap; grows with the actual font and scaler.
  static double buttonWidth(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!;
    var width = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    return width.ceilToDouble() + 16;
  }

  static double preferredWidth(BuildContext context) =>
      buttonWidth(context) * 2 + 16;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final natural = buttonWidth(context);
      final columns = constraints.maxWidth >= natural * 2 + 16 ? 2 : 1;
      final width = columns == 2 ? natural : constraints.maxWidth;
      final actions = [onVerify, onKey, onHistory, onRefresh];
      return Wrap(
        spacing: 16,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++)
            SizedBox(
              width: width,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  alignment: Alignment.center,
                  backgroundColor: AppColors.primarySubtle,
                  foregroundColor: AppColors.primaryStrong,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                onPressed: actions[i],
                child: Text(labels[i], textAlign: TextAlign.center),
              ),
            ),
        ],
      );
    },
  );
}
