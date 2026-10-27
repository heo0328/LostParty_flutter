import 'package:flutter/material.dart';
import '../../domain/beta_schedule_draft.dart';
import '../../domain/policies/recruitment_start_policy.dart';
import '../../data/cycle_schedule.dart';
import 'recruitment_time_picker.dart';

/// The same single-date and local start policy used by recruitment creation.
class BetaScheduleEditor extends StatefulWidget {
  const BetaScheduleEditor({
    super.key,
    required this.target,
    required this.now,
    required this.duration,
    required this.capacity,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showCoordination = true,
    this.scopeKey,
  });
  final String target;
  final DateTime now;
  final int duration, capacity;
  final BetaScheduleInput value;
  final ValueChanged<BetaScheduleInput> onChanged;
  final bool enabled, showCoordination;
  final Object? Function()? scopeKey;

  static bool valid(
    String target,
    DateTime now,
    int duration,
    int capacity,
    BetaScheduleInput value,
  ) =>
      value.weekday != null &&
      value.minute != null &&
      (!value.enabled ||
          value.additional >= 1 && value.additional < capacity) &&
      const RecruitmentStartPolicy().allows(
        now: now,
        weekday: value.weekday!,
        minute: value.minute!,
        durationMinutes: duration,
        targetCycleKey: target,
        precision: StartTimePrecision.minute,
      );

  static Map<String, dynamic> config(
    String target,
    BetaScheduleInput value,
  ) => {
    'base_starts_at': cycleScheduleStart(
      target,
      value.weekday!,
      '${(value.minute! ~/ 60).toString().padLeft(2, '0')}:${(value.minute! % 60).toString().padLeft(2, '0')}',
    ).toIso8601String(),
    'early_coordination_enabled': value.enabled,
    'early_additional_members': value.enabled ? value.additional : null,
  };
  @override
  State<BetaScheduleEditor> createState() => _BetaScheduleEditorState();
}

class _BetaScheduleEditorState extends State<BetaScheduleEditor> {
  bool allowed(int day, int minute) => const RecruitmentStartPolicy().allows(
    now: widget.now,
    weekday: day,
    minute: minute,
    durationMinutes: widget.duration,
    targetCycleKey: widget.target,
    precision: StartTimePrecision.minute,
  );

  Future<void> pick() async {
    final value = widget.value, target = widget.target;
    final scope = widget.scopeKey?.call();
    final minute = await showRecruitmentTimePicker(
      context,
      initial: value.minute,
    );
    if (!mounted ||
        !widget.enabled ||
        value != widget.value ||
        target != widget.target ||
        scope != widget.scopeKey?.call() ||
        minute == null) {
      return;
    }
    widget.onChanged(value.copy(minute: minute));
  }

  String? get timeFailure {
    final v = widget.value;
    if (v.weekday == null || v.minute == null) return null;
    return const RecruitmentStartPolicy().failureReason(
      now: widget.now,
      weekday: v.weekday!,
      minute: v.minute!,
      durationMinutes: widget.duration,
      targetCycleKey: widget.target,
      precision: StartTimePrecision.minute,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final day in [3, 4, 5, 6, 7, 1, 2])
            ChoiceChip(
              label: Text(dayLabel(day)),
              selected: widget.value.weekday == day,
              onSelected:
                  widget.enabled &&
                      List.generate(1440, (i) => i).any((m) => allowed(day, m))
                  ? (_) => widget.onChanged(
                      widget.value.copy(weekday: day, clearMinute: true),
                    )
                  : null,
            ),
        ],
      ),
      OutlinedButton.icon(
        onPressed: widget.enabled && widget.value.weekday != null ? pick : null,
        icon: const Icon(Icons.schedule),
        label: Text(
          widget.value.minute == null
              ? '출발 시각 선택'
              : '${(widget.value.minute! ~/ 60).toString().padLeft(2, '0')}:${(widget.value.minute! % 60).toString().padLeft(2, '0')} · KST',
        ),
      ),
      if (timeFailure != null)
        Text(
          timeFailure!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
      if (widget.showCoordination)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            '더 일찍 출발할 수 있으면 자동으로 조율',
            style: TextStyle(fontSize: 12),
          ),
          value: widget.value.enabled,
          onChanged: widget.enabled
              ? (v) => widget.onChanged(widget.value.copy(enabled: v))
              : null,
        ),
      if (widget.showCoordination && widget.value.enabled)
        DropdownButtonFormField<int>(
          key: ValueKey('${widget.capacity}/${widget.value.additional}'),
          initialValue: widget.value.additional < widget.capacity
              ? widget.value.additional
              : null,
          decoration: const InputDecoration(labelText: '공대장 외 추가 참가 인원'),
          items: [
            for (var i = 1; i < widget.capacity; i++)
              DropdownMenuItem(value: i, child: Text('$i명')),
          ],
          onChanged: widget.enabled
              ? (v) {
                  if (v != null) {
                    widget.onChanged(widget.value.copy(additional: v));
                  }
                }
              : null,
        ),
    ],
  );

  String dayLabel(int day) {
    final date = const RecruitmentStartPolicy().dateForDay(
      widget.now,
      day,
      targetCycleKey: widget.target,
    );
    return '${date.month}/${date.day}(${' 월화수목금토일'[day]})';
  }
}
