/// ISO weekdays on the wire; the editor displays Wednesday through Tuesday.
const playWeekdays = [3, 4, 5, 6, 7, 1, 2];
const playWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String playClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class PlayTimeRow {
  const PlayTimeRow({
    required this.weekday,
    this.start,
    this.end,
    this.endDayOffset = 0,
  });
  final int weekday;
  final int? start, end;
  final int endDayOffset;

  int? get duration =>
      start == null || end == null ? null : end! + endDayOffset * 1440 - start!;
  bool get valid =>
      weekday >= 1 &&
      weekday <= 7 &&
      (endDayOffset == 0 || endDayOffset == 1) &&
      [
        start,
        end,
      ].every((n) => n != null && n >= 0 && n < 1440 && n % 5 == 0) &&
      duration! > 0 &&
      duration! <= 1440;

  PlayTimeRow withTime({
    required bool ending,
    required int minute,
    int offset = 0,
  }) => PlayTimeRow(
    weekday: weekday,
    start: ending ? start : minute,
    end: ending ? minute : end,
    endDayOffset: ending ? offset : endDayOffset,
  );

  Map<String, dynamic> toJson() {
    if (!valid) throw const FormatException('Invalid play interval');
    return {
      'weekday': weekday,
      'start': playClock(start!),
      'end': playClock(end!),
      'end_day_offset': endDayOffset,
    };
  }

  factory PlayTimeRow.fromJson(Map<String, dynamic> json) {
    _shape(json, const {'weekday', 'start', 'end', 'end_day_offset'});
    int clock(Object? raw) {
      if (raw is! String ||
          !RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][05]$').hasMatch(raw)) {
        throw const FormatException('Invalid play clock');
      }
      return int.parse(raw.substring(0, 2)) * 60 + int.parse(raw.substring(3));
    }

    if (json['weekday'] is! int || json['end_day_offset'] is! int) {
      throw const FormatException('Invalid play day');
    }
    final row = PlayTimeRow(
      weekday: json['weekday'] as int,
      start: clock(json['start']),
      end: clock(json['end']),
      endDayOffset: json['end_day_offset'] as int,
    );
    if (!row.valid) throw const FormatException('Invalid play duration');
    return row;
  }
}

class PlayAvailability {
  PlayAvailability({
    required this.exists,
    required this.version,
    required List<PlayTimeRow> intervals,
  }) : intervals = List.unmodifiable(intervals);
  final bool exists;
  final int version;

  /// Preserve editing rows. The server's merged coverage is not an editor draft.
  final List<PlayTimeRow> intervals;

  factory PlayAvailability.fromJson(Map<String, dynamic> json) {
    _shape(json, const {
      'exists',
      'version',
      'timezone',
      'intervals',
      'normalized_intervals',
      'updated_at',
    });
    if (json['exists'] is! bool ||
        json['version'] is! int ||
        (json['version'] as int) < 1 ||
        (json['version'] as int) > 2147483647 ||
        json['timezone'] != 'Asia/Seoul' ||
        json['intervals'] is! List ||
        json['normalized_intervals'] is! List) {
      throw const FormatException('Invalid personal availability');
    }
    for (final raw in json['normalized_intervals'] as List) {
      final item = raw as Map<String, dynamic>;
      _shape(item, const {'start_minute', 'end_minute'});
      if (item['start_minute'] is! int ||
          item['end_minute'] is! int ||
          (item['start_minute'] as int) < 0 ||
          (item['end_minute'] as int) > 10080 ||
          (item['start_minute'] as int) >= (item['end_minute'] as int)) {
        throw const FormatException('Invalid normalized interval');
      }
    }
    final updated = json['updated_at'];
    if (updated != null &&
        (updated is! String || DateTime.tryParse(updated) == null)) {
      throw const FormatException('Invalid availability timestamp');
    }
    final rows = (json['intervals'] as List)
        .map((raw) => PlayTimeRow.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (json['exists'] == false &&
        (rows.isNotEmpty ||
            (json['normalized_intervals'] as List).isNotEmpty ||
            updated != null ||
            json['version'] != 1)) {
      throw const FormatException('Invalid missing availability');
    }
    return PlayAvailability(
      exists: json['exists'] as bool,
      version: json['version'] as int,
      intervals: rows,
    );
  }
}

void _shape(Map<String, dynamic> json, Set<String> keys) {
  if (json.length != keys.length || !keys.every(json.containsKey)) {
    throw const FormatException('Invalid availability fields');
  }
}

abstract interface class PlayAvailabilityRepository {
  Future<PlayAvailability> load();
  Future<PlayAvailability> save({
    required int version,
    required List<PlayTimeRow> rows,
    required String key,
  });
}
