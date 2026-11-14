import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../recruitment_list/data/membership_readers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/personal_reservations.dart';
import '../../domain/play_availability.dart';
import '../viewmodels/personal_schedule_view_model.dart';
import '../viewmodels/play_availability_view_model.dart';
import 'play_availability_card.dart';

/// Shared account typography is inherited; sizes grow with actual text metrics.
class PersonalScheduleSection extends StatelessWidget {
  const PersonalScheduleSection({
    required this.schedule,
    required this.editor,
    super.key,
  });
  final PersonalScheduleViewModel schedule;
  final PlayAvailabilityViewModel editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([schedule, editor]),
    builder: (context, _) {
      if (!schedule.visible) return const SizedBox.shrink();
      final metrics = ScheduleMetrics.of(context);
      return LayoutBuilder(
        builder: (context, box) {
          final editorWidth = metrics.editorWidth;
          final graphMin = metrics.labelWidth + 6 * metrics.hourWidth;
          final maxWidth =
              editorWidth +
              16 +
              metrics.labelWidth +
              24 * metrics.hourWidth +
              32;
          final width = math.min(box.maxWidth, maxWidth);
          final horizontal = width - 32 >= editorWidth + 16 + graphMin;
          final graph = _PersonalScheduleGraph(
            schedule: schedule,
            editor: editor,
            metrics: metrics,
          );
          final setting = editor.visible
              ? PlayAvailabilityCard(model: editor, embedded: true)
              : const Text('가능 시간을 설정하려면 원정대 인증이 필요합니다.');
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: editor.busy
                            ? null
                            : () {
                                if (editor.visible &&
                                    editor.expanded == schedule.expanded) {
                                  editor.toggle();
                                }
                                schedule.toggle();
                              },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '레이드 진행 가능 시간',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Icon(
                                schedule.expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!schedule.expanded)
                        Text(
                          editor.value?.intervals.isNotEmpty == true
                              ? '가능 시간과 내 예약을 확인하세요.'
                              : '설정한 시간이 없습니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (schedule.expanded) ...[
                        const SizedBox(height: 16),
                        if (horizontal)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: editorWidth, child: setting),
                              const SizedBox(width: 16),
                              Expanded(child: graph),
                            ],
                          )
                        else ...[
                          setting,
                          const SizedBox(height: 16),
                          graph,
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class ScheduleMetrics {
  const ScheduleMetrics(
    this.hourWidth,
    this.labelWidth,
    this.rowHeight,
    this.editorWidth,
  );
  final double hourWidth, labelWidth, rowHeight, editorWidth;
  static ScheduleMetrics of(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Size measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final hour = measure('24', theme.bodySmall);
    final label = measure('수 11/28', theme.bodySmall);
    final time = measure('다음 날 23:55', theme.labelLarge);
    return ScheduleMetrics(
      math.max(48, hour.width + 16),
      label.width + 16,
      math.max(48, label.height + 24),
      math.max(280, time.width * 2 + 96),
    );
  }
}

class _PersonalScheduleGraph extends StatefulWidget {
  const _PersonalScheduleGraph({
    required this.schedule,
    required this.editor,
    required this.metrics,
  });
  final PersonalScheduleViewModel schedule;
  final PlayAvailabilityViewModel editor;
  final ScheduleMetrics metrics;
  @override
  State<_PersonalScheduleGraph> createState() => _PersonalScheduleGraphState();
}

class _PersonalScheduleGraphState extends State<_PersonalScheduleGraph> {
  double startHour = 18;
  String? selected;
  final _lanes = <String, int>{};
  final _laneCounts = List<int>.filled(7, 1);
  @override
  Widget build(BuildContext context) {
    final model = widget.schedule, editor = widget.editor, m = widget.metrics;
    final key = model.key;
    final reservations = key == null
        ? <ScheduleSegment>[]
        : reservationSegments(model.items, key);
    _lanes.clear();
    for (var day = 0; day < 7; day++) {
      final ends = <double>[];
      for (final segment in reservations.where((s) => s.day == day)) {
        var lane = ends.indexWhere((end) => end <= segment.start);
        if (lane < 0) {
          lane = ends.length;
          ends.add(segment.end);
        } else {
          ends[lane] = segment.end;
        }
        _lanes['$day:${segment.reservation!.id}'] = lane;
      }
      _laneCounts[day] = math.max(1, ends.length);
    }
    final rows = editor.expanded && !editor.hasPending
        ? editor.draft
        : editor.value?.intervals ?? <PlayTimeRow>[];
    final availability = availabilitySegments(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final next in [false, true])
              OutlinedButton(
                onPressed: next == model.nextWeek
                    ? null
                    : () {
                        setState(() => selected = null);
                        model.selectWeek(next);
                      },
                child: Text(next ? '다음 주' : '이번 주'),
              ),
            OutlinedButton.icon(
              onPressed: model.canReload ? model.reload : null,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (key != null)
          Text(
            '$key ~ ${calendarStart(key).add(kstOffset).add(const Duration(days: 6)).toIso8601String().substring(0, 10)} · 한국 시간',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _legend(context, AppColors.primarySoft, '가능 시간'),
            _legend(context, AppColors.primaryStrong, '내 예약'),
          ],
        ),
        if (editor.hasDraftChanges && editor.editable)
          Text(
            '편집 중인 가능 시간 · 저장 전',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (editor.value == null)
          Text(editor.loading ? '가능 시간을 불러오는 중입니다.' : '가능 시간 설정을 확인해 주세요.')
        else if (rows.where((r) => r.valid).isEmpty)
          const Text('설정한 가능 시간이 없습니다.'),
        if (rows.any((r) => !r.valid)) const Text('입력 중인 시간은 그래프에 표시하지 않습니다.'),
        if (model.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (model.failure != null) ...[
          const Text('예약을 불러오지 못했습니다. 새로고침해 주세요.'),
          if (model.retryAt != null) Text('다시 시도 가능: ${_time(model.retryAt!)}'),
        ],
        if (model.checkedAt != null)
          Text(
            '${model.failure == null ? '확인' : '이전 조회'}: ${_time(model.checkedAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (model.checkedAt != null && model.items.isEmpty)
          const Text('예약된 레이드가 없습니다.'),
        if (key != null)
          LayoutBuilder(
            builder: (context, box) {
              final available = math.max(0.0, box.maxWidth - m.labelWidth);
              final hours = [24, 18, 12, 6].firstWhere(
                (h) => available >= h * m.hourWidth,
                orElse: () => 6,
              );
              final from = startHour.clamp(0.0, 24.0 - hours);
              final plotWidth = math.max(hours * m.hourWidth, available);
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final hour in [0, 6, 12, 18, 24])
                        Text(
                          hour.toString().padLeft(2, '0'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  Slider(
                    value: from,
                    min: 0,
                    max: math.max(1, 24.0 - hours),
                    label: '${from.round()}:00',
                    divisions: math.max(1, 24 - hours),
                    onChanged: hours == 24
                        ? null
                        : (v) => setState(() => startHour = v),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '이전 시간',
                        onPressed: from > 0
                            ? () => setState(
                                () => startHour = math.max(0, from - 1),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${playClock((from * 60).round())}–${playClock(((from + hours) * 60).round())}',
                      ),
                      IconButton(
                        tooltip: '다음 시간',
                        onPressed: from + hours < 24
                            ? () => setState(() => startHour = from + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: m.labelWidth,
                        child: Column(
                          children: [
                            SizedBox(height: m.rowHeight),
                            for (var day = 0; day < 7; day++)
                              SizedBox(
                                height: _height(reservations, day, m) + 8,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${playWeekdayLabels[playWeekdays[day] - 1]} ${_date(key, day)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: plotWidth,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: m.rowHeight,
                                  child: Stack(
                                    children: [
                                      for (var h = 0; h <= hours; h++)
                                        Positioned(
                                          left: h == hours
                                              ? null
                                              : plotWidth * h / hours,
                                          right: h == hours ? 0 : null,
                                          top: 12,
                                          child: Text(
                                            '${(from + h).round()}'.padLeft(
                                              2,
                                              '0',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                for (var day = 0; day < 7; day++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _day(
                                      context,
                                      day,
                                      reservations,
                                      availability,
                                      from * 60,
                                      hours * 60.0,
                                      plotWidth,
                                      m,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _openReservation(PersonalReservation reservation) async {
    if (selected != null) return;
    final model = widget.schedule;
    final user = model.session.userId;
    final generation = model.session.generation;
    bool current() =>
        model.visible &&
        model.session.userId == user &&
        model.session.generation == generation;
    setState(() => selected = reservation.id);
    try {
      final navigate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ListenableBuilder(
          listenable: model.session,
          builder: (context, _) => AlertDialog(
            title: Text(current() ? reservation.raidName : '로그인 상태가 변경되었습니다.'),
            content: current()
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reservation.characterName),
                        Text(_reservationTime(reservation)),
                      ],
                    ),
                  )
                : null,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('닫기'),
              ),
              if (current())
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('이동'),
                ),
            ],
          ),
        ),
      );
      if (!mounted || navigate != true || !current()) return;
      context.go(
        recruitmentFromTab(
          membershipDetailLocation(reservation.roomId, reservation.cycleKey),
          'account',
        ),
      );
    } finally {
      if (mounted) setState(() => selected = null);
    }
  }

  double _height(List<ScheduleSegment> r, int day, ScheduleMetrics m) =>
      _laneCounts[day] * m.rowHeight;
  Widget _day(
    BuildContext context,
    int day,
    List<ScheduleSegment> reservations,
    List<ScheduleSegment> availability,
    double from,
    double length,
    double width,
    ScheduleMetrics m,
  ) {
    final r = reservations.where((s) => s.day == day).toList();
    final height = _height(reservations, day, m);
    Widget? bar(
      ScheduleSegment s,
      double top,
      double h,
      Color color, {
      bool interactive = false,
    }) {
      final a = math.max(from, s.start), b = math.min(from + length, s.end);
      if (a >= b) return null;
      final left = (a - from) / length * width;
      final visualWidth = math.max(2.0, (b - a) / length * width);
      final label = s.reservation == null
          ? '가능 시간'
          : '${s.reservation!.raidName}, ${s.reservation!.characterName}, ${_reservationTime(s.reservation!)}';
      final visual = DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: s.reservation?.id == selected && selected != null
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
        ),
      );
      if (!interactive) {
        return Positioned(
          left: left,
          top: top,
          width: math.min(visualWidth, width - left),
          height: h,
          child: visual,
        );
      }
      final hitWidth = math.min(width, math.max(48.0, visualWidth));
      final hitLeft = (left - (hitWidth - visualWidth) / 2).clamp(
        0.0,
        math.max(0.0, width - hitWidth),
      );
      return Positioned(
        left: hitLeft.toDouble(),
        top: top,
        width: hitWidth,
        height: h,
        child: Semantics(
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: InkWell(
              onTap: () => _openReservation(s.reservation!),
              child: Stack(
                children: [
                  Positioned(
                    left: left - hitLeft,
                    top: 10,
                    width: math.min(visualWidth, width - left),
                    height: h - 20,
                    child: visual,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
            ),
            for (final s in availability.where((s) => s.day == day))
              ?bar(s, 0, height, AppColors.primarySoft),
            for (var i = 0; i < r.length; i++)
              ?bar(
                r[i],
                _lanes['$day:${r[i].reservation!.id}']! * m.rowHeight,
                m.rowHeight,
                AppColors.primaryStrong,
                interactive: true,
              ),
            for (var hour = 1; hour < length ~/ 60; hour++)
              Positioned(
                left: width * hour / (length / 60),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
  String _date(String key, int day) {
    final date = calendarStart(key).add(kstOffset).add(Duration(days: day));
    return '${date.month}/${date.day}';
  }

  String _time(DateTime time) => time
      .toUtc()
      .add(kstOffset)
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', ' ');

  String _reservationTime(PersonalReservation reservation) {
    String local(DateTime value) =>
        value.toUtc().add(kstOffset).toIso8601String();
    final start = local(reservation.start), end = local(reservation.end);
    return '${start.substring(2, 10)} ${start.substring(11, 16)} ~ ${end.substring(11, 16)}';
  }
}
