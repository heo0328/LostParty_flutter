import 'package:flutter/foundation.dart';
import '../../account/domain/play_availability.dart';
import 'policies/recruitment_start_policy.dart';

@immutable
class TimeSpan {
  const TimeSpan(this.start, this.end);
  final int start, end;
}

List<TimeSpan> mergeSpans(Iterable<TimeSpan> input) {
  final sorted = input.where((s) => s.start < s.end).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final out = <TimeSpan>[];
  for (final s in sorted) {
    if (out.isNotEmpty && s.start <= out.last.end) {
      final prev = out.removeLast();
      out.add(TimeSpan(prev.start, s.end > prev.end ? s.end : prev.end));
    } else {
      out.add(s);
    }
  }
  return List.unmodifiable(out);
}

List<TimeSpan> intersectSpans(List<TimeSpan> left, List<TimeSpan> right) =>
    mergeSpans([
      for (final a in left)
        for (final b in right)
          if (a.start < b.end && b.start < a.end)
            TimeSpan(
              a.start > b.start ? a.start : b.start,
              a.end < b.end ? a.end : b.end,
            ),
    ]);

List<TimeSpan> subtractSpans(List<TimeSpan> available, List<TimeSpan> busy) {
  var result = available;
  for (final cut in busy) {
    result = [
      for (final span in result) ...[
        if (cut.end <= span.start || cut.start >= span.end)
          span
        else ...[
          if (cut.start > span.start) TimeSpan(span.start, cut.start),
          if (cut.end < span.end) TimeSpan(cut.end, span.end),
        ],
      ],
    ];
  }
  return List.unmodifiable(result);
}

enum TimetableState { configured, unset, unavailable }

class ScheduleMemberRow {
  ScheduleMemberRow({
    required this.id,
    required this.name,
    required this.state,
    required List<PlayTimeRow> intervals,
    required List<(DateTime, DateTime)> busy,
    required this.busyAvailable,
  }) : intervals = List.unmodifiable(intervals),
       busy = List.unmodifiable(busy);
  final String id, name;
  final TimetableState state;
  final List<PlayTimeRow> intervals;
  final List<(DateTime, DateTime)> busy;
  final bool busyAvailable;

  bool availableFor(int weekday, int start, int duration) {
    var day = weekday, minute = start, remaining = duration;
    while (remaining > 0) {
      final length = remaining < 1440 - minute ? remaining : 1440 - minute;
      if (!availableOn(
        day,
      ).any((s) => s.start <= minute && s.end >= minute + length)) {
        return false;
      }
      remaining -= length;
      minute = 0;
      day = day % 7 + 1;
    }
    return true;
  }

  List<TimeSpan> availableOn(int weekday) => state == TimetableState.unset
      ? const [TimeSpan(0, 1440)]
      : state == TimetableState.unavailable
      ? const []
      : mergeSpans([
          for (final r in intervals) ...[
            if (r.weekday == weekday)
              TimeSpan(r.start!, r.endDayOffset == 1 ? 1440 : r.end!),
            if (r.endDayOffset == 1 && r.weekday % 7 + 1 == weekday)
              TimeSpan(0, r.end!),
          ],
        ]);
  List<TimeSpan> busyOn(DateTime localDay) => mergeSpans([
    for (final interval in busy)
      TimeSpan(
        interval.$1
            .add(const Duration(hours: 9))
            .difference(localDay)
            .inMinutes
            .clamp(0, 1440),
        interval.$2
            .add(const Duration(hours: 9))
            .difference(localDay)
            .inMinutes
            .clamp(0, 1440),
      ),
  ]);
}

class ScheduleComparison {
  ScheduleComparison(this.target, List<ScheduleMemberRow> members)
    : members = List.unmodifiable(members);

  final String target;
  final List<ScheduleMemberRow> members;
  DateTime date(int weekday) => const RecruitmentStartPolicy().dateForDay(
    DateTime.parse('${target}T00:00:00Z'),
    weekday,
    targetCycleKey: target,
  );

  /// Null means a selected member's data is unknown, not "no common time".
  List<TimeSpan>? common(int weekday, Set<String> selected) {
    final rows = members.where((m) => selected.contains(m.id)).toList();
    if (rows.isEmpty) return const [];
    if (rows.any(
      (m) => m.state == TimetableState.unavailable || !m.busyAvailable,
    )) {
      return null;
    }
    var common = const [TimeSpan(0, 1440)];
    for (final member in rows) {
      common = intersectSpans(
        common,
        subtractSpans(
          member.availableOn(weekday),
          member.busyOn(date(weekday)),
        ),
      );
    }
    return common;
  }
}
