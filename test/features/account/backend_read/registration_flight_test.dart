import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_account_read_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_combat_power_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_registration_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

class NoWritesApi implements BackendRegistrationApi {
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) => throw StateError('No mutation expected');
}

void main() {
  late ReadSessionFake session;
  late ReadApiFake api;
  late ServerAccountReadRepository reads;
  setUp(() {
    session = ReadSessionFake();
    api = ReadApiFake();
    reads = ServerAccountReadRepository(api, session);
  });
  tearDown(() => session.dispose());

  test(
    'initial panel and power cache use one registration HTTP request',
    () async {
      final pending = Completer<ServerRegistrationPage>();
      api.onRegistrations = (_) => pending.future;
      final writes = ServerRegistrationViewModel(NoWritesApi(), reads, session);
      final panel = ServerAccountReadViewModel(reads, session);
      final powers = ServerCombatPowerViewModel(reads, writes, session);
      addTearDown(() {
        panel.dispose();
        powers.dispose();
        writes.dispose();
      });
      expect(api.registrationCalls, 1);
      pending.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
      await Future<void>.delayed(Duration.zero);
      expect(panel.registrations.single.registrationId, registrationId);
      expect(powers.registrations.single.registrationId, registrationId);
      expect(api.characterCalls, 1);
    },
  );

  test(
    'consumers share the complete pagination, never a partial snapshot',
    () async {
      final first = Completer<ServerRegistrationPage>();
      final second = Completer<ServerRegistrationPage>();
      api.onRegistrations = (cursor) =>
          cursor == null ? first.future : second.future;
      final one = reads.loadRegistrations(shareInFlight: true);
      final two = reads.loadRegistrations(shareInFlight: true);
      expect(api.registrationCalls, 1);
      first.complete(
        ServerRegistrationPage.fromJson(registrationPageJson(cursor: 'next')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.registrationCalls, 2);
      final three = reads.loadRegistrations(shareInFlight: true);
      final json = registrationJson()
        ..['registration_id'] = '66666666-6666-4666-8666-666666666666'
        ..['is_main'] = false;
      second.complete(
        ServerRegistrationPage.fromJson({
          'items': [json],
          'next_cursor': null,
        }),
      );
      final results = await Future.wait([one, two, three]);
      expect(results.every((r) => r.length == 2), isTrue);
      expect(identical(results[0], results[1]), isTrue);
      expect(api.registrationCalls, 2);
    },
  );

  test(
    'success is not cached for subsequent explicit or initial reads',
    () async {
      await reads.loadRegistrations(shareInFlight: true);
      await reads.loadRegistrations(shareInFlight: true);
      await reads.loadRegistrations();
      expect(api.registrationCalls, 3);
    },
  );

  test(
    'shared failure reaches both consumers and next read starts afresh',
    () async {
      final pending = Completer<ServerRegistrationPage>();
      api.onRegistrations = (_) => pending.future;
      final one = reads.loadRegistrations(shareInFlight: true);
      final two = reads.loadRegistrations(shareInFlight: true);
      final checks = [
        expectLater(one, throwsA(isA<AccountReadException>())),
        expectLater(two, throwsA(isA<AccountReadException>())),
      ];
      pending.completeError(const AccountReadException('NETWORK_UNAVAILABLE'));
      await Future.wait(checks);
      api.onRegistrations = null;
      await reads.loadRegistrations(shareInFlight: true);
      expect(api.registrationCalls, 2);
    },
  );

  for (final changeMember in [false, true]) {
    test(
      'new ${changeMember ? 'member' : 'session'} never joins old flight',
      () async {
        final old = Completer<ServerRegistrationPage>();
        final current = Completer<ServerRegistrationPage>();
        api.onRegistrations = (_) =>
            api.registrationCalls == 1 ? old.future : current.future;
        final previous = reads.loadRegistrations(shareInFlight: true);
        final rejected = expectLater(
          previous,
          throwsA(
            isA<AccountReadException>().having(
              (e) => e.code,
              'code',
              'SESSION_CHANGED',
            ),
          ),
        );
        session.change(
          authenticated: true,
          user: changeMember ? 'next-user' : null,
        );
        final next = reads.loadRegistrations(shareInFlight: true);
        expect(api.registrationCalls, 2);
        old.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
        await rejected;
        // Cleanup for the old scope must not evict the new scope's flight.
        final joined = reads.loadRegistrations(shareInFlight: true);
        expect(api.registrationCalls, 2);
        current.complete(
          ServerRegistrationPage.fromJson(registrationPageJson(empty: true)),
        );
        expect(await next, isEmpty);
        expect(await joined, isEmpty);
      },
    );
  }

  test(
    'post-write explicit review starts a new GET even while initial read is pending',
    () async {
      final initial = Completer<ServerRegistrationPage>();
      api.onRegistrations = (_) async => api.registrationCalls == 1
          ? initial.future
          : ServerRegistrationPage.fromJson(registrationPageJson());
      final old = reads.loadRegistrations(shareInFlight: true);
      final refreshed = await reads.loadRegistrations();
      expect(api.registrationCalls, 2);
      expect(refreshed.single.registrationId, registrationId);
      initial.complete(
        ServerRegistrationPage.fromJson(registrationPageJson(empty: true)),
      );
      expect(await old, isEmpty);
      expect(refreshed.length, 1);
    },
  );
}
