import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/schedule_comparison.dart';

class ScheduleTimeline extends StatefulWidget {
  const ScheduleTimeline({
    super.key,
    required this.comparison,
    required this.weekday,
    required this.selected,
    this.onTimeSelected,
  });
  final ScheduleComparison comparison;
  final int weekday;
  final Set<String> selected;
  final ValueChanged<int>? onTimeSelected;
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
          const Text(
            '하루 전체 · 보고 싶은 시간대를 움직여 보세요.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _TimelinePainter(
                available: common ?? [],
                busy: const [],
                start: 0,
                length: 1440,
                viewport: TimeSpan(from, from + width),
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00시', style: TextStyle(fontSize: 10)),
              Text('12시', style: TextStyle(fontSize: 10)),
              Text('24시', style: TextStyle(fontSize: 10)),
            ],
          ),
          Slider(
            value: from.toDouble(),
            min: 0,
            max: (1440 - width).toDouble(),
            divisions: (1440 - width) ~/ 30,
            label: '${clock(from)}–${clock(from + width)}',
            onChanged: (v) => setState(() => start = v),
          ),
          Row(
            children: [
              const SizedBox(width: 88),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i <= 3; i++)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            clock(from + width * i ~/ 3),
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
                    width: 88,
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
                        height: 25,
                        child: CustomPaint(
                          painter: _TimelinePainter(
                            available: member.availableOn(widget.weekday),
                            busy: member.busyOn(date),
                            start: from,
                            length: width,
                            unknown: member.state == TimetableState.unavailable,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              const SizedBox(
                width: 88,
                child: Text(
                  '함께 가능한 시간',
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
                      height: 30,
                      child: CustomPaint(
                        painter: _TimelinePainter(
                          available: common ?? [],
                          busy: const [],
                          start: from,
                          length: width,
                          unknown: common == null,
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
                : common
                      .map((s) => '${clock(s.start)}–${clock(s.end)}')
                      .join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            children: [
              _Legend('가능 시간', AppColors.primary),
              _Legend('예약 중', Color(0xFFDB9E6C)),
              _Legend('조회 불가', Color(0xFFADADB5)),
            ],
          ),
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

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.available,
    required this.busy,
    required this.start,
    required this.length,
    this.viewport,
    this.unknown = false,
  });
  final List<TimeSpan> available, busy;
  final int start, length;
  final TimeSpan? viewport;
  final bool unknown;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      Paint()..color = const Color(0xFFF0EDF5),
    );
    for (var i = 0; i <= 6; i++) {
      canvas.drawLine(
        Offset(size.width * i / 6, 0),
        Offset(size.width * i / 6, size.height),
        Paint()..color = const Color(0xFFE1DDE7),
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
      bar(s, AppColors.primary.withValues(alpha: .7), 4);
    }
    for (final s in busy) {
      bar(s, const Color(0xFFDB9E6C), 7);
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
