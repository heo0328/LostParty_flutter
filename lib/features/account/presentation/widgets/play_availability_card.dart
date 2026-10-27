import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/play_availability.dart';
import '../viewmodels/play_availability_view_model.dart';

class PlayAvailabilityCard extends StatelessWidget {
  const PlayAvailabilityCard({required this.model, super.key});
  final PlayAvailabilityViewModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (!model.visible) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Card(
        key: const ValueKey('play-availability-card'),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: model.busy ? null : model.toggle,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '레이드 진행 가능 시간',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (model.busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    Icon(
                      model.expanded ? Icons.expand_less : Icons.expand_more,
                      semanticLabel: model.expanded ? '접기' : '펼치기',
                    ),
                  ],
                ),
              ),
              if (!model.expanded) ...[
                const SizedBox(height: 8),
                Text(
                  model.value == null
                      ? (model.loading
                            ? '시간 설정을 불러오는 중입니다.'
                            : '시간 설정을 확인해 주세요.')
                      : _summary(model.value!.intervals),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (model.expanded && model.value != null) ...[
                const SizedBox(height: 16),
                const Text('플레이할 수 있는 요일과 시간을 선택해 주세요.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final day in playWeekdays)
                      FilterChip(
                        key: ValueKey('play-day-$day'),
                        label: Text(playWeekdayLabels[day - 1]),
                        selected: model.draft.any((r) => r.weekday == day),
                        onSelected: model.editable
                            ? (_) => model.selectDay(day)
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final day in playWeekdays) ..._dayRows(context, day),
                const SizedBox(height: 8),
                Text(
                  '24시간제 · 5분 단위 · 다음 날 종료 가능\n한 구간 최대 24시간 · 한국 시간',
                  style: theme.textTheme.bodySmall,
                ),
                if (!model.validDraft)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '각 구간의 시작과 종료를 설정해 주세요. 길이는 0시간 초과, 24시간 이하여야 합니다.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
              if (model.failure != null) ...[
                const SizedBox(height: 8),
                Text(
                  _failure(model.failure!),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (model.notice != null) ...[
                const SizedBox(height: 8),
                Text(model.notice!),
                if (model.expanded)
                  Text(
                    '서버 저장값: ${_summary(model.value?.intervals ?? [])}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
              if (model.hasPending && !model.saving) ...[
                const SizedBox(height: 8),
                const Text('저장 결과 확인이 필요합니다. 재시도해도 중복 저장되지 않습니다.'),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: model.canRetry ? model.retry : null,
                      child: const Text('저장 재시도'),
                    ),
                    TextButton(
                      onPressed: model.busy
                          ? null
                          : () => _reviewPending(context),
                      child: const Text('저장값 확인'),
                    ),
                  ],
                ),
              ] else if (model.needsReview ||
                  (model.value == null && !model.loading))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: model.busy ? null : model.reload,
                    child: Text(model.needsReview ? '최신 값 확인' : '다시 불러오기'),
                  ),
                ),
              if (model.expanded && model.value != null) ...[
                const SizedBox(height: 16),
                if (model.notice != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: model.editable ? model.useServer : null,
                      child: const Text('서버 값으로 편집'),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: model.busy ? null : model.cancel,
                      child: Text(model.hasPending ? '닫기' : '취소'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: model.canSave ? model.save : null,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  List<Widget> _dayRows(BuildContext context, int day) {
    final rows = model.draft.where((r) => r.weekday == day).toList();
    return [
      for (var index = 0; index < rows.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: index == 0
                    ? Text(playWeekdayLabels[day - 1])
                    : IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 48,
                        ),
                        onPressed: model.editable
                            ? () => model.removeRow(rows[index])
                            : null,
                        icon: Icon(
                          Icons.remove,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: '시간 구간 삭제',
                      ),
              ),
              Expanded(
                flex: 10,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: model.editable
                      ? () => _pick(context, rows[index], false)
                      : null,
                  child: Text(
                    rows[index].start == null
                        ? '시작'
                        : playClock(rows[index].start!),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('–'),
              ),
              Expanded(
                flex: 14,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: model.editable
                      ? () => _pick(context, rows[index], true)
                      : null,
                  child: Text(
                    rows[index].end == null
                        ? '종료'
                        : '${rows[index].endDayOffset == 1 ? '다음 날 ' : ''}${playClock(rows[index].end!)}',
                  ),
                ),
              ),
              if (index == 0)
                IconButton(
                  onPressed: model.editable ? () => model.addRow(day) : null,
                  icon: const Icon(Icons.add),
                  tooltip: '시간 구간 추가',
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
    ];
  }

  Future<void> _pick(BuildContext context, PlayTimeRow row, bool ending) async {
    final result = await showModalBottomSheet<PlayTimeRow>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlayTimePicker(row: row, ending: ending),
    );
    if (result != null) model.replaceRow(row, result);
  }

  Future<void> _reviewPending(BuildContext context) async {
    final generation = model.editGeneration;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('현재 저장값을 확인할까요?'),
        content: const Text(
          '처리 중인 요청은 나중에 반영될 수 있습니다. 초안을 유지하고 현재 서버 값을 확인합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (accepted == true && generation == model.editGeneration) {
      await model.reviewPending();
    }
  }
}

String _summary(List<PlayTimeRow> rows) {
  if (rows.isEmpty) return '설정한 시간이 없습니다.';
  final ordered = [
    for (final day in playWeekdays) ...rows.where((r) => r.weekday == day),
  ];
  final r = ordered.first;
  return '${playWeekdayLabels[r.weekday - 1]} ${playClock(r.start!)}–${r.endDayOffset == 1 ? '다음 날 ' : ''}${playClock(r.end!)}${rows.length > 1 ? ' 외 ${rows.length - 1}구간' : ''}';
}

String _failure(String code) => switch (code) {
  'REVISION_CONFLICT' => '다른 변경이 확인됐습니다. 최신 값을 확인해 주세요. 초안은 유지됩니다.',
  'OWNERSHIP_REQUIRED' => '원정대 인증 상태를 확인해 주세요.',
  'REQUEST_TOO_LARGE' => '시간 구간이 너무 많습니다. 일부 구간을 줄여 주세요.',
  'INVALID_REQUEST' => '입력한 시간 구간을 확인해 주세요.',
  'RATE_LIMITED' || 'REQUEST_IN_PROGRESS' => '잠시 후 다시 시도해 주세요.',
  'IDEMPOTENCY_EXPIRED' ||
  'IDEMPOTENCY_CONFLICT' => '최신 저장값을 확인한 뒤 다시 저장해 주세요.',
  _ => '시간 설정을 확인하거나 저장하지 못했습니다. 초안은 유지됩니다.',
};

class _PlayTimePicker extends StatefulWidget {
  const _PlayTimePicker({required this.row, required this.ending});
  final PlayTimeRow row;
  final bool ending;
  @override
  State<_PlayTimePicker> createState() => _PlayTimePickerState();
}

class _PlayTimePickerState extends State<_PlayTimePicker> {
  late int hour, minute, offset;
  late final FixedExtentScrollController hours, minutes;
  @override
  void initState() {
    super.initState();
    final time = (widget.ending ? widget.row.end : widget.row.start) ?? 0;
    hour = time ~/ 60;
    minute = time % 60;
    offset = widget.row.endDayOffset;
    hours = FixedExtentScrollController(initialItem: hour);
    minutes = FixedExtentScrollController(initialItem: minute ~/ 5);
  }

  @override
  void dispose() {
    hours.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.row.withTime(
      ending: widget.ending,
      minute: hour * 60 + minute,
      offset: offset,
    );
    final invalid = result.duration != null && !result.valid;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${playWeekdayLabels[widget.row.weekday - 1]}요일 ${widget.ending ? '종료' : '시작'} 시간',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
              ],
            ),
            if (widget.ending)
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('같은 날')),
                  ButtonSegment(value: 1, label: Text('다음 날')),
                ],
                selected: {offset},
                onSelectionChanged: (value) =>
                    setState(() => offset = value.single),
              ),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: hours,
                      itemExtent: 40,
                      onSelectedItemChanged: (n) => setState(() => hour = n),
                      children: [
                        for (var i = 0; i < 24; i++)
                          Center(
                            child: Text('${i.toString().padLeft(2, '0')} 시'),
                          ),
                      ],
                    ),
                  ),
                  const Text(':'),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: minutes,
                      itemExtent: 40,
                      onSelectedItemChanged: (n) =>
                          setState(() => minute = n * 5),
                      children: [
                        for (var i = 0; i < 60; i += 5)
                          Center(
                            child: Text('${i.toString().padLeft(2, '0')} 분'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (result.duration != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  invalid
                      ? '한 구간은 0시간 초과, 최대 24시간입니다.'
                      : '${playClock(result.start!)} → ${result.endDayOffset == 1 ? '다음 날 ' : ''}${playClock(result.end!)} · ${result.duration! ~/ 60}시간 ${result.duration! % 60}분',
                  style: TextStyle(
                    color: invalid ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: invalid
                      ? null
                      : () => Navigator.pop(context, result),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
