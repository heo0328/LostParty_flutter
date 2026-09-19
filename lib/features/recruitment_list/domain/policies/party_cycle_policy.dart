import 'raid_cycle_schedule.dart';

class PartyCycleWindow {
  const PartyCycleWindow({
    required this.key,
    required this.startedAt,
    required this.endsAt,
  });
  final String key;
  final DateTime startedAt;
  final DateTime endsAt;
}

class PartyCyclePolicy {
  const PartyCyclePolicy({this.schedule = const RaidCycleSchedule()});

  final RaidCycleSchedule schedule;

  PartyCycleWindow? fromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final localStart = DateTime.utc(
      year,
      month,
      day,
      schedule.resetHour,
      schedule.resetMinute,
    );
    if (localStart.year != year ||
        localStart.month != month ||
        localStart.day != day ||
        localStart.weekday != schedule.resetWeekday) {
      return null;
    }
    final startedAt = localStart.subtract(schedule.utcOffset);
    final endsAt = startedAt.add(schedule.cycleLength);
    return PartyCycleWindow(key: key, startedAt: startedAt, endsAt: endsAt);
  }

  String keyFor(DateTime instant) {
    final local = instant.toUtc().add(schedule.utcOffset);
    final midnight = DateTime.utc(local.year, local.month, local.day);
    final days = (local.weekday - schedule.resetWeekday + 7) % 7;
    var start = midnight
        .subtract(Duration(days: days))
        .add(
          Duration(hours: schedule.resetHour, minutes: schedule.resetMinute),
        );
    if (local.isBefore(start)) start = start.subtract(schedule.cycleLength);
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }
}
