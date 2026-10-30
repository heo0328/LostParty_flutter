import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/participation_command_evidence.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_member_actions.dart';
import 'package:lost_party/features/recruitment_list/data/membership_actions.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'cycle_interaction_test.dart' as interaction;
import 'beta_foundation_test.dart' as foundation;
import 'membership_actions_test.dart' as membership;
import 'cycle_removal_test.dart' as removal;
import 'cycle_departure_test.dart' as departure;
import 'cycle_schedule_test.dart' as schedule;
import 'cycle_management_test.dart' as management;
import 'beta_schedule_management_test.dart' as beta_schedule;
import '../account/backend_read/play_availability_test.dart' as personal;

class JournalFaults extends foundation.FaultStore {
  JournalFaults(super.inner);
  bool failRelease = false, corrupt = false, readBroken = false;
  RecruitmentCommand? overrideRead;
  Completer<void>? gate;
  @override
  Future<RecruitmentCommand?> read(
    StorageScope s,
    RecruitmentCommandOwner o,
  ) async {
    if (gate != null) await gate!.future;
    if (corrupt) throw const FormatException('corrupt');
    if (readBroken) throw StateError('disk read');
    if (overrideRead != null && o == RecruitmentCommandOwner.participation) {
      return overrideRead;
    }
    return super.read(s, o);
  }

  @override
  Future<void> releaseResolved(
    StorageScope s,
    RecruitmentCommandOwner o,
    String key,
  ) {
    if (failRelease) throw StateError('disk release');
    return super.releaseResolved(s, o, key);
  }
}

Future<void> ready(CycleParticipationController c) async {
  for (var i = 0; i < 300 && c.restoring; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(c.restoring, isFalse);
}

Map<String, dynamic> applicationAck(RecruitmentCommand cmd) =>
    cycles.envelope(interaction.n, {
      'command_id': cmd.key,
      'room_id': base.roomId,
      'application_id': base.membershipId,
      'revision': 2,
      'state': 'pending',
      'executed_at': cycles.nowStamp,
      'target_cycle_key': interaction.n,
    }, created: true);
Map<String, dynamic> copiedSubmission({int revision = 1}) {
  final j = schedule.submissionWire();
  j['data'].addAll({
    'state': 'ready',
    'revision': revision,
    'source_personal_version': 1,
    'submitted_at': cycles.nowStamp,
    'availability_copy': {
      'state': 'unset',
      'source_personal_version': 1,
      'copied_at': cycles.nowStamp,
    },
  });
  return j;
}

void main() {
  group('durable app-owned participation', () {
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late JournalFaults store;
    late base.Api api;
    late DateTime now;
    String binding = 'env/member/1', baseUrl = 'https://example.test';
    final alive = <CycleParticipationController>{};
    void stop(CycleParticipationController c) {
      if (alive.remove(c)) c.dispose();
    }

    final writes = <RecruitmentCommand>[];
    final mutations = <String>[];
    final usageSignals = <String>[];
    late Future<Map<String, dynamic>> Function(RecruitmentCommand) answer;
    setUp(() {
      binding = 'env/member/1';
      baseUrl = 'https://example.test';
      now = DateTime.parse(cycles.nowStamp);
      writes.clear();
      mutations.clear();
      usageSignals.clear();
      session = ReadSessionFake()..userId = foundation.user;
      changes = ChangeNotifier();
      store = JournalFaults(
        DriftRecruitmentCommandStore(
          databaseFactory: () =>
              RecruitmentCommandDatabase(NativeDatabase.memory()),
        ),
      );
      api = base.Api()
        ..respond = (_, _) async {
          final j = interaction.admissionWire(interaction.n, intent: 'apply');
          j['data']['beta_schedule'] = null;
          return j;
        };
      answer = (cmd) async => applicationAck(cmd);
    });
    tearDown(() async {
      await store.close();
      changes.dispose();
      session.dispose();
    });
    RecruitmentCommandTransport transport() {
      final t = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => baseUrl,
        mode: RecruitmentContractMode.betaWire2,
        clock: () => now,
        send: (cmd, scope) async {
          writes.add(cmd);
          return answer(cmd);
        },
      );
      addTearDown(t.dispose);
      return t;
    }

    Future<CycleParticipationController> controller({
      bool failedRefresh = false,
      RecruitmentContractMode mode = RecruitmentContractMode.betaWire2,
    }) async {
      final c = CycleParticipationController(
        gateway: CycleInteractionRepository(
          api: api,
          recruitment: cycles.CycleGateway(),
          contractMode: mode,
        ),
        commandTransport: transport(),
        session: session,
        changes: changes,
        scopeKey: () => '$binding/${session.userId}/${session.generation}',
        now: () => now,
        onActiveRoomsChanged: usageSignals.add,
        onMutation: (t) async {
          mutations.add(t);
          if (failedRefresh) throw StateError('read');
        },
      );
      alive.add(c);
      addTearDown(() => stop(c));
      await ready(c);
      return c;
    }

    Future<String?> apply(CycleParticipationController c) async {
      final p = await c.preview(
        base.roomId,
        interaction.n,
        characterId,
        'dealer',
        'apply',
      );
      expect(p, isNotNull);
      return c.admit(p!, {}, applicationMemo: '  가  ');
    }

    test(
      'normal DI path journals before send, ACK then refresh and clears slot',
      () async {
        final c = await controller();
        answer = (cmd) async {
          expect(
            await store.read(
              StorageScope(baseUrl: baseUrl, userId: session.userId!),
              cmd.owner,
            ),
            isNotNull,
          );
          return applicationAck(cmd);
        };
        final key = await apply(c);
        expect(c.failure, isNull);
        expect(writes, hasLength(1));
        expect(writes.single.version, 3);
        expect(writes.single.query['contract_profile'], BetaContract.profile);
        expect(writes.single.rawBody, contains('가'));
        expect(c.admissionSuccess!.$1, key);
        expect(c.hasPending, isFalse);
        expect(mutations, [interaction.n]);
      },
    );
    test(
      'lost response, fresh controller/transport restores exact request without GET or automatic POST',
      () async {
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        await apply(c);
        expect(c.hasPending, isTrue);
        final original = writes.single;
        stop(c);
        api.requests.clear();
        final next = await controller();
        expect(writes, hasLength(1));
        expect(api.requests, isEmpty);
        expect(next.pendingRequestKey, original.key);
        answer = (cmd) async => applicationAck(cmd);
        await next.retry();
        expect(writes, hasLength(2));
        expect(writes.last.sameOriginal(original), isTrue);
        expect(next.hasPending, isFalse);
        expect(next.admissionSuccess, isNull);
        expect(next.membershipSuccess, isNull);
        expect(next.scheduleSuccess, isNull);
        expect(mutations, [interaction.n]);
      },
    );
    for (final fault in ['insert', 'attempt', 'ack', 'release']) {
      test(
        'disk $fault failure preserves original and avoids duplicate effects',
        () async {
          store.failInsert = fault == 'insert';
          store.failAttempt = fault == 'attempt';
          store.failAck = fault == 'ack';
          store.failRelease = fault == 'release';
          final c = await controller();
          await apply(c);
          expect(c.hasPending, isTrue);
          expect(
            writes.length,
            fault == 'insert' || fault == 'attempt' ? 0 : 1,
          );
          if (fault == 'ack') expect(c.admissionSuccess, isNull);
          store.failInsert = store.failAttempt = store.failAck =
              store.failRelease = false;
          await c.retry();
          expect(c.hasPending, isFalse);
          expect(writes, hasLength(1));
          expect(mutations, [interaction.n]);
        },
      );
    }
    test(
      'persisted ACK survives restart and 24h without HTTP or old-sheet navigation',
      () async {
        store.failRelease = true;
        final c = await controller();
        await apply(c);
        expect(c.hasPending, isTrue);
        stop(c);
        store.failRelease = false;
        now = now.add(const Duration(days: 2));
        final next = await controller();
        expect(next.hasPending, isFalse);
        expect(writes, hasLength(1));
        expect(next.admissionSuccess, isNull);
        expect(mutations, [interaction.n, interaction.n]);
      },
    );
    test(
      'ACK disk failure after process loss replays original key, not a fresh context',
      () async {
        store.failAck = true;
        final c = await controller();
        await apply(c);
        final key = writes.single.key;
        stop(c);
        store.failAck = false;
        api.requests.clear();
        final next = await controller();
        expect(writes, hasLength(1));
        await next.retry();
        expect(writes, hasLength(2));
        expect(writes.last.key, key);
        expect(api.requests, isEmpty);
        expect(next.hasPending, isFalse);
      },
    );
    for (final issue in [
      'NETWORK_UNAVAILABLE',
      'INVALID_RESPONSE',
      'UNRECOGNIZED_FAILURE',
    ]) {
      test('unknown $issue is retained even with HTTP400', () async {
        answer = (_) async => throw AccountReadException(issue, status: 400);
        final c = await controller();
        await apply(c);
        expect(c.hasPending, isTrue);
        expect(c.canRetry, isTrue);
        expect(mutations, isEmpty);
      });
    }
    test(
      'verified no-effect rejection is saved/released and permits a new action',
      () async {
        answer = (_) async => throw const AccountReadException(
          'REVISION_CONFLICT',
          status: 409,
          retryAfter: Duration(minutes: 1),
        );
        final c = await controller();
        await apply(c);
        expect(c.hasPending, isFalse);
        expect(c.canAct, isTrue);
        expect(c.admissionSuccess, isNull);
        expect(mutations, isEmpty);
      },
    );
    test(
      'startup rejection cleanup does not suppress the next live success',
      () async {
        store.failRelease = true;
        answer = (_) async =>
            throw const AccountReadException('REVISION_CONFLICT', status: 409);
        final previous = await controller();
        await apply(previous);
        stop(previous);
        store.failRelease = false;
        final next = await controller();
        expect(next.hasPending, isFalse);
        answer = (cmd) async => applicationAck(cmd);
        final key = await apply(next);
        expect(next.hasPending, isFalse);
        expect(next.admissionSuccess!.$1, key);
        expect(writes, hasLength(2));
      },
    );
    test(
      'RetryAfter persists across new transport and blocks premature HTTP',
      () async {
        answer = (_) async => throw const AccountReadException(
          'REQUEST_IN_PROGRESS',
          status: 409,
          retryAfter: Duration(minutes: 5),
        );
        final c = await controller();
        await apply(c);
        stop(c);
        final next = await controller();
        expect(next.canRetry, isFalse);
        await next.retry();
        expect(writes, hasLength(1));
        now = now.add(const Duration(minutes: 5));
        answer = (cmd) async => applicationAck(cmd);
        await next.retry();
        expect(writes, hasLength(2));
        expect(next.hasPending, isFalse);
      },
    );
    for (final delta in [
      const Duration(hours: 24),
      const Duration(minutes: -1),
    ]) {
      test(
        'replay deadline/clock reversal $delta holds instead of sending',
        () async {
          answer = (_) async =>
              throw const AccountReadException('NETWORK_UNAVAILABLE');
          final c = await controller();
          await apply(c);
          stop(c);
          now = now.add(delta);
          final next = await controller();
          expect(next.needsReview, isTrue);
          expect(next.canRetry, isFalse);
          expect(next.canAct, isFalse);
          await next.retry();
          expect(writes, hasLength(1));
        },
      );
    }
    test(
      'pending restore isolates environment and returning member sees old original',
      () async {
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        await apply(c);
        final key = c.pendingRequestKey;
        baseUrl = 'https://other.test';
        binding = 'other/member/2';
        changes.notifyListeners();
        await ready(c);
        expect(c.hasPending, isFalse);
        expect(c.canAct, isTrue);
        baseUrl = 'https://example.test';
        binding = 'env/member/3';
        changes.notifyListeners();
        await ready(c);
        expect(c.pendingRequestKey, key);
        expect(writes, hasLength(1));
      },
    );
    test(
      'late response after binding change cannot publish or clear another scope',
      () async {
        final reply = Completer<Map<String, dynamic>>();
        answer = (_) async => reply.future;
        final c = await controller();
        final send = apply(c);
        for (var i = 0; i < 300 && writes.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final original = writes.single;
        baseUrl = 'https://other.test';
        binding = 'other/member/2';
        changes.notifyListeners();
        await ready(c);
        reply.complete(applicationAck(original));
        await send;
        expect(c.admissionSuccess, isNull);
        expect(mutations, isEmpty);
        expect(c.hasPending, isFalse);
      },
    );
    test(
      'restore in flight blocks writes, corruption is not a vacant slot',
      () async {
        store.gate = Completer<void>();
        final c = CycleParticipationController(
          gateway: CycleInteractionRepository(
            api: api,
            recruitment: cycles.CycleGateway(),
          ),
          commandTransport: transport(),
          session: session,
          changes: changes,
          scopeKey: () => '$binding/${session.userId}/${session.generation}',
        );
        alive.add(c);
        addTearDown(() => stop(c));
        expect(c.canAct, isFalse);
        store.corrupt = true;
        store.gate!.complete();
        await ready(c);
        expect(c.needsReview, isTrue);
        expect(c.hasPending, isTrue);
        expect(c.canAct, isFalse);
        expect(writes, isEmpty);
      },
    );
    test(
      'successful command followed by refresh failure remains successful',
      () async {
        final c = await controller(failedRefresh: true);
        await apply(c);
        expect(c.hasPending, isFalse);
        expect(c.admissionSuccess, isNotNull);
        expect(c.notice, contains('반영'));
        await c.retry();
        expect(writes, hasLength(1));
      },
    );
    for (final kind in [
      'membership',
      'membership-empty',
      'removal',
      'departure',
    ]) {
      test(
        '$kind durable original and replay preserve dedicated impact',
        () async {
          final context = kind.startsWith('membership')
              ? membership.fixture(
                  kind == 'membership-empty'
                      ? 'empty-effects-context'
                      : 'eight-members-two-targets-context',
                )
              : kind == 'removal'
              ? removal.context('removal_both')
              : departure.context('personal_automatic_successor');
          final ack = kind.startsWith('membership')
              ? membership.fixture(
                  kind == 'membership-empty'
                      ? 'empty-effects-result'
                      : 'eight-members-two-targets-result',
                )
              : kind == 'removal'
              ? removal.ack('removal_both')
              : departure.ack('personal_automatic_successor');
          api.respond = (_, _) async => membership.copy(context);
          answer = (_) async =>
              throw const AccountReadException('NETWORK_UNAVAILABLE');
          final c = await controller();
          if (kind.startsWith('membership')) {
            final p = membership.context(context).select(ack['data']['action']);
            await c.performMembershipAction(p, isCurrent: () => true);
          } else if (kind == 'removal') {
            final p = removal.preview(context);
            await c.removeMember(
              p,
              'both',
              membership: p.membership,
              isCurrent: () => true,
            );
          } else {
            await c.depart(departure.preview(context));
          }
          expect(c.failure, 'NETWORK_UNAVAILABLE');
          expect(c.hasPending, isTrue);
          expect(writes, hasLength(1));
          final original = writes.single;
          stop(c);
          api.requests.clear();
          final next = await controller();
          answer = (cmd) async {
            final result = membership.copy(ack);
            result['data']['command_id'] = cmd.key;
            return result;
          };
          await next.retry();
          expect(next.failure, isNull);
          expect(next.hasPending, isFalse);
          expect(next.membershipSuccess, isNull);
          expect(next.removalSuccess, isNull);
          expect(next.departureSuccess, isNull);
          expect(
            next.relationEnded != null,
            ack['data']['actor_membership_ended'] == true,
          );
          expect(writes.last.sameOriginal(original), isTrue);
          expect(api.requests, isEmpty);
          expect(mutations, original.validationSnapshot!['affected_targets']);
          expect(usageSignals, kind == 'removal' ? isEmpty : [original.key]);
        },
      );
    }
    test(
      'restored composition rejection releases original slot, never retries a new write',
      () async {
        api.respond = (_, _) async => management.managementWire('formation');
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final first = await controller(mode: RecruitmentContractMode.legacy);
        final p = await first.management(
          base.roomId,
          interaction.n,
          'formation',
        );
        await first.manage(p!, {
          'placements': [
            {
              'cycle_member_id': base.membershipId,
              'expected_cycle_member_revision': 7,
              'item_id': base.itemId,
              'party_no': 2,
              'slot_no': 4,
            },
          ],
        });
        expect(first.hasPending, true);
        final original = writes.single;
        stop(first);
        final restored = await controller(mode: RecruitmentContractMode.legacy);
        answer = (_) async => throw const AccountReadException(
          'ROOM_COMPOSITION_CONFLICT',
          status: 409,
        );
        await restored.retry();
        expect(restored.failure, 'ROOM_COMPOSITION_CONFLICT');
        expect(restored.hasPending, false);
        expect(restored.canAct, true);
        expect(writes.last.sameOriginal(original), true);
        expect(
          await restored.commandTransport!.restore(
            RecruitmentCommandOwner.participation,
          ),
          isNull,
        );
        final sent = writes.length;
        await restored.retry();
        expect(writes.length, sent);
      },
    );
    for (final action in ['common', 'cancel']) {
      test(
        '$action management replays frozen scope and exact affected cycles',
        () async {
          api.respond = (_, _) async {
            final raw = management.managementWire(action);
            if (action == 'common') {
              raw['data']['current_settings'] = {'title': '기존 제목'};
            }
            return raw;
          };
          answer = (_) async =>
              throw const AccountReadException('NETWORK_UNAVAILABLE');
          final c = await controller();
          final p = await c.management(base.roomId, interaction.n, action);
          expect(p, isNotNull);
          await c.manage(
            p!,
            action == 'common' ? {'title': 'original title'} : {},
          );
          expect(writes, hasLength(1));
          final original = writes.single;
          stop(c);
          api.requests.clear();
          final next = await controller();
          answer = (cmd) async => action == 'common'
              ? {
                  'scope': management.globalScope(),
                  'data': {
                    'command_id': cmd.key,
                    'outcome': 'applied',
                    'executed_at': cycles.nowStamp,
                    'room_id': base.roomId,
                    'room_revision': 4,
                    'affected_cycle_keys': [interaction.c, interaction.n],
                  },
                }
              : cycles.envelope(interaction.n, {
                  'command_id': cmd.key,
                  'outcome': 'applied',
                  'executed_at': cycles.nowStamp,
                  'room_id': base.roomId,
                  'target_cycle_key': interaction.n,
                  'revisions': [
                    {
                      'resource': 'target',
                      'id': cycles.nextCycleId,
                      'revision': 2,
                    },
                  ],
                }, created: true);
          await next.retry();
          expect(next.failure, isNull);
          expect(next.hasPending, isFalse);
          expect(writes.last.sameOriginal(original), isTrue);
          expect(api.requests, isEmpty);
          expect(mutations, original.validationSnapshot!['affected_targets']);
        },
      );
    }
    test(
      'absent N opening submits the confirmed seed and recovers that original ACK',
      () async {
        var reads = 0;
        late Map<String, dynamic> confirmed;
        api.respond = (_, _) async {
          final raw = beta_schedule.openingWire('open');
          final seed = management.id(100 + ++reads);
          raw['data']['prospective_room_cycle_id'] = seed;
          raw['data']['context_token'] = 'opening-seed-$reads';
          raw['data']['targets'][0]['round_id'] = management.id(200 + reads);
          raw['data']['session_display']['room_cycle_id'] = seed;
          raw['data']['session_display']['display_revision'] = reads
              .toRadixString(16)
              .padLeft(64, '0');
          raw['data']['group_policy_effect'] = {
            'room_id': base.roomId,
            'target_cycle_key': interaction.n,
            'room_cycle_id': seed,
            'generation': 2,
            'before': {'scope': 'public', 'group_id': null, 'revision': 5},
            'after': {'scope': 'public', 'group_id': null},
          };
          return raw;
        };
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        final p = await c.management(
          base.roomId,
          interaction.n,
          'open',
          query: beta_schedule.config,
        );
        expect(p, isNotNull);
        confirmed = jsonDecode(
          jsonEncode({
            ...p!.data,
            'group_policy_effect': p.effectsFor().single,
          }),
        );
        await c.manage(p, {'beta_schedule': beta_schedule.config});
        expect(writes, hasLength(1));
        expect(reads, 1);
        expect(c.failure, 'NETWORK_UNAVAILABLE');
        final original = writes.single;
        final body = jsonDecode(original.rawBody);
        expect(body['context_token'], confirmed['context_token']);
        expect(body['target_items'], confirmed['targets']);
        late Map<String, dynamic> actualAck;
        stop(c);
        api.requests.clear();
        final next = await controller();
        expect(next.recoveryIssue, isNull);
        expect(next.pendingRequestKey, original.key);
        answer = (cmd) async {
          final ack = cycles.envelope(interaction.n, {
            'command_id': cmd.key,
            'outcome': 'applied',
            'executed_at': cycles.nowStamp,
            'room_id': base.roomId,
            'target_cycle_key': interaction.n,
            'revisions': [
              {
                'resource': 'target',
                'id': confirmed['prospective_room_cycle_id'],
                'revision': 1,
              },
            ],
          }, created: true);
          ack['scope']['room_cycle_id'] =
              confirmed['prospective_room_cycle_id'];
          ack['scope']['target_generation'] = 2;
          ack['scope']['target_revision'] = 1;
          ack['group_policy_effects'] = [
            <String, dynamic>{
              ...confirmed['group_policy_effect'],
              'after': {'scope': 'public', 'group_id': null, 'revision': 1},
            },
          ];
          actualAck = ack;
          return ack;
        };
        await next.retry();
        expect(writes, hasLength(2));
        ParticipationCommandEvidence(original.validationSnapshot!).validate(
          actualAck,
          method: original.method,
          path: original.path,
          key: original.key,
          status: original.expectedStatus,
          mode: original.contractMode,
          rawBody: original.rawBody,
        );
        expect(next.failure, isNull);
        expect(next.hasPending, false);
        expect(writes.last.sameOriginal(original), true);
        expect(api.requests, isEmpty);
        expect(mutations, [interaction.n]);
      },
    );

    test(
      'absent N review from previous member generation cannot submit',
      () async {
        api.respond = (_, _) async => beta_schedule.openingWire('open');
        final c = await controller();
        final p = await c.management(
          base.roomId,
          interaction.n,
          'open',
          query: beta_schedule.config,
        );
        session.generation++;
        session.notifyListeners();
        await ready(c);
        await c.manage(p!, {'beta_schedule': beta_schedule.config});
        expect(c.failure, 'REVISION_CONFLICT');
        expect(writes, isEmpty);
        expect(c.hasPending, false);
      },
    );

    for (final failure in [
      ('TARGET_CONTEXT_STALE', 409),
      ('TARGET_LEADER_REQUIRED', 403),
    ]) {
      test(
        'opening ${failure.$1} clears rejected original and requires explicit new confirmation',
        () async {
          api.respond = (_, _) async => beta_schedule.openingWire('open');
          answer = (_) async =>
              throw AccountReadException(failure.$1, status: failure.$2);
          final c = await controller();
          final p = await c.management(
            base.roomId,
            interaction.n,
            'open',
            query: beta_schedule.config,
          );
          await c.manage(p!, {'beta_schedule': beta_schedule.config});
          expect(c.failure, failure.$1);
          expect(c.hasPending, false);
          expect(mutations, isEmpty);
          await c.retry();
          expect(writes, hasLength(1));
        },
      );
    }
    test(
      'schedule proposal uses original body/profile after restart',
      () async {
        api.respond = (_, _) async => beta_schedule.betaPlan();
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        final p = await c.schedulePreview(
          base.roomId,
          interaction.n,
          'propose',
        );
        expect(p, isNotNull);
        await c.scheduleCommand(p!, {'targets': schedule.targets()});
        expect(c.hasPending, isTrue);
        expect(writes, hasLength(1));
        final original = writes.single;
        stop(c);
        api.requests.clear();
        final next = await controller();
        answer = (cmd) async => cycles.envelope(interaction.n, {
          'command_id': cmd.key,
          'outcome': 'recorded',
          'executed_at': cycles.nowStamp,
          'room_id': base.roomId,
          'target_cycle_key': interaction.n,
          'revisions': [
            {'resource': 'target', 'id': cycles.nextCycleId, 'revision': 2},
          ],
        }, created: true);
        await next.retry();
        expect(next.failure, isNull);
        expect(next.hasPending, isFalse);
        expect(next.scheduleSuccess, isNull);
        expect(writes.last.sameOriginal(original), isTrue);
        expect(api.requests, isEmpty);
      },
    );
    test(
      'personal timetable PUT validates frozen submission without refetch on retry',
      () async {
        api.respond = (path, q) async {
          if (path.endsWith('/plan')) return beta_schedule.betaPlan();
          if (path.endsWith('/play-availability')) return personal.response();
          return copiedSubmission();
        };
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        final p = await c.schedulePreview(
          base.roomId,
          interaction.n,
          'submission',
        );
        expect(p, isNotNull);
        await c.scheduleCommand(p!, {});
        expect(writes, hasLength(1));
        final original = writes.single;
        expect(original.method, 'PUT');
        expect(original.validationSnapshot!['kind'], 'submission');
        stop(c);
        api.requests.clear();
        final next = await controller();
        answer = (cmd) async {
          final j = schedule.submissionWire();
          j['data'].addAll({
            'state': 'ready',
            'revision': 2,
            'source_personal_version': 1,
            'submitted_at': cycles.nowStamp,
            'availability_copy': {
              'state': 'unset',
              'source_personal_version': 1,
              'copied_at': cycles.nowStamp,
            },
          });
          return j;
        };
        await next.retry();
        expect(next.failure, isNull);
        expect(next.hasPending, isFalse);
        expect(writes.last.sameOriginal(original), isTrue);
        expect(api.requests, isEmpty);
        expect(mutations, [interaction.n]);
      },
    );
    test(
      'pre-fix submission journal recovers original ACK without rewriting evidence',
      () async {
        api.respond = (path, q) async {
          if (path.endsWith('/plan')) return beta_schedule.betaPlan();
          if (path.endsWith('/play-availability')) return personal.response();
          return copiedSubmission();
        };
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        final p = await c.schedulePreview(
          base.roomId,
          interaction.n,
          'submission',
        );
        await c.scheduleCommand(p!, {});
        final original = writes.single;
        final wire = jsonDecode(original.encode()) as Map<String, dynamic>;
        final evidence = wire['validation_snapshot'] as Map<String, dynamic>;
        evidence['submission_ack']['revision'] =
            1; // The released app's old no-op expectation.
        evidence['checksum'] = sha256
            .convert(
              utf8.encode(cycleStableJson({...evidence}..remove('checksum'))),
            )
            .toString();
        wire['attempted_at'] = null;
        final saved = RecruitmentCommand.decode(jsonEncode(wire));
        stop(c);
        await store.close();
        store = JournalFaults(
          DriftRecruitmentCommandStore(
            databaseFactory: () =>
                RecruitmentCommandDatabase(NativeDatabase.memory()),
          ),
        );
        await store.insert(
          StorageScope(baseUrl: baseUrl, userId: foundation.user),
          saved,
        );
        api.requests.clear();
        final next = await controller();
        expect(writes, hasLength(1)); // No automatic replay.
        answer = (_) async => copiedSubmission(revision: 3);
        await next.retry();
        expect(
          next.hasPending,
          isTrue,
        ); // Never relax to an arbitrary higher revision.
        answer = (_) async => copiedSubmission(revision: 2);
        await next.retry();
        expect(next.hasPending, isFalse);
        expect(next.failure, isNull);
        expect(writes.last.sameOriginal(saved), isTrue);
        expect(writes.last.rawBody, original.rawBody);
        expect(
          writes.last.validationSnapshot!['submission_ack']['revision'],
          1,
        );
        expect(api.requests, isEmpty);
        expect(next.scheduleSuccess, isNull);
        expect(mutations, [interaction.n]);
      },
    );
    test(
      'relogin restores only the original member slot and never submits automatically',
      () async {
        answer = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = await controller();
        await apply(c);
        final key = c.pendingRequestKey;
        session.change(authenticated: false);
        expect(c.hasPending, isFalse);
        session.change(authenticated: true, user: foundation.otherKey);
        await ready(c);
        expect(c.hasPending, isFalse);
        session.change(authenticated: false);
        session.change(authenticated: true, user: foundation.user);
        await ready(c);
        expect(c.pendingRequestKey, key);
        expect(writes, hasLength(1));
      },
    );
    test('double submission and forged ACK cannot publish success', () async {
      final reply = Completer<Map<String, dynamic>>();
      answer = (_) async => reply.future;
      final c = await controller();
      final p = await c.preview(
        base.roomId,
        interaction.n,
        characterId,
        'dealer',
        'apply',
      );
      final first = c.admit(p!, {});
      expect(await c.admit(p, {}), isNull);
      for (var i = 0; i < 300 && writes.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final raw = applicationAck(writes.single);
      raw['data']['command_id'] = foundation.otherKey;
      reply.complete(raw);
      await first;
      expect(c.hasPending, isTrue);
      expect(c.admissionSuccess, isNull);
      expect(writes, hasLength(1));
      answer = (cmd) async => applicationAck(cmd);
      await c.retry();
      expect(writes, hasLength(2));
      expect(writes.first.key, writes.last.key);
      expect(c.hasPending, isFalse);
    });
    test(
      'transient local read and rejected-slot cleanup failures can retry locally',
      () async {
        store.readBroken = true;
        final c = await controller();
        expect(c.canAct, isFalse);
        expect(c.canRetry, isTrue);
        store.readBroken = false;
        await c.retry();
        expect(c.canAct, isTrue);
        expect(writes, isEmpty);
        store.failRelease = true;
        answer = (_) async =>
            throw const AccountReadException('REVISION_CONFLICT', status: 409);
        await apply(c);
        expect(c.hasPending, isTrue);
        store.failRelease = false;
        await c.retry();
        expect(c.hasPending, isFalse);
        expect(writes, hasLength(1));
      },
    );
    for (final variant in ['v1', 'missing', 'IF001']) {
      test(
        'unsupported $variant stays held without network or replacement',
        () async {
          answer = (_) async =>
              throw const AccountReadException('NETWORK_UNAVAILABLE');
          final c = await controller();
          await apply(c);
          final original = writes.single;
          stop(c);
          var j = original.toJson();
          if (variant == 'missing') {
            j['validation_snapshot'] = null;
          } else {
            j.remove('validation_snapshot');
            j.remove('rejection');
            j.remove('retry_not_before');
            j['version'] = 1;
            if (variant == 'IF001') {
              j['path'] =
                  '/v2/raid-rooms/${base.roomId}/weekly-incomplete-closures';
              j['operation'] = const BetaContract().operation(
                'POST',
                j['path'],
              )['id'];
              j['contract_mode'] = 'legacy';
              j['raw_query'] = '{}';
              j['expected_status'] = 200;
            }
          }
          store.overrideRead = RecruitmentCommand.decode(jsonEncode(j));
          final next = await controller();
          expect(next.hasPending, isTrue);
          expect(next.canRetry, isFalse);
          expect(next.canAct, isFalse);
          expect(writes, hasLength(1));
        },
      );
    }
    test('stored evidence/body/query mutations cannot be replayed', () async {
      answer = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      final c = await controller();
      await apply(c);
      final original = writes.single;
      for (final field in [
        'raw_body',
        'raw_query',
        'key',
        'validation_snapshot',
      ]) {
        final j = jsonDecode(original.encode()) as Map<String, dynamic>;
        if (field == 'validation_snapshot') {
          j[field]['room'] = foundation.otherKey;
        } else if (field == 'key') {
          j[field] = foundation.otherKey;
        } else {
          j[field] = '{}';
        }
        expect(
          () => RecruitmentCommand.decode(jsonEncode(j)),
          throwsFormatException,
        );
      }
    });
  });
  test(
    'specialized membership evidence survives JSON without an authorization preview',
    () {
      for (final name in [
        'eight-members-two-targets',
        'empty-effects',
        'no-successor',
      ]) {
        final ack = membership.fixture('$name-result');
        final p = membership
            .context(membership.fixture('$name-context'))
            .select(ack['data']['action']);
        final e = MembershipAckEvidence(
          jsonDecode(jsonEncode(MembershipAckEvidence.fromPreview(p).wire)),
        );
        final r = MembershipActionResult.fromEvidence(
          ack,
          e,
          ack['data']['command_id'],
        );
        expect(r.affected, p.affected);
        expect(e.wire.toString(), isNot(contains('context_token')));
      }
    },
  );
  test(
    'removal and completion-departure evidence reuse all original ACK rules',
    () {
      for (final name in removal.examples.keys.cast<String>()) {
        if ((removal.examples[name]['responses'] as List).length < 2) continue;
        final p = removal.preview(removal.context(name)),
            ack = removal.ack(name);
        final mode = (ack['data']['affected_cycle_keys'] as List).length == 2
            ? 'both'
            : 'current_only';
        final e = RemovalAckEvidence(
          jsonDecode(jsonEncode(RemovalAckEvidence.fromPreview(p, mode).wire)),
        );
        validateRemovalEvidenceResult(ack, e, ack['data']['command_id']);
      }
      for (final name in departure.examples.keys.cast<String>()) {
        final values = departure.examples[name]['responses'] as List;
        if (!values.any((v) => v['data']['outcome'] == 'applied')) continue;
        final p = departure.preview(departure.context(name));
        final e = DepartureAckEvidence(
          jsonDecode(jsonEncode(DepartureAckEvidence.fromPreview(p).wire)),
        );
        final ack = departure.ack(name);
        validateDepartureEvidenceResult(ack, e, ack['data']['command_id']);
      }
    },
  );
}
