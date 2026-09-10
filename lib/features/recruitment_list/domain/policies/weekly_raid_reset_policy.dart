import '../entities/weekly_raid_clear.dart';
import 'raid_cycle_schedule.dart';

class WeeklyRaidResetPolicy {
  const WeeklyRaidResetPolicy({this.schedule = const RaidCycleSchedule()});

  final RaidCycleSchedule schedule;

  RaidResetWeek weekFor(DateTime instant) {
    final koreaTime = instant.toUtc().add(schedule.utcOffset);
    final midnight = DateTime.utc(
      koreaTime.year,
      koreaTime.month,
      koreaTime.day,
    );
    final daysSinceReset =
        (koreaTime.weekday - schedule.resetWeekday + 7) % 7;
    var resetInKorea = midnight
        .subtract(Duration(days: daysSinceReset))
        .add(
          Duration(
            hours: schedule.resetHour,
            minutes: schedule.resetMinute,
          ),
        );
    if (koreaTime.isBefore(resetInKorea)) {
      resetInKorea = resetInKorea.subtract(schedule.cycleLength);
    }
    final startedAt = resetInKorea.subtract(schedule.utcOffset);
    final month = resetInKorea.month.toString().padLeft(2, '0');
    final day = resetInKorea.day.toString().padLeft(2, '0');
    return RaidResetWeek(
      key: '${resetInKorea.year}-$month-$day',
      startedAt: startedAt,
    );
  }
}
