import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/policies/recruitment_start_policy.dart';
import '../../domain/policies/party_cycle_policy.dart';
import 'recruitment_design.dart';

const scheduleGreen = Color(0xFF21764E);
const scheduleCommon = Color(0xFFB9DDC8);
const scheduleBusy = Color(0xFFF7DEB1);

String scheduleWeekLabel(String target, String? serverNow) {
  final start = DateTime.parse('${target}T00:00:00Z');
  final end = start.add(const Duration(days: 6));
  final current = serverNow == null
      ? null
      : const PartyCyclePolicy().keyFor(DateTime.parse(serverNow));
  final next = current == null
      ? null
      : DateTime.parse(
          '${current}T00:00:00Z',
        ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
  final prefix = target == current
      ? '이번 주 · '
      : target == next
      ? '다음 주 · '
      : '';
  return '$prefix${start.month}.${start.day}(수)–${end.month}.${end.day}(화)';
}

class ScheduleRefreshButton extends StatelessWidget {
  const ScheduleRefreshButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: recruitmentSelectionFill,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: const Text('내 일정 갱신', maxLines: 1),
    ),
  );
}

/// Scoped to Penpot03's schedule boards; other detail sections keep their UI.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    this.title,
    this.trailing,
    required this.children,
  });
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 16),
        ],
        ...children,
      ],
    ),
  );
}

class ScheduleDaySelector extends StatelessWidget {
  const ScheduleDaySelector({
    super.key,
    required this.target,
    required this.value,
    required this.onChanged,
    this.allowed,
  });
  final String target;
  final int value;
  final ValueChanged<int>? onChanged;
  final bool Function(int)? allowed;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final day in [3, 4, 5, 6, 7, 1, 2]) ...[
        if (day != 3) const SizedBox(width: 5),
        Expanded(
          child: Semantics(
            selected: value == day,
            button: true,
            label: '${date(day).month}월 ${date(day).day}일 ${' 월화수목금토일'[day]}요일',
            child: Material(
              color: value == day ? AppColors.primary : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: value == day ? AppColors.primary : AppColors.outline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('schedule-day-$day'),
                onTap: onChanged == null || allowed?.call(day) == false
                    ? null
                    : () => onChanged!(day),
                child: Opacity(
                  opacity: allowed?.call(day) == false ? 0.4 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      children: [
                        Text(
                          ' 월화수목금토일'[day],
                          style: TextStyle(
                            fontSize: 12,
                            color: value == day
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date(day).day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: value == day
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
  DateTime date(int day) => const RecruitmentStartPolicy().dateForDay(
    DateTime.parse('${target}T00:00:00Z'),
    day,
    targetCycleKey: target,
  );
}

class ScheduleTag extends StatelessWidget {
  const ScheduleTag(
    this.text, {
    super.key,
    this.warning = false,
    this.common = false,
  });
  final String text;
  final bool warning, common;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: warning
          ? const Color(0xFFFFF4DF)
          : common
          ? const Color(0xFFE7F4ED)
          : recruitmentSelectionFill,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: warning
            ? const Color(0xFF9C5D13)
            : common
            ? scheduleGreen
            : AppColors.primary,
      ),
    ),
  );
}

class ScheduleAction extends StatelessWidget {
  const ScheduleAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: secondary
            ? recruitmentSelectionFill
            : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: secondary ? AppColors.primary : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
