import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_wire_schema.g.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import '../../support/server_account_read_fakes.dart';
import 'cycle_recruitment_test.dart' as f;
import 'backend_recruitment_test.dart' as b;
import 'membership_readers_test.dart' as records;

const key = '11111111-1111-4111-8111-111111111111';
const otherKey = '22222222-2222-4222-8222-222222222222';
const user = '33333333-3333-4333-8333-333333333333';
const path = '/v2/me/application-message-presets';
const beta = BetaContract(mode: RecruitmentContractMode.betaWire2);
final instant = DateTime.utc(2026, 10, 22, 3);
Map<String, dynamic> ack() => {'version': 1, 'items': [], 'saved_at': null};
RecruitmentCommand command({
  String id = key,
  String body = '{ "expected_version": 1, "items": [] }',
  DateTime? created,
}) => RecruitmentCommand(
  owner: RecruitmentCommandOwner.presets,
  operation: 'beta_application_message_presets_put',
  method: 'PUT',
  path: path,
  query: const {},
  targetCycles: const [],
  rawBody: body,
  key: id,
  createdAt: created ?? instant,
);
void validateAck(Map<String, dynamic> value) {
  ApplicationMessagePresets(value);
}

Map<String, dynamic> schedule() => {
  'policy_version': 'beta-schedule-1',
  'revision': 1,
  'session_id': key,
  'base_starts_at': '2026-10-24T09:00:00Z',
  'base_ends_at': '2026-10-24T10:00:00Z',
  'base_deadline_at': '2026-10-24T08:30:00Z',
  'early_coordination_enabled': false,
  'early_additional_members': null,
  'coordination_state': 'base_committed',
  'coordination_active': false,
  'confirmed_starts_at': null,
  'confirmed_ends_at': null,
  'effective_starts_at': '2026-10-24T09:00:00Z',
  'effective_ends_at': '2026-10-24T10:00:00Z',
  'admission_deadline': '2026-10-24T08:30:00Z',
  'deadline_status': 'not_due',
  'pending_transition': null,
  'review_reason': null,
  'evaluated_at': '2026-10-22T03:00:00Z',
};
BetaScheduleConfig config(String start) => BetaScheduleConfig({
  'base_starts_at': start,
  'early_coordination_enabled': false,
  'early_additional_members': null,
});

class FaultStore implements RecruitmentCommandStore {
  FaultStore(this.inner);
  final RecruitmentCommandStore inner;
  bool failInsert = false, failAttempt = false, failAck = false;
  int writes = 0;
  @override
  Future<RecruitmentCommand?> read(StorageScope s, RecruitmentCommandOwner o) =>
      inner.read(s, o);
  @override
  Future<void> insert(StorageScope s, RecruitmentCommand c) {
    if (failInsert) throw StateError('disk');
    return inner.insert(s, c);
  }

  @override
  Future<void> replace(StorageScope s, RecruitmentCommand c) {
    writes++;
    if (failAttempt && c.state == RecruitmentCommandState.pending ||
        failAck && c.state == RecruitmentCommandState.acknowledged) {
      throw StateError('disk');
    }
    return inner.replace(s, c);
  }

  @override
  Future<void> releaseResolved(
    StorageScope s,
    RecruitmentCommandOwner o,
    String k,
  ) => inner.releaseResolved(s, o, k);
  @override
  Future<void> close() => inner.close();
}

class WireAdapter implements HttpClientAdapter {
  late RequestOptions request;
  String bytes = '';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    bytes = utf8.decode(await requestStream!.expand((v) => v).toList());
    return ResponseBody.fromString(
      jsonEncode(ack()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class JournalSession extends ReadSessionFake {
  void sameIdentityNotification() => notifyListeners();
}

void main() {
  group('closed beta models and explicit profile', () {
    test(
      'all 64 existing operations are profiled; only two preset operations are unprofiled',
      () {
        final wire = jsonDecode(betaWireSchemaJson) as Map<String, dynamic>;
        final operations = wire['operations'] as List;
        var profiles = 0, presets = 0;
        for (final o in operations) {
          final p = (o['path'] as String).replaceAll(RegExp(r'\{[^}]+\}'), key);
          final q = beta.query(o['method'], p);
          if (p == path) {
            expect(q, isEmpty);
            presets++;
          } else {
            expect(q['contract_profile'], BetaContract.profile);
            profiles++;
          }
        }
        expect(profiles, 64);
        expect(presets, 2);
      },
    );
    test(
      'legacy default never adds profile; beta fixed paths only, presets excluded',
      () {
        expect(const BetaContract().query('POST', '/v2/raid-rooms'), isEmpty);
        expect(beta.query('POST', '/v2/raid-rooms'), {
          'contract_profile': BetaContract.profile,
          'group_policy_version': BetaContract.groupPolicyVersion,
        });
        expect(beta.query('GET', path), isEmpty);
        expect(beta.query('PUT', path), isEmpty);
        expect(
          () => beta.query('GET', '/v2/me/personal-play-availability'),
          throwsFormatException,
        );
        expect(
          () => beta.query('GET', path, {
            'contract_profile': BetaContract.profile,
          }),
          throwsFormatException,
        );
        expect(
          () => beta.query('POST', '/v2/raid-rooms', {
            'contract_profile': 'unknown',
          }),
          throwsFormatException,
        );
      },
    );
    test(
      'independent C/N configs; invalid cycle and wrong-week date rejected',
      () {
        final draft = BetaCreationDraft({
          f.c: config('2026-10-24T09:00:00Z'),
          f.n: config('2026-10-30T08:00:00Z'),
        });
        expect(draft.toWire()[1]['base_starts_at'], '2026-10-30T08:00:00Z');
        expect(() => draft.targets.clear(), throwsUnsupportedError);
        expect(
          () => BetaCreationDraft({f.c: config('2026-10-30T08:00:00Z')}),
          throwsFormatException,
        );
        expect(
          () => config('2026-10-24T09:00:00+09:00'),
          throwsFormatException,
        );
        expect(
          () => BetaScheduleConfig({
            ...config('2026-10-24T09:00:00Z').wire,
            'early_additional_members': 2,
          }),
          throwsFormatException,
        );
      },
    );
    test(
      'schedule nullable pairs, deadline and effective relationship stay strict',
      () {
        expect(BetaSchedule(schedule()).state, 'base_committed');
        for (final delta in [
          {'confirmed_starts_at': '2026-10-24T08:00:00Z'},
          {'effective_starts_at': '2026-10-24T08:00:00Z'},
          {'base_deadline_at': '2026-10-24T08:00:00Z'},
          {'coordination_state': 'invented'},
          {'unknown': null},
        ]) {
          expect(
            () => BetaSchedule({...schedule(), ...delta}),
            throwsFormatException,
          );
        }
      },
    );
    test(
      'copy missing is different from unset; strict presets/memo and leading zero identity',
      () {
        expect(
          AvailabilityCopy({
            'state': 'unset',
            'source_personal_version': 1,
            'copied_at': '2026-10-22T03:00:00Z',
          }).unset,
          isTrue,
        );
        expect(() => AvailabilityCopy({}), throwsFormatException);
        expect(
          RecruitmentIdentity({'number': 1, 'password': '00009'}).password,
          '00009',
        );
        expect(
          () => RecruitmentIdentity({'number': 1, 'password': 9}),
          throwsFormatException,
        );
        expect(() => ApplicationMemo('🙂'), throwsFormatException);
        expect(() => ApplicationMemo(' a '), throwsFormatException);
        expect(ApplicationMemo('한글 ㅋㅋ.,!?~()-_/@#&+').text, isNotEmpty);
        expect(
          () => ApplicationMessagePresets({
            'version': 1,
            'items': [
              {'id': key, 'text': 'a'},
              {'id': key, 'text': 'a'},
            ],
            'saved_at': null,
          }),
          throwsFormatException,
        );
      },
    );
    test(
      'normal detail uses beta parser then existing semantic parser, legacy parser remains closed',
      () {
        final json = f.detail(f.c), d = json['data'] as Map<String, dynamic>;
        d['my_membership'] = {
          'membership_id': b.membershipId,
          'revision': 1,
          'group_member': false,
          'target_role': 'leader',
          'cycle_member_id': b.membershipId,
          'cycle_member_revision': 1,
          'joined_order': '1',
        };
        d['permissions'] = {
          'view_detail': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
          'view_plan': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
        };
        d['beta_schedule'] = schedule();
        d['recruitment_identity'] = {'number': 1, 'password': '00009'};
        d['room']['beta_schedule'] = schedule();
        final parsed = BetaResponse.parse(
          method: 'GET',
          path: '/v2/raid-rooms/${b.roomId}/detail',
          status: 200,
          json: json,
          parseLegacy: (j) =>
              BackendRecruitmentRepository.parseCycleDetail(j, b.roomId, f.c),
        );
        expect(
          parsed.metadata['data']['recruitment_identity']['password'],
          '00009',
        );
        expect(
          () => BackendRecruitmentRepository.parseCycleDetail(
            json,
            b.roomId,
            f.c,
          ),
          throwsFormatException,
        );
        d['room']['recruitment_identity'] = d['recruitment_identity'];
        expect(
          () => BetaResponse.parse(
            method: 'GET',
            path: '/v2/raid-rooms/${b.roomId}/detail',
            status: 200,
            json: json,
            parseLegacy: (j) => j,
          ),
          throwsFormatException,
        );
      },
    );
    test(
      'record content null and nullable generation/leader reuse record parser without inventing content',
      () {
        final raw = records.sample('known_generation_null_leader_detail');
        raw['data']['beta_schedule'] = null;
        raw['data']['recruitment_identity'] = null;
        final parsed = BetaResponse.parse(
          method: 'GET',
          path: '/v2/raid-rooms/${b.roomId}/detail',
          status: 200,
          json: raw,
          parseLegacy: (j) => records.parse(j),
        );
        expect(parsed.metadata['data']['content'], isNull);
        raw['data']['recruitment_identity'] = {
          'number': 1,
          'password': '00000',
        };
        expect(
          () => BetaResponse.parse(
            method: 'GET',
            path: '/v2/raid-rooms/${b.roomId}/detail',
            status: 200,
            json: raw,
            parseLegacy: (j) => j,
          ),
          throwsFormatException,
        );
      },
    );
    test('public and pending viewers cannot receive participant identity', () {
      final json = f.detail(f.c), d = json['data'] as Map<String, dynamic>;
      d['permissions'] = {
        'view_detail': {
          'allowed': true,
          'reason': null,
          'next_change_at': null,
        },
        'view_plan': {'allowed': true, 'reason': null, 'next_change_at': null},
      };
      d['beta_schedule'] = null;
      d['room']['beta_schedule'] = null;
      d['my_membership'] = null;
      d['recruitment_identity'] = {'number': 1, 'password': '00000'};
      beta.validateResponse(
        'GET',
        '/v2/raid-rooms/${b.roomId}/detail',
        200,
        json,
      );
      expect(
        () => BetaResponse.parse(
          method: 'GET',
          path: '/v2/raid-rooms/${b.roomId}/detail',
          status: 200,
          json: json,
          parseLegacy: (j) => j,
        ),
        throwsFormatException,
      );
    });
    test('stored command corruption and target/body mismatch are rejected', () {
      expect(
        () => RecruitmentCommand.decode(
          jsonEncode({
            ...command().toJson(),
            'raw_ack': '{}',
            'state': 'acknowledged',
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => RecruitmentCommand.decode(
          jsonEncode({...command().toJson(), 'unknown': null}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecruitmentCommand.decode(
          jsonEncode({...command().toJson(), 'owner': 'invented'}),
        ),
        throwsFormatException,
      );
      expect(
        () => command(
          body: '{"expected_version":1,"items":[],"Authorization":"token"}',
        ),
        throwsFormatException,
      );
    });
    test(
      'application-display memo remains a snapshot; null application is never manufactured',
      () {
        final json = f.detail(f.c), d = json['data'] as Map<String, dynamic>;
        d['my_membership'] = null;
        d['permissions'] = {
          'view_detail': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
          'view_plan': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
        };
        d['beta_schedule'] = null;
        d['room']['beta_schedule'] = null;
        d['recruitment_identity'] = null;
        d['my_application'] = {
          'application_id': key,
          'revision': 1,
          'state': 'pending',
          'expires_at': '2026-10-23T03:00:00Z',
          'application_memo': '잘 부탁드립니다!',
        };
        final parsed = BetaResponse.parse(
          method: 'GET',
          path: '/v2/raid-rooms/${b.roomId}/detail',
          status: 200,
          json: json,
          parseLegacy: (j) =>
              ApplicationDisplayDetail.fromJson(j, b.roomId, f.c),
        );
        expect(parsed.value.application!.pending, isTrue);
        expect(
          parsed.metadata['data']['my_application']['application_memo'],
          '잘 부탁드립니다!',
        );
        d['my_application'] = null;
        expect(
          BetaResponse.parse(
            method: 'GET',
            path: '/v2/raid-rooms/${b.roomId}/detail',
            status: 200,
            json: json,
            parseLegacy: (j) =>
                ApplicationDisplayDetail.fromJson(j, b.roomId, f.c),
          ).value.application,
          isNull,
        );
      },
    );
    test(
      'membership list records preserve distinct old identities with null content',
      () {
        final raw = records.sample('ended_records_page');
        // Source design vectors reuse one CM for three states. Preserve the source;
        // this independent synthetic page gives each historical relation its own CM.
        final items = raw['data']['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final original = items[i]['viewer']['cycle_member_id'] as String;
          final distinct =
              '00000000-0000-4000-8000-${(i + 1000).toString().padLeft(12, '0')}';
          items[i] = jsonDecode(
            jsonEncode(items[i]).replaceAll(original, distinct),
          );
        }
        for (final item in items) {
          item['beta_schedule'] = null;
        }
        final parsed = BetaResponse.parse(
          method: 'GET',
          path: '/v2/me/raid-room-memberships',
          status: 200,
          json: raw,
          parseLegacy: (j) =>
              MembershipReadPage(raw['scope']['target_cycle_key'], j),
        );
        expect(parsed.value.items, isNotEmpty);
        expect(
          parsed.value.items.map((v) => v.identity).toSet().length,
          parsed.value.items.length,
        );
      },
    );
    test(
      'raw input has its own byte limit, separate from normalized stored memo',
      () {
        expect(RawApplicationMemo('한').text, '한');
        expect(
          () => RawApplicationMemo(List.filled(1500, '한').join()),
          throwsFormatException,
        );
        expect(() => ApplicationMemo('메모\n'), throwsFormatException);
      },
    );
  });

  group('durable recruitment journal and explicit transmission', () {
    late ReadSessionFake session;
    late FaultStore store;
    late RecruitmentCommandDatabase db;
    late RecruitmentCommandTransport transport;
    late String environment;
    late DateTime now;
    late int requests;
    late Future<Map<String, dynamic>> Function(RecruitmentCommand) respond;
    StorageScope scope() =>
        StorageScope(baseUrl: environment, userId: session.userId!);
    setUp(() {
      session = JournalSession()..userId = user;
      db = RecruitmentCommandDatabase(NativeDatabase.memory());
      store = FaultStore(
        DriftRecruitmentCommandStore(databaseFactory: () => db),
      );
      environment = 'https://EXAMPLE.com/';
      now = instant;
      requests = 0;
      respond = (c) async => ack();
      transport = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => environment,
        mode: RecruitmentContractMode.betaWire2,
        clock: () => now,
        send: (c, binding) async {
          requests++;
          return respond(c);
        },
      );
    });
    tearDown(() async {
      await transport.dispose();
      await db.close();
      session.dispose();
    });
    test(
      'lazy DI construction opens no database and sends no request',
      () async {
        var opens = 0;
        final unused = DriftRecruitmentCommandStore(
          databaseFactory: () {
            opens++;
            return db;
          },
        );
        await unused.close();
        expect(opens, 0);
        expect(requests, 0);
      },
    );
    test(
      'persist exact original before HTTP, acknowledged before success and no second POST after failed read',
      () async {
        final c = command();
        respond = (sent) async {
          expect((await store.read(scope(), c.owner))!.rawBody, c.rawBody);
          expect(sent.query, isEmpty);
          expect(sent.rawBody, c.rawBody);
          return ack();
        };
        await transport.submit(c, validateAck: validateAck);
        expect(
          (await store.read(scope(), c.owner))!.state,
          RecruitmentCommandState.acknowledged,
        );
        // UI read failing outside the transport does not erase successful ACK.
        await transport.submit(c, validateAck: validateAck);
        expect(requests, 1);
      },
    );
    test(
      'insert and attempted-time storage failures each prohibit HTTP',
      () async {
        store.failInsert = true;
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsStateError,
        );
        expect(requests, 0);
        store.failInsert = false;
        store.failAttempt = true;
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsStateError,
        );
        expect(requests, 0);
      },
    );
    test(
      'unknown result retains exact key/body; explicit retry replays original once',
      () async {
        respond = (c) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        final c = command();
        await expectLater(
          transport.submit(c, validateAck: validateAck),
          throwsA(isA<AccountReadException>()),
        );
        final saved = (await transport.restore(c.owner))!;
        expect(saved.rawBody, c.rawBody);
        expect(saved.key, c.key);
        respond = (sent) async {
          expect(sent.rawBody, c.rawBody);
          expect(sent.key, c.key);
          return ack();
        };
        await transport.submit(saved, validateAck: validateAck);
        expect(requests, 2);
      },
    );
    test(
      'malformed ACK retains request rather than reporting success',
      () async {
        respond = (c) async => {'version': 1};
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsFormatException,
        );
        expect(
          (await transport.restore(RecruitmentCommandOwner.presets))!.state,
          RecruitmentCommandState.pending,
        );
      },
    );
    test(
      'ACK disk failure retries only persistence, never repeats HTTP in same runtime',
      () async {
        store.failAck = true;
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsStateError,
        );
        expect(requests, 1);
        (session as JournalSession).sameIdentityNotification();
        store.failAck = false;
        await transport.submit(command(), validateAck: validateAck);
        expect(requests, 1);
      },
    );
    test(
      'concurrent submit and new key blocked until successful request is explicitly consumed',
      () async {
        final waiting = Completer<Map<String, dynamic>>();
        respond = (c) => waiting.future;
        final first = transport.submit(command(), validateAck: validateAck);
        while (requests == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsA(isA<AccountReadException>()),
        );
        waiting.complete(ack());
        await first;
        await expectLater(
          transport.submit(command(id: otherKey), validateAck: validateAck),
          throwsA(isA<AccountReadException>()),
        );
        await transport.releaseResolved(RecruitmentCommandOwner.presets, key);
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNull,
        );
      },
    );
    test(
      'exact 24h expires, no HTTP, no automatically generated replacement',
      () async {
        now = instant.add(const Duration(hours: 24));
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsA(isA<AccountReadException>()),
        );
        expect(requests, 0);
        expect(
          (await transport.restore(RecruitmentCommandOwner.presets))!.state,
          RecruitmentCommandState.needsReview,
        );
      },
    );
    test(
      'restore and relogin do not send; other account/environment see no original',
      () async {
        await store.insert(scope(), command());
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNotNull,
        );
        expect(requests, 0);
        session.change(authenticated: true, user: otherKey);
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNull,
        );
        session.change(authenticated: true, user: user);
        environment = 'https://other.example.com';
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNull,
        );
        environment = 'https://example.com';
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNotNull,
        );
        expect(requests, 0);
      },
    );
    for (final change in ['member', 'generation', 'environment', 'dispose']) {
      test('late ACK isolated after $change', () async {
        final pending = Completer<Map<String, dynamic>>();
        respond = (c) => pending.future;
        final original = scope();
        final work = transport.submit(command(), validateAck: validateAck);
        while (requests == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        if (change == 'member') {
          session.change(authenticated: true, user: otherKey);
        }
        if (change == 'generation') {
          session.change(authenticated: true, user: user);
        }
        if (change == 'environment') environment = 'https://other.example.com';
        if (change == 'dispose') await transport.dispose();
        pending.complete(ack());
        await expectLater(work, throwsA(isA<AccountReadException>()));
        if (change != 'dispose') {
          expect(
            (await store.read(
              original,
              RecruitmentCommandOwner.presets,
            ))!.state,
            RecruitmentCommandState.pending,
          );
        }
      });
    }
    test('corrupt storage fails closed without network or replacement', () async {
      await db.customStatement(
        'INSERT INTO recruitment_command_rows(environment,user_id,owner,payload) VALUES (?,?,?,?)',
        [scope().environment, scope().userId, 'presets', '{broken'],
      );
      await expectLater(
        transport.restore(RecruitmentCommandOwner.presets),
        throwsFormatException,
      );
      expect(requests, 0);
    });
    test('mode mismatch is rejected before persisting or sending', () async {
      final legacy = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => environment,
        send: (c, b) async {
          requests++;
          return ack();
        },
      );
      await expectLater(
        legacy.submit(command(), validateAck: validateAck),
        throwsA(isA<AccountReadException>()),
      );
      expect(requests, 0);
      expect(await transport.restore(RecruitmentCommandOwner.presets), isNull);
      await legacy.dispose();
    });
    test(
      'failed ACK persistence survives restart and uses the same original request',
      () async {
        store.failAck = true;
        await expectLater(
          transport.submit(command(), validateAck: validateAck),
          throwsStateError,
        );
        final restored = RecruitmentCommand.decode(
          (await store.read(
            scope(),
            RecruitmentCommandOwner.presets,
          ))!.encode(),
        );
        // A fresh owner has no in-memory ACK. The server replays the original key.
        final fresh = RecruitmentCommandTransport(
          store: store,
          session: session,
          baseUrl: () => environment,
          mode: RecruitmentContractMode.betaWire2,
          clock: () => now,
          send: (c, b) async {
            requests++;
            expect(c.key, key);
            return ack();
          },
        );
        store.failAck = false;
        await fresh.submit(restored, validateAck: validateAck);
        expect(requests, 2);
        await fresh.dispose();
      },
    );
    test(
      'pending command cannot be removed, overwritten or have original text replaced',
      () async {
        final c = command();
        await store.insert(scope(), c);
        await expectLater(
          store.releaseResolved(scope(), c.owner, c.key),
          throwsStateError,
        );
        await expectLater(
          store.insert(scope(), command(id: otherKey)),
          throwsA(anything),
        );
        await expectLater(
          store.replace(
            scope(),
            command(body: '{"expected_version":2,"items":[]}'),
          ),
          throwsStateError,
        );
        expect((await store.read(scope(), c.owner))!.rawBody, c.rawBody);
      },
    );
    test('three owner slots remain independent in the same scope', () async {
      final creation = RecruitmentCommand(
        owner: RecruitmentCommandOwner.creation,
        operation: 'contract3_post__v2_raid-rooms',
        method: 'POST',
        path: '/v2/raid-rooms',
        query: const {},
        targetCycles: [f.c],
        rawBody: '{"target_cycle_key":"${f.c}"}',
        key: key,
        createdAt: instant,
        expectedStatus: 201,
        contractMode: RecruitmentContractMode.legacy,
      );
      final participation = RecruitmentCommand(
        owner: RecruitmentCommandOwner.participation,
        operation: 'contract3_post__v2_raid-rooms_room_id_applications',
        method: 'POST',
        path: '/v2/raid-rooms/$key/applications',
        query: const {},
        targetCycles: [f.c],
        rawBody: '{"target_cycle_key":"${f.c}"}',
        key: key,
        createdAt: instant,
        expectedStatus: 201,
        contractMode: RecruitmentContractMode.legacy,
      );
      await store.insert(scope(), creation);
      await store.insert(scope(), participation);
      await store.insert(scope(), command());
      for (final owner in RecruitmentCommandOwner.values) {
        expect(await store.read(scope(), owner), isNotNull);
      }
      expect(requests, 0);
    });
  });

  test(
    'real Dio sender keeps raw bytes and uses current authentication with explicit query',
    () async {
      final session = ReadSessionFake()..userId = user;
      final adapter = WireAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;
      final c = command();
      final sender = DioRecruitmentCommandSender(dio, session);
      await sender.call(c, accountReadScope(session));
      expect(adapter.bytes, c.rawBody);
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.headers['Authorization'], 'Bearer test-access');
      session.access = 'new-access';
      await sender.call(c, accountReadScope(session));
      expect(adapter.request.headers['Authorization'], 'Bearer new-access');
      expect(c.encode(), isNot(contains('test-access')));
      expect(c.encode(), isNot(contains('new-access')));
      dio.close();
      session.dispose();
    },
  );

  test(
    'existing gateway forwards an explicit query without rewriting body/key',
    () async {
      final api = b.Api();
      api.respond = (p, q) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      final gateway = CycleInteractionRepository(
        api: api,
        recruitment: f.CycleGateway(),
      );
      final body = {'target_cycle_key': f.c, 'nullable': null};
      await expectLater(
        gateway.write(
          '/v2/raid-rooms/${b.roomId}/applications',
          key,
          body,
          room: b.roomId,
          target: f.c,
          applicationAck: true,
          query: {'contract_profile': BetaContract.profile},
        ),
        throwsA(isA<AccountReadException>()),
      );
      expect(api.requests.single['query'], {
        'contract_profile': BetaContract.profile,
      });
      expect(api.requests.single['body'], body);
      expect(api.requests.single['key'], key);
    },
  );

  test(
    'file database survives app restart, original null/absent/string/array and query remain exact',
    () async {
      final dir = await Directory.systemTemp.createTemp('recruitment-journal');
      final file = File('${dir.path}/commands.sqlite');
      final scope = StorageScope(baseUrl: 'https://example.com', userId: user);
      final raw =
          '{ "target_cycle_key":"2026-10-21", "nullable": null, "array":[2,1], "text":"  한  " }';
      final c = RecruitmentCommand(
        owner: RecruitmentCommandOwner.participation,
        operation: 'contract3_post__v2_raid-rooms_room_id_applications',
        method: 'POST',
        path: '/v2/raid-rooms/$key/applications',
        query: {'target_cycle_key': '2026-10-21'},
        targetCycles: ['2026-10-21'],
        rawBody: raw,
        key: key,
        createdAt: instant,
        contractMode: RecruitmentContractMode.legacy,
        expectedStatus: 201,
      );
      var store = DriftRecruitmentCommandStore(
        databaseFactory: () => RecruitmentCommandDatabase(NativeDatabase(file)),
      );
      try {
        await store.insert(scope, c);
        await store.close();
        store = DriftRecruitmentCommandStore(
          databaseFactory: () =>
              RecruitmentCommandDatabase(NativeDatabase(file)),
        );
        final saved = (await store.read(scope, c.owner))!;
        expect(saved.rawBody, raw);
        expect(saved.rawQuery, c.rawQuery);
        expect(saved.key, key);
        expect(jsonDecode(saved.rawBody).containsKey('absent'), isFalse);
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
