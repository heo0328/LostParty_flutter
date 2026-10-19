import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/ownership_command_store.dart';
import 'package:lost_party/features/account/data/ownership_dispute_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/ownership_command.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/presentation/viewmodels/ownership_dispute_controller.dart';
import '../../../support/server_account_read_fakes.dart';
import 'ownership_dispute_client_test.dart'
    show JournalFake, OwnershipApiFake, code;
import 'ownership_dispute_fixtures.dart';

const proofsPath = OwnershipCommand.proofsPath;
const disputesPath = OwnershipCommand.disputesPath;
Future<void> settleEvents() async {
  for (var i = 0; i < 16; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, dynamic> expiredProof() => {
  ...proofJson(),
  'equipment_status': 'expired',
  'result_code': 'VERIFICATION_EXPIRED',
  'ended_at': '2026-10-19T01:10:00Z',
  'server_now': '2026-10-19T01:10:00Z',
  'allowed_actions': <String>[],
};
Map<String, dynamic> transferredDispute() => {
  ...disputeJson(role: 'owner', due: true),
  'version': 2,
  'state': 'transferred',
  'phase': 'finished',
  'reason_code': 'OWNERSHIP_TRANSFERRED',
  'resolved_at': '2026-10-20T01:00:00Z',
  'allowed_actions': <String>[],
};

void main() {
  late ReadSessionFake session;
  late JournalFake disk;
  late OwnershipCommandStore store;
  late OwnershipApiFake api;
  late OwnershipDisputeController controller;
  late StorageScope scope;
  late DateTime clock;
  late String environment;
  late int syncCalls;
  Future<void> Function(AccountReadScope)? sync;
  List<Map<String, dynamic>> proofRows = [], disputeRows = [];
  Map<String, dynamic>? currentProof, currentDispute;
  OwnershipCommand claim({DateTime? created, String key = commandKey}) =>
      OwnershipCommand.claim(
        session,
        scope,
        key: key,
        createdAt: created ?? clock,
        characterName: 'Hero',
      );
  Future<Map<String, dynamic>?> normalReply() async {
    final call = api.calls.last;
    if (call.path == proofsPath && call.method == 'GET') {
      return pageJson(proofRows);
    }
    if (call.path == disputesPath) return pageJson(disputeRows);
    if (call.path.startsWith('$proofsPath/')) {
      return currentProof ?? proofJson();
    }
    if (call.path.startsWith('$disputesPath/')) {
      return currentDispute ?? disputeJson(role: 'owner');
    }
    if (call.method == 'POST') return proofJson();
    throw StateError('unexpected request ${call.path}');
  }

  setUp(() {
    session = ReadSessionFake()..userId = ownerId;
    disk = JournalFake();
    store = OwnershipCommandStore(disk);
    api = OwnershipApiFake();
    scope = StorageScope(baseUrl: 'https://example.test', userId: ownerId);
    clock = clockNow;
    environment = scope.environment;
    syncCalls = 0;
    sync = null;
    proofRows = [];
    disputeRows = [];
    currentProof = null;
    currentDispute = null;
    api.respond = normalReply;
    controller = OwnershipDisputeController(
      api: api,
      session: session,
      baseUrl: environment,
      currentBaseUrl: () => environment,
      commands: store,
      now: () => clock,
      onAccountStateChanged: (member) async {
        syncCalls++;
        await sync?.call(member);
      },
    );
  });
  tearDown(() {
    controller.dispose();
    session.dispose();
  });

  test(
    'failed defense proof read cannot keep a stale actionable defense notice',
    () async {
      final defense = proofJson(defense: true);
      proofRows = [defense];
      currentProof = defense;
      currentDispute = {
        ...disputeJson(role: 'owner'),
        'allowed_actions': <String>[],
        'my_active_verification_ids': [proofId],
      };
      disputeRows = [currentDispute!];
      await controller.refresh();
      expect(controller.notice, OwnershipNotice.defenseRequired);
      api.respond = () async {
        if (api.calls.last.path == '$proofsPath/$proofId') {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return normalReply();
      };
      await controller.refresh();
      expect(controller.proofFailure(proofId)?.code, 'NETWORK_UNAVAILABLE');
      expect(controller.notice, OwnershipNotice.checkRequired);
    },
  );

  test(
    'guest has zero calls; login starts independent lists once and resume coalesces',
    () async {
      session.change(authenticated: false);
      controller.initialize();
      await controller.refresh();
      expect(api.calls, isEmpty);
      session.change(authenticated: true);
      await controller.refresh();
      expect(
        api.calls.map((c) => c.path),
        containsAll([proofsPath, disputesPath]),
      );
      expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
      expect(controller.journalLoaded, true);
      api.calls.clear();
      await Future.wait([
        controller.resume(),
        controller.resume(),
        controller.refresh(),
      ]);
      expect(api.calls.length, 2);
    },
  );

  test(
    'proof read failure does not block owner discovery or erase its notice',
    () async {
      final blocked = Completer<Map<String, dynamic>?>();
      disputeRows = [disputeJson(role: 'owner')];
      api.respond = () =>
          api.calls.last.path == proofsPath ? blocked.future : normalReply();
      final flight = controller.refresh();
      await settleEvents();
      expect(controller.disputesCurrent, true);
      expect(controller.notice, OwnershipNotice.defenseRequired);
      expect(controller.proofsCurrent, false);
      blocked.completeError(const AccountReadException('NETWORK_UNAVAILABLE'));
      await flight;
      expect(controller.proofsFailure!.code, 'NETWORK_UNAVAILABLE');
      expect(controller.notice, OwnershipNotice.defenseRequired);
    },
  );

  test(
    'single proof on a new device is recovered by current GET without a start',
    () async {
      proofRows = [proofJson()];
      await controller.refresh();
      expect(controller.selectedProofId, proofId);
      expect(controller.proofIsCurrent(proofId), true);
      expect(controller.selectedProof!.requiredSlots, ['장갑']);
      expect(
        api.calls.where((c) => c.path == '$proofsPath/$proofId').length,
        1,
      );
      expect(api.calls.every((c) => c.method == 'GET'), true);
      expect(disk.writes, 0);
    },
  );

  test(
    'multiple proofs require selection and reordered lists never replace it',
    () async {
      final second = {...proofJson(), 'verification_id': charId};
      proofRows = [proofJson(), second];
      await controller.refresh();
      expect(controller.selectedProofId, isNull);
      expect(
        api.calls.where((c) => c.path.startsWith('$proofsPath/')),
        isEmpty,
      );
      currentProof = second;
      await controller.selectProof(charId);
      expect(controller.selectedProofId, charId);
      proofRows = [second, proofJson()];
      await controller.refresh();
      expect(controller.selectedProofId, charId);
      expect(controller.proofIsCurrent(charId), true);
    },
  );

  test(
    'full pagination is atomic; stale cursor restarts once without merging snapshots',
    () async {
      var starts = 0;
      final second = {...proofJson(), 'verification_id': charId};
      api.respond = () async {
        final call = api.calls.last;
        if (call.path == proofsPath) {
          if (call.query?['cursor'] == null) {
            starts++;
            return starts == 1
                ? pageJson([proofJson()], cursor: 'old')
                : pageJson([second]);
          }
          throw const AccountReadException('CURSOR_STALE', status: 409);
        }
        if (call.path == '$proofsPath/$charId') return second;
        return normalReply();
      };
      await controller.refresh();
      expect(starts, 2);
      expect(controller.activeProofs.map((v) => v.id), [charId]);
      expect(controller.proofsFailure, isNull);
    },
  );

  test(
    'partial page failure retains old observations and blocks stale writes',
    () async {
      proofRows = [proofJson()];
      await controller.refresh();
      api.respond = () async {
        final call = api.calls.last;
        if (call.path == proofsPath) {
          if (call.query?['cursor'] == null) {
            return pageJson([
              {...proofJson(), 'verification_id': charId},
            ], cursor: 'next');
          }
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return normalReply();
      };
      await controller.refresh();
      expect(controller.activeProofs.map((v) => v.id), [proofId]);
      expect(controller.proofsCurrent, false);
      expect(controller.proofIsCurrent(proofId), false);
      final confirm = OwnershipCommand.versioned(
        session,
        scope,
        operation: OwnershipOperation.confirm,
        key: commandKey,
        createdAt: clock,
        id: proofId,
        version: 1,
      );
      await expectLater(
        controller.execute(confirm),
        code('CURRENT_READ_REQUIRED'),
      );
      expect(api.calls.every((c) => c.method == 'GET'), true);
    },
  );

  test('a repeatedly stale or looping cursor stops boundedly', () async {
    api.respond = () async {
      final call = api.calls.last;
      if (call.path == proofsPath) {
        if (call.query?['cursor'] == null) {
          return pageJson([proofJson()], cursor: 'old');
        }
        throw const AccountReadException('CURSOR_STALE');
      }
      return normalReply();
    };
    await controller.refresh();
    expect(api.calls.where((c) => c.path == proofsPath).length, 4);
    expect(controller.proofsFailure!.code, 'CURSOR_STALE');
    expect(controller.activeProofs, isEmpty);
  });

  test(
    'a known dispute disappearing requires terminal GET before account sync',
    () async {
      disputeRows = [disputeJson(role: 'owner')];
      await controller.refresh();
      expect(syncCalls, 0);
      disputeRows = [];
      currentDispute = transferredDispute();
      await controller.refresh();
      expect(syncCalls, 1);
      expect(controller.selectedDispute!.state, 'transferred');
      expect(controller.activeDisputes, isEmpty);
      await controller.refresh();
      expect(syncCalls, 1);
    },
  );

  test(
    'missing dispute GET failure preserves last owner warning, never means success',
    () async {
      disputeRows = [disputeJson(role: 'owner')];
      await controller.refresh();
      disputeRows = [];
      api.respond = () async {
        if (api.calls.last.path == '$disputesPath/$disputeId') {
          throw const AccountReadException('DISPUTE_NOT_FOUND', status: 404);
        }
        return normalReply();
      };
      await controller.refresh();
      expect(controller.notice, OwnershipNotice.checkRequired);
      expect(controller.activeDisputes.single.id, disputeId);
      expect(controller.disputeIsCurrent(disputeId), false);
      expect(syncCalls, 0);
    },
  );

  test(
    'known pending proof disappearing is confirmed as expired, not verified',
    () async {
      proofRows = [proofJson()];
      await controller.refresh();
      proofRows = [];
      currentProof = expiredProof();
      await controller.refresh();
      expect(controller.selectedProof!.equipmentStatus, 'expired');
      expect(controller.activeProofs, isEmpty);
      expect(syncCalls, 0);
    },
  );

  for (final user in [ownerId, charId]) {
    test(
      'session generation change discards late list success and selected state for $user',
      () async {
        final response = Completer<Map<String, dynamic>?>();
        api.respond = () =>
            api.calls.last.path == proofsPath ? response.future : normalReply();
        final pending = controller.refresh();
        await settleEvents();
        session.change(authenticated: true, user: user);
        response.complete(pageJson([proofJson()]));
        await pending;
        expect(controller.activeProofs, isEmpty);
        expect(controller.selectedProofId, isNull);
        expect(controller.notice, OwnershipNotice.none);
      },
    );
  }

  test(
    'environment change fences late data and new member/environment journal scope',
    () async {
      final response = Completer<Map<String, dynamic>?>();
      api.respond = () =>
          api.calls.last.path == proofsPath ? response.future : normalReply();
      final old = controller.refresh();
      await settleEvents();
      environment = 'https://other.test';
      api.respond = normalReply;
      await controller.resume();
      response.complete(pageJson([proofJson()]));
      await old;
      expect(controller.scope!.environment, environment);
      expect(controller.activeProofs, isEmpty);
      expect(controller.pendingCommands, isEmpty);
    },
  );

  test(
    'unknown ACK is discovered from journal but never automatically replayed',
    () async {
      await store.prepare(session, claim());
      await controller.refresh();
      expect(
        controller.pendingCommands.single.phase,
        OwnershipCommandPhase.awaitingAck,
      );
      expect(api.calls.every((c) => c.method == 'GET'), true);
      await controller.recoverCommand(commandKey);
      await controller.refresh();
      final posts = api.calls.where((c) => c.method == 'POST').toList();
      expect(posts.length, 1);
      expect(posts.single.key, commandKey);
      expect(posts.single.body, {
        'source': 'direct_input',
        'character_name': 'Hero',
      });
      expect(controller.pendingCommands, isEmpty);
    },
  );

  test(
    'restart with persisted ACK resumes only GET and keeps failed current reads pending',
    () async {
      final command = claim();
      await store.prepare(session, command);
      await store.acknowledge(session, command, proofId);
      var fail = true;
      api.respond = () async {
        if (api.calls.last.path == '$proofsPath/$proofId' && fail) {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return normalReply();
      };
      await controller.refresh();
      expect(
        controller.pendingCommands.single.phase,
        OwnershipCommandPhase.awaitingCurrent,
      );
      fail = false;
      await controller.recoverCommand(commandKey);
      await controller.refresh();
      expect(controller.pendingCommands, isEmpty);
      expect(api.calls.every((c) => c.method == 'GET'), true);
      expect(controller.selectedProofId, proofId);
    },
  );

  test(
    'expired original requires complete review and explicit confirmation, retaining original key/body',
    () async {
      final original = claim(
        created: clock.subtract(const Duration(hours: 24)),
      );
      await store.prepare(session, original);
      await controller.refresh();
      await expectLater(
        controller.acknowledgeReconciliation(commandKey),
        code('RECONCILIATION_REVIEW_REQUIRED'),
      );
      await controller.reviewReconciliation(commandKey);
      expect(
        controller.pendingCommands.single.phase,
        OwnershipCommandPhase.reconciliationRequired,
      );
      await controller.acknowledgeReconciliation(commandKey);
      expect(controller.pendingCommands, isEmpty);
      final archived = (await store.load(session, scope)).single;
      expect(archived.phase, OwnershipCommandPhase.reconciled);
      expect(archived.command.toJson(), original.toJson());
      expect(archived.responseId, isNull);
      final client = OwnershipDisputeClient(
        api,
        session,
        scope,
        store,
        now: () => clock,
      );
      await expectLater(
        client.execute(archived.command),
        code('COMMAND_RECONCILIATION_REQUIRED'),
      );
      expect(api.calls.every((c) => c.method == 'GET'), true);
      final allQueries = api.calls.where((c) => c.query?['view'] == 'all');
      expect(
        allQueries.map((c) => c.path),
        containsAll([proofsPath, disputesPath]),
      );
    },
  );

  test(
    'corrupt journal blocks new commands without losing stored data',
    () async {
      disk.values[scope] = 'broken';
      await controller.refresh();
      expect(controller.journalLoaded, false);
      expect(controller.journalFailure!.code, 'JOURNAL_INVALID');
      await expectLater(controller.execute(claim()), code('JOURNAL_NOT_READY'));
      expect(disk.values[scope], 'broken');
      expect(api.calls.every((c) => c.method == 'GET'), true);
    },
  );

  test(
    '429 Retry-After prevents repeated discovery until the delay passes',
    () async {
      api.respond = () async {
        if (api.calls.last.path == proofsPath) {
          throw const AccountReadException(
            'RATE_LIMITED',
            status: 429,
            retryAfter: Duration(seconds: 30),
          );
        }
        return normalReply();
      };
      await controller.refresh();
      await controller.refresh();
      expect(api.calls.where((c) => c.path == proofsPath).length, 1);
      clock = clock.add(const Duration(seconds: 30));
      await controller.refresh();
      expect(api.calls.where((c) => c.path == proofsPath).length, 2);
    },
  );

  test(
    'account synchronization failure is retryable and never removes old ownership on dispute opening',
    () async {
      disputeRows = [disputeJson(role: 'owner')];
      await controller.refresh();
      expect(syncCalls, 0);
      currentDispute = transferredDispute();
      disputeRows = [];
      var fail = true;
      sync = (_) async {
        if (fail) throw const AccountReadException('NETWORK_UNAVAILABLE');
      };
      await controller.refresh();
      expect(controller.accountSyncFailure!.code, 'NETWORK_UNAVAILABLE');
      fail = false;
      await controller.retryAccountSync();
      expect(controller.accountSyncFailure, isNull);
      final completed = syncCalls;
      await controller.refresh();
      expect(syncCalls, completed);
    },
  );

  test(
    'D1 environment guard prevents HTTP after a journal write switches environment',
    () async {
      disk.beforeWrite = () async {
        environment = 'https://other.test';
      };
      final client = OwnershipDisputeClient(
        api,
        session,
        scope,
        store,
        now: () => clock,
        environmentIsCurrent: () => environment == scope.environment,
      );
      await expectLater(client.execute(claim()), code('ENVIRONMENT_CHANGED'));
      expect(api.calls, isEmpty);
      expect(jsonDecode(disk.values[scope]!)['entries'], isNotEmpty);
    },
  );

  test(
    'ACK then current GET failure never repeats POST; explicit recovery is GET only',
    () async {
      await controller.refresh();
      var failCurrent = true;
      api.respond = () async {
        if (api.calls.last.path == '$proofsPath/$proofId' && failCurrent) {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return normalReply();
      };
      await expectLater(
        controller.execute(claim()),
        code('NETWORK_UNAVAILABLE'),
      );
      await settleEvents();
      expect(
        controller.pendingCommands.single.phase,
        OwnershipCommandPhase.awaitingCurrent,
      );
      expect(api.calls.where((c) => c.method == 'POST').length, 1);
      expect(
        api.calls.where((c) => c.path == '$proofsPath/$proofId').length,
        1,
      );
      failCurrent = false;
      await controller.recoverCommand(commandKey);
      await controller.refresh();
      expect(api.calls.where((c) => c.method == 'POST').length, 1);
      expect(controller.pendingCommands, isEmpty);
    },
  );

  test(
    'definitive revision rejection permits explicit review, not an endless same-body replay',
    () async {
      proofRows = [proofJson()];
      await controller.refresh();
      final confirm = OwnershipCommand.versioned(
        session,
        scope,
        operation: OwnershipOperation.confirm,
        key: commandKey,
        createdAt: clock,
        id: proofId,
        version: 1,
      );
      api.respond = () async {
        if (api.calls.last.method == 'POST') {
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
        }
        return normalReply();
      };
      await expectLater(controller.execute(confirm), code('REVISION_CONFLICT'));
      expect(
        controller.pendingCommands.single.phase,
        OwnershipCommandPhase.reconciliationRequired,
      );
      await controller.reviewReconciliation(commandKey);
      await controller.acknowledgeReconciliation(commandKey);
      expect(controller.pendingCommands, isEmpty);
      expect(api.calls.where((c) => c.method == 'POST').length, 1);
      expect((await store.load(session, scope)).single.responseId, isNull);
    },
  );

  test(
    'late business errors after logout do not become new-session failures',
    () async {
      final response = Completer<Map<String, dynamic>?>();
      api.respond = () =>
          api.calls.last.path == proofsPath ? response.future : normalReply();
      final flight = controller.refresh();
      await settleEvents();
      session.change(authenticated: false);
      response.completeError(const AccountReadException('REVISION_CONFLICT'));
      await flight;
      expect(controller.proofsFailure, isNull);
      expect(controller.pendingCommands, isEmpty);
      expect(controller.selectedProofId, isNull);
    },
  );

  test(
    'duplicate IDs across pages are rejected without publishing a partial feed',
    () async {
      api.respond = () async {
        final call = api.calls.last;
        if (call.path == proofsPath) {
          return pageJson([
            proofJson(),
          ], cursor: call.query?['cursor'] == null ? 'next' : null);
        }
        return normalReply();
      };
      await controller.refresh();
      expect(controller.proofsFailure!.code, 'INVALID_RESPONSE');
      expect(controller.activeProofs, isEmpty);
      expect(controller.proofsCurrent, false);
    },
  );

  testWidgets(
    'server deadline triggers one read, no periodic polling or local success',
    (tester) async {
      controller.dispose();
      var elapsed = Duration.zero;
      controller = OwnershipDisputeController(
        api: api,
        session: session,
        baseUrl: environment,
        commands: store,
        now: () => clockNow.add(elapsed),
        elapsed: () => elapsed,
      );
      api.respond = () async {
        final call = api.calls.last;
        if (call.path == proofsPath) {
          return pageJson(
            elapsed < const Duration(minutes: 10) ? [proofJson()] : [],
          );
        }
        if (call.path == '$proofsPath/$proofId') {
          return elapsed < const Duration(minutes: 10)
              ? proofJson()
              : expiredProof();
        }
        return normalReply();
      };
      controller.initialize();
      for (var i = 0; i < 12; i++) {
        await tester.pump(Duration.zero);
      }
      expect(controller.selectedProofId, proofId);
      final before = api.calls.length;
      elapsed = const Duration(minutes: 10);
      await tester.pump(elapsed);
      for (var i = 0; i < 12; i++) {
        await tester.pump(Duration.zero);
      }
      expect(api.calls.length, greaterThan(before));
      expect(controller.selectedProof!.equipmentStatus, 'expired');
      final after = api.calls.length;
      elapsed = const Duration(days: 1);
      await tester.pump(const Duration(days: 1));
      expect(api.calls.length, after);
      expect(api.calls.every((c) => c.method == 'GET'), true);
    },
  );
}
