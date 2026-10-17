import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/server_account_verification_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_verification.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';

import '../../../support/server_account_read_fakes.dart';

const challenge = '55555555-5555-4555-8555-555555555555';
const requestKey = '66666666-6666-4666-8666-666666666666';

Map<String, dynamic> verificationJson() => {
  'challenge_id': challenge,
  'status': 'pending',
  'required_slots': ['무기', '투구'],
  'expires_at': '2026-10-15T01:10:00Z',
  'remaining_seconds': 600,
  'result_code': 'PROVIDER_EVIDENCE_PENDING',
  'result_reference': null,
  'registration_id': registrationId,
};

class VerificationApiFake implements BackendRegistrationApi {
  final calls =
      <
        ({
          String path,
          String method,
          Map<String, dynamic>? body,
          String? key,
          int status,
        })
      >[];
  Future<Map<String, dynamic>?> Function()? respond;

  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    calls.add((
      path: path,
      method: method,
      body: body,
      key: idempotencyKey,
      status: expectedStatus,
    ));
    return respond != null ? respond!() : verificationJson();
  }
}

void main() {
  late ReadSessionFake session;
  late VerificationApiFake api;
  late ServerAccountVerificationClient client;
  setUp(() {
    session = ReadSessionFake();
    api = VerificationApiFake();
    client = ServerAccountVerificationClient(api, session);
  });
  tearDown(() => session.dispose());

  test('published response shape and evidence-pending status are preserved', () {
    final spec =
        jsonDecode(
              File(
                'docs/backend-migration/contracts/issue7-9e1a255.openapi.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final wire = spec['components']['schemas']['VerificationOut'] as Map;
    expect(verificationJson().keys.toSet(), (wire['required'] as List).toSet());
    final result = ServerAccountVerification.fromJson(verificationJson());
    expect(result.status, ServerVerificationStatus.pending);
    expect(result.resultCode, 'PROVIDER_EVIDENCE_PENDING');
    expect(result.resultReference, isNull);
    expect(result.requiredSlots, ['무기', '투구']);
    expect(() => result.requiredSlots.add('상의'), throwsUnsupportedError);
  });

  test('unknown business codes remain pending, not verified', () {
    final result = ServerAccountVerification.fromJson(
      verificationJson()..['result_code'] = 'FUTURE_EVIDENCE_PENDING',
    );
    expect(result.status, ServerVerificationStatus.pending);
    expect(result.resultCode, 'FUTURE_EVIDENCE_PENDING');
  });

  test('rejects malformed and incomplete responses without coercion', () {
    final invalid = <Map<String, dynamic>>[
      verificationJson()..remove('result_reference'),
      verificationJson()..['owner_id'] = 'unexpected',
      verificationJson()..['status'] = 'success',
      verificationJson()..['challenge_id'] = '../other',
      verificationJson()..['registration_id'] = 1,
      verificationJson()..['result_reference'] = '',
      verificationJson()..['remaining_seconds'] = true,
      verificationJson()..['remaining_seconds'] = '600',
      verificationJson()..['remaining_seconds'] = -1,
      verificationJson()..['required_slots'] = [1],
      verificationJson()..['expires_at'] = '2026-10-15T01:10:00',
      verificationJson()..['expires_at'] = 'invalidZ',
      verificationJson()..['result_code'] = 1,
    ];
    for (final json in invalid) {
      expect(
        () => ServerAccountVerification.fromJson(json),
        throwsFormatException,
      );
    }
  });

  test(
    'selected registration freezes nested target, version and replay payload',
    () async {
      final command = ServerVerificationCommand.startForRegistration(
        session,
        registrationId: registrationId,
        idempotencyKey: requestKey,
        targetCharacter: VerificationTarget(
          serverName: ' server ',
          characterName: ' low-level ',
        ),
        expectedRegistrationVersion: 3,
      );
      expect(command.body, {
        'source': 'registration',
        'registration_id': registrationId,
        'target_character': {
          'server_name': 'server',
          'character_name': 'low-level',
        },
        'expected_registration_version': 3,
      });
      expect(
        () => (command.body!['target_character'] as Map)['character_name'] =
            'other',
        throwsUnsupportedError,
      );
      api.respond = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await expectLater(
        client.execute(command),
        throwsA(isA<AccountReadException>()),
      );
      api.respond = null;
      await client.execute(command);
      expect(identical(api.calls.first.body, api.calls.last.body), isTrue);
      expect(api.calls.last.key, requestKey);
    },
  );

  test(
    'target and version are paired and reject invalid names or versions',
    () {
      final target = VerificationTarget(serverName: 's', characterName: 'n');
      for (final args in [(target, null), (null, 1), (target, 0)]) {
        expect(
          () => ServerVerificationCommand.startForRegistration(
            session,
            registrationId: registrationId,
            idempotencyKey: requestKey,
            targetCharacter: args.$1,
            expectedRegistrationVersion: args.$2,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => VerificationTarget(serverName: ' ', characterName: 'n'),
        throwsFormatException,
      );
      expect(
        () => VerificationTarget(serverName: 's', characterName: 'n' * 65),
        throwsFormatException,
      );
    },
  );

  test(
    'registration and direct input use mutually exclusive wire sources',
    () async {
      await client.execute(
        ServerVerificationCommand.startForRegistration(
          session,
          registrationId: registrationId,
          idempotencyKey: requestKey,
        ),
      );
      expect(api.calls.single.status, 201);
      expect(api.calls.single.body, {
        'source': 'registration',
        'registration_id': registrationId,
      });
      await client.execute(
        ServerVerificationCommand.startForName(
          session,
          characterName: '  fixture  ',
          idempotencyKey: requestKey,
        ),
      );
      expect(api.calls.last.body, {
        'source': 'direct_input',
        'character_name': 'fixture',
      });
    },
  );

  test(
    'GET and confirm reject a response from a different challenge',
    () async {
      api.respond = () async =>
          verificationJson()..['challenge_id'] = characterId;
      await expectLater(
        client.load(challenge),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
      await expectLater(
        client.execute(
          ServerVerificationCommand.confirm(
            session,
            challengeId: challenge,
            idempotencyKey: requestKey,
          ),
        ),
        throwsA(isA<AccountReadException>()),
      );
      expect(
        api.calls.last.path,
        '/v1/me/game-account-verifications/$challenge/confirm',
      );
      expect(api.calls.last.body, isEmpty);
    },
  );

  test('start cannot attach a response to another registration', () async {
    api.respond = () async =>
        verificationJson()..['registration_id'] = characterId;
    await expectLater(
      client.execute(
        ServerVerificationCommand.startForRegistration(
          session,
          registrationId: registrationId,
          idempotencyKey: requestKey,
        ),
      ),
      throwsA(isA<AccountReadException>()),
    );
  });

  test('uncertain write reuses the exact key and immutable payload', () async {
    final command = ServerVerificationCommand.startForName(
      session,
      characterName: 'fixture',
      idempotencyKey: requestKey,
    );
    expect(
      () => command.body!['character_name'] = 'other',
      throwsUnsupportedError,
    );
    api.respond = () async => throw const AccountReadException('NETWORK_ERROR');
    await expectLater(
      client.execute(command),
      throwsA(isA<AccountReadException>()),
    );
    api.respond = null;
    await client.execute(command);
    expect(api.calls.length, 2);
    expect(api.calls.map((call) => call.key), everyElement(requestKey));
    expect(identical(api.calls.first.body, api.calls.last.body), isTrue);
  });

  test(
    'guest, invalid path, invalid key and stale commands make no calls',
    () async {
      await expectLater(client.load('../other'), throwsFormatException);
      expect(
        () => ServerVerificationCommand.startForName(
          session,
          characterName: '',
          idempotencyKey: requestKey,
        ),
        throwsFormatException,
      );
      expect(
        () => ServerVerificationCommand.confirm(
          session,
          challengeId: challenge,
          idempotencyKey: '55555555-5555-1555-8555-555555555555',
        ),
        throwsFormatException,
      );
      final old = ServerVerificationCommand.confirm(
        session,
        challengeId: challenge,
        idempotencyKey: requestKey,
      );
      session.change(authenticated: true);
      await expectLater(
        client.execute(old),
        throwsA(isA<AccountReadException>()),
      );
      session.change(authenticated: false);
      await expectLater(
        client.load(challenge),
        throwsA(isA<AccountReadException>()),
      );
      expect(api.calls, isEmpty);
    },
  );

  for (final nextUser in ['sample-user', 'another-user']) {
    test(
      'late response is rejected after session switch to $nextUser',
      () async {
        final pending = Completer<Map<String, dynamic>?>();
        api.respond = () => pending.future;
        final result = client.load(challenge);
        final check = expectLater(
          result,
          throwsA(
            isA<AccountReadException>().having(
              (e) => e.code,
              'code',
              'SESSION_CHANGED',
            ),
          ),
        );
        session.change(authenticated: true, user: nextUser);
        pending.complete(verificationJson());
        await check;
      },
    );
  }

  test('late business errors cannot leak into a new session', () async {
    final pending = Completer<Map<String, dynamic>?>();
    api.respond = () => pending.future;
    final check = expectLater(
      client.load(challenge),
      throwsA(
        isA<AccountReadException>().having(
          (e) => e.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
    session.change(authenticated: false);
    pending.completeError(
      const AccountReadException('ROSTER_EVIDENCE_PENDING'),
    );
    await check;
  });

  test(
    'real authenticated transport sends POST 201, confirm 200 and DELETE 204',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      final path = ServerVerificationCommand.basePath;
      final startBody = {
        'source': 'registration',
        'registration_id': registrationId,
      };
      final headers = {
        'Authorization': 'Bearer test-access',
        'Idempotency-Key': requestKey,
      };
      adapter.onPost(
        path,
        (server) => server.reply(201, verificationJson()),
        data: startBody,
        headers: headers,
      );
      adapter.onPost(
        '$path/$challenge/confirm',
        (server) => server.reply(
          200,
          verificationJson()..['result_code'] = 'ROSTER_EVIDENCE_PENDING',
        ),
        data: <String, dynamic>{},
        headers: headers,
      );
      adapter.onDelete(
        '$path/$challenge',
        (server) => server.reply(204, null),
        headers: headers,
      );
      final transport = ServerAccountVerificationClient(
        DioBackendAccountReadApi(dio, session),
        session,
      );
      expect(
        (await transport.execute(
          ServerVerificationCommand.startForRegistration(
            session,
            registrationId: registrationId,
            idempotencyKey: requestKey,
          ),
        ))!.status,
        ServerVerificationStatus.pending,
      );
      expect(
        (await transport.execute(
          ServerVerificationCommand.confirm(
            session,
            challengeId: challenge,
            idempotencyKey: requestKey,
          ),
        ))!.resultCode,
        'ROSTER_EVIDENCE_PENDING',
      );
      expect(
        await transport.execute(
          ServerVerificationCommand.cancel(
            session,
            challengeId: challenge,
            idempotencyKey: requestKey,
          ),
        ),
        isNull,
      );
      expect(session.isAuthenticated, isTrue);
    },
  );

  test(
    'DELETE rejects unexpected body and non-delete rejects missing body',
    () async {
      await expectLater(
        client.execute(
          ServerVerificationCommand.cancel(
            session,
            challengeId: challenge,
            idempotencyKey: requestKey,
          ),
        ),
        throwsA(isA<AccountReadException>()),
      );
      api.respond = () async => null;
      await expectLater(
        client.load(challenge),
        throwsA(isA<AccountReadException>()),
      );
    },
  );
}
