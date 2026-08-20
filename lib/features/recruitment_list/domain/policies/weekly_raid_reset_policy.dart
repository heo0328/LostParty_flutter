import '../entities/weekly_raid_clear.dart';

class WeeklyRaidResetPolicy {
  const WeeklyRaidResetPolicy();

  static const _koreaOffset = Duration(hours: 9);

  RaidResetWeek weekFor(DateTime instant) {
    final koreaTime = instant.toUtc().add(_koreaOffset);
    final midnight = DateTime.utc(
      koreaTime.year,
      koreaTime.month,
      koreaTime.day,
    );
    final daysSinceWednesday = (koreaTime.weekday - DateTime.wednesday + 7) % 7;
    var resetInKorea = midnight
        .subtract(Duration(days: daysSinceWednesday))
        .add(const Duration(hours: 6));
    if (koreaTime.isBefore(resetInKorea)) {
      resetInKorea = resetInKorea.subtract(const Duration(days: 7));
    }
    final startedAt = resetInKorea.subtract(_koreaOffset);
    final month = resetInKorea.month.toString().padLeft(2, '0');
    final day = resetInKorea.day.toString().padLeft(2, '0');
    return RaidResetWeek(
      key: '${resetInKorea.year}-$month-$day',
      startedAt: startedAt,
    );
  }
}
