import 'package:flutter/material.dart';
import '../../domain/member_cycle_models.dart';

class MemberCycleSelector extends StatelessWidget {
  const MemberCycleSelector({
    required this.cycles,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.issueCycles = const {},
    this.contentWidth = false,
    this.stretch = false,
    super.key,
  });
  final MemberCycles cycles;
  final String value;
  final void Function(String) onChanged;
  final bool enabled;
  final Set<String> issueCycles;
  final bool contentWidth;
  final bool stretch;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelStyle = contentWidth
          ? Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.labelLarge?.fontSize ?? 14) + 2,
              fontWeight: FontWeight.bold,
            )
          : null;
      final content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: cycles.current.key,
                  label: Text(
                    '이번 주${issueCycles.contains(cycles.current.key) ? ' ❗' : ''}',
                    style: labelStyle,
                  ),
                ),
                ButtonSegment(
                  value: cycles.next.key,
                  label: Text(
                    '다음 주${issueCycles.contains(cycles.next.key) ? ' ❗' : ''}',
                    style: labelStyle,
                  ),
                ),
              ],
              selected: cycles.find(value) == null ? {} : {value},
              emptySelectionAllowed: cycles.find(value) == null,
              onSelectionChanged: enabled ? (v) => onChanged(v.single) : null,
            ),
            const SizedBox(height: 6),
            Text(
              cycles.find(value) == null
                  ? '대상 주차 $value · 주차를 다시 선택해 주세요.'
                  : '$value ~ ${cycles.find(value)!.endsAt.add(const Duration(hours: 9)).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}',
              textAlign: TextAlign.center,
              style: contentWidth
                  ? Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.bodySmall?.fontSize ??
                              12) +
                          2,
                      fontWeight: FontWeight.bold,
                    )
                  : Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
      if (!contentWidth || stretch || constraints.maxWidth <= 600) {
        return content;
      }
      return Align(
        alignment: Alignment.center,
        child: IntrinsicWidth(child: content),
      );
    },
  );
}
