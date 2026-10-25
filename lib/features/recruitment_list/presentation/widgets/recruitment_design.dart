import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/domain/member_cycle_models.dart';

// Penpot03: approved white cards and solid lavender controls, not default chips.
const recruitmentSelectionFill = Color(0xFFEEE7F8);

class RecruitmentWeekTabs extends StatelessWidget {
  const RecruitmentWeekTabs({
    super.key,
    required this.cycles,
    required this.value,
    required this.onChanged,
  });
  final MemberCycles cycles;
  final String? value;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: recruitmentSelectionFill,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final entry in {
          cycles.current.key: '이번주',
          cycles.next.key: '다음주',
        }.entries)
          Expanded(
            child: RecruitmentOptionButton(
              text: entry.value,
              selected: value == entry.key,
              height: 32,
              fontSize: 13,
              onPressed: onChanged == null ? null : () => onChanged!(entry.key),
            ),
          ),
      ],
    ),
  );
}

class RecruitmentDesignCard extends StatelessWidget {
  const RecruitmentDesignCard({
    super.key,
    required this.child,
    this.padding = 14,
    this.bottom = 16,
  });
  final Widget child;
  final double padding, bottom;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: bottom),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
    ),
    child: child,
  );
}

class RecruitmentOptionButton extends StatelessWidget {
  const RecruitmentOptionButton({
    super.key,
    required this.text,
    required this.selected,
    required this.onPressed,
    this.height = 30,
    this.fontSize = 12,
  });
  final String text;
  final bool selected;
  final VoidCallback? onPressed;
  final double height, fontSize;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: selected ? AppColors.primary : recruitmentSelectionFill,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                widthFactor: 1,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: selected ? Colors.white : AppColors.primary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RecruitmentPrimaryButton extends StatelessWidget {
  const RecruitmentPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 44,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: secondary
            ? recruitmentSelectionFill
            : AppColors.primary,
        foregroundColor: secondary ? AppColors.primary : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

InputDecoration recruitmentPaleInput({String? hint, String? error}) =>
    InputDecoration(
      hintText: hint,
      errorText: error,
      errorMaxLines: 3,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
