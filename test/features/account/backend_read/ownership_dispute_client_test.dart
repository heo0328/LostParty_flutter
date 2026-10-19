import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart' hide Matcher;
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/ownership_command_store.dart';
import 'package:lost_party/features/account/data/ownership_dispute_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/ownership_command.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_verification.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import '../../../support/server_account_read_fakes.dart';
import 'ownership_dispute_fixtures.dart';

class JournalFake implements OwnershipJournalStorage {
  final values = <StorageScope, String>{};
  int writes = 0;
  int? failWrite;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> read(StorageScope scope) async => values[scope];
  @override
  Future<void> write(StorageScope scope, String value) async {
    writes++;
    await beforeWrite?.call();
    if (writes == failWrite) throw StateError('disk failed');
    values[scope] = value;
  }
}

class OwnershipApiFake implements BackendRegistrationApi {
  final calls =
      <
        ({
          String path,
          String method,
          Map<String, dynamic>? body,
          Map<String, dynamic>? query,
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
      query: query,
      key: idempotencyKey,
      status: expectedStatus,
    ));
    return respond == null ? proofJson() : respond!();
  }
}

Matcher code(String value) =>
    throwsA(isA<AccountReadException>().having((e) => e.code, 'code', value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReadSessionFake session;
  late StorageScope scope;
  late JournalFake disk;
  late OwnershipCommandStore store;
  late OwnershipApiFake api;
  late OwnershipDisputeClient client;
  OwnershipCommand claim({
    String key = commandKey,
    String name = 'Hero',
    DateTime? created,
  }) => OwnershipCommand.claim(
    session,
    scope,
    key: key,
    createdAt: created ?? clockNow,
    characterName: name,
  );
  OwnershipCommand versioned(OwnershipOperation operation) =>
      OwnershipCommand.versioned(
        session,
        scope,
        operation: operation,
        key: commandKey,
        createdAt: clockNow,
        id:
            operation == OwnershipOperation.confirm ||
                operation == OwnershipOperation.cancelProof
            ? proofId
            : disputeId,
        version: 1,
      );
  setUp(() {
    session = ReadSessionFake()..userId = ownerId;
    scope = StorageScope(baseUrl: 'https://example.test', userId: ownerId);
    disk = JournalFake();
    store = OwnershipCommandStore(disk);
    api = OwnershipApiFake();
    client = OwnershipDisputeClient(
      api,
      session,
      scope,
      store,
      now: () => clockNow,
    );
  });
  tearDown(() => session.dispose());

  test(
    'registration and defense nested bodies are immutable with exact revisions',
    () {
      final target = VerificationTarget(
        serverName: '서버',
        characterName: 'Hero',
      );
      final registration = OwnershipCommand.claim(
        session,
        scope,
        key: commandKey,
        createdAt: clockNow,
        registrationId: regId,
        registrationVersion: 3,
        target: target,
      );
      expect(
        () => (registration.body['target_character'] as Map)['character_name'] =
            'wrong',
        throwsUnsupportedError,
      );
      expect(registration.body['expected_registration_version'], 3);
      final selection = OwnershipDefenseSelection(
        registrationId: regId,
        characterId: charId,
        registrationVersion: 1,
        ownershipRevision: 2,
        rosterRevision: 3,
        lifecycleRevision: 4,
      );
      final defense = OwnershipCommand.defense(
        session,
        scope,
        key: commandKey,
        createdAt: clockNow,
        disputeId: disputeId,
        disputeVersion: 5,
        selection: selection,
      );
      expect(
        (defense.body['selection'] as Map)['expected_lifecycle_revision'],
        4,
      );
      expect(
        () => (defense.body['selection'] as Map).clear(),
        throwsUnsupportedError,
      );
      expect(defense.body['expected_dispute_version'], 5);
      expect(
        OwnershipCommand.restore(defense.toJson(), session, scope).toJson(),
        defense.toJson(),
      );
    },
  );

  test('invalid/mixed starts, versions and keys are rejected before HTTP', () {
    expect(
      () => OwnershipCommand.claim(
        session,
        scope,
        key: commandKey,
        createdAt: clockNow,
        characterName: 'Hero',
        registrationId: regId,
      ),
      throwsFormatException,
    );
    expect(
      () => OwnershipCommand.claim(
        session,
        scope,
        key: commandKey,
        createdAt: clockNow,
        registrationId: regId,
      ),
      throwsFormatException,
    );
    expect(() => claim(name: ''), throwsFormatException);
    expect(
      () => claim(key: ownerId.replaceFirst('4aaa', '1aaa')),
      throwsFormatException,
    );
    expect(
      () => OwnershipCommand.versioned(
        session,
        scope,
        operation: OwnershipOperation.confirm,
        key: commandKey,
        createdAt: clockNow,
        id: proofId,
        version: 0,
      ),
      throwsFormatException,
    );
    expect(api.calls, isEmpty);
  });

  test(
    'journal is durable before sending and ACK is persisted separately from current GET',
    () async {
      final command = claim();
      api.respond = () async {
        final entries = await store.load(session, scope);
        expect(entries.single.phase, OwnershipCommandPhase.awaitingAck);
        expect(entries.single.command.toJson(), command.toJson());
        return proofJson();
      };
      await client.execute(command);
      final entry = (await store.load(session, scope)).single;
      expect(entry.phase, OwnershipCommandPhase.awaitingCurrent);
      expect(entry.responseId, proofId);
      await expectLater(client.execute(command), code('CURRENT_READ_REQUIRED'));
      expect(api.calls.length, 1);
      api.respond = () async => proofJson();
      await client.loadCurrentFor(entry);
      expect((await store.load(session, scope)), isEmpty);
      expect(api.calls.map((e) => e.method), ['POST', 'GET']);
    },
  );

  test(
    'failed initial persistence sends no HTTP and retains the old journal',
    () async {
      disk.failWrite = 1;
      await expectLater(client.execute(claim()), code('JOURNAL_UNAVAILABLE'));
      expect(api.calls, isEmpty);
      expect(disk.values, isEmpty);
    },
  );

  test(
    'lost ACK persistence retains original command, never reports success',
    () async {
      disk.failWrite = 2;
      await expectLater(client.execute(claim()), code('JOURNAL_UNAVAILABLE'));
      final entry = (await store.load(session, scope)).single;
      expect(entry.phase, OwnershipCommandPhase.awaitingAck);
      expect(api.calls.length, 1);
    },
  );

  test(
    'lost response replays same key/body after restart and same-member new session',
    () async {
      final command = claim();
      api.respond = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await expectLater(client.execute(command), code('NETWORK_UNAVAILABLE'));
      session.change(authenticated: true);
      final restarted = OwnershipCommandStore(disk);
      final recovered = (await restarted.load(session, scope)).single.command;
      expect(recovered.sessionScope.generation, session.generation);
      expect(recovered.toJson(), command.toJson());
      api.respond = () async => proofJson();
      await OwnershipDisputeClient(
        api,
        session,
        scope,
        restarted,
        now: () => clockNow,
      ).execute(recovered);
      expect(api.calls.map((e) => e.key), [commandKey, commandKey]);
      expect(api.calls.first.body, api.calls.last.body);
      await expectLater(client.execute(command), code('SESSION_CHANGED'));
    },
  );

  test(
    'uncertain original cannot be discharged by a GET or an empty list',
    () async {
      await store.prepare(session, claim());
      await client.proof(proofId);
      api.respond = () async => pageJson([]);
      await client.proofs();
      final entry = (await store.load(session, scope)).single;
      expect(entry.phase, OwnershipCommandPhase.awaitingAck);
      await expectLater(client.loadCurrentFor(entry), code('ACK_REQUIRED'));
      await expectLater(
        client.execute(claim(key: secondKey)),
        code('COMMAND_PENDING'),
      );
    },
  );

  test('ACK followed by GET failure retries only GET', () async {
    await client.execute(claim());
    final entry = (await store.load(session, scope)).single;
    api.respond = () async =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    await expectLater(
      client.loadCurrentFor(entry),
      code('NETWORK_UNAVAILABLE'),
    );
    expect(
      (await store.load(session, scope)).single.phase,
      OwnershipCommandPhase.awaitingCurrent,
    );
    api.respond = () async => proofJson();
    await client.loadCurrentFor(entry);
    expect(api.calls.map((e) => e.method), ['POST', 'GET', 'GET']);
  });

  test(
    'expiry, future creation and server idempotency conflicts block blind replays',
    () async {
      final expired = claim(
        created: clockNow.subtract(const Duration(hours: 24)),
      );
      await expectLater(
        client.execute(expired),
        code('COMMAND_RECONCILIATION_REQUIRED'),
      );
      expect(api.calls, isEmpty);
      expect(
        (await store.load(session, scope)).single.phase,
        OwnershipCommandPhase.reconciliationRequired,
      );
      final otherDisk = JournalFake();
      final otherStore = OwnershipCommandStore(otherDisk);
      final other = OwnershipDisputeClient(
        api,
        session,
        scope,
        otherStore,
        now: () => clockNow,
      );
      api.respond = () async =>
          throw const AccountReadException('IDEMPOTENCY_CONFLICT');
      await expectLater(other.execute(claim()), code('IDEMPOTENCY_CONFLICT'));
      await expectLater(
        other.execute(claim()),
        code('COMMAND_RECONCILIATION_REQUIRED'),
      );
      expect(api.calls.length, 1);
      expect(
        claim(
          created: clockNow.add(const Duration(seconds: 1)),
        ).replayableAt(clockNow),
        false,
      );
    },
  );

  test(
    'concurrent calls cannot duplicate or replace pending command',
    () async {
      final sent = Completer<void>();
      final response = Completer<Map<String, dynamic>?>();
      api.respond = () {
        sent.complete();
        return response.future;
      };
      final first = client.execute(claim());
      await sent.future;
      await expectLater(client.execute(claim()), code('REQUEST_IN_PROGRESS'));
      await expectLater(
        client.execute(claim(key: secondKey)),
        code('COMMAND_PENDING'),
      );
      response.complete(proofJson());
      await first;
      expect(api.calls.length, 1);
      await expectLater(
        client.execute(claim(name: 'Different')),
        code('IDEMPOTENCY_CONFLICT'),
      );
    },
  );

  for (final user in [ownerId, charId]) {
    for (final error in [false, true]) {
      test(
        'late ${error ? 'error' : 'success'} fenced after session change to $user',
        () async {
          final sent = Completer<void>();
          final response = Completer<Map<String, dynamic>?>();
          api.respond = () {
            sent.complete();
            return response.future;
          };
          final check = expectLater(
            client.execute(claim()),
            code('SESSION_CHANGED'),
          );
          await sent.future;
          session.change(authenticated: true, user: user);
          if (error) {
            response.completeError(
              const AccountReadException('REVISION_CONFLICT'),
            );
          } else {
            response.complete(proofJson());
          }
          await check;
          session.change(authenticated: true, user: ownerId);
          expect(
            (await store.load(session, scope)).single.phase,
            OwnershipCommandPhase.awaitingAck,
          );
        },
      );
    }
  }

  test(
    'logout during persistence stops network, journals remain isolated by member/environment',
    () async {
      disk.beforeWrite = () async => session.change(authenticated: false);
      await expectLater(client.execute(claim()), code('SESSION_CHANGED'));
      expect(api.calls, isEmpty);
      session.change(authenticated: true, user: ownerId);
      disk.beforeWrite = null;
      expect((await store.load(session, scope)).length, 1);
      final otherEnvironment = StorageScope(
        baseUrl: 'https://other.test',
        userId: ownerId,
      );
      expect(await store.load(session, otherEnvironment), isEmpty);
      await expectLater(
        OwnershipDisputeClient(
          api,
          session,
          otherEnvironment,
          store,
        ).execute(claim()),
        code('ENVIRONMENT_CHANGED'),
      );
      session.change(authenticated: true, user: charId);
      final otherMember = StorageScope(
        baseUrl: 'https://example.test',
        userId: charId,
      );
      expect(await store.load(session, otherMember), isEmpty);
      await expectLater(client.proof(proofId), code('SESSION_CHANGED'));
    },
  );

  test(
    'corrupt/wrong-scope journals fail closed without HTTP or overwrite',
    () async {
      for (final raw in [
        'not json',
        jsonEncode({'schema': 2}),
        jsonEncode({
          'schema': 1,
          'environment': 'https://wrong.test',
          'user_id': ownerId,
          'entries': [],
        }),
      ]) {
        disk.values[scope] = raw;
        await expectLater(client.execute(claim()), code('JOURNAL_INVALID'));
        expect(disk.values[scope], raw);
      }
      expect(api.calls, isEmpty);
      expect(disk.writes, 0);
    },
  );

  test(
    'mismatched ACK targets and malformed ACKs leave original awaitingAck',
    () async {
      for (final wire in [
        proofJson()..['verification_id'] = charId,
        {'wrong': 'shape'},
      ]) {
        api.respond = () async => wire;
        await expectLater(
          client.execute(versioned(OwnershipOperation.confirm)),
          code('INVALID_RESPONSE'),
        );
        expect(
          (await store.load(session, scope)).single.phase,
          OwnershipCommandPhase.awaitingAck,
        );
      }
    },
  );

  test(
    'cursor/filter/limit validation and stale page errors never become empty success',
    () async {
      expect(() => client.proofs(cursor: ''), throwsFormatException);
      expect(() => client.disputes(limit: 101), throwsFormatException);
      expect(() => client.proofs(purpose: 'owner'), throwsFormatException);
      expect(api.calls, isEmpty);
      api.respond = () async =>
          throw const AccountReadException('CURSOR_STALE', status: 409);
      await expectLater(
        client.disputes(role: 'owner', cursor: 'old'),
        code('CURSOR_STALE'),
      );
      expect(api.calls.length, 1);
      expect(api.calls.single.query, {
        'role': 'owner',
        'view': 'active',
        'limit': 20,
        'cursor': 'old',
      });
      api.respond = () async => pageJson([disputeJson()]);
      await expectLater(
        client.disputes(role: 'owner'),
        code('INVALID_RESPONSE'),
      );
    },
  );

  test(
    'settle reservation stays defending; current GET uses no POST replay',
    () async {
      api.respond = () async => disputeJson(due: true);
      final ack = await client.execute(versioned(OwnershipOperation.settle));
      expect(ack.dispute!.state, 'defending');
      final entry = (await store.load(session, scope)).single;
      final current = await client.loadCurrentFor(entry);
      expect(current.dispute!.phase, 'settlement_due');
      expect(api.calls.map((e) => e.method), ['POST', 'GET']);
    },
  );

  test(
    'real authenticated transport implements all 11 V2 operations and exact POST bodies/statuses',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final adapter = DioAdapter(dio: dio);
      final transport = DioBackendAccountReadApi(dio, session);
      final headers = {
        'Authorization': 'Bearer test-access',
        'Idempotency-Key': commandKey,
      };
      final p = OwnershipCommand.proofsPath, d = OwnershipCommand.disputesPath;
      adapter.onPost(
        '/v2/game-accounts/preview',
        (s) => s.reply(200, previewJson()),
        data: {'character_name': 'Hero'},
        headers: {'Authorization': 'Bearer test-access'},
      );
      adapter.onGet(
        p,
        (s) => s.reply(200, pageJson([proofJson()])),
        queryParameters: {'purpose': 'all', 'view': 'active', 'limit': 20},
      );
      adapter.onGet('$p/$proofId', (s) => s.reply(200, proofJson()));
      adapter.onGet(
        d,
        (s) => s.reply(200, pageJson([disputeJson()])),
        queryParameters: {'role': 'all', 'view': 'active', 'limit': 20},
      );
      adapter.onGet('$d/$disputeId', (s) => s.reply(200, disputeJson()));
      final readClient = OwnershipDisputeClient(
        transport,
        session,
        scope,
        store,
        now: () => clockNow,
      );
      expect((await readClient.preview('Hero')).context.relation, 'other');
      expect((await readClient.proofs()).items.single.id, proofId);
      expect((await readClient.proof(proofId)).id, proofId);
      expect((await readClient.disputes()).items.single.id, disputeId);
      expect((await readClient.dispute(disputeId)).id, disputeId);
      final selection = OwnershipDefenseSelection(
        registrationId: regId,
        characterId: charId,
        registrationVersion: 1,
        ownershipRevision: 2,
        rosterRevision: 3,
        lifecycleRevision: 4,
      );
      final operations = [
        claim(),
        versioned(OwnershipOperation.confirm),
        versioned(OwnershipOperation.cancelProof),
        OwnershipCommand.defense(
          session,
          scope,
          key: commandKey,
          createdAt: clockNow,
          disputeId: disputeId,
          disputeVersion: 1,
          selection: selection,
        ),
        versioned(OwnershipOperation.cancelDispute),
        versioned(OwnershipOperation.settle),
      ];
      for (final command in operations) {
        final response = command.returnsProof
            ? proofJson(
                defense: command.operation == OwnershipOperation.startDefense,
              )
            : disputeJson();
        adapter.onPost(
          command.path,
          (s) => s.reply(command.expectedStatus, response),
          data: command.body,
          headers: headers,
        );
        final isolated = OwnershipDisputeClient(
          transport,
          session,
          scope,
          OwnershipCommandStore(JournalFake()),
          now: () => clockNow,
        );
        final ack = await isolated.execute(command);
        expect(ack.id, command.returnsProof ? proofId : disputeId);
      }
      expect(session.refreshCalls, 0);
    },
  );

  test(
    'secure adapter uses its own member/environment namespace without secrets',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const secure = SecureOwnershipJournalStorage();
      await secure.write(scope, 'journal');
      final values = await const FlutterSecureStorage().readAll();
      expect(values.keys.single, startsWith('ownership_commands_v1_'));
      expect(await secure.read(scope), 'journal');
      expect(
        await secure.read(
          StorageScope(baseUrl: 'https://other.test', userId: ownerId),
        ),
        isNull,
      );
      expect(
        await secure.read(
          StorageScope(baseUrl: 'https://example.test', userId: charId),
        ),
        isNull,
      );
      expect(jsonEncode(claim().toJson()), isNot(contains('test-access')));
    },
  );
}
