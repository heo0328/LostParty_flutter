import 'policies/party_cycle_policy.dart';

/// Calendar coordinates are KST; only the request boundary converts them to UTC.
class DepartureSearchSelection {
  DepartureSearchSelection({
    this.weekday,
    this.timeEnabled = false,
    this.from,
    this.to,
    Set<String> groups = const {},
  }) : groups = Set.unmodifiable(groups);
  final int? weekday, from, to;
  final bool timeEnabled;
  final Set<String> groups;
  static const confirmedStates = {
    'base_committed',
    'early_confirmed',
    'base_confirmed',
    'proposal_confirmed',
  };
  bool get valid =>
      (weekday == null || weekday! >= 1 && weekday! <= 7) &&
      groups.every((v) => v == 'coordinating' || v == 'confirmed') &&
      (!timeEnabled ||
          from != null &&
              to != null &&
              from! >= 0 &&
              from! < 1440 &&
              to! >= 0 &&
              to! <= 1440 &&
              from != to);
  DepartureSearchSelection copy({
    int? weekday,
    bool clearDay = false,
    bool? timeEnabled,
    int? from,
    int? to,
    Set<String>? groups,
  }) => DepartureSearchSelection(
    weekday: clearDay ? null : weekday ?? this.weekday,
    timeEnabled: timeEnabled ?? this.timeEnabled,
    from: from ?? this.from,
    to: to ?? this.to,
    groups: groups ?? this.groups,
  );
  DateTime date(String target, int day) {
    final start = DateTime.parse('${target}T00:00:00Z');
    return start.add(Duration(days: (day - 3) % 7));
  }

  Map<String, dynamic> wire(String target) {
    final cycle = const PartyCyclePolicy().fromKey(target);
    if (!valid || cycle == null) {
      throw const FormatException('Invalid departure filter');
    }
    final windows = <Map<String, dynamic>>[];
    if (weekday != null || timeEnabled) {
      // A time-only filter also covers the final reset-day morning.
      final dates = weekday == null
          ? [
              for (var i = 0; i <= 7; i++)
                date(target, 3).add(Duration(days: i)),
            ]
          : [date(target, weekday!)];
      for (final day in dates) {
        var start = day
            .add(Duration(minutes: timeEnabled ? from! : 0))
            .subtract(const Duration(hours: 9));
        var end = day
            .add(Duration(minutes: timeEnabled ? to! : 1440))
            .subtract(const Duration(hours: 9));
        if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
        if (start.isBefore(cycle.startedAt)) start = cycle.startedAt;
        if (end.isAfter(cycle.endsAt)) end = cycle.endsAt;
        if (end.isAfter(start)) {
          windows.add({
            'starts_at': start.toIso8601String(),
            'ends_at': end.toIso8601String(),
          });
        }
      }
      if (windows.isEmpty) {
        throw const FormatException(
          'Departure range is outside selected cycle',
        );
      }
    }
    final states = {
      if (groups.contains('coordinating')) 'coordinating',
      if (groups.contains('confirmed')) ...confirmedStates,
    }.toList()..sort();
    return {
      if (windows.isNotEmpty) 'departure_windows': windows,
      if (states.isNotEmpty) 'schedule_states': states,
    };
  }

  bool validFor(String target) {
    try {
      wire(target);
      return true;
    } on FormatException {
      return false;
    }
  }
}
