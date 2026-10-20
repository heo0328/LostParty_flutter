import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/play_availability.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/account/data/play_availability_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/play_availability_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

Map<String, dynamic> response({
  int version = 1,
  List<Map<String, dynamic>> rows = const [],
}) => {
  'exists': version > 1,
  'version': version,
  'timezone': 'Asia/Seoul',
  'intervals': rows,
  'normalized_intervals': <Object>[],
  'updated_at': version > 1 ? '2026-10-20T01:00:00Z' : null,
};
const row = PlayTimeRow(weekday: 7, start: 1380, end: 210, endDayOffset: 1);

class Access extends ChangeNotifier {
  bool verified = true;
  void change(bool value) {
    verified = value;
    notifyListeners();
  }
}

class Api implements BackendRegistrationApi {
  Map<String, dynamic> current = response();
  final writes = <({String key, Map<String, dynamic> body})>[];
  int reads = 0;
  Future<Map<String, dynamic>?> Function()? onRead;
  Future<Map<String, dynamic>?> Function()? onWrite;
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    expect(path, '/v1/me/play-availability');
    if (method == 'GET') {
      reads++;
      return onRead == null ? current : onRead!();
    }
    expect(method, 'PUT');
    expect(expectedStatus, 200);
    writes.add((key: idempotencyKey!, body: body!));
    if (onWrite != null) return onWrite!();
    current = response(
      version: (body['expected_version'] as int) + 1,
      rows: (body['intervals'] as List).cast<Map<String, dynamic>>(),
    );
    return current;
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ReadSessionFake session;
  late Access access;
  late Api api;
  late PlayAvailabilityViewModel model;
  setUp(() {
    session = ReadSessionFake();
    access = Access();
    api = Api();
    model = PlayAvailabilityViewModel(
      repository: BackendPlayAvailabilityRepository(api),
      session: session,
      accessChanges: access,
      hasVerifiedAccount: () => access.verified,
    );
  });
  tearDown(() {
    model.dispose();
    access.dispose();
    session.dispose();
  });

  test(
    'zero/negative/over24h rejected; exactly24h and Sunday overnight preserved',
    () {
      expect(const PlayTimeRow(weekday: 3, start: 600, end: 600).valid, false);
      expect(const PlayTimeRow(weekday: 3, start: 600, end: 595).valid, false);
      expect(
        const PlayTimeRow(
          weekday: 3,
          start: 600,
          end: 605,
          endDayOffset: 1,
        ).valid,
        false,
      );
      expect(
        const PlayTimeRow(
          weekday: 3,
          start: 600,
          end: 600,
          endDayOffset: 1,
        ).duration,
        1440,
      );
      expect(
        const PlayTimeRow(
          weekday: 3,
          start: 600,
          end: 600,
          endDayOffset: 1,
        ).valid,
        true,
      );
      expect(const PlayTimeRow(weekday: 3, start: 601, end: 610).valid, false);
      expect(row.valid, true);
      expect(row.toJson(), {
        'weekday': 7,
        'start': '23:00',
        'end': '03:30',
        'end_day_offset': 1,
      });
      expect(playWeekdays, [3, 4, 5, 6, 7, 1, 2]);
    },
  );
  test(
    'strict response uses original rows, not merged normalized coverage',
    () {
      final raw = response(version: 2, rows: [row.toJson(), row.toJson()]);
      raw['normalized_intervals'] = [
        {'start_minute': 0, 'end_minute': 210},
        {'start_minute': 10020, 'end_minute': 10080},
      ];
      expect(PlayAvailability.fromJson(raw).intervals, hasLength(2));
      for (final invalid in [
        {...raw, 'timezone': 'UTC'},
        {...raw, 'version': 0},
        {...raw, 'extra': true},
        {
          ...raw,
          'intervals': [
            {
              'weekday': 7,
              'start': '23:01',
              'end': '03:30',
              'end_day_offset': 1,
            },
          ],
        },
        {
          ...raw,
          'normalized_intervals': [
            {'start_minute': 10, 'end_minute': 10},
          ],
        },
      ]) {
        expect(() => PlayAvailability.fromJson(invalid), throwsFormatException);
      }
    },
  );
  test(
    'verified only; one load, no network on editor open/cancel; empty rows are explicit',
    () async {
      access.verified = false;
      model.initialize();
      await settle();
      expect(api.reads, 0);
      expect(model.visible, false);
      access.change(true);
      await settle();
      expect(api.reads, 1);
      model.toggle();
      model.selectDay(3);
      expect(model.draft.single.start, null);
      expect(model.canSave, false);
      model.cancel();
      model.toggle();
      expect(model.draft, isEmpty);
      expect(api.reads, 1);
      expect(api.writes, isEmpty);
      await model.save();
      expect(api.writes.single.body, {
        'expected_version': 1,
        'timezone': 'Asia/Seoul',
        'intervals': <Object>[],
      });
      expect(model.expanded, false);
    },
  );
  test(
    'unknown outcome retains immutable key/body, blocks edits and duplicate saves',
    () async {
      api.current = response(version: 2, rows: [row.toJson()]);
      model.initialize();
      await settle();
      model.toggle();
      final pending = Completer<Map<String, dynamic>?>();
      api.onWrite = () => pending.future;
      final first = model.save();
      await model.save();
      model.selectDay(3);
      expect(model.draft, hasLength(1));
      expect(api.writes, hasLength(1));
      pending.completeError(const AccountReadException('NETWORK_UNAVAILABLE'));
      await first;
      expect(model.hasPending, true);
      expect(model.expanded, true);
      model.cancel();
      model.toggle();
      expect(model.draft.single.toJson(), row.toJson());
      api.onWrite = null;
      await model.retry();
      expect(api.writes[0].key, api.writes[1].key);
      expect(api.writes[0].body, api.writes[1].body);
      expect(
        api.writes[0].key,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(model.expanded, false);
      expect(model.hasPending, false);
    },
  );
  test(
    '409 keeps draft; explicit latest read then save uses current revision/new key',
    () async {
      api.current = response(version: 2, rows: [row.toJson()]);
      model.initialize();
      await settle();
      model.toggle();
      api.onWrite = () async =>
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
      await model.save();
      expect(model.needsReview, true);
      expect(model.canSave, false);
      api.current = response(version: 5);
      await model.reload();
      expect(model.draft.single.weekday, 7);
      expect(model.value!.version, 5);
      expect(api.writes, hasLength(1));
      api.onWrite = null;
      await model.save();
      expect(api.writes[1].body['expected_version'], 5);
      expect(api.writes[1].key, isNot(api.writes[0].key));
    },
  );
  test('late read and old picker row cannot populate another member', () async {
    final read = Completer<Map<String, dynamic>?>();
    api.onRead = () => read.future;
    model.initialize();
    api.onRead = null;
    session.change(authenticated: true, user: 'other-member');
    await settle();
    read.complete(response(version: 2, rows: [row.toJson()]));
    await settle();
    expect(model.value!.version, 1);
    expect(model.value!.intervals, isEmpty);
    model.toggle();
    model.replaceRow(row, row.withTime(ending: false, minute: 1200));
    expect(model.draft, isEmpty);
  });
  test(
    'late successful write after ownership loss never resurrects editor or values',
    () async {
      api.current = response(version: 2, rows: [row.toJson()]);
      model.initialize();
      await settle();
      model.toggle();
      final write = Completer<Map<String, dynamic>?>();
      api.onWrite = () => write.future;
      final save = model.save();
      access.change(false);
      write.complete(response(version: 3, rows: [row.toJson()]));
      await save;
      expect(model.visible, false);
      expect(model.value, null);
      expect(model.draft, isEmpty);
      expect(model.hasPending, false);
    },
  );
  test('disposal ignores late completion', () async {
    final read = Completer<Map<String, dynamic>?>();
    api.onRead = () => read.future;
    model.initialize();
    model.dispose();
    read.complete(response(version: 2, rows: [row.toJson()]));
    await settle();
    expect(model.value, null);
  });
  test(
    'Retry-After blocks immediate retries; expired command requires explicit review',
    () async {
      model.dispose();
      var clock = DateTime.utc(2026, 10, 20);
      model = PlayAvailabilityViewModel(
        repository: BackendPlayAvailabilityRepository(api),
        session: session,
        accessChanges: access,
        hasVerifiedAccount: () => access.verified,
        now: () => clock,
      );
      api.current = response(version: 2, rows: [row.toJson()]);
      model.initialize();
      await settle();
      model.toggle();
      api.onWrite = () async => throw const AccountReadException(
        'REQUEST_IN_PROGRESS',
        status: 409,
        retryAfter: Duration(seconds: 2),
      );
      await model.save();
      expect(model.canRetry, false);
      await model.retry();
      expect(api.writes, hasLength(1));
      clock = clock.add(const Duration(seconds: 2));
      expect(model.canRetry, true);
      clock = clock.add(const Duration(hours: 24));
      expect(model.canRetry, false);
      api.current = response(version: 3, rows: [row.toJson()]);
      await model.reviewPending();
      expect(model.hasPending, false);
      expect(model.value!.version, 3);
      expect(model.draft.single.toJson(), row.toJson());
      expect(api.writes, hasLength(1));
    },
  );
  test(
    'invalid server response never becomes a successful empty save',
    () async {
      api.current = response(version: 2, rows: [row.toJson()]);
      model.initialize();
      await settle();
      model.toggle();
      api.onWrite = () async => <String, dynamic>{};
      await model.save();
      expect(model.failure, 'INVALID_RESPONSE');
      expect(model.hasPending, true);
      expect(model.expanded, true);
      expect(model.value!.version, 2);
      expect(model.draft.single.toJson(), row.toJson());
    },
  );
}
