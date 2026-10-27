import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/schedule_comparison.dart';
import 'schedule_design.dart';
import 'recruitment_design.dart';

class ScheduleTimeline extends StatefulWidget {
  const ScheduleTimeline({
    super.key,
    required this.comparison,
    required this.weekday,
    required this.selected,
    this.onTimeSelected,
    this.selectedMinute,
  });
  final ScheduleComparison comparison;
  final int weekday;
  final Set<String> selected;
  final ValueChanged<int>? onTimeSelected;
  final int? selectedMinute;
  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  double start = 18 * 60;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth >= 600 ? 720 : 360;
      final from = start.clamp(0, 1440 - width).round();
      final common = widget.comparison.common(widget.weekday, widget.selected);
      final date = widget.comparison.date(widget.weekday);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ScheduleTag('가능 시간'),
              ScheduleTag('다른 예약', warning: true),
              ScheduleTag('공통 가능', common: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in ['00', '06', '12', '18', '24'])
                Text(
                  h,
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, bar) {
              void move(double x) => setState(
                () => start =
                    ((x / bar.maxWidth * 1440 - width / 2) / 30).round() * 30.0,
              );
              return Semantics(
                label: '하루 전체 시간대 이동',
                value: '${clock(from)}–${clock(from + width)}',
                increasedValue:
                    '${clock((from + 30).clamp(0, 1440 - width))}–${clock((from + 30).clamp(0, 1440 - width) + width)}',
                decreasedValue:
                    '${clock((from - 30).clamp(0, 1440 - width))}–${clock((from - 30).clamp(0, 1440 - width) + width)}',
                onIncrease: () => setState(
                  () => start = (from + 30).clamp(0, 1440 - width).toDouble(),
                ),
                onDecrease: () => setState(
                  () => start = (from - 30).clamp(0, 1440 - width).toDouble(),
                ),
                child: GestureDetector(
                  key: const ValueKey('schedule-overview'),
                  onTapDown: (d) => move(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => move(d.localPosition.dx),
                  child: SizedBox(
                    height: 32,
                    child: CustomPaint(
                      painter: _TimelinePainter(
                        available: const [],
                        busy: const [],
                        start: 0,
                        length: 1440,
                        viewport: TimeSpan(from, from + width),
                        overview: widget.comparison.members
                            .map(
                              (m) => (
                                m.availableOn(widget.weekday),
                                m.busyOn(date),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            children: [
              IconButton(
                tooltip: '이전 시간대',
                onPressed: from > 0
                    ? () => setState(
                        () => start = (from - 60)
                            .clamp(0, 1440 - width)
                            .toDouble(),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: Text(
                  '${clock(from)}–${clock(from + width)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                tooltip: '다음 시간대',
                onPressed: from < 1440 - width
                    ? () => setState(
                        () => start = (from + 60)
                            .clamp(0, 1440 - width)
                            .toDouble(),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 68),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i <= width ~/ 60; i++)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(from ~/ 60) + i}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final member in widget.comparison.members)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (member.state != TimetableState.configured)
                            Text(
                              member.state == TimetableState.unset
                                  ? '시간 미설정'
                                  : '조회 불가',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    member.state == TimetableState.unavailable
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          if (!member.busyAvailable)
                            const Text(
                              '예약 조회 불가',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: widget.selected.contains(member.id) ? 1 : .25,
                      child: SizedBox(
                        height: 24,
                        child: CustomPaint(
                          painter: _TimelinePainter(
                            available: member.availableOn(widget.weekday),
                            busy: member.busyOn(date),
                            start: from,
                            length: width,
                            unknown:
                                member.state == TimetableState.unavailable ||
                                !member.busyAvailable,
                            marker: widget.selectedMinute,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(
                width: 68,
                child: Text(
                  '공통',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, chart) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: widget.onTimeSelected == null
                        ? null
                        : (d) => widget.onTimeSelected!(
                            ((from +
                                            d.localPosition.dx /
                                                chart.maxWidth *
                                                width) /
                                        5)
                                    .round()
                                    .clamp(0, 287) *
                                5,
                          ),
                    child: SizedBox(
                      height: 24,
                      child: CustomPaint(
                        painter: _TimelinePainter(
                          available: common ?? [],
                          busy: const [],
                          start: from,
                          length: width,
                          unknown: common == null,
                          common: true,
                          marker: widget.selectedMinute,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.selected.isEmpty
                ? '비교할 공대원을 선택해 주세요.'
                : common == null
                ? '조회할 수 없는 공대원의 시간이 있어 공통 시간을 계산하지 못했습니다.'
                : common.isEmpty
                ? '선택한 공대원이 함께 가능한 시간은 없습니다.'
                : '${widget.selected.length}명 공통 가능 ${common.map((s) => '${clock(s.start)}–${clock(s.end)}').join(' · ')}',
            style: const TextStyle(
              fontSize: 12,
              color: scheduleGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.onTimeSelected != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '그래프를 누르거나 아래에서 직접 시간을 선택할 수 있어요.',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      );
    },
  );
}

String clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.available,
    required this.busy,
    required this.start,
    required this.length,
    this.viewport,
    this.unknown = false,
    this.common = false,
    this.marker,
    this.overview = const [],
  });
  final List<TimeSpan> available, busy;
  final int start, length;
  final TimeSpan? viewport;
  final bool unknown, common;
  final int? marker;
  final List<(List<TimeSpan>, List<TimeSpan>)> overview;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      Paint()..color = const Color(0xFFF4F1F7),
    );
    for (var i = 0; i <= length ~/ 60; i++) {
      canvas.drawLine(
        Offset(size.width * i / (length ~/ 60), 0),
        Offset(size.width * i / (length ~/ 60), size.height),
        Paint()..color = const Color(0xFFE5DFEC),
      );
    }
    void bar(TimeSpan s, Color color, double inset) {
      final left = (s.start - start) / length * size.width,
          right = (s.end - start) / length * size.width;
      if (right <= 0 || left >= size.width) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left.clamp(0, size.width),
            inset,
            right.clamp(0, size.width),
            size.height - inset,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }

    for (final s in available) {
      bar(s, common ? scheduleCommon : recruitmentSelectionFill, 0);
    }
    for (final s in busy) {
      bar(s, scheduleBusy, 0);
    }
    if (unknown) {
      for (var x = -size.height; x < size.width; x += 10) {
        canvas.drawLine(
          Offset(x.toDouble(), size.height),
          Offset(x + size.height, 0),
          Paint()
            ..color = const Color(0xFFADADB5)
            ..strokeWidth = 1,
        );
      }
    }
    if (overview.isNotEmpty) {
      final rowHeight = (size.height - 6) / overview.length;
      for (var i = 0; i < overview.length; i++) {
        for (final data in [
          (overview[i].$1, recruitmentSelectionFill),
          (overview[i].$2, scheduleBusy),
        ]) {
          for (final span in data.$1) {
            canvas.drawRect(
              Rect.fromLTWH(
                span.start / 1440 * size.width,
                3 + i * rowHeight,
                (span.end - span.start) / 1440 * size.width,
                rowHeight.clamp(1, 6).toDouble(),
              ),
              Paint()..color = data.$2,
            );
          }
        }
      }
    }
    if (marker != null && marker! >= start && marker! <= start + length) {
      final x = (marker! - start) / length * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2,
      );
    }
    if (viewport != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            viewport!.start / 1440 * size.width,
            1,
            viewport!.end / 1440 * size.width,
            size.height - 1,
          ),
          const Radius.circular(4),
        ),
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}
