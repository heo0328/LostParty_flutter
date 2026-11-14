import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'account_responsive_layout.dart';

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

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AccountResponsiveLayout.toolsMaxWidth,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 16) / 2;
          final labels = [
            '원정대 인증',
            '로스트아크 API 관리',
            '사라진 캐릭터명 기록',
            '서버 정보 다시 불러오기',
          ];
          final actions = [onVerify, onKey, onHistory, onRefresh];
          return Wrap(
            spacing: 16,
            runSpacing: 20,
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
      ),
    ),
  );
}
