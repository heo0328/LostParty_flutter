import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/repositories/scoped_character_cache_repository.dart';
import 'package:lost_party/features/account/data/account_bootstrap.dart';
import 'package:lost_party/features/account/domain/server_character_lifecycle.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/recruitment_list/data/roster_participation.dart';
import 'package:lost_party/features/recruitment_list/data/admission_candidates.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/roster_issue_controller.dart';
import '../../support/server_account_read_fakes.dart';

final examples =
    (jsonDecode(
              File(
                'test/fixtures/roster_participation.json',
              ).readAsStringSync(),
            )
            as Map)['examples']
        as Map;
Map<String, dynamic> clone(Object raw) => jsonDecode(jsonEncode(raw));
Map<String, dynamic> response(String name) => clone(examples[name]['response']);
Map<String, dynamic> summary({bool warning = false}) {
  final raw = response('own_summary_normal_zero');
  if (warning) {
    raw['has_issues'] = true;
    raw['affected_room_count'] = 1;
    raw['affected_target_count'] = 1;
    raw['cycles'][0]['has_issues'] = true;
    raw['cycles'][0]['affected_room_count'] = 1;
  }
  return raw;
}

class QueueApi implements BackendRegistrationApi {
  final pending = <Completer<Map<String, dynamic>?>>[];
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) {
    expect(path, '/v2/me/raid-room-character-issues');
    final c = Completer<Map<String, dynamic>?>();
    pending.add(c);
    return c.future;
  }
}

class FixtureApi implements BackendRegistrationApi {
  FixtureApi(this.value);
  Map<String, dynamic> value;
  Map<String, dynamic>? lastQuery;
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    lastQuery = query;
    return clone(value);
  }
}

Future<void> turn() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'live read opt-ins validate full envelope, retain metadata and reject silently missing warning data',
    () async {
      final raw = response('full_new_beta_detail_both_opt_ins');
      final member = raw['participation_context']['members'][0];
      final path = '/v2/raid-rooms/${member['room_id']}/detail';
      final api = FixtureApi(raw);
      Future<dynamic> read() => readRecruitment(
        api: api,
        mode: RecruitmentContractMode.betaWire2,
        path: path,
        query: {
          'target_cycle_key': raw['scope']['target_cycle_key'],
          'reader_profile': 'membership-actions-1',
          'include_character_issues': 'true',
        },
        parse: (j) {
          expect(j.keys.toSet(), {'scope', 'data'});
          return j;
        },
      );
      final decoded = await read();
      expect(api.lastQuery!['participation_profile'], 'remaining-active-1');
      expect(decoded.metadata['character_issue_context'], isNotNull);
      expect(decoded.metadata['participation_context'], isNotNull);
      api.value = clone(raw)..remove('character_issue_context');
      await expectLater(read(), throwsFormatException);
    },
  );
  test(
    'cache preserves the raw missing character and same-scope omitted presence, invalidates changed roster scope',
    () async {
      final raw = response('characters_presence_same_scope');
      raw['items'][0]['roster_presence'] = {
        'state': 'missing',
        'observed_at': raw['server_fetched_at'],
      };
      final page = LifecycleCharacterPage.fromJson(raw, includePresence: true);
      final session = ReadSessionFake()
        ..userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final db = ScopedAccountCacheDatabase(NativeDatabase.memory());
      final cache = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: 'https://example.test',
      );
      addTearDown(() async {
        cache.dispose();
        await db.close();
        session.dispose();
      });
      var reg = page.registration('test');
      await cache.applyRegistrations(await cache.beginRegistrations(), [reg]);
      final ref = ScopedRegistrationRef(cache.scope, reg.registrationId);
      final c = page.items.first;
      CacheCharacterObservation row({bool presence = true}) =>
          CacheCharacterObservation(
            characterId: c.characterId!,
            accountId: page.accountId!,
            serverName: c.serverName,
            characterName: c.characterName,
            lifecycleState: c.lifecycleState,
            lifecycleRevision: c.lifecycleRevision,
            usable: c.usable,
            blockedReason: c.blockedReason,
            profile: c.wire,
            rosterPresence: presence ? c.presence : null,
          );
      await cache.applyRoster(
        await cache.beginRoster(ref),
        CacheRosterSnapshot(reg, [row()]),
      );
      await cache.applyRoster(
        await cache.beginRoster(ref),
        CacheRosterSnapshot(reg, [row(presence: false)]),
      );
      var view = await cache.readRoster(ref);
      expect(view!.characters.single.rosterPresence!.missing, isTrue);
      expect(view.characters.single.characterId, c.characterId);
      final changed = clone(reg.toStorage());
      changed['rosterRevision']++;
      reg = CacheRegistrationSnapshot.fromStorage(changed);
      await cache.applyRegistrations(await cache.beginRegistrations(), [reg]);
      await cache.applyRoster(
        await cache.beginRoster(ref),
        CacheRosterSnapshot(reg, [row(presence: false)]),
      );
      view = await cache.readRoster(ref);
      expect(view!.characters.single.rosterPresence, isNull);
      expect(view.characters.single.characterId, c.characterId);
    },
  );
  test(
    'reviewed full wire responses validate before metadata is separated',
    () {
      const contract = BetaContract(mode: RecruitmentContractMode.betaWire2);
      for (final key in [
        'full_new_beta_detail_both_opt_ins',
        'full_new_beta_character_preview',
        'full_new_candidates_empty_but_exact_actor',
      ]) {
        final example = examples[key];
        final raw = response(key);
        final p = raw['participation_context'];
        final actor = p['actor'] ?? p['members'][0];
        final path = (example['path'] as String).replaceAll(
          '{room_id}',
          actor['room_id'],
        );
        contract.validateResponse('GET', path, 200, raw);
        validateRosterEnvelope(raw);
      }
    },
  );
  test(
    'opposite week without permission remains null and cannot display issues',
    () {
      final raw = response('room_other_member_missing_opposite_unauthorized');
      final context = RosterIssueRoom(raw);
      final hidden = (context.wire['target_summaries'] as List).firstWhere(
        (s) => s['state'] == 'not_authorized',
      );
      expect(
        context.affectedCycles,
        isNot(contains(hidden['target_cycle_key'])),
      );
      final invalid = clone(context.wire);
      invalid['target_summaries'].firstWhere(
        (s) => s['state'] == 'not_authorized',
      )['has_issues'] = false;
      expect(() => RosterIssueRoom(invalid), throwsFormatException);
      expect(context.items.every((i) => i.registration == null), isTrue);
    },
  );
  test(
    'candidate M, preview M, preserved P and current character stay separate',
    () {
      final candidate = response('full_new_candidates_empty_but_exact_actor');
      final member = RosterParticipationContext(
        candidate['participation_context'],
      ).members.single;
      final bare = clone(candidate)..remove('participation_context');
      final page = AdmissionCandidatePage(
        bare,
        room: bare['data']['room_id'],
        target: bare['scope']['target_cycle_key'],
        intent: 'change_character',
      );
      member.matchActor(page.actor!.wire);
      final preview = response('full_new_beta_character_preview');
      final next = RosterParticipationContext(
        preview['participation_context'],
      ).members.single;
      expect(next.binding, member.binding);
      expect(member.active, isNotEmpty);
      expect(member.preserved, isNotEmpty);
      final allRows = <Map<String, dynamic>>[
        ...member.active.map(clone),
        ...member.preserved.map(clone),
      ];
      for (final row in allRows) {
        row.remove('party_no');
        row.remove('slot_no');
      }
      final bodyAssignments = remainingAssignmentCas(allRows, member);
      expect(
        bodyAssignments.map((a) => a['assignment_id']).toSet(),
        member.active.map((a) => a['assignment_id']).toSet(),
      );
      allRows.first['revision']++;
      expect(
        () => remainingAssignmentCas(allRows, member),
        throwsFormatException,
      );
      final wrong = clone(page.actor!.wire);
      wrong['assignments'] = [...wrong['assignments'], member.preserved.first];
      expect(() => member.matchActor(wrong), throwsFormatException);
      final ended = clone(member.wire)..['active_assignments'] = [];
      ended['current_character'] = null;
      expect(RosterParticipationMember(ended).current, isNull);
      ended['current_character'] = member.current;
      expect(() => RosterParticipationMember(ended), throwsFormatException);
    },
  );
  test(
    'presence travels through bootstrap and characters into an independent cache field',
    () {
      final bootstrap = AccountBootstrap.fromJson(
        response('bootstrap_presence_in_same_character_dto'),
        includePresence: true,
      );
      final page = LifecycleCharacterPage.fromJson(
        response('characters_presence_same_scope'),
        includePresence: true,
      );
      expect(
        bootstrap.registrations.first.characters.presenceRevision,
        page.presenceRevision,
      );
      final observed = response('characters_presence_same_scope');
      observed['items'][0]['roster_presence'] = {
        'state': 'missing',
        'observed_at': observed['server_fetched_at'],
      };
      final missing = LifecycleCharacterPage.fromJson(
        observed,
        includePresence: true,
      ).items.first;
      final row = CacheCharacterObservation(
        characterId: missing.characterId!,
        accountId: page.accountId!,
        serverName: missing.serverName,
        characterName: missing.characterName,
        lifecycleState: missing.lifecycleState,
        lifecycleRevision: missing.lifecycleRevision,
        usable: missing.usable,
        blockedReason: missing.blockedReason,
        profile: missing.wire,
        rosterPresence: missing.presence,
      );
      final restored = CacheCharacterObservation.fromStorage(
        clone(row.toStorage()),
      );
      expect(restored.rosterPresence!.missing, isTrue);
      expect(restored.characterId, missing.characterId);
      expect(jsonDecode(restored.profileJson), missing.wire);
      final legacy = clone(row.toStorage())..remove('rosterPresence');
      expect(
        CacheCharacterObservation.fromStorage(legacy).rosterPresence,
        isNull,
      );
      final wrong = response('characters_presence_same_scope');
      wrong['roster_presence_scope']['roster_revision']++;
      expect(
        () => LifecycleCharacterPage.fromJson(wrong, includePresence: true),
        throwsFormatException,
      );
    },
  );
  test(
    'new profiles are limited to supported fresh requests; original query is unchanged',
    () {
      const current = BetaContract(mode: RecruitmentContractMode.betaWire2);
      const original = BetaContract(
        mode: RecruitmentContractMode.betaWire2,
        original: true,
      );
      const path =
          '/v2/raid-rooms/11111111-1111-4111-8111-111111111111/character-changes';
      expect(
        current.query('POST', path)['participation_profile'],
        'remaining-active-1',
      );
      expect(
        original.query('POST', path).containsKey('participation_profile'),
        isFalse,
      );
      expect(
        current.query('GET', '/v2/me/application-message-presets'),
        isEmpty,
      );
      expect(
        definiteRecruitmentRejection(409, 'CHARACTER_SELECTION_REQUIRED'),
        isTrue,
      );
      expect(
        definiteRecruitmentRejection(503, 'CHARACTER_SELECTION_REQUIRED'),
        isFalse,
      );
    },
  );
  test(
    'summary preserves a warning on failure and rejects late previous-member responses',
    () async {
      final api = QueueApi(),
          session = ReadSessionFake()
            ..userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final changes = ChangeNotifier();
      var scope = 'a';
      final controller = RosterIssueController(
        api: api,
        session: session,
        scopeKey: () => scope,
        changes: changes,
      );
      addTearDown(() {
        controller.dispose();
        changes.dispose();
        session.dispose();
      });
      api.pending[0].complete(summary(warning: true));
      await turn();
      expect(controller.hasIssues, isTrue);
      final failed = controller.refresh();
      api.pending[1].completeError(StateError('offline'));
      await failed;
      expect(controller.hasIssues, isTrue);
      expect(controller.failure, isNotNull);
      final old = controller.refresh();
      scope = 'b';
      changes.notifyListeners();
      api.pending[2].complete(summary(warning: true));
      await old;
      expect(controller.value, isNull);
      api.pending[3].complete(summary());
      await turn();
      expect(controller.value!.hasIssues, isFalse);
    },
  );
  test(
    'mutation during a shared read schedules a fresh read and discards pre-command zero',
    () async {
      final api = QueueApi(),
          session = ReadSessionFake()
            ..userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final changes = ChangeNotifier();
      final controller = RosterIssueController(
        api: api,
        session: session,
        scopeKey: () => 'a',
        changes: changes,
      );
      addTearDown(() {
        controller.dispose();
        changes.dispose();
        session.dispose();
      });
      final f = controller.refresh();
      expect(api.pending.length, 1);
      controller.invalidate();
      api.pending[0].complete(summary());
      await turn();
      expect(controller.value, isNull);
      expect(api.pending.length, 2);
      api.pending[1].complete(summary(warning: true));
      await f;
      expect(controller.hasIssues, isTrue);
    },
  );
}
