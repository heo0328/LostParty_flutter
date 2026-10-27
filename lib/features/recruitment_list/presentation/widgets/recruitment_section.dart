import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class RecruitmentSection extends StatelessWidget {
  const RecruitmentSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class RecruitmentBadge extends StatelessWidget {
  const RecruitmentBadge(this.text, {this.success = false, super.key});
  final String text;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: success ? AppColors.successContainer : AppColors.primarySubtle,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: success ? AppColors.success : AppColors.primary,
      ),
    ),
  );
}
