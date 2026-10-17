import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/personal_settings_client.dart';
import 'package:lost_party/features/account/data/repositories/scoped_character_cache_repository.dart';
import 'package:lost_party/features/account/data/repositories/scoped_settings_repository.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/scoped_settings_sync.dart';
import 'package:lost_party/features/account/data/server_character_lifecycle_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/personal_settings.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/services/scoped_account_presentation.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart' as wire show item, roster;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account = '44444444-4444-4444-8444-444444444444';
const newRegistration = '99999999-9999-4999-8999-999999999999';
Map<String, dynamic> defaults() => {
  'version': 1,
  'preferred_role': null,
  'visible': true,
  'display_order': null,
  'saved_at': null,
};
Map<String, dynamic> emptyRole() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
};
Matcher cacheError(String code) =>
    throwsA(isA<ScopedCacheException>().having((e) => e.code, 'code', code));

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late ScopedAccountCacheDatabase db;
  late ScopedCharacterCacheRepository cache;
  late ScopedSettingsRepository store;
  late ScopedSettingsSync sync;
  late Directory temp;
  late File file;
  late List<RequestOptions> calls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  late DateTime clock;
  late Map<String, Map<String, dynamic>> preferences, replays;
  late Map<String, dynamic> presentation;
  String activeRegistration = registrationId, lifecycle = 'active';
  int registrationVersion = 1, owner = 1, life = 1;
  bool registered = true;
  Map<String, dynamic> profile(String id) => {
    'character_id': id,
    'game_account_id': account,
    'ownership_revision': owner,
    'lifecycle_revision': life,
    'lifecycle_state': lifecycle,
    'dealer': emptyRole(),
    'support': emptyRole(),
    'preferences': preferences[id] ?? defaults(),
  };
  Map<String, dynamic> countProfile() => {
    'registration_id': activeRegistration,
    'game_account_id': account,
    'registration_version': registrationVersion,
    'ownership_revision': owner,
    ...presentation,
  };
  DioException failure(
    RequestOptions r, {
    int status = 503,
    String code = 'SERVICE_UNAVAILABLE',
    int? seconds,
  }) => DioException.badResponse(
    statusCode: status,
    requestOptions: r,
    response: Response(
      requestOptions: r,
      statusCode: status,
      data: {
        'error': {
          'code': code,
          'request_id': 'settings-test',
          'retry_after_seconds': ?seconds,
        },
      },
    ),
  );
  Map<String, dynamic> backend(RequestOptions r) {
    if (r.path == '/v1/me/game-accounts') {
      return {
        'items': registered
            ? [
                {
                  ...registrationJson(),
                  'registration_id': activeRegistration,
                  'version': registrationVersion,
                  'ownership_revision': owner,
                  'settings': {...settingsJson(), 'ownership_revision': owner},
                },
              ]
            : [],
        'next_cursor': null,
      };
    }
    if (r.path.endsWith('/characters')) {
      return {
        ...wire.roster(
          items: [
            {
              ...wire.item(),
              'lifecycle_state': lifecycle,
              'lifecycle_revision': life,
              'usable': lifecycle == 'active',
              'blocked_reason': lifecycle == 'active'
                  ? null
                  : 'CHARACTER_UNUSABLE',
            },
            {...wire.item(id: secondCharacterId, name: 'second')},
          ],
        ),
        'registration_id': activeRegistration,
        'registration_version': registrationVersion,
        'ownership_revision': owner,
        'settings': {...settingsJson(), 'ownership_revision': owner},
      };
    }
    if (r.path.endsWith('/personal-profile')) {
      return profile(r.path.split('/')[4]);
    }
    if (r.method == 'GET' && r.path.endsWith('/presentation-settings')) {
      return countProfile();
    }
    if (r.method == 'PUT') {
      final key = r.headers['Idempotency-Key'] as String;
      if (replays[key] case final previous?) return previous;
      final b = r.data as Map<String, dynamic>;
      final isPrefs = r.path.endsWith('/personal-preferences');
      final id = r.path.split('/')[4];
      final old = isPrefs ? preferences[id] ?? defaults() : presentation;
      if (b['expected_version'] != old['version']) {
        throw failure(r, status: 409, code: 'REVISION_CONFLICT');
      }
      final values = isPrefs
          ? {
              for (final k in ['preferred_role', 'visible', 'display_order'])
                k: b[k],
            }
          : {'visible_count': b['visible_count']};
      final oldValues = isPrefs
          ? PreferenceValues.fromJson({
              for (final k in ['preferred_role', 'visible', 'display_order'])
                k: old[k],
            }).toJson()
          : {'visible_count': old['visible_count']};
      final same = jsonEncode(values) == jsonEncode(oldValues);
      final stored = {
        'version': (old['version'] as int) + (same ? 0 : 1),
        ...values,
        'saved_at': same ? old['saved_at'] : clock.toIso8601String(),
      };
      if (isPrefs) {
        preferences[id] = stored;
        return replays[key] = {
          ...stored,
          'character_id': id,
          'ownership_revision': owner,
          'lifecycle_revision': life,
        };
      }
      presentation = stored;
      return replays[key] = countProfile();
    }
    throw StateError('Unexpected request ${r.path}');
  }

  void connect() {
    db = ScopedAccountCacheDatabase(NativeDatabase(file));
    cache = ScopedCharacterCacheRepository(
      db,
      session,
      baseUrl: dio.options.baseUrl,
    );
    store = ScopedSettingsRepository(cache);
    sync = ScopedSettingsSync(
      PersonalSettingsClient(api),
      store,
      now: () => clock,
    );
  }

  ScopedRegistrationRef reg([String? id]) =>
      ScopedRegistrationRef(cache.scope, id ?? activeRegistration);
  ScopedCharacterRef character([String id = characterId]) =>
      ScopedCharacterRef(cache.scope, accountId: account, characterId: id);
  Future<void> seed({bool roster = true}) async {
    final c = ServerCharacterLifecycleClient(api);
    try {
      await c.refreshRegistrations(cache);
      if (roster) await c.refreshRoster(cache, reg());
    } finally {
      c.dispose();
    }
  }

  Future<ScopedSettingsPlan> prepare({bool count = false}) =>
      sync.prepare(reg(), character: count ? null : character());
  Future<ScopedSettingsState> edit({
    bool count = false,
    int limit = 8,
    int rank = 0,
  }) async => store.save(
    await prepare(count: count),
    count
        ? {'visible_count': limit}
        : PreferenceValues(
            preferredRole: CharacterBuildRole.support,
            displayOrder: rank,
            visible: false,
          ).toJson(),
  );
  Iterable<RequestOptions> puts() => calls.where((c) => c.method == 'PUT');

  setUp(() async {
    session = ReadSessionFake()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    api = DioBackendAccountReadApi(dio, session);
    calls = [];
    clock = DateTime.utc(2026, 10, 16);
    activeRegistration = registrationId;
    lifecycle = 'active';
    registrationVersion = 1;
    owner = 1;
    life = 1;
    registered = true;
    preferences = {};
    replays = {};
    presentation = {'version': 1, 'visible_count': 6, 'saved_at': null};
    respond = backend;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          calls.add(r);
          try {
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: await respond(r),
              ),
            );
          } on DioException catch (e) {
            h.reject(e);
          } catch (e) {
            h.reject(DioException(requestOptions: r, error: e));
          }
        },
      ),
    );
    temp = await Directory.systemTemp.createTemp('lost-party-settings-');
    file = File('${temp.path}/cache.sqlite');
    connect();
    await seed();
    calls.clear();
  });
  tearDown(() async {
    store.dispose();
    cache.dispose();
    await db.close();
    dio.close();
    session.dispose();
    final resolved = temp.absolute.path;
    expect(
      resolved.startsWith(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}lost-party-settings-',
      ),
      isTrue,
    );
    await temp.delete(recursive: true);
  });

  for (final invalid in <String, Map<String, dynamic>>{
    'non-bool visible': {...defaults(), 'visible': 1},
    'floating rank': {...defaults(), 'display_order': 1.0},
    'negative rank': {...defaults(), 'display_order': -1},
    'overflow rank': {...defaults(), 'display_order': 2147483648},
    'unknown role': {...defaults(), 'preferred_role': 'tank'},
    'missing field': {...defaults()}..remove('visible'),
    'extra raw': {...defaults(), 'raw': {}},
    'stored null time': {...defaults(), 'version': 2},
    'default with custom value': {...defaults(), 'visible': false},
    'non-UTC time': {
      ...defaults(),
      'version': 2,
      'saved_at': '2026-10-16T09:00:00+09:00',
    },
  }.entries) {
    test(
      'strict preferences rejects ${invalid.key}',
      () => expect(
        () => PersonalPreferences.fromJson(invalid.value),
        throwsFormatException,
      ),
    );
  }
  for (final invalid in [0, 201, 1.0, null, true]) {
    test(
      'strict count rejects $invalid (${invalid.runtimeType})',
      () => expect(() => presentationCount(invalid), throwsFormatException),
    );
  }
  test(
    'default no-op ACK keeps version1/null and GET never creates pending',
    () async {
      final p = await prepare();
      expect((await store.read(p)).hasPending, isFalse);
      await store.save(p, PreferenceValues().toJson());
      final result = await sync.sync(reg(), character: character());
      expect(result.state!.server['version'], 1);
      expect(result.state!.server['saved_at'], isNull);
      expect(result.state!.hasPending, isFalse);
      expect(await db.select(db.scopedRoleRecords).get(), isEmpty);
    },
  );
  test(
    'confirmed setting restore without raw overwrites no role or activity data',
    () async {
      preferences[characterId] = {
        'version': 3,
        'preferred_role': 'support',
        'visible': false,
        'display_order': 4,
        'saved_at': clock.toIso8601String(),
      };
      final p = await prepare(), s = await store.read(p);
      expect(s.preferences.preferredRole, CharacterBuildRole.support);
      expect(s.preferences.visible, isFalse);
      expect(s.hasPending, isFalse);
      expect(await db.select(db.scopedSettingCommands).get(), isEmpty);
      expect(
        (await cache.readRoster(reg()))!.registration.settings.activityIds,
        [characterId],
      );
      expect(await db.select(db.scopedRoleRecords).get(), isEmpty);
    },
  );
  test(
    'local pending before network and ACK is per-character, not whole ranking',
    () async {
      final first = await edit(rank: 0);
      final second = await sync.prepare(
        reg(),
        character: character(secondCharacterId),
      );
      await store.save(second, PreferenceValues(displayOrder: 0).toJson());
      expect(first.hasPending, isTrue);
      expect(puts(), isEmpty);
      final result = await sync.sync(reg(), character: character());
      expect(result.state!.hasPending, isFalse);
      expect(
        (await store.read(
          await sync.prepare(reg(), character: character(secondCharacterId)),
        )).hasPending,
        isTrue,
      );
      expect(await db.select(db.scopedSettingCommands).get(), hasLength(1));
    },
  );
  test(
    'count preparation and save need metadata only, including non-main account',
    () async {
      store.dispose();
      cache.dispose();
      await db.close();
      file = File('${temp.path}/metadata.sqlite');
      connect();
      respond = (r) {
        final data = backend(r);
        if (r.path == '/v1/me/game-accounts') {
          (data['items'] as List).single['is_main'] = false;
        }
        return data;
      };
      await seed(roster: false);
      calls.clear();
      expect((await cache.readRoster(reg()))!.complete, isFalse);
      await edit(count: true, limit: 200);
      final result = await sync.sync(reg());
      expect(result.state!.visibleCount, 200);
      expect(result.state!.hasPending, isFalse);
      expect(calls.any((r) => r.path.endsWith('/characters')), isFalse);
    },
  );
  test(
    'suspect preserves preferences but does not permit edits; count remains editable',
    () async {
      lifecycle = 'suspect';
      life = 2;
      await seed();
      final p = await prepare();
      expect((await store.read(p)).preferences.visible, isTrue);
      await expectLater(
        store.save(p, PreferenceValues(visible: false).toJson()),
        cacheError('CHARACTER_UNUSABLE'),
      );
      await edit(count: true);
      expect((await sync.sync(reg())).state!.hasPending, isFalse);
    },
  );
  test('SQL failure rolls back settings draft and outbox together', () async {
    final p = await prepare();
    await db.customStatement(
      "CREATE TRIGGER settings_fail BEFORE INSERT ON scoped_setting_commands BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    await expectLater(
      store.save(p, PreferenceValues(visible: false).toJson()),
      throwsA(anything),
    );
    final state = await store.read(p);
    expect(state.hasPending, isFalse);
    expect(state.preferences.visible, isTrue);
    expect(state.command, isNull);
  });
  test(
    'captured guard checked inside commit rolls back cancellation',
    () async {
      var valid = true;
      final p = await sync.prepare(
        reg(),
        character: character(),
        guard: () => cacheRequire(valid, 'KEY_CHANGED'),
      );
      valid = false;
      await expectLater(
        store.save(p, PreferenceValues(visible: false).toJson()),
        cacheError('KEY_CHANGED'),
      );
      expect((await store.read(await prepare())).hasPending, isFalse);
    },
  );
  test('same plan competing writes use row CAS', () async {
    final p = await prepare();
    await store.save(p, PreferenceValues(visible: false).toJson());
    await expectLater(
      store.save(p, PreferenceValues(displayOrder: 4).toJson()),
      cacheError('CACHE_CONFLICT'),
    );
  });
  test('lost response and process restart replay original key/body', () async {
    await edit();
    var drop = true;
    respond = (r) {
      final result = backend(r);
      if (r.method == 'PUT' && drop) {
        drop = false;
        throw failure(r);
      }
      return result;
    };
    await sync.sync(reg(), character: character());
    final first = puts().single, body = jsonEncode(puts().single.data);
    store.dispose();
    cache.dispose();
    await db.close();
    connect();
    final result = await sync.sync(reg(), character: character());
    expect(result.state!.hasPending, isFalse);
    expect(
      puts().last.headers['Idempotency-Key'],
      first.headers['Idempotency-Key'],
    );
    expect(jsonEncode(puts().last.data), body);
  });
  test(
    'Retry-After deadline is fixed at receipt and cannot be shortened by reads',
    () async {
      await edit();
      respond = (r) {
        if (r.method == 'PUT') {
          clock = clock.add(const Duration(seconds: 5));
          throw failure(r, status: 429, code: 'RATE_LIMITED', seconds: 10);
        }
        return backend(r);
      };
      final result = await sync.sync(reg(), character: character());
      final deadline = result.state!.command!.retryAt;
      expect(deadline, clock.add(const Duration(seconds: 10)));
      clock = clock.add(const Duration(seconds: 9));
      await sync.sync(reg(), character: character());
      expect(puts(), hasLength(1));
      expect((await store.read(await prepare())).command!.retryAt, deadline);
      clock = clock.add(const Duration(seconds: 1));
      respond = backend;
      expect(
        (await sync.sync(reg(), character: character())).state!.hasPending,
        isFalse,
      );
    },
  );
  test(
    '24-hour first-send expiry stops replay until explicit fresh server selection',
    () async {
      await edit();
      respond = (r) {
        if (r.method == 'PUT') throw failure(r);
        return backend(r);
      };
      await sync.sync(reg(), character: character());
      clock = clock.add(const Duration(hours: 24));
      final result = await sync.sync(reg(), character: character());
      expect(result.state!.command!.state, 'review');
      expect(puts(), hasLength(1));
      final state = await sync.useServer(reg(), character: character());
      expect(state.hasPending, isFalse);
      expect(state.preferences.visible, isTrue);
    },
  );
  test(
    'another device version blocks unsent edit without auto-rebase',
    () async {
      await edit();
      preferences[characterId] = {
        'version': 2,
        'preferred_role': null,
        'visible': true,
        'display_order': 7,
        'saved_at': clock.toIso8601String(),
      };
      final r = await sync.sync(reg(), character: character());
      expect(r.state!.command!.state, 'conflict');
      expect(r.state!.preferences.visible, isFalse);
      expect(puts(), isEmpty);
      expect(
        (await sync.useServer(
          reg(),
          character: character(),
        )).preferences.displayOrder,
        7,
      );
    },
  );
  test(
    'late ACK confirms only old edit while newer local preference remains pending',
    () async {
      await edit(rank: 1);
      final entered = Completer<void>(), release = Completer<void>();
      respond = (r) async {
        if (r.method == 'PUT') {
          entered.complete();
          await release.future;
        }
        return backend(r);
      };
      final flight = sync.sync(reg(), character: character());
      await entered.future;
      await edit(rank: 2);
      release.complete();
      final result = await flight;
      expect(result.state!.hasPending, isTrue);
      expect(result.state!.preferences.displayOrder, 2);
      expect(result.state!.server['display_order'], 1);
    },
  );
  test(
    'member switch blocks late ACK and preserves old member pending on disk',
    () async {
      await edit();
      final entered = Completer<void>(), release = Completer<void>();
      respond = (r) async {
        if (r.method == 'PUT') {
          entered.complete();
          await release.future;
        }
        return backend(r);
      };
      final flight = sync.sync(reg(), character: character());
      final expectation = expectLater(flight, throwsA(anything));
      await entered.future;
      session.change(authenticated: true, user: other);
      release.complete();
      await expectation;
      expect(await db.select(db.scopedSettingCommands).get(), hasLength(1));
    },
  );
  test('wrong ACK identity keeps exact command recoverable', () async {
    await edit();
    respond = (r) {
      final value = backend(r);
      return r.method == 'PUT'
          ? {...value, 'character_id': secondCharacterId}
          : value;
    };
    final r = await sync.sync(reg(), character: character());
    expect(r.failure!.code, 'INVALID_RESPONSE');
    expect(r.state!.hasPending, isTrue);
    expect(r.state!.command!.state, 'retry');
  });
  test(
    'GET failure is not restored default and never deletes local pending',
    () async {
      await edit();
      respond = (r) => throw failure(r);
      final r = await sync.sync(reg(), character: character());
      expect(r.state, isNull);
      expect(r.failure, isNotNull);
      expect(puts(), isEmpty);
      expect(await db.select(db.scopedSettingCommands).get(), hasLength(1));
    },
  );
  test(
    'deleted registration blocks access; same-owner re-registration restores server but never moves old command',
    () async {
      await edit(count: true);
      registered = false;
      await seed(roster: false);
      await expectLater(
        sync.prepare(reg()),
        cacheError('REGISTRATION_NOT_CURRENT'),
      );
      activeRegistration = newRegistration;
      registered = true;
      await seed();
      final r = await sync.sync(reg());
      expect(r.state!.command!.state, 'blocked');
      expect(r.state!.command!.registrationId, registrationId);
      expect(puts(), isEmpty);
      final fresh = await sync.useServer(reg());
      expect(fresh.visibleCount, 6);
      expect(fresh.hasPending, isFalse);
      await edit(count: true, limit: 9);
      await sync.sync(reg());
      expect(puts().single.path, contains(newRegistration));
    },
  );
  test(
    'historical count replay allows label registration-version change and refreshes current metadata',
    () async {
      await edit(count: true);
      var drop = true;
      respond = (r) {
        final result = backend(r);
        if (r.method == 'PUT' && drop) {
          drop = false;
          throw failure(r);
        }
        return result;
      };
      await sync.sync(reg());
      registrationVersion = 2;
      await seed();
      final result = await sync.sync(reg());
      expect(result.state!.hasPending, isFalse);
      expect(result.state!.server['registration_version'], 2);
      expect(puts().last.data['expected_registration_version'], 1);
    },
  );
  test(
    'count unsent registration-version conflict never silently updates expected fence',
    () async {
      await edit(count: true);
      registrationVersion = 2;
      await seed();
      final r = await sync.sync(reg());
      expect(r.state!.command!.state, 'conflict');
      expect(puts(), isEmpty);
      expect(r.state!.command!.body['expected_registration_version'], 1);
    },
  );
  test('same resource in-flight calls share one PUT', () async {
    await edit();
    final entered = Completer<void>(), release = Completer<void>();
    respond = (r) async {
      if (r.method == 'PUT') {
        entered.complete();
        await release.future;
      }
      return backend(r);
    };
    final one = sync.sync(reg(), character: character());
    await entered.future;
    final two = sync.sync(reg(), character: character());
    expect(identical(one, two), isTrue);
    release.complete();
    await Future.wait([one, two]);
    expect(puts(), hasLength(1));
  });
  test(
    'schema2 migration preserves cached identity and existing role records',
    () async {
      final p = await prepare();
      await db.customStatement(
        'INSERT INTO scoped_role_records(scope_id,character_id,account_id,ownership_revision,role,row_version,payload) VALUES(?,?,?,?,?,?,?)',
        [
          p.scopeId,
          characterId,
          account,
          1,
          'dealer',
          1,
          '{"fixture":"preserve"}',
        ],
      );
      store.dispose();
      cache.dispose();
      await db.customStatement('DROP TABLE scoped_setting_commands');
      await db.customStatement('DROP TABLE scoped_setting_records');
      await db.customStatement('PRAGMA user_version = 2');
      await db.close();
      connect();
      expect(await db.select(db.cachedCharacters).get(), hasLength(2));
      expect(
        (await db.select(db.scopedRoleRecords).getSingle()).payload,
        '{"fixture":"preserve"}',
      );
      expect(await db.select(db.scopedSettingRecords).get(), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
  test(
    'settings FK rejects a canonical character belonging to another account',
    () async {
      final p = await prepare();
      await expectLater(
        db.customStatement(
          'INSERT INTO scoped_setting_records(scope_id,kind,target_id,account_id,character_id,ownership_revision,row_version,payload) VALUES(?,?,?,?,?,?,?,?)',
          [
            p.scopeId,
            'preferences',
            characterId,
            newRegistration,
            characterId,
            1,
            1,
            '{}',
          ],
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'runtime disabled settings APIs have no DB/HTTP and enabled uses existing connection',
    () async {
      var opens = 0;
      ScopedAccountRuntime runtime(bool enabled) => ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        databaseFactory: () {
          opens++;
          return db;
        },
        ownsDatabase: false,
        enabled: enabled,
      );
      final disabled = runtime(false);
      await expectLater(
        () => disabled.preparePersonalSettings(reg()),
        throwsA(isA<AccountReadException>()),
      );
      expect(opens, 0);
      expect(calls, isEmpty);
      await disabled.close();
      final enabled = runtime(true);
      final p = await enabled.preparePersonalSettings(reg());
      await enabled.saveAccountPresentation(p, 10);
      expect(
        (await enabled.readPersonalSettings(
          await enabled.preparePersonalSettings(reg()),
        )).visibleCount,
        10,
      );
      expect(opens, 1);
      await enabled.close();
      expect(await db.select(db.cachedCharacters).get(), hasLength(2));
    },
  );
  test(
    'cached restore survives restart without HTTP and never supplies a write plan',
    () async {
      await edit();
      store.dispose();
      cache.dispose();
      await db.close();
      connect();
      calls.clear();
      final restored = await store.readCached(reg(), character: character());
      expect(restored!.fromCache, isTrue);
      expect(restored.preferences.visible, isFalse);
      expect(restored.hasPending, isTrue);
      expect(calls, isEmpty);
      session.change(authenticated: true, user: other);
      expect(await store.readCached(reg(), character: character()), isNull);
      expect(calls, isEmpty);
    },
  );
  test(
    'unqueried settings are absent rather than false successful defaults',
    () async {
      expect(await store.readCached(reg(), character: character()), isNull);
      expect(await store.readCached(reg()), isNull);
      expect(calls, isEmpty);
    },
  );
  test(
    'cancellation after draft write rolls back the whole nested transaction',
    () async {
      final p = await prepare();
      var checks = 0;
      await expectLater(
        store.save(
          p,
          PreferenceValues(visible: false).toJson(),
          guard: () => cacheRequire(++checks < 3, 'RUN_CANCELLED'),
        ),
        cacheError('RUN_CANCELLED'),
      );
      final s = await store.read(p);
      expect(s.hasPending, isFalse);
      expect(s.preferences.visible, isTrue);
      expect(await db.select(db.scopedSettingCommands).get(), isEmpty);
    },
  );
  test(
    'new ownership lifetime restores defaults without moving old pending',
    () async {
      await edit(count: true);
      owner = 2;
      await seed(roster: false);
      final p = await prepare(count: true);
      final state = await store.read(p);
      expect(state.visibleCount, 6);
      expect(state.hasPending, isFalse);
      expect(state.command, isNull);
      expect(await db.select(db.scopedSettingRecords).get(), hasLength(2));
      expect(await db.select(db.scopedSettingCommands).get(), hasLength(1));
    },
  );
  test(
    'count default no-op and reset preserve monotonically increasing versions',
    () async {
      final p = await prepare(count: true);
      await store.save(p, {'visible_count': 6});
      expect((await sync.sync(reg())).state!.server['version'], 1);
      await edit(count: true, limit: 8);
      expect((await sync.sync(reg())).state!.server['version'], 2);
      await edit(count: true, limit: 6);
      final reset = await sync.sync(reg());
      expect(reset.state!.server['version'], 3);
      expect(reset.state!.server['saved_at'], isNotNull);
    },
  );
  test(
    'same-member new login invalidates previous plan but permits safe original replay',
    () async {
      final p = await prepare();
      await store.save(p, PreferenceValues(visible: false).toJson());
      session.change(authenticated: true, user: member);
      await expectLater(
        store.save(p, PreferenceValues().toJson()),
        cacheError('STALE_WRITE'),
      );
      expect(
        (await sync.sync(reg(), character: character())).state!.hasPending,
        isFalse,
      );
    },
  );
  test(
    'presentation malformed response does not fabricate restored data',
    () async {
      respond = (r) => r.path.endsWith('/presentation-settings')
          ? {...countProfile(), 'visible_count': true}
          : backend(r);
      await expectLater(
        prepare(count: true),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
      expect(await db.select(db.scopedSettingRecords).get(), isEmpty);
    },
  );
  test(
    'projection visible representative first, null rank last, and rank ties resolved by UUID',
    () {
      ScopedPresentationItem row(String id, int? rank) =>
          ScopedPresentationItem(
            character(id),
            CacheCharacterObservation.fromStorage({
              'id': id,
              'account': account,
              'server': 'sample-server',
              'name': 'same',
              'lifecycle': 'active',
              'revision': 1,
              'usable': true,
              'blocked': null,
              'profile': <String, dynamic>{},
            }),
            PreferenceValues(displayOrder: rank),
            itemLevel: 1700,
          );
      final items = [
        row(newRegistration, 0),
        row(characterId, null),
        row(secondCharacterId, 0),
      ];
      final result = projectScopedAccountPresentation(
        items: items,
        scope: cache.scope,
        accountId: account,
        representativeId: characterId,
        visibleCount: 200,
      );
      expect(result.map((i) => i.ref.characterId), [
        characterId,
        secondCharacterId,
        newRegistration,
      ]);
      final ordinary = projectScopedAccountPresentation(
        items: items,
        scope: cache.scope,
        accountId: account,
        representativeId: null,
        visibleCount: 200,
      );
      expect(ordinary.last.ref.characterId, characterId);
    },
  );
  test(
    'projection keeps hidden representative hidden and deterministically sorts duplicate ranks before limit',
    () {
      ScopedPresentationItem item(
        String id,
        String name,
        int? rank,
        double? level, {
        bool visible = true,
      }) => ScopedPresentationItem(
        character(id),
        CacheCharacterObservation.fromStorage({
          'id': id,
          'account': account,
          'server': 'sample-server',
          'name': name,
          'lifecycle': 'active',
          'revision': 1,
          'usable': true,
          'blocked': null,
          'profile': <String, dynamic>{},
        }),
        PreferenceValues(displayOrder: rank, visible: visible),
        itemLevel: level,
      );
      final input = [
        item(characterId, 'representative', 0, 1800, visible: false),
        item(secondCharacterId, 'second', 0, 1700),
        item(newRegistration, 'third', 0, 1750),
      ];
      final projected = projectScopedAccountPresentation(
        items: input,
        scope: cache.scope,
        accountId: account,
        representativeId: characterId,
        visibleCount: 1,
      );
      expect(projected.single.ref.characterId, newRegistration);
      expect(input, hasLength(3));
      expect(
        () => projectScopedAccountPresentation(
          items: [...input, input.first],
          scope: cache.scope,
          accountId: account,
          representativeId: null,
          visibleCount: 6,
        ),
        cacheError('IDENTITY_CONFLICT'),
      );
    },
  );
}
