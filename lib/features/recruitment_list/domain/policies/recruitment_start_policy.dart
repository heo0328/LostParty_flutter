import 'raid_cycle_schedule.dart';
import 'weekly_raid_reset_policy.dart';

enum StartTimePrecision { fiveMinutes, minute }

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
  DateTime dateForDay(DateTime now, int weekday, {String? targetCycleKey}) {
    final start = targetCycleKey == null
        ? _reset.weekFor(now).startedAt.add(_schedule.utcOffset)
        : DateTime.parse('${targetCycleKey}T06:00:00Z');
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
    String? targetCycleKey,
    StartTimePrecision precision = StartTimePrecision.fiveMinutes,
  }) =>
      failureReason(
        now: now,
        weekday: weekday,
        minute: minute,
        durationMinutes: durationMinutes,
        targetCycleKey: targetCycleKey,
        precision: precision,
      ) ==
      null;

  String? failureReason({
    required DateTime now,
    required int weekday,
    required int minute,
    required int? durationMinutes,
    String? targetCycleKey,
    StartTimePrecision precision = StartTimePrecision.fiveMinutes,
  }) {
    if (weekday < 1 || weekday > 7 || minute < 0 || minute >= 1440) {
      return '출발 날짜와 시각을 다시 선택해 주세요.';
    }
    if (precision == StartTimePrecision.fiveMinutes && minute % 5 != 0) {
      return '출발 시각은 5분 단위로 선택해 주세요.';
    }
    if (durationMinutes == null ||
        durationMinutes <= 0 ||
        durationMinutes > 1440) {
      return '진행 시간을 먼저 확인해 주세요.';
    }
    final week = _reset.weekFor(now);
    final cycleStart = targetCycleKey == null
        ? week.startedAt
        : DateTime.parse(
            '${targetCycleKey}T06:00:00Z',
          ).subtract(_schedule.utcOffset);
    if (cycleStart != week.startedAt &&
        cycleStart != week.startedAt.add(_schedule.cycleLength)) {
      return '이번 주 또는 다음 주의 날짜를 선택해 주세요.';
    }
    final start = dateForDay(
      now,
      weekday,
      targetCycleKey: targetCycleKey,
    ).add(Duration(minutes: minute)).subtract(_schedule.utcOffset);
    final end = start.add(Duration(minutes: durationMinutes));
    final cycleEnd = cycleStart.add(_schedule.cycleLength);
    final maintenanceEnd = cycleStart.add(const Duration(hours: 4));
    if (start.isBefore(cycleStart) ||
        !start.isBefore(cycleEnd) ||
        end.isAfter(cycleEnd)) {
      return '진행 시간이 선택한 주차를 벗어납니다. 날짜와 시각을 다시 선택해 주세요.';
    }
    if (start.isBefore(maintenanceEnd) && end.isAfter(cycleStart)) {
      return '수요일 오전 6시부터 10시까지는 점검 시간입니다.';
    }
    if (start.isBefore(now.toUtc().add(const Duration(minutes: 30)))) {
      return '지금부터 30분 이후의 출발 시간을 선택해 주세요.';
    }
    return null;
  }
}
