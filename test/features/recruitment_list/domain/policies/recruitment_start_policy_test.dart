import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/recruitment_start_policy.dart';

void main() {
  const policy = RecruitmentStartPolicy();
  test(
    'explicit minute precision preserves exact floor, maintenance and week end',
    () {
      String? reason(String now, int day, int minute, {int duration = 20}) =>
          policy.failureReason(
            now: DateTime.parse(now),
            weekday: day,
            minute: minute,
            durationMinutes: duration,
            precision: StartTimePrecision.minute,
          );
      expect(reason('2026-10-20T08:33:00Z', 2, 1083), isNull);
      expect(reason('2026-10-20T08:33:01Z', 2, 1083), contains('30분'));
      expect(reason('2026-10-20T21:00:00Z', 3, 599), contains('점검'));
      expect(reason('2026-10-20T21:00:00Z', 3, 601), isNull);
      expect(reason('2026-10-20T01:00:00Z', 2, 1439, duration: 361), isNull);
      expect(
        reason('2026-10-20T01:00:00Z', 2, 1439, duration: 362),
        contains('주차'),
      );
      expect(
        policy.allows(
          now: DateTime.parse('2026-10-20T01:00:00Z'),
          weekday: 2,
          minute: 1083,
          durationMinutes: 20,
        ),
        false,
      );
    },
  );
  bool allows(String now, int day, int minute, {int? duration = 20}) =>
      policy.allows(
        now: DateTime.parse(now),
        weekday: day,
        minute: minute,
        durationMinutes: duration,
      );

  test(
    'current +30 minutes and five-minute boundary, regardless of host timezone',
    () {
      expect(allows('2026-10-20T01:00:00Z', 2, 630), true);
      expect(allows('2026-10-20T10:00:00+09:00', 2, 625), false);
      expect(allows('2026-10-20T01:00:01Z', 2, 630), false);
      expect(allows('2026-10-20T01:00:01Z', 2, 635), true);
      expect(allows('2026-10-20T01:00:00Z', 2, 631), false);
    },
  );
  test(
    'Wednesday reset and maintenance apply to actual play, not creation time',
    () {
      expect(allows('2026-10-13T21:00:00Z', 3, 595), false);
      expect(allows('2026-10-13T21:00:00Z', 3, 600), true);
      expect(allows('2026-10-13T21:00:00Z', 3, 300), false);
      expect(
        policy.dateForDay(DateTime.parse('2026-10-20T20:59:59Z'), 3),
        DateTime.utc(2026, 10, 14),
      );
      expect(
        policy.dateForDay(DateTime.parse('2026-10-20T21:00:00Z'), 3),
        DateTime.utc(2026, 10, 21),
      );
    },
  );
  test('past selected weekdays never roll into next week', () {
    for (final day in [1, 4, 6]) {
      expect(allows('2026-10-20T01:00:00Z', day, 1200), false);
    }
    expect(allows('2026-10-20T01:00:00Z', 2, 1200), true);
  });
  test(
    'duration must fit before cycle end, including midnight across month/year',
    () {
      expect(allows('2026-10-20T01:00:00Z', 2, 1430, duration: 370), true);
      expect(allows('2026-10-20T01:00:00Z', 2, 1430, duration: 375), false);
      expect(allows('2026-10-20T01:00:00Z', 2, 1200, duration: 1441), false);
      expect(allows('2026-10-20T01:00:00Z', 2, 1200, duration: null), false);
      expect(
        policy.dateForDay(DateTime.parse('2027-01-01T01:00:00Z'), 2),
        DateTime.utc(2027, 1, 5),
      );
    },
  );
  test(
    'difficulty fallback is 10/20/30; unknown difficulty is not guessed',
    () {
      expect(
        [
          'normal',
          'hard',
          'nightmare',
          'stage1',
          'stage2',
          'stage3',
        ].map(policy.defaultMinutes),
        [10, 20, 30, 10, 20, 30],
      );
      expect(policy.defaultMinutes('unknown'), isNull);
    },
  );
}
