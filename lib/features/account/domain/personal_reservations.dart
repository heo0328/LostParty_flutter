import 'play_availability.dart';

const reservationPolicy = 'personal-reservations-1';
const kstOffset = Duration(hours: 9);

String calendarKey(DateTime utc) {
  final day = utc.toUtc().add(kstOffset);
  final date = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: (day.weekday - 3 + 7) % 7));
  return date.toIso8601String().substring(0, 10);
}

DateTime calendarStart(String key) {
  checkReservation(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key));
  final date = DateTime.parse('${key}T00:00:00Z');
  checkReservation(date.toIso8601String().startsWith(key) && date.weekday == 3);
  return date.subtract(kstOffset);
}

void checkReservation(bool condition) {
  if (!condition) throw const FormatException('Invalid personal reservations');
}

Map<String, dynamic> reservationShape(Object? value, String fields) {
  checkReservation(value is Map<String, dynamic>);
  final map = value as Map<String, dynamic>;
  final keys = fields.split(' ');
  checkReservation(map.length == keys.length && keys.every(map.containsKey));
  return map;
}

DateTime reservationUtc(Object? value) {
  checkReservation(
    value is String &&
        RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
        ).hasMatch(value),
  );
  final text = value as String;
  final date = DateTime.parse(text);
  checkReservation(
    date.toIso8601String().substring(0, 19) == text.substring(0, 19),
  );
  return date;
}

String reservationId(Object? value) {
  checkReservation(
    value is String &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(value),
  );
  return value as String;
}

String? _display(Object? value, int max) {
  checkReservation(
    value == null ||
        value is String && value.trim().isNotEmpty && value.runes.length <= max,
  );
  return value as String?;
}

class PersonalReservation {
  PersonalReservation.fromJson(Object? raw) {
    final j = reservationShape(
      raw,
      'reservation_id session_id segment_id room_id cycle_key starts_at ends_at schedule_revision raid character',
    );
    id = reservationId(j['reservation_id']);
    sessionId = reservationId(j['session_id']);
    segmentId = reservationId(j['segment_id']);
    roomId = reservationId(j['room_id']);
    cycleKey = j['cycle_key'] as String;
    calendarStart(cycleKey);
    start = reservationUtc(j['starts_at']);
    end = reservationUtc(j['ends_at']);
    checkReservation(
      start.isBefore(end) &&
          j['schedule_revision'] is int &&
          (j['schedule_revision'] as int) >= 1 &&
          (j['schedule_revision'] as int) <= 2147483647,
    );
    final raid = reservationShape(
      j['raid'],
      'raid_id difficulty_id display_name',
    );
    scheduleRevision = j['schedule_revision'] as int;
    raidId = raid['raid_id'] as String;
    difficultyId = raid['difficulty_id'] as String;
    for (final key in ['raid_id', 'difficulty_id']) {
      checkReservation(
        raid[key] is String && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(raid[key]),
      );
    }
    raidName = _display(raid['display_name'], 128) ?? '레이드 정보 확인 불가';
    final character = reservationShape(j['character'], 'character_id display');
    characterId = reservationId(character['character_id']);
    final display = reservationShape(
      character['display'],
      'name server_name class_name',
    );
    characterName = _display(display['name'], 128) ?? '캐릭터명 확인 불가';
    _display(display['server_name'], 64);
    _display(display['class_name'], 64);
  }
  late final String id, raidName, characterName;
  late final String sessionId,
      segmentId,
      roomId,
      cycleKey,
      raidId,
      difficultyId,
      characterId;
  late final int scheduleRevision;
  late final DateTime start, end;
}

class ReservationPage {
  ReservationPage.fromJson(
    Map<String, dynamic> raw, {
    required String key,
    int limit = 100,
  }) {
    final root = reservationShape(raw, 'scope data');
    final s = reservationShape(
      root['scope'],
      'server_now current_cycle_key current_calendar_week_key calendar_week_key timezone window_start window_end policy_version',
    );
    final d = reservationShape(
      root['data'],
      'items result_revision next_cursor evaluated_at',
    );
    serverNow = reservationUtc(s['server_now']);
    checkReservation(reservationUtc(d['evaluated_at']) == serverNow);
    currentKey = s['current_calendar_week_key'] as String;
    calendarStart(currentKey);
    calendarStart(s['current_cycle_key'] as String);
    windowStart = reservationUtc(s['window_start']);
    windowEnd = reservationUtc(s['window_end']);
    checkReservation(
      s['calendar_week_key'] == key &&
          s['timezone'] == 'Asia/Seoul' &&
          s['policy_version'] == reservationPolicy &&
          windowStart == calendarStart(key) &&
          windowEnd == windowStart.add(const Duration(days: 7)) &&
          currentKey == calendarKey(serverNow) &&
          [
            calendarStart(currentKey),
            calendarStart(currentKey).add(const Duration(days: 7)),
          ].contains(windowStart),
    );
    revision = d['result_revision'] as String;
    checkReservation(RegExp(r'^[0-9a-f]{64}$').hasMatch(revision));
    cursor = d['next_cursor'] as String?;
    checkReservation(
      cursor == null || RegExp(r'^[A-Za-z0-9_.-]{1,8192}$').hasMatch(cursor!),
    );
    checkReservation(
      d['items'] is List && (d['items'] as List).length <= limit,
    );
    items = List.unmodifiable(
      (d['items'] as List).map(PersonalReservation.fromJson),
    );
    for (final item in items) {
      checkReservation(
        item.start.isBefore(windowEnd) && item.end.isAfter(windowStart),
      );
    }
  }
  late final String currentKey, revision;
  late final String? cursor;
  late final DateTime serverNow, windowStart, windowEnd;
  late final List<PersonalReservation> items;
}

/// Precise, clipped render segment. Original reservation identity is retained.
class ScheduleSegment {
  const ScheduleSegment(this.day, this.start, this.end, {this.reservation});
  final int day;
  final double start, end;
  final PersonalReservation? reservation;
}

List<ScheduleSegment> reservationSegments(
  List<PersonalReservation> items,
  String key,
) {
  final result = <ScheduleSegment>[];
  final origin = calendarStart(key);
  for (final item in items) {
    for (var day = 0; day < 7; day++) {
      final start = origin.add(Duration(days: day));
      final end = start.add(const Duration(days: 1));
      if (!item.start.isBefore(end) || !item.end.isAfter(start)) continue;
      final a = item.start.isBefore(start) ? start : item.start;
      final b = item.end.isAfter(end) ? end : item.end;
      result.add(
        ScheduleSegment(
          day,
          a.difference(start).inMicroseconds / 60000000,
          b.difference(start).inMicroseconds / 60000000,
          reservation: item,
        ),
      );
    }
  }
  return result;
}

List<ScheduleSegment> availabilitySegments(List<PlayTimeRow> rows) {
  final result = <ScheduleSegment>[];
  for (final row in rows.where((r) => r.valid)) {
    final day = playWeekdays.indexOf(row.weekday);
    final end = row.end! + row.endDayOffset * 1440;
    result.add(
      ScheduleSegment(
        day,
        row.start!.toDouble(),
        end.clamp(0, 1440).toDouble(),
      ),
    );
    if (end > 1440) {
      result.add(ScheduleSegment((day + 1) % 7, 0, (end - 1440).toDouble()));
    }
  }
  return result;
}
