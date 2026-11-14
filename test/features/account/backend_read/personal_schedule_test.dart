import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/personal_reservations.dart';
import 'package:lost_party/features/account/domain/play_availability.dart';
import 'package:lost_party/features/account/data/personal_reservations_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/personal_schedule_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

Map<String, dynamic> reservationJson({
  int id = 1,
  String start = '2026-11-18T12:00:00Z',
  String end = '2026-11-18T12:30:00Z',
}) => {
  'reservation_id': '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
  'session_id': '00000000-0000-4000-8000-000000000002',
  'segment_id': '00000000-0000-4000-8000-000000000003',
  'room_id': '00000000-0000-4000-8000-000000000004',
  'cycle_key': '2026-11-18',
  'starts_at': start,
  'ends_at': end,
  'schedule_revision': 1,
  'raid': {
    'raid_id': 'synthetic_raid',
    'difficulty_id': 'normal',
    'display_name': '합성 레이드',
  },
  'character': {
    'character_id': '00000000-0000-4000-8000-000000000005',
    'display': {'name': '합성 캐릭터', 'server_name': '합성 서버', 'class_name': null},
  },
};
Map<String, dynamic> pageJson({
  List<Map<String, dynamic>>? items,
  String? cursor,
  String key = '2026-11-18',
  String? revision,
}) => {
  'scope': {
    'server_now': '2026-11-18T18:00:00Z',
    'current_cycle_key': '2026-11-18',
    'current_calendar_week_key': '2026-11-18',
    'calendar_week_key': key,
    'timezone': 'Asia/Seoul',
    'window_start': calendarStart(key).toIso8601String(),
    'window_end': calendarStart(
      key,
    ).add(const Duration(days: 7)).toIso8601String(),
    'policy_version': reservationPolicy,
  },
  'data': {
    'items': items ?? [reservationJson()],
    'result_revision': revision ?? 'a' * 64,
    'next_cursor': cursor,
    'evaluated_at': '2026-11-18T18:00:00Z',
  },
};

class ReservationsFake implements PersonalReservationsRepository {
  int calls = 0, clocks = 0;
  Future<ReservationPage> Function(String, String?)? onPage;
  @override
  Future<DateTime> serverTime() async {
    clocks++;
    return DateTime.parse('2026-11-18T18:00:00Z');
  }

  @override
  Future<ReservationPage> page(String key, {String? cursor}) async {
    calls++;
    return onPage != null
        ? onPage!(key, cursor)
        : ReservationPage.fromJson(
            pageJson(key: key, items: []),
            key: key,
          );
  }
}

void main() {
  test(
    'published synthetic fixture, strict wire, canonical date/time and nullable display',
    () {
      final fixture = pageJson();
      expect(
        ReservationPage.fromJson(
          fixture,
          key: '2026-11-18',
        ).items.single.characterName,
        '합성 캐릭터',
      );
      expect(
        () => ReservationPage.fromJson({
          ...fixture,
          'extra': 1,
        }, key: '2026-11-18'),
        throwsFormatException,
      );
      for (final invalid in [
        '2026-11-18T12:00:00+00:00',
        '2026-11-31T12:00:00Z',
        '2026-11-18T24:00:00Z',
      ]) {
        expect(() => reservationUtc(invalid), throwsFormatException);
      }
      expect(() => calendarStart('2026-11-19'), throwsFormatException);
      final row = reservationJson();
      ((row['character'] as Map)['display'] as Map)['name'] = null;
      expect(PersonalReservation.fromJson(row).characterName, '캐릭터명 확인 불가');
    },
  );
  test(
    'calendar midnight differs from game six; clipping preserves microseconds and original identity',
    () {
      expect(calendarKey(DateTime.parse('2026-11-17T15:00:00Z')), '2026-11-18');
      expect(calendarKey(DateTime.parse('2026-11-17T14:59:59Z')), '2026-11-11');
      final reservation = PersonalReservation.fromJson(
        reservationJson(
          start: '2026-11-18T14:59:59.500001Z',
          end: '2026-11-18T15:00:01Z',
        ),
      );
      final segments = reservationSegments([reservation], '2026-11-18');
      expect(segments.map((s) => s.day), [0, 1]);
      expect(segments.first.end, 1440);
      expect(segments.first.start, closeTo(1440 - .499999 / 60, .00000001));
      expect(identical(segments.last.reservation, reservation), true);
      final weekEnd = PersonalReservation.fromJson(
        reservationJson(
          start: '2026-11-24T14:00:00Z',
          end: '2026-11-24T16:00:00Z',
        ),
      );
      expect(reservationSegments([weekEnd], '2026-11-18').single.day, 6);
      final possible = availabilitySegments([
        const PlayTimeRow(weekday: 2, start: 1380, end: 60, endDayOffset: 1),
      ]);
      expect(possible.map((s) => s.day), [6, 0]);
    },
  );

  late ReadSessionFake session;
  late ReservationsFake repository;
  late PersonalScheduleViewModel model;
  setUp(() {
    session = ReadSessionFake();
    repository = ReservationsFake();
    model = PersonalScheduleViewModel(repository: repository, session: session);
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });

  test('201 reservations collect across pages without partial state', () async {
    repository.onPage = (key, cursor) async {
      final offset = cursor == null ? 0 : int.parse(cursor);
      final end = (offset + 100).clamp(0, 201);
      return ReservationPage.fromJson(
        pageJson(
          items: [
            for (var id = offset + 1; id <= end; id++) reservationJson(id: id),
          ],
          cursor: end < 201 ? '$end' : null,
        ),
        key: key,
      );
    };
    await model.reload();
    expect(repository.calls, 3);
    expect(model.items, hasLength(201));
    expect(model.failure, isNull);
  });

  test(
    'calendar recovery and stale recovery each stop after one retry',
    () async {
      repository.onPage = (key, cursor) async {
        throw AccountReadException(
          repository.calls.isOdd ? 'CURSOR_STALE' : 'CALENDAR_WEEK_UNAVAILABLE',
        );
      };
      await model.reload();
      expect(repository.calls, 3);
      expect(repository.clocks, 2);
      expect(model.failure, 'CURSOR_STALE');
    },
  );

  test(
    'pages commit atomically; later-page error keeps only same-window success',
    () async {
      repository.onPage = (key, cursor) async =>
          ReservationPage.fromJson(pageJson(), key: key);
      await model.reload();
      final old = model.items;
      final second = Completer<ReservationPage>();
      repository.onPage = (key, cursor) async => cursor == null
          ? ReservationPage.fromJson(
              pageJson(items: [reservationJson(id: 2)], cursor: 'next'),
              key: key,
            )
          : second.future;
      final pending = model.reload();
      await Future<void>.delayed(Duration.zero);
      expect(identical(model.items, old), true);
      second.completeError(const AccountReadException('NETWORK_UNAVAILABLE'));
      await pending;
      expect(identical(model.items, old), true);
      expect(model.failure, 'NETWORK_UNAVAILABLE');
      expect(model.checkedAt, isNotNull);
    },
  );
  test(
    'stale retry bounded once, revision mismatch and repeated cursor are errors',
    () async {
      repository.onPage = (key, cursor) async =>
          throw const AccountReadException('CURSOR_STALE');
      await model.reload();
      expect(repository.calls, 2);
      expect(model.failure, 'CURSOR_STALE');
      repository.onPage = (key, cursor) async => ReservationPage.fromJson(
        pageJson(
          items: [reservationJson(id: cursor == null ? 1 : 2)],
          cursor: 'same',
        ),
        key: key,
      );
      await model.reload();
      expect(model.failure, 'INVALID_RESPONSE');
      expect(model.checkedAt, isNull);
      repository.onPage = (key, cursor) async => ReservationPage.fromJson(
        pageJson(
          items: [reservationJson(id: cursor == null ? 1 : 2)],
          cursor: cursor == null ? 'second' : null,
          revision: cursor == null ? 'a' * 64 : 'b' * 64,
        ),
        key: key,
      );
      await model.reload();
      expect(model.failure, 'INVALID_RESPONSE');
    },
  );
  test(
    'logout discards late pages and next week never displays earlier week',
    () async {
      final pending = Completer<ReservationPage>();
      repository.onPage = (key, cursor) => pending.future;
      final load = model.reload();
      await Future<void>.delayed(Duration.zero);
      session.change(authenticated: false);
      pending.complete(ReservationPage.fromJson(pageJson(), key: '2026-11-18'));
      await load;
      expect(model.items, isEmpty);
      expect(model.key, isNull);
      expect(model.visible, false);
      session.change(authenticated: true, user: 'other');
      repository.onPage = (key, cursor) async =>
          throw const AccountReadException('SERVICE_UNAVAILABLE');
      model.selectWeek(true);
      await Future<void>.delayed(Duration.zero);
      expect(model.items, isEmpty);
      expect(model.checkedAt, isNull);
      expect(model.key, '2026-11-25');
    },
  );
  test(
    'retry-after blocks requests; calendar recovery and stale share bounded budgets',
    () async {
      repository.onPage = (key, cursor) async =>
          throw const AccountReadException(
            'RATE_LIMITED',
            retryAfter: Duration(minutes: 1),
          );
      await model.reload();
      final count = repository.calls;
      await model.reload();
      expect(repository.calls, count);
      expect(model.canReload, false);
    },
  );
}
