import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_settings_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

class SettingsApiFake implements BackendRegistrationApi {
  Map<String, dynamic> current = {
    'nice_group_auto_refresh_enabled': false,
    'version': 1,
  };
  final calls = <({String method, Map<String, dynamic>? body, String? key})>[];
  Future<Map<String, dynamic>?> Function()? onGet;
  Future<Map<String, dynamic>?> Function()? onPut;
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    expect(path, '/v1/me/settings');
    calls.add((method: method, body: body, key: idempotencyKey));
    if (method == 'GET') return onGet == null ? Map.of(current) : onGet!();
    if (onPut != null) return onPut!();
    current = {
      'nice_group_auto_refresh_enabled':
          body!['nice_group_auto_refresh_enabled'],
      'version': (current['version'] as int) + 1,
    };
    return Map.of(current);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ReadSessionFake session;
  late SettingsApiFake api;
  late MemberSettingsViewModel model;
  test(
    'strict boolean/integer and exact keys, never coerce missing into OFF',
    () {
      model = MemberSettingsViewModel(api, session);
      for (final json in <Map<String, dynamic>?>[
        null,
        {},
        {'nice_group_auto_refresh_enabled': 0, 'version': 1},
        {'nice_group_auto_refresh_enabled': false, 'version': true},
        {'nice_group_auto_refresh_enabled': false, 'version': 0},
        {'nice_group_auto_refresh_enabled': false, 'version': 1.0},
        {'nice_group_auto_refresh_enabled': false, 'version': 1, 'extra': true},
      ]) {
        expect(() => MemberSettings.fromJson(json), throwsFormatException);
      }
    },
  );

  setUp(() {
    session = ReadSessionFake();
    api = SettingsApiFake();
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });

  test('guest never GETs or writes; login restores server true', () async {
    session.change(authenticated: false);
    model = MemberSettingsViewModel(api, session);
    await model.change(true);
    expect(api.calls, isEmpty);
    api.current = {'nice_group_auto_refresh_enabled': true, 'version': 4};
    session.change(authenticated: true);
    await settle();
    expect(model.value!.enabled, isTrue);
    expect(api.calls.single.method, 'GET');
  });

  test('failed first read stays unknown and never writes false', () async {
    api.onGet = () async =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    model = MemberSettingsViewModel(api, session);
    await settle();
    expect(model.value, isNull);
    expect(model.canChange, isFalse);
    await model.change(false);
    expect(api.calls.every((c) => c.method == 'GET'), isTrue);
  });

  test(
    'save immediately, suppress duplicate taps and GET current after replay',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      final put = Completer<Map<String, dynamic>?>();
      api.onPut = () => put.future;
      final saving = model.change(true);
      await model.change(false);
      expect(model.busy, isTrue);
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
      // A replay can be older than another device's current state.
      api.current = {'nice_group_auto_refresh_enabled': false, 'version': 3};
      put.complete({'nice_group_auto_refresh_enabled': true, 'version': 2});
      await saving;
      expect(model.value!.enabled, isFalse);
      expect(model.value!.version, 3);
      expect(model.hasPending, isFalse);
    },
  );

  test('lost response retries exact key/body and blocks replacement', () async {
    model = MemberSettingsViewModel(api, session);
    await settle();
    api.onPut = () async =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    await model.change(true);
    await model.change(false);
    await model.retry();
    final puts = api.calls.where((c) => c.method == 'PUT').toList();
    expect(puts.length, 2);
    expect(puts[0].key, puts[1].key);
    expect(
      puts[0].key,
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
    expect(puts[0].body, {
      'nice_group_auto_refresh_enabled': true,
      'expected_version': 1,
    });
    expect(puts[1].body, puts[0].body);
  });

  test(
    'version conflict GETs other device value without auto overwrite',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      api.current = {'nice_group_auto_refresh_enabled': true, 'version': 5};
      api.onPut = () async =>
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
      await model.change(true);
      expect(model.hasPending, isFalse);
      expect(model.value!.version, 5);
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
      expect(model.notice, contains('다른 곳'));
    },
  );

  test(
    'same member new session clears pending and restores GET only',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      api.onPut = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.change(true);
      session.change(authenticated: false);
      expect(model.value, isNull);
      expect(model.hasPending, isFalse);
      api.current = {'nice_group_auto_refresh_enabled': true, 'version': 2};
      session.change(authenticated: true);
      await settle();
      expect(model.value!.enabled, isTrue);
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
    },
  );

  test(
    'late read from previous member cannot overwrite current settings',
    () async {
      final oldRead = Completer<Map<String, dynamic>?>();
      api.onGet = () => oldRead.future;
      model = MemberSettingsViewModel(api, session);
      api.onGet = null;
      session.change(authenticated: true, user: 'other-user');
      await settle();
      oldRead.complete({'nice_group_auto_refresh_enabled': true, 'version': 8});
      await settle();
      expect(model.value!.enabled, isFalse);
      expect(model.value!.version, 1);
    },
  );

  test(
    'late PUT from previous member cannot trigger GET or update next member',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      final oldPut = Completer<Map<String, dynamic>?>();
      api.onPut = () => oldPut.future;
      final saving = model.change(true);
      session.change(authenticated: true, user: 'other-user');
      await settle();
      final callCount = api.calls.length;
      oldPut.complete({'nice_group_auto_refresh_enabled': true, 'version': 2});
      await saving;
      expect(api.calls.length, callCount);
      expect(model.value!.enabled, isFalse);
      expect(model.hasPending, isFalse);
    },
  );

  test(
    '24h expiration requires successful GET and explicit finish, no fresh key retry',
    () async {
      var now = DateTime.utc(2026, 10, 14);
      model = MemberSettingsViewModel(api, session, now: () => now);
      await settle();
      api.onPut = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.change(true);
      now = now.add(const Duration(hours: 24));
      expect(model.canRetry, isFalse);
      await model.retry();
      model.finishReview();
      expect(model.hasPending, isTrue);
      await model.reload();
      model.finishReview();
      expect(model.hasPending, isFalse);
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
    },
  );

  test('Retry-After blocks immediate retry and replacement', () async {
    var now = DateTime.utc(2026, 10, 14);
    model = MemberSettingsViewModel(api, session, now: () => now);
    await settle();
    api.onPut = () async => throw const AccountReadException(
      'REQUEST_IN_PROGRESS',
      status: 409,
      retryAfter: Duration(seconds: 2),
    );
    await model.change(true);
    expect(model.canRetry, isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(model.canRetry, isTrue);
    await model.retry();
    expect(api.calls.where((c) => c.method == 'PUT').length, 2);
  });

  test(
    'mismatched PUT result keeps original immutable command recoverable',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      api.onPut = () async => {
        'nice_group_auto_refresh_enabled': false,
        'version': 2,
      };
      await model.change(true);
      expect(model.failure!.code, 'INVALID_RESPONSE');
      expect(model.hasPending, isTrue);
      expect(model.value!.enabled, isFalse);
    },
  );

  test(
    'confirmed PUT followed by failed GET stays unknown and does not resubmit',
    () async {
      model = MemberSettingsViewModel(api, session);
      await settle();
      api.onGet = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.change(true);
      expect(model.value, isNull);
      expect(model.hasPending, isFalse);
      expect(model.notice, contains('저장했습니다'));
      await model.retry();
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
      api.onGet = null;
      await model.reload();
      expect(model.value!.enabled, isTrue);
    },
  );

  test('failed review cannot shorten a pending command Retry-After', () async {
    var now = DateTime.utc(2026, 10, 14);
    model = MemberSettingsViewModel(api, session, now: () => now);
    await settle();
    api.onPut = () async => throw const AccountReadException(
      'REQUEST_IN_PROGRESS',
      status: 409,
      retryAfter: Duration(seconds: 2),
    );
    await model.change(true);
    api.onGet = () async =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    await model.reload();
    expect(model.canRetry, isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(model.canRetry, isTrue);
  });
}
