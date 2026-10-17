import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/mappers/scoped_role_build_mapper.dart';
import 'package:lost_party/features/account/data/repositories/scoped_character_cache_repository.dart';
import 'package:lost_party/features/account/data/repositories/scoped_role_repository.dart';
import 'package:lost_party/features/account/data/role_summary_client.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/scoped_role_sync.dart';
import 'package:lost_party/features/account/data/server_character_lifecycle_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart' as wire show roster, item;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account = '44444444-4444-4444-8444-444444444444';
const profilePath = '/v2/me/characters/$characterId/personal-profile';
const putPath = '/v2/me/characters/$characterId/role-summaries/dealer';
Map<String, dynamic> emptyRole() => {
  'version': 1,
  'summary': null,
  'saved_at': null,
};
Map<String, dynamic> armory({
  String name = 'sample',
  String className = '버서커',
}) => {
  'ArmoryProfile': {
    'ServerName': 'sample-server',
    'CharacterName': name,
    'CharacterLevel': 70,
    'CharacterClassName': className,
    'ItemAvgLevel': '1,700.00',
    'CombatPower': '12,345.67',
  },
};
GameCatalog catalog() => GameCatalog(
  schemaVersion: 1,
  catalogVersion: 'tests-v1',
  updatedAt: DateTime.utc(2026),
  classes: const [
    GameClassDefinition(
      classId: 'berserker',
      apiClassName: '버서커',
      aliases: [],
      supportedRoles: {GameCatalogRole.dealer},
      defaultRole: GameCatalogRole.dealer,
      enlightenmentBranches: [],
      specialSkills: [],
      gemSkillTargets: [],
      arkGridPresets: [],
    ),
  ],
);
Map<String, dynamic> summaryJson() => {
  'source': 'flutter_analysis',
  'analysis_rules_version': 'tests-v1',
  'analyzed_at': serverTime,
  'combat_power': null,
  'item_level': null,
  'combat_power_observed_at': null,
  'item_level_observed_at': null,
  'integrity_status': 'unavailable',
  'catalog_version': null,
  'issues': <Object>[],
  'observed_lifecycle_revision': 1,
};

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late ScopedAccountCacheDatabase db;
  late ScopedCharacterCacheRepository cache;
  late ScopedRoleRepository store;
  late ScopedRoleSync sync;
  late Directory temp;
  late File file;
  late DateTime clock;
  late Map<String, Map<String, dynamic>> serverRoles, replays;
  late List<RequestOptions> calls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  int owner = 1, life = 1;
  String state = 'active';
  Map<String, dynamic> profile() => {
    'character_id': characterId,
    'game_account_id': account,
    'ownership_revision': owner,
    'lifecycle_revision': life,
    'lifecycle_state': state,
    'dealer': serverRoles['dealer'],
    'support': serverRoles['support'],
    'preferences': {
      'version': 1,
      'preferred_role': null,
      'visible': true,
      'display_order': null,
      'saved_at': null,
    },
  };
  DioException error(
    RequestOptions r,
    int status,
    String code, {
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
          'retry_after_seconds': ?seconds,
          'request_id': 'role-test',
        },
      },
    ),
  );
  Map<String, dynamic> backend(RequestOptions r) {
    if (r.path == '/v1/me/game-accounts') return registrationPageJson();
    if (r.path.endsWith('/characters')) {
      return wire.roster(
        items: [
          {...wire.item(), 'class_name': '버서커'},
        ],
      );
    }
    if (r.path == profilePath) return profile();
    if (r.method == 'PUT') {
      final key = r.headers['Idempotency-Key'] as String;
      if (replays[key] case final response?) return response;
      final body = r.data as Map<String, dynamic>,
          role = r.path.split('/').last;
      final previous = serverRoles[role]!;
      if (body['expected_version'] != previous['version']) {
        throw error(r, 409, 'REVISION_CONFLICT');
      }
      final value = {
        'version': (previous['version'] as int) + 1,
        'summary': body['summary'],
        'saved_at': clock.toIso8601String(),
      };
      serverRoles[role] = value;
      return replays[key] = {
        ...value,
        'character_id': characterId,
        'role': role,
        'ownership_revision': owner,
        'lifecycle_revision': life,
      };
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
    store = ScopedRoleRepository(cache);
    sync = ScopedRoleSync(RoleSummaryClient(api), store, now: () => clock);
  }

  ScopedRegistrationRef reg() =>
      ScopedRegistrationRef(cache.scope, registrationId);
  ScopedCharacterRef ref() => ScopedCharacterRef(
    cache.scope,
    accountId: account,
    characterId: characterId,
  );
  Future<void> seed() async {
    final client = ServerCharacterLifecycleClient(api);
    try {
      await client.refreshRegistrations(cache);
      await client.refreshRoster(cache, reg());
    } finally {
      client.dispose();
    }
  }

  ScopedRoleBuildDraft draft({String name = 'sample'}) =>
      analyzeScopedRoleBuild(
        armory: armory(name: name),
        catalog: catalog(),
        lifecycleRevision: life,
        fetchedAt: clock,
      );
  Future<ScopedRolePlan> prepared() => sync.prepare(reg(), ref());
  Future<ScopedRoleState> saved() async => sync.save(await prepared(), draft());
  List<RequestOptions> puts() => calls.where((r) => r.method == 'PUT').toList();
  setUp(() async {
    owner = life = 1;
    state = 'active';
    clock = DateTime.utc(2026, 10, 16);
    session = ReadSessionFake()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    api = DioBackendAccountReadApi(dio, session);
    serverRoles = {'dealer': emptyRole(), 'support': emptyRole()};
    replays = {};
    calls = [];
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
          } catch (e) {
            h.reject(
              e is DioException ? e : DioException(requestOptions: r, error: e),
            );
          }
        },
      ),
    );
    temp = await Directory.systemTemp.createTemp('lost-party-role-');
    file = File('${temp.path}/roles.sqlite');
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
    final root = Directory.systemTemp.absolute.path;
    if (!temp.absolute.path.startsWith(
      '$root${Platform.pathSeparator}lost-party-role-',
    )) {
      throw StateError('Unexpected fixture path');
    }
    await temp.delete(recursive: true);
  });

  test(
    'unavailable empty issues stays unavailable; immutable summary/null time pairs',
    () {
      final input = summaryJson();
      final parsed = RoleSummary.fromJson(input);
      input['integrity_status'] = 'clean';
      expect(parsed.integrity.name, 'unavailable');
      expect(parsed.catalogVersion, isNull);
      expect(
        () => parsed.issues.add(AnalysisIssue('X', 'warning')),
        throwsUnsupportedError,
      );
    },
  );
  final invalids = <String, void Function(Map<String, dynamic>)>{
    'missing nullable': (j) => j.remove('catalog_version'),
    'extra raw': (j) => j['raw'] = {},
    'numeric coercion': (j) => j['observed_lifecycle_revision'] = true,
    'exponent': (j) {
      j['combat_power'] = '1e3';
      j['combat_power_observed_at'] = serverTime;
    },
    'unpaired timestamp': (j) => j['combat_power'] = '3',
    'calendar rollover': (j) => j['analyzed_at'] = '2026-02-30T00:00:00Z',
    'nonUTC': (j) => j['analyzed_at'] = '2026-10-15T09:00:00+09:00',
    'invalid status combination': (j) => j['integrity_status'] = 'error',
    'duplicate issue': (j) {
      j['integrity_status'] = 'review';
      j['issues'] = [
        {'code': 'X', 'severity': 'warning'},
        {'code': 'X', 'severity': 'warning'},
      ];
    },
  };
  for (final entry in invalids.entries) {
    test('strict DTO rejects ${entry.key}', () {
      final value = summaryJson();
      entry.value(value);
      expect(() => RoleSummary.fromJson(value), throwsFormatException);
    });
  }
  test(
    'automatic support role requires evidence, never a preferred-role fallback',
    () {
      expect(
        () => analyzeScopedRoleBuild(
          armory: armory(className: '바드'),
          catalog: catalog(),
          lifecycleRevision: 1,
          fetchedAt: clock,
        ),
        throwsFormatException,
      );
      final result = draft();
      expect(result.role, CharacterBuildRole.dealer);
      expect(result.summary.combatPower, '12345.67');
      expect(result.summary.itemLevel, '1700.00');
      expect(result.summary.integrity.name, isNot('clean'));
    },
  );
  test(
    'P2 persisted preferences coexist with role storage without changing it',
    () async {
      respond = (r) => r.path == profilePath
          ? (profile()
              ..['preferences'] = {
                'version': 2,
                'preferred_role': 'support',
                'visible': false,
                'display_order': 0,
                'saved_at': serverTime,
              })
          : backend(r);
      final p = await prepared();
      expect(p.profile.preferences.values.visible, isFalse);
      expect(
        p.profile.preferences.values.preferredRole,
        CharacterBuildRole.support,
      );
      expect(
        (await store.read(p, CharacterBuildRole.dealer)).hasPending,
        isFalse,
      );
      expect(await db.select(db.scopedSettingRecords).get(), isEmpty);
    },
  );
  test(
    'snapshot and outbox commit locally before HTTP; exact ACK preserves opposite role',
    () async {
      final local = await saved();
      expect(local.hasPending, isTrue);
      expect(local.rawJson, isNotNull);
      expect(local.command!.firstSentAt, isNull);
      expect(puts(), isEmpty);
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.failure, isNull);
      expect(result.state!.hasPending, isFalse);
      expect(result.state!.server.version, 2);
      expect(result.state!.rawMatchesDisplay, isTrue);
      expect(serverRoles['support'], emptyRole());
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
      expect(puts().single.path, putPath);
      expect(puts().single.data.toString(), isNot(contains('ArmoryProfile')));
    },
  );
  test(
    'SQL command failure rolls back the corresponding local detail and draft',
    () async {
      final plan = await prepared();
      await db.customStatement(
        "CREATE TRIGGER reject_role_command BEFORE INSERT ON scoped_role_commands BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
      );
      await expectLater(sync.save(plan, draft()), throwsA(anything));
      final state = await store.read(plan, CharacterBuildRole.dealer);
      expect(state.hasPending, isFalse);
      expect(state.rawJson, isNull);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'captured key/run guard is checked again even when save omits a new guard',
    () async {
      var valid = true;
      final plan = await sync.prepare(
        reg(),
        ref(),
        guard: () {
          if (!valid) throw const ScopedCacheException('KEY_CHANGED');
        },
      );
      valid = false;
      await expectLater(
        sync.save(plan, draft()),
        throwsA(isA<ScopedCacheException>()),
      );
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'identity mismatch and session/epoch changes cannot write local details',
    () async {
      final plan = await prepared();
      await expectLater(
        sync.save(plan, draft(name: 'another')),
        throwsA(isA<ScopedCacheException>()),
      );
      session.change(authenticated: true, user: other);
      await expectLater(sync.save(plan, draft()), throwsA(anything));
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'fresh account metadata invalidates an older prepared analysis',
    () async {
      final plan = await prepared();
      await seed();
      await expectLater(
        sync.save(plan, draft()),
        throwsA(isA<ScopedCacheException>()),
      );
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'network loss after commit is recovered using exactly the same key/body',
    () async {
      await saved();
      var lose = true;
      respond = (r) {
        final result = backend(r);
        if (r.method == 'PUT' && lose) {
          lose = false;
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        return result;
      };
      final first = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(first.state!.hasPending, isTrue);
      expect(first.failure!.code, 'NETWORK_UNAVAILABLE');
      final second = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(second.state!.hasPending, isFalse);
      expect(puts(), hasLength(2));
      expect(
        puts()[0].headers['Idempotency-Key'],
        puts()[1].headers['Idempotency-Key'],
      );
      expect(jsonEncode(puts()[0].data), jsonEncode(puts()[1].data));
      expect(serverRoles['dealer']!['version'], 2);
    },
  );
  test(
    '429 has a fixed deadline and sends no retry before it passes',
    () async {
      await saved();
      respond = (r) {
        if (r.method == 'PUT') throw error(r, 429, 'RATE_LIMITED', seconds: 30);
        return backend(r);
      };
      final first = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      final deadline = first.state!.command!.retryAt;
      clock = clock.add(const Duration(seconds: 5));
      final second = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(puts(), hasLength(1));
      expect(second.state!.command!.retryAt, deadline);
      clock = clock.add(const Duration(seconds: 25));
      respond = backend;
      expect(
        (await sync.sync(
          reg(),
          ref(),
          CharacterBuildRole.dealer,
        )).state!.hasPending,
        isFalse,
      );
    },
  );
  test(
    '24h uncertain command is reviewed using GET, never blindly rekeyed',
    () async {
      await saved();
      respond = (r) {
        if (r.method == 'PUT') {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        return backend(r);
      };
      await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      clock = clock.add(const Duration(hours: 24));
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.state!.command!.state, 'review');
      expect(puts(), hasLength(1));
      final reviewed = await sync.useServer(
        reg(),
        ref(),
        CharacterBuildRole.dealer,
      );
      expect(reviewed.hasPending, isFalse);
      expect(reviewed.displaySummary, isNull);
      expect(reviewed.rawMatchesDisplay, isFalse);
    },
  );
  test(
    'another device version conflicts without automatic expected-version rebasing',
    () async {
      await saved();
      serverRoles['dealer'] = {
        'version': 2,
        'summary': summaryJson(),
        'saved_at': clock.toIso8601String(),
      };
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.state!.command!.state, 'conflict');
      expect(puts(), isEmpty);
      expect(result.state!.hasPending, isTrue);
      expect(result.state!.command!.body['expected_version'], 1);
    },
  );
  test(
    'newer draft survives a late successful ACK of an already-sent command',
    () async {
      await saved();
      final started = Completer<void>(), finish = Completer<void>();
      respond = (r) async {
        if (r.method == 'PUT') {
          started.complete();
          await finish.future;
        }
        return backend(r);
      };
      final old = sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      await started.future;
      clock = clock.add(const Duration(minutes: 1));
      await saved();
      finish.complete();
      final result = await old;
      expect(result.state!.localRevision, 2);
      expect(result.state!.hasPending, isTrue);
      expect(result.state!.command, isNull);
      expect(result.state!.localSummary!.analyzedAt, clock);
      expect(result.state!.server.summary!.analyzedAt, isNot(clock));
    },
  );
  test(
    'late PUT across logout never acknowledges or replaces the next member',
    () async {
      await saved();
      final started = Completer<void>(), finish = Completer<void>();
      respond = (r) async {
        if (r.method == 'PUT') {
          started.complete();
          await finish.future;
        }
        return backend(r);
      };
      final flight = sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      await started.future;
      session.change(authenticated: true, user: other);
      finish.complete();
      await expectLater(flight, throwsA(anything));
      expect(await db.select(db.scopedRoleCommands).get(), hasLength(1));
      expect(
        (await db.select(db.cacheScopes).get()).every(
          (s) => s.userId == member,
        ),
        isTrue,
      );
    },
  );
  test(
    'same member restart restores pending command and its immutable identity',
    () async {
      await saved();
      respond = (r) {
        if (r.method == 'PUT') {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        return backend(r);
      };
      final first = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      final key = first.state!.command!.id;
      store.dispose();
      cache.dispose();
      await db.close();
      session.change(authenticated: true, user: member);
      connect();
      respond = backend;
      await seed();
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.state!.hasPending, isFalse);
      expect(puts().last.headers['Idempotency-Key'], key);
    },
  );
  test(
    'new ownership lifetime cannot receive the old lifetime draft or command',
    () async {
      await saved();
      owner = 2;
      await expectLater(prepared(), throwsA(isA<ScopedCacheException>()));
      expect(puts(), isEmpty);
      expect(await db.select(db.scopedRoleCommands).get(), hasLength(1));
    },
  );
  test(
    'schema1 migration preserves canonical rows and starts with empty roles',
    () async {
      store.dispose();
      cache.dispose();
      await db.customStatement('DROP TABLE scoped_setting_commands');
      await db.customStatement('DROP TABLE scoped_setting_records');
      await db.customStatement('DROP TABLE scoped_role_commands');
      await db.customStatement('DROP TABLE scoped_role_records');
      await db.customStatement('DROP INDEX cached_characters_role_identity');
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();
      connect();
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
      expect(await db.select(db.scopedRoleRecords).get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        3,
      );
      expect(
        (await db.customSelect('PRAGMA foreign_key_check').get()),
        isEmpty,
      );
    },
  );
  for (final status in ['clean', 'review', 'error', 'unavailable']) {
    test(
      'P1 preserves explicit integrity $status without inferring from null catalog',
      () {
        final input = summaryJson()..['integrity_status'] = status;
        if (status == 'review') {
          input['issues'] = [
            {'code': 'GEM_UNAVAILABLE', 'severity': 'warning'},
          ];
        }
        if (status == 'error') {
          input['issues'] = [
            {'code': 'FOREIGN_CLASS_GEM', 'severity': 'error'},
          ];
        }
        final parsed = RoleSummary.fromJson(input);
        expect(parsed.integrity.name, status);
        expect(parsed.catalogVersion, isNull);
      },
    );
  }
  test(
    'delayed rate-limit response starts retry duration at receipt',
    () async {
      await saved();
      respond = (r) {
        if (r.method == 'PUT') {
          clock = clock.add(const Duration(seconds: 8));
          throw error(r, 429, 'RATE_LIMITED', seconds: 30);
        }
        return backend(r);
      };
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(
        result.state!.command!.retryAt,
        clock.add(const Duration(seconds: 30)),
      );
    },
  );
  test(
    'wrong acknowledgement identity keeps the original command uncertain',
    () async {
      await saved();
      respond = (r) {
        final value = backend(r);
        return r.method == 'PUT'
            ? {...value, 'character_id': secondCharacterId}
            : value;
      };
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.failure!.code, 'INVALID_RESPONSE');
      expect(result.state!.hasPending, isTrue);
      expect(await db.select(db.scopedRoleCommands).get(), hasLength(1));
      respond = backend;
      expect(
        (await sync.sync(
          reg(),
          ref(),
          CharacterBuildRole.dealer,
        )).state!.hasPending,
        isFalse,
      );
    },
  );
  test(
    'failed profile GET does not discard a locally committed role',
    () async {
      final plan = await prepared();
      await sync.save(plan, draft());
      respond = (r) {
        if (r.path == profilePath) throw error(r, 503, 'SERVICE_UNAVAILABLE');
        return backend(r);
      };
      final result = await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      expect(result.failure!.code, 'SERVICE_UNAVAILABLE');
      expect(puts(), isEmpty);
      expect(
        (await store.read(plan, CharacterBuildRole.dealer)).hasPending,
        isTrue,
      );
    },
  );
  test('same-scope concurrent sync shares one immutable PUT', () async {
    await saved();
    final started = Completer<void>(), finish = Completer<void>();
    respond = (r) async {
      if (r.method == 'PUT') {
        started.complete();
        await finish.future;
      }
      return backend(r);
    };
    final first = sync.sync(reg(), ref(), CharacterBuildRole.dealer);
    await started.future;
    final second = sync.sync(reg(), ref(), CharacterBuildRole.dealer);
    expect(identical(first, second), isTrue);
    finish.complete();
    await Future.wait([first, second]);
    expect(puts(), hasLength(1));
  });
  test(
    'saving dealer preserves a previously stored support summary/version',
    () async {
      serverRoles['support'] = {
        'version': 2,
        'summary': summaryJson(),
        'saved_at': serverTime,
      };
      await saved();
      await sync.sync(reg(), ref(), CharacterBuildRole.dealer);
      final support = await store.read(
        await prepared(),
        CharacterBuildRole.support,
      );
      expect(support.server.version, 2);
      expect(support.server.summary!.integrity.name, 'unavailable');
      expect(support.rawJson, isNull);
      expect(support.hasPending, isFalse);
    },
  );
  test(
    'physical FK rejects assigning a role to another existing account',
    () async {
      final plan = await prepared();
      const wrongAccount = '77777777-7777-4777-8777-777777777777';
      await db.customStatement(
        'INSERT INTO cached_account_heads(scope_id,account_id,payload) VALUES(?,?,?)',
        [plan.scopeId, wrongAccount, '{}'],
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO scoped_role_records(scope_id,character_id,account_id,ownership_revision,role,row_version,payload) VALUES(?,?,?,?,?,?,?)',
          [plan.scopeId, characterId, wrongAccount, 2, 'dealer', 1, '{}'],
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'disabled runtime role entrypoint never opens DB or sends HTTP',
    () async {
      var opens = 0;
      final disabled = ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        databaseFactory: () {
          opens++;
          return db;
        },
        ownsDatabase: false,
      );
      try {
        await expectLater(
          () => disabled.prepareRoleBuild(reg(), ref()),
          throwsA(
            isA<AccountReadException>().having(
              (e) => e.code,
              'code',
              'FEATURE_DISABLED',
            ),
          ),
        );
        expect(opens, 0);
        expect(calls, isEmpty);
      } finally {
        await disabled.close();
      }
    },
  );
  test(
    'app runtime uses its one DB and never starts role HTTP implicitly',
    () async {
      var opens = 0;
      final runtime = ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        enabled: true,
        ownsDatabase: false,
        databaseFactory: () {
          opens++;
          return db;
        },
      );
      try {
        expect(calls, isEmpty);
        expect(opens, 0);
        await runtime.refreshRegistrations();
        await runtime.refreshRoster(runtime.reference(registrationId));
        final target = ScopedCharacterRef(
          runtime.scope,
          accountId: account,
          characterId: characterId,
        );
        final plan = await runtime.prepareRoleBuild(
          runtime.reference(registrationId),
          target,
        );
        await runtime.saveRoleBuild(plan, draft());
        final result = await runtime.syncRoleBuild(
          runtime.reference(registrationId),
          target,
          CharacterBuildRole.dealer,
        );
        expect(result.state!.hasPending, isFalse);
        expect(opens, 1);
      } finally {
        await runtime.close();
      }
    },
  );
}
