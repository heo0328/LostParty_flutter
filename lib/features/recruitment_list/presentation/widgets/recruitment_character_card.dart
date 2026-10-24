import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatters/display_number_formatter.dart';

/// Presentation only: absent server data stays unknown, never a passing result.
class RecruitmentCharacterCard extends StatelessWidget {
  const RecruitmentCharacterCard({
    required this.name,
    required this.className,
    required this.role,
    required this.itemLevel,
    required this.power,
    required this.status,
    this.warning = false,
    this.itemLevelLabel,
    this.leading,
    this.trailing,
    this.actions,
    super.key,
  });
  final String name, className, role, status;
  final Object? itemLevel, power;
  final String? itemLevelLabel;
  final bool warning;
  final Widget? leading, trailing, actions;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$className · $role',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              itemLevelLabel ?? '아이템레벨 ${itemLevel ?? '확인 필요'}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '전투력 ${DisplayNumberFormatter.whole(power, missing: '확인 필요')}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            color: warning ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        if (actions != null) ...[const SizedBox(height: 10), actions!],
      ],
    ),
  );
}
