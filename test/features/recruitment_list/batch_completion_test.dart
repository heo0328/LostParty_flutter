import 'package:lost_party/features/recruitment_list/presentation/widgets/participation_recovery_card.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/batch_completion.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/cycle_group_policy.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/beta/participation_command_evidence.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'beta_foundation_test.dart' as beta;

Map<String, dynamic> copy(Object raw) =>
    jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
Map<String, dynamic> fixture(String name) => copy(
  (jsonDecode(File('test/fixtures/batch_completion.json').readAsStringSync())
      as Map)[name],
);
BatchCompletionPreview preview(Map<String, dynamic> raw) {
  final d = raw['data'] as Map;
  return BatchCompletionPreview(
    d['room_id'],
    raw['scope']['target_cycle_key'],
    batchKind(d['action']),
    (d['round_ids'] as List).cast<String>(),
    raw,
    metadata: raw,
  );
}

RecruitmentCommand journal(BatchCompletionPreview p) {
  final key = '00000000-0000-4000-8000-000000000199';
  final contract = BetaContract(mode: RecruitmentContractMode.betaWire2);
  final q = contract.query('POST', p.path);
  final body = jsonEncode(p.body());
  final e = ParticipationCommandEvidence.create(
    kind: p.kind.action,
    groupEffects: p.groupEffects,
    room: p.room,
    target: p.target,
    scope: p.scope,
    affected: [p.target],
    details: BatchCompletionAckEvidence.fromPreview(p).wire,
    method: 'POST',
    path: p.path,
    rawQuery: jsonEncode(q),
    rawBody: body,
    key: key,
    status: 200,
    targets: [p.target],
  );
  return RecruitmentCommand(
    owner: RecruitmentCommandOwner.participation,
    operation: contract.operation('POST', p.path)['id'],
    method: 'POST',
    path: p.path,
    query: q,
    targetCycles: [p.target],
    rawBody: body,
    key: key,
    createdAt: DateTime.parse(p.scope['server_now']),
    version: 3,
    validationSnapshot: e.wire,
  );
}

Map<String, dynamic> successorGroupPolicy(Map<String, dynamic> raw) {
  final s = raw['scope'] as Map, d = raw['data'] as Map;
  final identity = <String, dynamic>{
    'room_id': d['room_id'],
    'target_cycle_key': s['target_cycle_key'],
    'room_cycle_id': s['room_cycle_id'],
    'generation': s['target_generation'],
  };
  raw['group_policy_version'] = BetaContract.groupPolicyVersion;
  raw['group_policy'] = {
    ...identity,
    'scope': 'public',
    'group_id': null,
    'revision': 1,
    'state': 'known',
  };
  raw['group_policy_effect'] = {
    ...identity,
    'before': {'scope': 'public', 'group_id': null, 'revision': 1},
    'after': {'scope': 'public', 'group_id': null, 'revision': null},
  };
  return raw;
}

void validateJournalAck(RecruitmentCommand j, Map<String, dynamic> ack) {
  ParticipationCommandEvidence(j.validationSnapshot!).validate(
    ack,
    method: j.method,
    path: j.path,
    key: j.key,
    status: j.expectedStatus,
    mode: j.contractMode,
    rawBody: j.rawBody,
  );
}

void main() {
  test(
    'successor ACK binds omitted effect revision to original ACK policy',
    () {
      final p = preview(
        successorGroupPolicy(fixture('personal_successor_context')),
      );
      final j = journal(p),
          ack = successorGroupPolicy(fixture('personal_successor_ack'));
      ack['data']['command_id'] = j.key;
      final original = jsonEncode(ack), stored = j.encode();
      validateJournalAck(RecruitmentCommand.decode(stored), ack);
      expect(jsonEncode(ack), original);
      expect(j.encode(), stored);
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing policy': (a) => a.remove('group_policy'),
    'unavailable policy': (a) {
      a['group_policy']['state'] = 'unavailable';
      a['group_policy']['scope'] = null;
      a['group_policy']['revision'] = null;
    },
    'another room': (a) =>
        a['group_policy']['room_id'] = '00000000-0000-4000-8000-000000000099',
    'another cycle': (a) => a['group_policy']['room_cycle_id'] =
        '00000000-0000-4000-8000-000000000099',
    'another generation': (a) => a['group_policy']['generation']++,
    'another week': (a) => a['group_policy']['target_cycle_key'] = '2026-11-11',
    'unproven increment': (a) => a['group_policy']['revision']++,
    'wrong resulting scope': (a) {
      a['group_policy']['scope'] = 'group';
      a['group_policy']['group_id'] = '00000000-0000-4000-8000-000000000099';
    },
    'changed original revision': (a) =>
        a['group_policy_effect']['before']['revision']++,
    'missing effect': (a) => a.remove('group_policy_effect'),
    'duplicated effect': (a) =>
        a['group_policy_effects'] = [copy(a['group_policy_effect'])],
  }.entries) {
    test('successor revision proof rejects ${mutation.key}', () {
      final p = preview(
        successorGroupPolicy(fixture('personal_successor_context')),
      );
      final j = journal(p),
          ack = successorGroupPolicy(fixture('personal_successor_ack'));
      ack['data']['command_id'] = j.key;
      mutation.value(ack);
      expect(() => validateJournalAck(j, ack), throwsFormatException);
    });
  }
  test('batch proof preserves strict ordinary group ACK validation', () {
    final ack = successorGroupPolicy(fixture('personal_successor_ack'));
    final effect = ack['group_policy_effect'] as Map<String, dynamic>;
    expect(
      () => CycleGroupEffect(effect).validateAck(effect),
      throwsFormatException,
    );
  });
  test(
    'successor group disconnect requires exactly one policy revision increment',
    () {
      final context = successorGroupPolicy(
        fixture('personal_successor_context'),
      );
      final ack = successorGroupPolicy(fixture('personal_successor_ack'));
      for (final raw in [context, ack]) {
        raw['group_policy_effect']['before'] = {
          'scope': 'group',
          'group_id': '00000000-0000-4000-8000-000000000099',
          'revision': 4,
        };
      }
      context['group_policy'].addAll(context['group_policy_effect']['before']);
      ack['group_policy']['revision'] = 5;
      final j = journal(preview(context));
      ack['data']['command_id'] = j.key;
      validateJournalAck(j, ack);
      ack['group_policy']['revision'] = 4;
      expect(() => validateJournalAck(j, ack), throwsFormatException);
    },
  );
  for (final name in [
    'party_partial',
    'personal_leave',
    'personal_successor',
    'personal_last_full',
    'personal_last_partial',
  ]) {
    test(
      '$name exact effect, historical proof and ACK survive journal decode',
      () {
        final p = preview(fixture('${name}_context'));
        final ack = fixture('${name}_ack');
        BatchCompletionAckEvidence.fromPreview(
          p,
        ).validate(ack, ack['data']['command_id']);
        final j = journal(p),
            restored = RecruitmentCommand.decode(journal(p).encode());
        expect(restored.sameOriginal(j), true);
        expect(restored.validationSnapshot!['kind'], p.kind.action);
        expect(restored.rawBody, jsonEncode(p.body()));
      },
    );
  }
  test('denied successor context is displayable but never produces a body', () {
    final p = preview(fixture('personal_denied_context'));
    expect(p.permission.allowed, false);
    expect(() => p.body(), throwsA(isA<AccountReadException>()));
  });
  test(
    'selection order normalizes once; duplicates and zero selection rejected',
    () {
      final raw = fixture('party_partial_context'), p = preview(raw);
      final reversed = p.rounds.reversed.toList();
      expect(
        BatchCompletionPreview(p.room, p.target, p.kind, reversed, raw).rounds,
        p.rounds,
      );
      expect(() => batchRoundIds([]), throwsFormatException);
      expect(
        () => batchRoundIds([p.rounds.first, p.rounds.first]),
        throwsFormatException,
      );
    },
  );
  for (final entry in <String, void Function(Map<String, dynamic>)>{
    'missing active raid mapping': (j) =>
        j['data']['display']['rounds'].removeLast(),
    'duplicate assignment': (j) => j['data']['display']['assignments'].add(
      copy(j['data']['display']['assignments'][0]),
    ),
    'effect mismatch': (j) =>
        j['data']['display']['assignments'][0]['effect'] = 'cancel',
    'overlapping effect': (j) =>
        j['data']['impact']['cancelled_assignment_ids'] = [
          j['data']['impact']['completed_assignment_ids'][0],
        ],
    'history count mismatch': (j) =>
        j['data']['impact']['preserved_completed']['assignment_count']++,
    'bad history digest': (j) =>
        j['data']['impact']['preserved_completed']['digest'] = 'broken',
    'wrong actor': (j) => j['data']['actor_cycle_member_id'] =
        '00000000-0000-4000-8000-000000000099',
    'missing revision': (j) => j['data']['revisions'].removeLast(),
    'denied with token': (j) => j['data']['permission']['allowed'] = false,
    'extra field': (j) => j['data']['extra'] = true,
    'wrong target': (j) => j['scope']['target_cycle_key'] = '2026-11-11',
  }.entries) {
    test('reject context ${entry.key}', () {
      final raw = fixture('personal_leave_context');
      entry.value(raw);
      expect(() => preview(raw), throwsFormatException);
    });
  }
  for (final entry in <String, void Function(Map<String, dynamic>)>{
    'different proof': (j) =>
        j['data']['impact']['preserved_completed']['digest'] = List.filled(
          64,
          'a',
        ).join(),
    'wrong selection': (j) => j['data']['round_ids'].removeLast(),
    'wrong actor': (j) => j['data']['actor_cycle_member_id'] =
        '00000000-0000-4000-8000-000000000099',
    'wrong generation': (j) => j['scope']['target_generation']++,
    'changed successor': (j) =>
        j['data']['departure']['successor']['cycle_member_id'] =
            '00000000-0000-4000-8000-000000000099',
    'wrong final state': (j) =>
        j['data']['state']['actor_cycle_member_state'] = 'completed',
    'unchanged target revision': (j) {
      j['scope']['target_revision'] = 7;
      j['data']['revisions'].last['revision'] = 7;
    },
    'wrong leader revision': (j) =>
        j['data']['leadership']['leadership_revision']++,
    'missing revision key': (j) => j['data']['revisions'].removeAt(0),
    'expired execution': (j) {
      j['data']['executed_at'] = '2026-11-10T05:02:00Z';
      j['scope']['server_now'] = '2026-11-10T05:02:00Z';
    },
  }.entries) {
    test('reject ACK ${entry.key}', () {
      final p = preview(fixture('personal_successor_context')),
          ack = fixture('personal_successor_ack');
      entry.value(ack);
      expect(
        () => BatchCompletionAckEvidence.fromPreview(
          p,
        ).validate(ack, ack['data']['command_id']),
        throwsFormatException,
      );
    });
  }
  test(
    'semantic signature ignores observation/token time but binds effects and display',
    () {
      final raw = fixture('party_partial_context'), p = preview(raw);
      raw['scope']['server_now'] = raw['data']['confirmation']['issued_at'] =
          '2026-11-10T05:00:01Z';
      raw['data']['confirmation']['expires_at'] = '2026-11-10T05:02:01Z';
      raw['data']['confirmation']['context_token'] = 'other';
      expect(preview(raw).signature, p.signature);
      raw['data']['display']['rounds'][0]['raid_name'] = 'changed';
      expect(preview(raw).signature, isNot(p.signature));
    },
  );
  test('new batch ACK stores up to 1MiB; original commands retain 256KiB', () {
    final p = preview(fixture('party_partial_context')), j = journal(p);
    final ack = fixture('party_partial_ack');
    ack['data']['command_id'] = j.key;
    final raw = jsonEncode(ack);
    final large = raw + ' ' * (300000 - utf8.encode(raw).length);
    final saved = j.transition(
      state: RecruitmentCommandState.acknowledged,
      rawAck: large,
    );
    expect(RecruitmentCommand.decode(saved.encode()).rawAck, large);
    expect(
      () => j.transition(
        state: RecruitmentCommandState.acknowledged,
        rawAck: raw + ' ' * 1048576,
      ),
      throwsFormatException,
    );
    expect(
      () => beta.command().transition(
        state: RecruitmentCommandState.acknowledged,
        rawAck: jsonEncode(beta.ack()) + ' ' * 262144,
      ),
      throwsFormatException,
    );
  });

  group('real participation transport', () {
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late base.Api api;
    late CycleInteractionRepository repository;
    late CycleParticipationController controller;
    late RecruitmentCommandTransport transport;
    late Map<String, dynamic> currentContext;
    Map<String, dynamic>? responseAck;
    late List<RecruitmentCommand> writes;
    bool loseAck = false, failRefresh = false;
    Completer<void>? pauseContext;
    late List<String> refreshes;
    CycleParticipationController makeController() =>
        CycleParticipationController(
          gateway: repository,
          session: session,
          changes: changes,
          scopeKey: () => '${session.userId}/${session.generation}',
          commandTransport: transport,
          now: () => DateTime.parse('2026-11-10T05:00:00Z'),
          onMutation: (t) async {
            refreshes.add(t);
            if (failRefresh) {
              throw const AccountReadException('NETWORK_UNAVAILABLE');
            }
          },
        );
    setUp(() async {
      session = ReadSessionFake()
        ..userId = '33333333-3333-4333-8333-333333333333';
      changes = ChangeNotifier();
      api = base.Api();
      currentContext = fixture('party_partial_context');
      writes = [];
      refreshes = [];
      loseAck = false;
      failRefresh = false;
      pauseContext = null;
      responseAck = null;
      api.respond = (path, q) async {
        await pauseContext?.future;
        expect(q!['contract_profile'], BetaContract.profile);
        expect(q['participation_profile'], BetaContract.participationProfile);
        expect(jsonDecode(q['round_ids']), currentContext['data']['round_ids']);
        return copy(currentContext);
      };
      repository = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      final store = DriftRecruitmentCommandStore(
        databaseFactory: () =>
            RecruitmentCommandDatabase(NativeDatabase.memory()),
      );
      transport = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => 'https://example.com',
        mode: RecruitmentContractMode.betaWire2,
        clock: () => DateTime.parse('2026-11-10T05:00:00Z'),
        send: (j, _) async {
          writes.add(j);
          if (loseAck) {
            loseAck = false;
            throw const AccountReadException('NETWORK_UNAVAILABLE');
          }
          final ack = responseAck == null
              ? fixture(
                  currentContext['data']['action'] == 'batch_completion'
                      ? 'party_partial_ack'
                      : 'personal_leave_ack',
                )
              : copy(responseAck!);
          ack['data']['command_id'] = j.key;
          return ack;
        },
      );
      controller = makeController();
      while (controller.restoring) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    tearDown(() async {
      controller.dispose();
      changes.dispose();
      session.dispose();
      await transport.dispose();
    });
    test(
      'production contract enables batch and exact POST produces target success',
      () async {
        expect(controller.batchCompletionEnabled, true);
        final p = preview(currentContext);
        final result = await controller.batchCompletion(
          p.room,
          p.target,
          p.kind,
          p.rounds,
          isCurrent: () => true,
        );
        expect(result, isNotNull);
        await controller.completeBatch(result!, isCurrent: () => true);
        expect(controller.failure, isNull);
        expect(controller.hasPending, false);
        expect(writes, hasLength(1));
        expect(jsonDecode(writes.single.rawBody)['round_ids'], p.rounds);
        expect(controller.completionSuccess?.$1, writes.single.key);
        expect(refreshes, [p.target]);
      },
    );
    test(
      'changed context requires another confirmation and sends nothing',
      () async {
        final p = preview(currentContext);
        currentContext['data']['display']['rounds'][0]['raid_name'] =
            'new display';
        final revised = await controller.completeBatch(
          p,
          isCurrent: () => true,
        );
        expect(revised, isNotNull);
        expect(writes, isEmpty);
        expect(controller.hasPending, false);
      },
    );
    test('closed during recheck does not save or send a new request', () async {
      final p = preview(currentContext), hold = Completer<void>();
      pauseContext = hold;
      var live = true;
      final sending = controller.completeBatch(p, isCurrent: () => live);
      live = false;
      hold.complete();
      await sending;
      expect(writes, isEmpty);
      expect(controller.hasPending, false);
    });
    test(
      'timeout retains selected rounds; replay sends same original without context GET',
      () async {
        final p = preview(currentContext);
        loseAck = true;
        final f = CompletionDialogFeedback(
          controller,
          p.room,
          p.target,
          p.kind.uiAction,
        );
        await controller.completeBatch(p, isCurrent: () => true);
        expect(controller.hasPending, true);
        expect(controller.pendingCompletionRound, isNull);
        expect(controller.pendingCompletionRounds, p.rounds);
        expect(controller.pendingBatchKind, p.kind);
        final original = writes.single, gets = api.requests.length;
        f.close();
        final reopened = CompletionDialogFeedback(
          controller,
          p.room,
          p.target,
          p.kind.uiAction,
        );
        await controller.retry();
        expect(controller.failure, isNull);
        expect(writes, hasLength(2));
        expect(writes.last.sameOriginal(original), true);
        expect(api.requests.length, gets);
        expect(controller.hasPending, false);
        reopened.close();
      },
    );
    test(
      'restart restores exact evidence without sending or navigating',
      () async {
        final p = preview(currentContext);
        loseAck = true;
        await controller.completeBatch(p, isCurrent: () => true);
        controller.dispose();
        controller = makeController();
        while (controller.restoring) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(writes, hasLength(1));
        expect(controller.pendingCompletionRounds, p.rounds);
        await controller.retry();
        expect(controller.hasPending, false);
        expect(controller.completionSuccess, isNull);
      },
    );
    test('ACK success and read failure recover by reads only', () async {
      final p = preview(currentContext);
      failRefresh = true;
      final f = CompletionDialogFeedback(
        controller,
        p.room,
        p.target,
        p.kind.uiAction,
      );
      await controller.completeBatch(p, isCurrent: () => true);
      f.capture();
      expect(f.acknowledged, true);
      expect(f.refreshFailed, true);
      final successKey = controller.completionSuccess!.$1;
      f.close();
      controller.keepRecoveryOnCurrentScreen();
      failRefresh = false;
      await controller.refreshCompletion(p.room, p.target);
      expect(controller.completionNavigationAllowed(successKey), false);
      f.capture();
      expect(controller.completionRefreshFailed, false);
      expect(writes, hasLength(1));
      f.close();
    });
    test(
      'personal batch publishes departure; account never sees a singleton target',
      () async {
        currentContext = fixture('personal_leave_context');
        final p = preview(currentContext);
        await controller.completeBatch(p, isCurrent: () => true);
        expect(controller.failure, isNull);
        expect(controller.departureSuccess?.$1, writes.single.key);
        expect(controller.completionSuccess, isNull);
      },
    );
    test(
      'successor pending restores original request and verifies original ACK policy',
      () async {
        currentContext = successorGroupPolicy(
          fixture('personal_successor_context'),
        );
        responseAck = successorGroupPolicy(fixture('personal_successor_ack'));
        responseAck!.remove('group_policy');
        final p = preview(currentContext);
        await controller.completeBatch(p, isCurrent: () => true);
        expect(controller.failure, 'INVALID_RESPONSE');
        expect(controller.hasPending, true);
        expect(refreshes, isEmpty);
        final original = writes.single, reads = api.requests.length;
        controller.dispose();
        controller = makeController();
        while (controller.restoring) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(writes, hasLength(1));
        expect(controller.pendingCompletionRound, isNull);
        responseAck = successorGroupPolicy(fixture('personal_successor_ack'));
        await controller.retry();
        expect(controller.failure, isNull);
        expect(controller.hasPending, false);
        expect(writes, hasLength(2));
        expect(writes.last.sameOriginal(original), true);
        expect(api.requests.length, reads);
        expect(refreshes, [p.target]);
        expect(controller.departureSuccess, isNull);
      },
    );
    testWidgets(
      'pending batch recovery remains reachable after room read permission ends',
      (tester) async {
        currentContext = successorGroupPolicy(
          fixture('personal_successor_context'),
        );
        responseAck = successorGroupPolicy(fixture('personal_successor_ack'));
        loseAck = true;
        final p = preview(currentContext);
        await controller.completeBatch(p, isCurrent: () => true);
        final original = writes.single;
        api.respond = (_, _) async => throw const AccountReadException(
          'ROOM_MEMBERSHIP_REQUIRED',
          status: 403,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParticipationRecoveryCard(controller: controller),
            ),
          ),
        );
        final readsBeforeRecovery = api.requests.length;
        expect(find.textContaining('이전 완료 요청'), findsOneWidget);
        await tester.tap(find.text('요청 결과 확인'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(api.requests.length, readsBeforeRecovery);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(writes, hasLength(1));
        await tester.tap(find.widgetWithText(FilledButton, '재시도'));
        await tester.pumpAndSettle();
        expect(controller.hasPending, false);
        expect(refreshes, [p.target]);
        expect(writes, hasLength(2));
        expect(writes.last.sameOriginal(original), true);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('요청 결과 확인'), findsNothing);
        expect(controller.failure, isNull);
        expect(
          controller.completionNavigationAllowed(
            controller.departureSuccess!.$1,
          ),
          false,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    test(
      'late display failure after ACK never changes command result',
      () async {
        loseAck = true;
        final p = preview(currentContext);
        await controller.completeBatch(p, isCurrent: () => true);
        final original = writes.single;
        final reply = Completer<Map<String, dynamic>>();
        api.respond = (_, _) => reply.future;
        final reading = controller.readScheduleForDisplay(
          p.room,
          p.target,
          'plan',
        );
        final failed = expectLater(
          reading,
          throwsA(isA<AccountReadException>()),
        );
        await controller.retry();
        expect(controller.hasPending, false);
        expect(controller.failure, isNull);
        reply.completeError(
          const AccountReadException(
            'WEEKLY_PARTICIPANT_REQUIRED',
            status: 403,
          ),
        );
        await failed;
        expect(controller.failure, isNull);
        expect(controller.completionSuccess, isNotNull);
        expect(writes.last.sameOriginal(original), true);
      },
    );

    test(
      'direct beta gateway preserves original ACK metadata for successor proof',
      () async {
        final p = preview(
          successorGroupPolicy(fixture('personal_successor_context')),
        );
        const key = '00000000-0000-4000-8000-000000000199';
        api.respond = (_, _) async {
          final ack = successorGroupPolicy(fixture('personal_successor_ack'));
          ack['data']['command_id'] = key;
          return ack;
        };
        await repository.writeBatchCompletion(p, key, p.body());
        expect(api.requests, hasLength(1));
        expect(api.requests.single['method'], 'POST');
        expect(api.requests.single['path'], p.path);
      },
    );
    test('old selection response cannot apply a stale query error', () async {
      final p = preview(currentContext), hold = Completer<void>();
      var live = true;
      api.respond = (_, _) async {
        await hold.future;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      };
      final reading = controller.batchCompletion(
        p.room,
        p.target,
        p.kind,
        p.rounds,
        isCurrent: () => live,
      );
      live = false;
      hold.complete();
      expect(await reading, isNull);
      expect(controller.failure, isNull);
    });
  });
}
