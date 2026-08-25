class PartyCycleWindow {
  const PartyCycleWindow({required this.key, required this.startedAt, required this.endsAt, required this.completionCancelDeadline});
  final String key;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime completionCancelDeadline;
}

class PartyCyclePolicy {
  const PartyCyclePolicy();
  static const _koreaOffset = Duration(hours: 9);

  PartyCycleWindow? fromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final koreaStart = DateTime.utc(year, month, day, 6);
    if (koreaStart.year != year || koreaStart.month != month || koreaStart.day != day || koreaStart.weekday != DateTime.wednesday) return null;
    final startedAt = koreaStart.subtract(_koreaOffset);
    final endsAt = startedAt.add(const Duration(days: 7));
    return PartyCycleWindow(key: key, startedAt: startedAt, endsAt: endsAt, completionCancelDeadline: endsAt.subtract(const Duration(hours: 8)));
  }

  String keyFor(DateTime instant) {
    final korea = instant.toUtc().add(_koreaOffset);
    final midnight = DateTime.utc(korea.year, korea.month, korea.day);
    final days = (korea.weekday - DateTime.wednesday + 7) % 7;
    var start = midnight.subtract(Duration(days: days)).add(const Duration(hours: 6));
    if (korea.isBefore(start)) start = start.subtract(const Duration(days: 7));
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }
}
