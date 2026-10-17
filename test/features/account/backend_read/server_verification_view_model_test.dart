import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/server_account_verification_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_verification.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_verification_view_model.dart';

import '../../../support/server_account_read_fakes.dart';

const challenge = '55555555-5555-4555-8555-555555555555';
Map<String, dynamic> snapshot({String status = 'pending', String? code}) => {
  'challenge_id': challenge,
  'status': status,
  'required_slots': ['무기', '투구'],
  'expires_at': '2026-10-15T01:10:00Z',
  'remaining_seconds': status == 'pending' ? 600 : 0,
  'result_code': code,
  'result_reference': null,
  'registration_id': registrationId,
};

class VerificationStateApi implements BackendRegistrationApi {
  final calls = <({String method, Map<String, dynamic>? body, String? key})>[];
  Future<Map<String, dynamic>?> Function(String method)? respond;
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    calls.add((method: method, body: body, key: idempotencyKey));
    return respond != null ? respond!(method) : snapshot();
  }
}

void main() {
  late ReadSessionFake session;
  late VerificationStateApi api;
  late ServerVerificationViewModel model;
  late DateTime now;
  setUp(() {
    session = ReadSessionFake();
    api = VerificationStateApi();
    // Intentionally differs from server expires_at: the server duration wins.
    now = DateTime.utc(2030);
    model = ServerVerificationViewModel(
      ServerAccountVerificationClient(api, session),
      now: () => now,
    );
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });

  test(
    'server already-verified start is settled without retry or fabricated success',
    () async {
      api.respond = (_) async =>
          throw const AccountReadException('ALREADY_VERIFIED', status: 409);
      await model.start(characterName: 'new-alias');
      expect(model.alreadyVerified, isTrue);
      expect(model.hasPending, isFalse);
      expect(model.value, isNull);
      expect(model.canRetry, isFalse);
      expect(model.canConfirm, isFalse);
      await model.retry();
      expect(api.calls, hasLength(1));
      session.change(authenticated: false);
      expect(model.alreadyVerified, isFalse);
    },
  );

  for (final getFails in [false, true]) {
    test(
      'already-verified confirm preserves pending challenge; GET fails=$getFails',
      () async {
        await model.start(characterName: 'sample');
        api.respond = (method) async {
          if (method == 'POST') {
            throw const AccountReadException('ALREADY_VERIFIED', status: 409);
          }
          if (getFails) throw const AccountReadException('NETWORK_UNAVAILABLE');
          return snapshot();
        };
        await model.confirm();
        expect(model.alreadyVerified, isTrue);
        expect(model.hasPending, isFalse);
        expect(model.hasChallenge, isTrue);
        expect(model.failure!.code, 'ALREADY_VERIFIED');
        expect(
          model.value?.status,
          getFails ? null : ServerVerificationStatus.pending,
        );
        expect(model.canConfirm, isFalse);
        expect(model.canCancel, isFalse);
        await model.retry();
        await model.confirm();
        await model.cancel();
        expect(api.calls.map((c) => c.method), ['POST', 'GET', 'POST', 'GET']);
      },
    );
  }

  test(
    'lost completed start ACK is still recovered and followed by current verified GET',
    () async {
      api.respond = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.start(characterName: 'sample');
      final original = api.calls.single;
      api.respond = (method) async =>
          snapshot(status: method == 'POST' ? 'pending' : 'verified');
      await model.retry();
      expect(model.alreadyVerified, isFalse);
      expect(model.value!.status, ServerVerificationStatus.verified);
      expect(api.calls[1].key, original.key);
      expect(api.calls[1].body, same(original.body));
      expect(api.calls.map((c) => c.method), ['POST', 'POST', 'GET']);
    },
  );

  test(
    'registration start reads current snapshot; local time is only advisory',
    () async {
      await model.start(registrationId: registrationId);
      expect(api.calls.map((c) => c.method), ['POST', 'GET']);
      expect(api.calls.first.body, {
        'source': 'registration',
        'registration_id': registrationId,
      });
      expect(model.remainingSeconds, 600);
      now = now.add(const Duration(seconds: 601));
      expect(model.remainingSeconds, 0);
      expect(model.value!.status, ServerVerificationStatus.pending);
      expect(model.canConfirm, false);
      expect(model.canStart, false);
      expect(model.canReload, true);
      api.respond = (_) async => snapshot(status: 'expired');
      await model.reload();
      expect(model.canStart, true);
    },
  );

  for (final code in [
    'PROVIDER_EVIDENCE_PENDING',
    'ROSTER_EVIDENCE_PENDING',
    'ACCOUNT_BINDING_EVIDENCE_PENDING',
    'FUTURE_RESULT',
  ]) {
    test(
      '$code remains pending; GET without a verdict does not manufacture success',
      () async {
        api.respond = (method) async =>
            snapshot(code: method == 'POST' ? code : null);
        await model.start(characterName: ' sample ');
        expect(api.calls.first.body, {
          'source': 'direct_input',
          'character_name': 'sample',
        });
        expect(model.verdictCode, code);
        expect(model.value!.status, ServerVerificationStatus.pending);
        final firstKey = api.calls.first.key;
        await model.confirm();
        expect(api.calls[2].body, isEmpty);
        expect(api.calls[2].key, isNot(firstKey));
        expect(model.hasPending, false);
        expect(model.value!.status, ServerVerificationStatus.pending);
      },
    );
  }

  test(
    'double tap cannot issue concurrent start, confirm, cancel or retry',
    () async {
      final waiting = Completer<Map<String, dynamic>?>();
      api.respond = (_) => waiting.future;
      final first = model.start(characterName: 'sample');
      await model.start(characterName: 'another');
      await model.confirm();
      await model.cancel();
      await model.retry();
      expect(api.calls.length, 1);
      api.respond = (_) async => snapshot();
      waiting.complete(snapshot());
      await first;
      expect(model.busy, false);
    },
  );

  test(
    'uncertain start keeps same key/body and replay is followed by current GET',
    () async {
      api.respond = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.start(characterName: 'sample');
      expect(model.hasPending, true);
      expect(model.canStart, false);
      api.respond = (method) async =>
          snapshot(status: method == 'GET' ? 'expired' : 'pending');
      await model.retry();
      expect(api.calls[1].key, api.calls[0].key);
      expect(identical(api.calls[1].body, api.calls[0].body), true);
      expect(model.value!.status, ServerVerificationStatus.expired);
      expect(model.canStart, true);
    },
  );

  test(
    'GET cannot settle uncertain confirm; same command recovery is required',
    () async {
      await model.start(characterName: 'sample');
      api.respond = (method) async {
        if (method == 'POST') {
          throw const AccountReadException('UPSTREAM_UNAVAILABLE', status: 503);
        }
        return snapshot();
      };
      await model.confirm();
      final uncertain = api.calls.last;
      await model.reload();
      expect(model.hasPending, true);
      expect(model.canConfirm, false);
      expect(model.canCancel, false);
      api.respond = (_) async => snapshot(status: 'verified');
      await model.retry();
      expect(api.calls[4].key, uncertain.key);
      expect(model.hasPending, false);
      expect(model.value!.status, ServerVerificationStatus.verified);
    },
  );

  test(
    'cancel 204 does not overwrite a concurrently verified challenge',
    () async {
      await model.start(characterName: 'sample');
      api.respond = (method) async =>
          method == 'DELETE' ? null : snapshot(status: 'verified');
      await model.cancel();
      expect(api.calls.map((c) => c.method), ['POST', 'GET', 'DELETE', 'GET']);
      expect(model.value!.status, ServerVerificationStatus.verified);
    },
  );

  test(
    'successful write with failed GET only retries GET, without another write',
    () async {
      api.respond = (method) async {
        if (method == 'GET') {
          throw const AccountReadException(
            'VERIFICATION_NOT_FOUND',
            status: 404,
          );
        }
        return snapshot();
      };
      await model.start(characterName: 'sample');
      expect(api.calls.length, 2);
      expect(model.value, null);
      expect(model.hasPending, false);
      expect(model.canStart, false);
      api.respond = (_) async => snapshot();
      await model.reload();
      expect(api.calls.map((c) => c.method), ['POST', 'GET', 'GET']);
    },
  );

  test('Retry-After blocks resending; the request key is retained', () async {
    api.respond = (_) async => throw const AccountReadException(
      'IDEMPOTENCY_IN_PROGRESS',
      status: 409,
      retryAfter: Duration(seconds: 30),
    );
    await model.start(characterName: 'sample');
    expect(model.retrySeconds, 30);
    await model.retry();
    expect(api.calls.length, 1);
    now = now.add(const Duration(seconds: 30));
    expect(model.canRetry, true);
    api.respond = (_) async => snapshot();
    await model.retry();
    expect(api.calls[1].key, api.calls[0].key);
  });

  test(
    '24-hour recovery boundary and idempotency conflicts never mint replacement writes',
    () async {
      api.respond = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.start(characterName: 'sample');
      now = now.add(const Duration(hours: 24));
      expect(model.canRetry, false);
      await model.retry();
      await model.start(characterName: 'sample');
      expect(api.calls.length, 1);
    },
  );

  for (final code in ['IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_EXPIRED']) {
    test('$code preserves unresolved command and blocks new key', () async {
      api.respond = (_) async => throw AccountReadException(code, status: 409);
      await model.start(characterName: 'sample');
      expect(model.hasPending, true);
      expect(model.canRetry, false);
      await model.start(characterName: 'sample');
      expect(api.calls.length, 1);
    });
  }

  test(
    'server terminal rejection refreshes status before enabling new start',
    () async {
      await model.start(characterName: 'sample');
      api.respond = (method) async {
        if (method == 'POST') {
          throw const AccountReadException('VERIFICATION_EXPIRED', status: 409);
        }
        return snapshot(status: 'expired');
      };
      await model.confirm();
      expect(model.hasPending, false);
      expect(model.value!.status, ServerVerificationStatus.expired);
      expect(model.canStart, true);
    },
  );

  for (final user in ['sample-user', 'other-user']) {
    for (final fail in [false, true]) {
      test(
        'late ${fail ? 'error' : 'success'} for $user cannot cross session generation',
        () async {
          final waiting = Completer<Map<String, dynamic>?>();
          api.respond = (_) => waiting.future;
          final running = model.start(characterName: 'sample');
          session.change(authenticated: true, user: user);
          if (fail) {
            waiting.completeError(
              const AccountReadException('UPSTREAM_UNAVAILABLE', status: 503),
            );
          } else {
            waiting.complete(snapshot(status: 'verified'));
          }
          await running;
          expect(model.value, null);
          expect(model.hasPending, false);
          expect(model.failure, null);
          expect(model.busy, false);
          expect(api.calls.length, 1);
        },
      );
    }
  }

  test('guest and invalid input do not issue network requests', () async {
    await model.start(characterName: '  ');
    expect(model.failure!.code, 'INVALID_REQUEST');
    session.change(authenticated: false);
    await model.start(characterName: 'sample');
    expect(api.calls, isEmpty);
  });

  for (final code in ['IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_EXPIRED']) {
    test('current GET cannot unlock $code recovery', () async {
      await model.start(characterName: 'sample');
      api.respond = (method) async {
        if (method == 'POST') throw AccountReadException(code, status: 409);
        return snapshot();
      };
      await model.confirm();
      await model.reload();
      expect(model.failure, null);
      expect(model.hasPending, true);
      expect(model.canRetry, false);
      await model.retry();
      expect(api.calls.length, 4);
    });
  }

  test(
    'disposing state owner prevents late results and notifications',
    () async {
      final retired = ServerVerificationViewModel(
        ServerAccountVerificationClient(api, session),
      );
      final waiting = Completer<Map<String, dynamic>?>();
      api.respond = (_) => waiting.future;
      var notifications = 0;
      retired.addListener(() => notifications++);
      final running = retired.start(characterName: 'sample');
      final beforeDispose = notifications;
      retired.dispose();
      waiting.complete(snapshot(status: 'verified'));
      await running;
      expect(notifications, beforeDispose);
      expect(retired.value, null);
      expect(api.calls.length, 1);
    },
  );
}
