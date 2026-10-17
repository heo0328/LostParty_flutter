import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/repositories/scoped_character_cache_repository.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';

import '../../../support/server_account_read_fakes.dart';

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherMember = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account = '44444444-4444-4444-8444-444444444444';
const otherAccount = '77777777-7777-4777-8777-777777777777';
const otherRegistration = '88888888-8888-4888-8888-888888888888';

CacheRegistrationSnapshot reg({
  String id = registrationId,
  String? aid = account,
  int version = 1,
  int? owner = 1,
  int roster = 2,
  int settings = 1,
  bool main = true,
  String ownership = 'owned',
}) => CacheRegistrationSnapshot(
  registrationId: id,
  accountId: aid,
  version: version,
  isMain: main,
  label: 'fixture',
  ownershipStatus: ownership,
  ownershipRevision: owner,
  rosterRevision: roster,
  settings: CacheSettings(
    version: settings,
    state: settings == 0 ? 'unconfigured' : 'configured',
    activityIds: settings == 0 ? [] : [characterId],
    representativeId: settings == 0 ? null : characterId,
  ),
  fetchedAt: DateTime.utc(2026, 10, 15),
  sourceContract: 'internal-fixture:s1',
);
CacheCharacterObservation character({
  String id = characterId,
  String aid = account,
  String name = 'same-name',
  int? revision = 1,
  String? state = 'active',
  bool? usable = true,
}) => CacheCharacterObservation(
  characterId: id,
  accountId: aid,
  serverName: 'fixture-server',
  characterName: name,
  lifecycleState: state,
  lifecycleRevision: revision,
  usable: usable,
  blockedReason: usable == true ? null : 'CHARACTER_UNUSABLE',
  profile: {'class': 'fixture-class'},
);
Matcher failure(String code) =>
    throwsA(isA<ScopedCacheException>().having((e) => e.code, 'code', code));

void main() {
  late ScopedAccountCacheDatabase db;
  late ReadSessionFake session;
  late ScopedCharacterCacheRepository repo;
  setUp(() {
    db = ScopedAccountCacheDatabase(NativeDatabase.memory());
    session = ReadSessionFake()..userId = member;
    repo = ScopedCharacterCacheRepository(
      db,
      session,
      baseUrl: 'https://example.test',
    );
  });
  tearDown(() async {
    repo.dispose();
    session.dispose();
    await db.close();
  });
  Future<void> registrations([List<CacheRegistrationSnapshot>? rows]) async =>
      repo.applyRegistrations(await repo.beginRegistrations(), rows ?? [reg()]);
  ScopedRegistrationRef ref([String id = registrationId]) =>
      ScopedRegistrationRef(repo.scope, id);
  Future<CacheValidationReceipt?> roster({
    CacheRegistrationSnapshot? registration,
    List<CacheCharacterObservation>? items,
  }) async {
    final r = registration ?? reg();
    return repo.applyRoster(
      await repo.beginRoster(ref(r.registrationId)),
      CacheRosterSnapshot(r, items ?? [character()]),
    );
  }

  test(
    'environment canonicalization isolates base paths, hosts and members',
    () {
      StorageScope s(String url, [String uid = member]) =>
          StorageScope(baseUrl: url, userId: uid);
      expect(s('HTTPS://EXAMPLE.test:443/'), s('https://example.test'));
      expect(
        s('https://example.test/api'),
        isNot(s('https://example.test/API')),
      );
      expect(
        s('https://example.test/api/'),
        isNot(s('https://example.test/api')),
      );
      expect(s('https://example.test/api'), isNot(s('https://example.test')));
      expect(
        s('https://example.test', otherMember),
        isNot(s('https://example.test')),
      );
      for (final url in [
        'http://example.test',
        'file:///example',
        'https://me@example.test',
        'https://example.test?q=x',
        'https://example.test#x',
      ]) {
        expect(() => s(url), failureSync('INVALID_ENVIRONMENT'));
      }
      expect(
        () => s('https://example.test', 'not-a-uuid'),
        failureSync('INVALID_ID'),
      );
    },
  );

  test('internal snapshots freeze caller-owned lists and nested JSON', () {
    final ids = [characterId];
    final settings = CacheSettings(
      version: 1,
      state: 'configured',
      activityIds: ids,
      representativeId: characterId,
    );
    ids.clear();
    expect(settings.activityIds, [characterId]);
    expect(() => settings.activityIds.clear(), throwsUnsupportedError);
    final payload = <String, dynamic>{
      'nested': <String, dynamic>{'value': 1},
    };
    final row = CacheCharacterObservation(
      characterId: characterId,
      accountId: account,
      serverName: 's',
      characterName: 'n',
      lifecycleState: 'active',
      lifecycleRevision: 1,
      usable: true,
      blockedReason: null,
      profile: payload,
    );
    (payload['nested'] as Map)['value'] = 99;
    expect(row.profileJson, contains('1'));
    expect(row.profileJson, isNot(contains('99')));
  });

  test(
    'new DB has four cache plus four personal tables, FK on and schema3; legacy stays separate',
    () async {
      final legacy = AccountDatabase(NativeDatabase.memory());
      await legacy.createAccount(
        label: 'local',
        isMain: true,
        lookupCharacterName: 'fixture',
      );
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(tables.map((r) => r.read<String>('name')).toSet(), {
        'cache_scopes',
        'cached_account_heads',
        'cached_registrations',
        'cached_characters',
        'scoped_role_records',
        'scoped_role_commands',
        'scoped_setting_records',
        'scoped_setting_commands',
      });
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle())
            .data
            .values
            .single,
        1,
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        3,
      );
      await registrations();
      await roster();
      expect(
        (await legacy.select(legacy.gameAccounts).getSingle()).label,
        'local',
      );
      expect(await legacy.select(legacy.accountCharacters).get(), isEmpty);
      expect(legacy.schemaVersion, 13);
      await legacy.close();
    },
  );

  test(
    'registration-only metadata never grants complete roster receipt',
    () async {
      expect(await repo.readRegistrations(repo.scope), isEmpty);
      expect(
        await db.select(db.cacheScopes).get(),
        isEmpty,
      ); // read-only, no default row
      await registrations();
      final view = (await repo.readRoster(ref()))!;
      expect(view.complete, false);
      expect(view.validated, false);
      expect(view.characters, isEmpty);
      expect(
        (await db.select(db.cachedAccountHeads).getSingle()).snapshotSequence,
        0,
      );
    },
  );

  test(
    'complete ID snapshot requires current runtime receipt; cached bool is not authority',
    () async {
      await registrations();
      final receipt = await roster();
      expect((await repo.readRoster(ref(), receipt: receipt))!.validated, true);
      expect((await repo.readRoster(ref()))!.validated, false);
      final restarted = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: 'https://example.test',
      );
      expect(
        (await restarted.readRoster(ref(), receipt: receipt))!.validated,
        false,
      );
      restarted.dispose();
      await repo.beginRoster(ref());
      expect(
        (await repo.readRoster(ref(), receipt: receipt))!.validated,
        false,
      );
    },
  );

  test(
    'member and environment changes isolate identical IDs without clearing old cache',
    () async {
      await registrations();
      await roster();
      final oldScope = repo.scope;
      session.change(authenticated: true, user: otherMember);
      expect(await repo.readRegistrations(repo.scope), isEmpty);
      await expectLater(
        repo.readRegistrations(oldScope),
        failure('SCOPE_CHANGED'),
      );
      await registrations();
      await roster(items: [character(name: 'other member')]);
      expect(
        (await repo.readRoster(ref()))!.characters.single.characterName,
        'other member',
      );
      repo.changeEnvironment('https://example.test/other-api');
      expect(await repo.readRegistrations(repo.scope), isEmpty);
      await registrations();
      expect(await db.select(db.cacheScopes).get(), hasLength(3));
      session.change(authenticated: true, user: member);
      repo.changeEnvironment('https://example.test');
      expect(
        (await repo.readRoster(ref()))!.characters.single.characterName,
        'same-name',
      );
      expect((await repo.readRoster(ref()))!.validated, false);
    },
  );

  test('same name with new ID never reuses the prior character row', () async {
    await registrations();
    await roster();
    await roster(items: [character(id: secondCharacterId)]);
    final view = (await repo.readRoster(ref()))!;
    expect(view.characters.single.characterId, secondCharacterId);
    expect(await db.select(db.cachedCharacters).get(), hasLength(2));
    final old = await repo.readCharacter(
      ScopedCharacterRef(
        repo.scope,
        accountId: account,
        characterId: characterId,
      ),
    );
    expect(old, isNotNull); // retained observation, not current eligibility
  });

  test(
    'same ID lifecycle revision changes update in place, with no personal tables or auto restoration',
    () async {
      await registrations();
      await roster();
      await roster(
        items: [character(revision: 2, state: 'suspect', usable: false)],
      );
      final view = (await repo.readRoster(ref()))!;
      expect(view.characters.single.lifecycleRevision, 2);
      expect(view.characters.single.usable, false);
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
      await expectLater(
        roster(items: [character(revision: 1)]),
        failure('REVISION_REGRESSION'),
      );
      expect(
        (await repo.readRoster(ref()))!.characters.single.lifecycleState,
        'suspect',
      );
    },
  );

  test('same ID cannot be rewritten as a renamed character', () async {
    await registrations();
    await roster();
    await expectLater(
      roster(items: [character(name: 'new-name')]),
      failure('IDENTITY_CONFLICT'),
    );
    expect(
      (await repo.readRoster(ref()))!.characters.single.characterName,
      'same-name',
    );
  });

  test(
    'a retired ID cannot be reactivated even with a newer revision',
    () async {
      await registrations();
      await roster(
        items: [character(state: 'retired', revision: 2, usable: false)],
      );
      await expectLater(
        roster(items: [character(revision: 3)]),
        failure('IDENTITY_CONFLICT'),
      );
      expect(
        (await repo.readRoster(ref()))!.characters.single.lifecycleState,
        'retired',
      );
    },
  );

  test(
    'V1 unknown lifecycle stays null rather than gaining synthetic active status',
    () async {
      await registrations();
      await roster(
        items: [character(state: null, revision: null, usable: null)],
      );
      final row = (await repo.readRoster(ref()))!.characters.single;
      expect(row.lifecycleRevision, null);
      expect(row.lifecycleState, null);
      expect(row.usable, null);
      expect(
        () => character(state: null, revision: null, usable: true),
        failureSync('INVALID_SNAPSHOT'),
      );
    },
  );

  test(
    'absent character is retained; complete empty observation does not retire it',
    () async {
      await registrations();
      await roster();
      await roster(items: []);
      expect((await repo.readRoster(ref()))!.characters, isEmpty);
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
      final old = await repo.readCharacter(
        ScopedCharacterRef(
          repo.scope,
          accountId: account,
          characterId: characterId,
        ),
      );
      expect(old!.lifecycleState, 'active');
    },
  );

  test(
    'registration omission and main changes retain referenced account data',
    () async {
      await registrations();
      final receipt = await roster();
      await registrations([reg(id: otherRegistration, aid: otherAccount)]);
      expect(await repo.readRoster(ref()), null);
      expect(
        (await repo.readRegistrations(repo.scope)).single.registrationId,
        otherRegistration,
      );
      expect(await db.select(db.cachedRegistrations).get(), hasLength(2));
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
      await expectLater(
        repo.beginRoster(ref()),
        failure('REGISTRATION_NOT_CURRENT'),
      );
      await registrations();
      expect(
        (await repo.readRoster(ref(), receipt: receipt))!.validated,
        false,
      );
    },
  );

  test(
    'preview without canonical ID cannot create characters or a canonical receipt',
    () async {
      final preview = reg(
        aid: null,
        owner: null,
        ownership: 'unverified',
        settings: 0,
        roster: 0,
      );
      await registrations([preview]);
      expect(await roster(registration: preview, items: []), null);
      expect(await db.select(db.cachedAccountHeads).get(), isEmpty);
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
      expect(
        () => CacheRosterSnapshot(preview, [character()]),
        failureSync('INVALID_SNAPSHOT'),
      );
    },
  );

  test(
    'duplicate registration/main/account and character IDs are rejected atomically',
    () async {
      await registrations();
      await expectLater(
        registrations([reg(), reg()]),
        failure('INVALID_SNAPSHOT'),
      );
      await expectLater(
        registrations([reg(), reg(id: otherRegistration, aid: otherAccount)]),
        failure('INVALID_SNAPSHOT'),
      );
      await expectLater(
        registrations([reg(), reg(id: otherRegistration, main: false)]),
        failure('INVALID_SNAPSHOT'),
      );
      expect(
        (await repo.readRegistrations(repo.scope)).single.registrationId,
        registrationId,
      );
      expect(
        () => CacheRosterSnapshot(reg(), [character(), character()]),
        failureSync('INVALID_SNAPSHOT'),
      );
    },
  );

  test(
    'ownership-lost preview observation keeps fresh display data without canonical characters',
    () async {
      final unowned = reg(
        owner: null,
        ownership: 'ownership_lost',
        settings: 0,
      );
      await registrations([unowned]);
      final observed = CacheRegistrationSnapshot.fromStorage({
        ...unowned.toStorage(),
        'display': {'power': '123.00', 'power_stale': false},
      });
      await roster(registration: observed, items: []);
      final view = (await repo.readRoster(ref()))!;
      expect(view.registration.displayJson, contains('123.00'));
      expect(view.registration.displayJson, contains('false'));
      expect(view.registration.ownershipStatus, 'ownership_lost');
      expect(view.characters, isEmpty);
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
    },
  );

  test(
    'character ID cannot be reparented to another canonical account, even after omission',
    () async {
      await registrations([
        reg(),
        reg(id: otherRegistration, aid: otherAccount, main: false),
      ]);
      await roster();
      final next = reg(id: otherRegistration, aid: otherAccount, main: false);
      await expectLater(
        roster(
          registration: next,
          items: [character(aid: otherAccount)],
        ),
        failure('IDENTITY_CONFLICT'),
      );
      final parent = await db.select(db.cachedCharacters).getSingle();
      expect(parent.accountId, account);
      final head = await (db.select(
        db.cachedAccountHeads,
      )..where((t) => t.accountId.equals(otherAccount))).getSingle();
      expect(head.complete, false);
    },
  );

  test('latest read sequence wins; superseded response cannot apply', () async {
    final first = await repo.beginRegistrations();
    final second = await repo.beginRegistrations();
    await expectLater(
      repo.applyRegistrations(first, [reg()]),
      failure('STALE_READ'),
    );
    await repo.applyRegistrations(second, [reg()]);
    final oldRoster = await repo.beginRoster(ref());
    final newerRoster = await repo.beginRoster(ref());
    await expectLater(
      repo.applyRoster(oldRoster, CacheRosterSnapshot(reg(), [character()])),
      failure('STALE_READ'),
    );
    await repo.applyRoster(
      newerRoster,
      CacheRosterSnapshot(reg(), [character()]),
    );
    final obsolete = await repo.beginRoster(ref());
    await repo.beginRegistrations();
    await expectLater(
      repo.applyRoster(obsolete, CacheRosterSnapshot(reg(), [])),
      failure('STALE_READ'),
    );
  });

  test(
    'independent stores with same captured local version cannot overwrite each other',
    () async {
      final second = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: 'https://example.test',
      );
      final stale = await second.beginRegistrations();
      await registrations();
      await expectLater(
        second.applyRegistrations(stale, [reg(version: 2)]),
        failure('CACHE_CONFLICT'),
      );
      expect((await repo.readRegistrations(repo.scope)).single.version, 1);
      second.dispose();
    },
  );

  test(
    'external roster write causes head CAS conflict without partial result',
    () async {
      await registrations();
      final stale = await repo.beginRoster(ref());
      final second = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: 'https://example.test',
      );
      await second.applyRoster(
        await second.beginRoster(ref()),
        CacheRosterSnapshot(reg(), [character(name: 'winner')]),
      );
      await expectLater(
        repo.applyRoster(
          stale,
          CacheRosterSnapshot(reg(), [character(name: 'loser')]),
        ),
        failure('CACHE_CONFLICT'),
      );
      expect(
        (await repo.readRoster(ref()))!.characters.single.characterName,
        'winner',
      );
      second.dispose();
    },
  );

  test(
    'newer registration metadata invalidates receipt without merging partial settings',
    () async {
      await registrations();
      final receipt = await roster();
      await registrations([reg(settings: 2)]);
      final view = (await repo.readRoster(ref(), receipt: receipt))!;
      expect(view.complete, false);
      expect(view.validated, false);
      expect(view.characters, isEmpty);
      await roster(registration: reg(settings: 2));
      expect((await repo.readRoster(ref()))!.registration.settings.version, 2);
    },
  );

  test(
    'revision floors survive ownership-hidden observations and allow settings reset only in new ownership epoch',
    () async {
      await registrations([reg(owner: 5, roster: 9, settings: 7)]);
      await registrations([
        reg(owner: null, roster: 9, settings: 0, ownership: 'ownership_lost'),
      ]);
      await expectLater(
        registrations([reg(owner: 4, roster: 9)]),
        failure('REVISION_REGRESSION'),
      );
      await expectLater(
        registrations([reg(owner: 5, roster: 9, settings: 6)]),
        failure('REVISION_REGRESSION'),
      );
      await registrations([reg(owner: 6, roster: 9, settings: 1)]);
      await roster(registration: reg(owner: 6, roster: 9, settings: 1));
      expect((await repo.readRoster(ref()))!.registration.settings.version, 1);
      await expectLater(
        registrations([reg(owner: 6, roster: 8)]),
        failure('REVISION_REGRESSION'),
      );
    },
  );

  test('snapshot must match captured registration structure', () async {
    await registrations();
    await expectLater(
      roster(registration: reg(roster: 3)),
      failure('SNAPSHOT_MISMATCH'),
    );
    expect(
      (await db.select(db.cachedAccountHeads).getSingle()).complete,
      false,
    );
  });

  test(
    'failure after metadata and first character write rolls back the whole batch',
    () async {
      await registrations();
      await db.customStatement(
        "CREATE TEMP TRIGGER injected_failure BEFORE INSERT ON cached_characters WHEN NEW.character_id = '$secondCharacterId' BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      await expectLater(
        roster(
          items: [
            character(),
            character(id: secondCharacterId),
          ],
        ),
        throwsA(isA<Exception>()),
      );
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
      final head = await db.select(db.cachedAccountHeads).getSingle();
      expect(head.complete, false);
      expect(head.localVersion, 1);
      expect(head.snapshotSequence, 0);
      await db.customStatement('DROP TRIGGER injected_failure');
      await roster();
      expect((await repo.readRoster(ref()))!.complete, true);
    },
  );

  test(
    'composite FK rejects cross-scope account references and restricts parent removal',
    () async {
      await registrations();
      await roster();
      final firstScope = await db.select(db.cacheScopes).getSingle();
      final sid = await db
          .into(db.cacheScopes)
          .insert(
            CacheScopesCompanion.insert(
              environment: 'https://other.test',
              userId: member,
            ),
          );
      await expectLater(
        db
            .into(db.cachedCharacters)
            .insert(
              CachedCharactersCompanion.insert(
                scopeId: sid,
                characterId: characterId,
                accountId: account,
                seenSequence: 1,
                payload: '{}',
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        (db.delete(
          db.cachedAccountHeads,
        )..where((t) => t.scopeId.equals(firstScope.id))).go(),
        throwsA(isA<Exception>()),
      );
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
    },
  );

  for (final user in [member, otherMember]) {
    test(
      'same/different member generation invalidates captured token ($user)',
      () async {
        await registrations();
        final read = await repo.beginRoster(ref());
        session.change(authenticated: true, user: user);
        await expectLater(
          repo.applyRoster(read, CacheRosterSnapshot(reg(), [character()])),
          failure('STALE_READ'),
        );
        expect(await db.select(db.cachedCharacters).get(), isEmpty);
      },
    );
  }

  test(
    'member switch while DB transaction is queued rolls back before commit',
    () async {
      await registrations();
      final read = await repo.beginRoster(ref());
      final held = Completer<void>(), release = Completer<void>();
      final blocker = db.transaction(() async {
        held.complete();
        await release.future;
      });
      await held.future;
      final applying = repo.applyRoster(
        read,
        CacheRosterSnapshot(reg(), [character()]),
      );
      final check = expectLater(applying, failure('STALE_READ'));
      await Future<void>.delayed(Duration.zero);
      session.change(authenticated: true, user: otherMember);
      release.complete();
      await blocker;
      await check;
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
      expect(await repo.readRegistrations(repo.scope), isEmpty);
    },
  );

  test(
    'guest and disposed repositories cannot read, write or resurrect receipts',
    () async {
      await registrations();
      final read = await repo.beginRoster(ref());
      final currentScope = repo.scope;
      session.change(authenticated: false);
      await expectLater(
        repo.readRegistrations(currentScope),
        failure('SCOPE_CHANGED'),
      );
      await expectLater(
        repo.applyRoster(read, CacheRosterSnapshot(reg(), [])),
        failure('STALE_READ'),
      );
      session.change(authenticated: true, user: member);
      final other = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: 'https://example.test',
      );
      final abandoned = await other.beginRoster(ref());
      other.dispose();
      await expectLater(
        other.applyRoster(abandoned, CacheRosterSnapshot(reg(), [])),
        failure('STALE_READ'),
      );
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
    },
  );
}

Matcher failureSync(String code) =>
    throwsA(isA<ScopedCacheException>().having((e) => e.code, 'code', code));
