import 'raid_cycle_schedule.dart';
import 'weekly_raid_reset_policy.dart';

/// Local editor guidance. The server still authorizes the final schedule.
class RecruitmentStartPolicy {
  const RecruitmentStartPolicy();
  static const _schedule = RaidCycleSchedule();
  static const _reset = WeeklyRaidResetPolicy();
  static const _defaults = {
    'normal': 10,
    'hard': 20,
    'nightmare': 30,
    'stage1': 10,
    'stage2': 20,
    'stage3': 30,
  };

  int? defaultMinutes(String difficultyId) => _defaults[difficultyId];

  /// Calendar coordinates in KST, independent of the device timezone.
  DateTime dateForDay(DateTime now, int weekday) {
    final start = _reset.weekFor(now).startedAt.add(_schedule.utcOffset);
    return DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).add(Duration(days: (weekday - _schedule.resetWeekday) % 7));
  }

  bool allows({
    required DateTime now,
    required int weekday,
    required int minute,
    required int? durationMinutes,
  }) {
    if (weekday < 1 ||
        weekday > 7 ||
        minute < 0 ||
        minute >= 1440 ||
        minute % 5 != 0 ||
        durationMinutes == null ||
        durationMinutes <= 0 ||
        durationMinutes > 1440) {
      return false;
    }
    final week = _reset.weekFor(now);
    final start = dateForDay(
      now,
      weekday,
    ).add(Duration(minutes: minute)).subtract(_schedule.utcOffset);
    final end = start.add(Duration(minutes: durationMinutes));
    final cycleEnd = week.startedAt.add(_schedule.cycleLength);
    final maintenanceEnd = week.startedAt.add(const Duration(hours: 4));
    return !start.isBefore(now.toUtc().add(const Duration(minutes: 30))) &&
        !start.isBefore(week.startedAt) &&
        !end.isAfter(cycleEnd) &&
        !(start.isBefore(maintenanceEnd) && end.isAfter(week.startedAt));
  }
}
