import 'package:flutter/material.dart';
import '../../domain/member_cycle_models.dart';

class MemberCycleSelector extends StatelessWidget {
  const MemberCycleSelector({
    required this.cycles,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final MemberCycles cycles;
  final String value;
  final void Function(String) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: cycles.current.key, label: const Text('이번 주')),
            ButtonSegment(value: cycles.next.key, label: const Text('다음 주')),
          ],
          selected: {value},
          onSelectionChanged: enabled ? (v) => onChanged(v.single) : null,
        ),
        const SizedBox(height: 6),
        Text(
          '$value ~ ${cycles.find(value)!.endsAt.add(const Duration(hours: 9)).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
