import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/scoped_startup_refresh_source.dart';
import 'package:lost_party/features/account/domain/scoped_startup_refresh.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';
import 'package:lost_party/shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';

import '../../../support/server_account_read_fakes.dart';
import 'scoped_role_sync_test.dart' as fixtures show catalog, armory;
import 'server_character_lifecycle_client_test.dart' as wire show item, roster;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const account = '44444444-4444-4444-8444-444444444444';

class Signals extends ChangeNotifier {
  void changed() => notifyListeners();
}

class Catalog implements GameCatalogRepository {
  @override
  Future<GameCatalog> loadCatalog() async => fixtures.catalog();
}

class Token implements ApiTokenStore {
  @override
  Future<ApiToken?> read() async => ApiToken('fixture-token');
  @override
  Future<void> write(ApiToken token) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  late ScopedAccountCacheDatabase db;
  late ReadSessionFake session;
  late Dio backend, provider;
  late DioBackendAccountReadApi api;
  late ScopedAccountRuntime runtime;
  late ApiCooldown cooldown;
  late Signals signals;
  late RuntimeStartupRefreshSource source;
  late ScopedStartupRefreshController controller;
  late ScopedRefreshAccess access;
  late List<RequestOptions> apiCalls, armoryCalls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) apiRespond,
      armoryRespond;
  late Map<String, Map<String, dynamic>> roleSummaries;
  late DateTime clock;
  int registrationVersion = 1;
  int rosterRevision = 2;
  late Map<String, Map<String, dynamic>> refreshReplies;
  String className = '버서커';
  bool failRoster = false, failPut = false;
  Map<String, dynamic> settings() => {
    ...settingsJson(),
    'activity_character_ids': [characterId, secondCharacterId],
  };
  Map<String, dynamic> empty() => {
    'version': 1,
    'summary': null,
    'saved_at': null,
  };
  DioException failure(RequestOptions r) => DioException.badResponse(
    statusCode: 503,
    requestOptions: r,
    response: Response(
      requestOptions: r,
      statusCode: 503,
      data: {
        'error': {'code': 'SERVICE_UNAVAILABLE', 'request_id': 'startup-test'},
      },
    ),
  );
  Map<String, dynamic> serve(RequestOptions r) {
    if (r.path == '/v1/me/game-accounts') {
      return {
        'items': [
          {
            ...registrationJson(),
            'version': registrationVersion,
            'roster_revision': rosterRevision,
            'settings': settings(),
          },
        ],
        'next_cursor': null,
      };
    }
    if (r.path.endsWith('/refresh')) {
      final key = r.headers['Idempotency-Key'] as String;
      return refreshReplies.putIfAbsent(key, () {
        registrationVersion++;
        rosterRevision++;
        return {
          'registration': {
            ...registrationJson(),
            'version': registrationVersion,
            'roster_revision': rosterRevision,
            'settings': settings(),
          },
          'added_count': 0,
          'suspect_count': 0,
          'requires_refresh': false,
        };
      });
    }
    if (r.path.endsWith('/characters')) {
      if (failRoster) throw failure(r);
      return {
        ...wire.roster(
          items: [
            {...wire.item(), 'class_name': className, 'item_level': '1600.00'},
            {
              ...wire.item(id: secondCharacterId, name: 'second'),
              'class_name': className,
            },
          ],
        ),
        'registration_version': registrationVersion,
        'roster_revision': rosterRevision,
        'settings': settings(),
      };
    }
    final id = r.path.split('/')[4];
    if (r.path.endsWith('/personal-profile')) {
      return {
        'character_id': id,
        'game_account_id': account,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
        'lifecycle_state': 'active',
        'dealer': roleSummaries[id] ?? empty(),
        'support': empty(),
        'preferences': {
          'version': 1,
          'preferred_role': null,
          'visible': true,
          'display_order': null,
          'saved_at': null,
        },
      };
    }
    if (r.method == 'PUT') {
      if (failPut) throw failure(r);
      final b = r.data as Map<String, dynamic>;
      final saved = {
        'version': (b['expected_version'] as int) + 1,
        'summary': b['summary'],
        'saved_at': clock.toIso8601String(),
      };
      roleSummaries[id] = saved;
      return {
        ...saved,
        'character_id': id,
        'role': r.path.split('/').last,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
      };
    }
    throw StateError('Unexpected ${r.path}');
  }

  setUp(() {
    clock = DateTime.utc(2026, 10, 16);
    registrationVersion = 1;
    rosterRevision = 2;
    refreshReplies = {};
    className = '버서커';
    failRoster = failPut = false;
    roleSummaries = {};
    apiCalls = [];
    armoryCalls = [];
    signals = Signals();
    access = const ScopedRefreshAccess(
      niceGroupEnabled: true,
      settingsVersion: 1,
      keyVersion: 1,
    );
    session = ReadSessionFake()..userId = member;
    cooldown = ApiCooldown(now: () => clock);
    backend = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    provider = Dio();
    apiRespond = serve;
    armoryRespond = (r) => fixtures.armory(
      name: Uri.decodeComponent(r.path.split('/').last),
      className: className,
    );
    backend.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          apiCalls.add(r);
          try {
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: await apiRespond(r),
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
    provider.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          armoryCalls.add(r);
          try {
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: await armoryRespond(r),
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
    api = DioBackendAccountReadApi(backend, session, cooldown: cooldown);
    db = ScopedAccountCacheDatabase(NativeDatabase.memory());
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () => db,
      enabled: true,
    );
    source = RuntimeStartupRefreshSource(
      runtime: runtime,
      remote: LostArkCharacterRemoteDataSource(
        apiClient: LostArkApiClient(
          apiTokenStore: Token(),
          dio: provider,
          cooldown: cooldown,
          scopeIdentity: () =>
              (session.userId, session.generation, access.keyVersion),
        ),
      ),
      catalog: Catalog(),
      readAccess: () => access,
      changes: signals,
      cooldown: cooldown,
      now: () => clock,
    );
    controller = ScopedStartupRefreshController(source);
  });
  tearDown(() async {
    controller.dispose();
    source.dispose();
    await runtime.close();
    session.dispose();
    signals.dispose();
    cooldown.dispose();
    backend.close();
    provider.close();
  });
  Future<void> run() async {
    controller.initialize();
    await controller.startIfReady();
  }

  test(
    'actual adapter fetches all active full armories, saves warnings in correct UUID role and uploads summaries only',
    () async {
      await run();
      expect(controller.savedCount, 2);
      expect(controller.warningCount, 2);
      expect(controller.pendingServerCount, 0);
      expect(armoryCalls, hasLength(2));
      final rows = await db.select(db.scopedRoleRecords).get();
      expect(rows, hasLength(4));
      final dealer = rows.where((r) => r.role == 'dealer').toList();
      expect(dealer.every((r) => jsonDecode(r.payload)['raw'] != null), isTrue);
      expect(
        rows
            .where((r) => r.role == 'support')
            .every((r) => jsonDecode(r.payload)['raw'] == null),
        isTrue,
      );
      final puts = apiCalls.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(2));
      expect(
        puts.every((r) => !(jsonEncode(r.data)).contains('ArmoryProfile')),
        isTrue,
      );
      expect(await db.select(db.scopedSettingRecords).get(), isEmpty);
    },
  );
  test(
    'provider list refresh precedes canonical read and details; detail retry never refreshes again',
    () async {
      final events = <String>[];
      apiRespond = (r) {
        events.add('${r.method}:${r.path}');
        return serve(r);
      };
      armoryRespond = (r) {
        events.add('ARMORY');
        return fixtures.armory(name: 'not-the-target');
      };
      await run();
      final posts = apiCalls.where((r) => r.path.endsWith('/refresh')).toList();
      expect(posts, hasLength(1));
      expect(posts.single.data, isEmpty);
      final postIndex = events.indexWhere((e) => e.startsWith('POST:'));
      final readIndex = events.indexWhere((e) => e.startsWith('GET:/v2/'));
      expect(postIndex, lessThan(readIndex));
      expect(readIndex, lessThan(events.indexOf('ARMORY')));
      await controller.retryIncomplete();
      expect(apiCalls.where((r) => r.path.endsWith('/refresh')), hasLength(1));
      expect(
        controller.rosterProgress.single.phase,
        RosterRefreshPhase.updated,
      );
    },
  );

  test(
    'lost list response leaves once unused and replays exact key/body before any Armory',
    () async {
      var lose = true;
      apiRespond = (r) {
        final json = serve(r);
        if (r.path.endsWith('/refresh') && lose) {
          lose = false;
          throw failure(r);
        }
        return json;
      };
      await run();
      expect(controller.consumed, isFalse);
      expect(armoryCalls, isEmpty);
      expect(controller.rosterProgress.single.phase, RosterRefreshPhase.failed);
      await controller.startIfReady();
      final posts = apiCalls.where((r) => r.path.endsWith('/refresh')).toList();
      expect(posts, hasLength(2));
      expect(
        posts.first.headers['Idempotency-Key'],
        posts.last.headers['Idempotency-Key'],
      );
      expect(posts.first.data, posts.last.data);
      expect(registrationVersion, 2);
      expect(controller.savedCount, 2);
      await controller.startIfReady();
      session.change(authenticated: false);
      session.change(authenticated: true, user: member);
      await controller.startIfReady();
      expect(apiCalls.where((r) => r.path.endsWith('/refresh')), hasLength(2));
    },
  );

  test(
    'canonical read failure after list ACK retries GET without another provider mutation',
    () async {
      failRoster = true;
      await run();
      expect(controller.consumed, isFalse);
      expect(armoryCalls, isEmpty);
      failRoster = false;
      await controller.startIfReady();
      expect(apiCalls.where((r) => r.path.endsWith('/refresh')), hasLength(1));
      expect(controller.savedCount, 2);
    },
  );

  test(
    'list rate limit preserves unused once, fixed deadline and explicit same-command retry',
    () async {
      var limited = true;
      apiRespond = (r) {
        if (r.path.endsWith('/refresh') && limited) {
          limited = false;
          throw DioException.badResponse(
            statusCode: 429,
            requestOptions: r,
            response: Response(
              requestOptions: r,
              statusCode: 429,
              headers: Headers.fromMap({
                'retry-after': ['20'],
              }),
              data: {
                'error': {'code': 'RATE_LIMITED', 'request_id': 'list-limit'},
              },
            ),
          );
        }
        return serve(r);
      };
      await run();
      expect(controller.consumed, isFalse);
      expect(cooldown.seconds, 20);
      await controller.startIfReady();
      expect(apiCalls.where((r) => r.path.endsWith('/refresh')), hasLength(1));
      clock = clock.add(const Duration(seconds: 21));
      await Future<void>.delayed(Duration.zero);
      expect(apiCalls.where((r) => r.path.endsWith('/refresh')), hasLength(1));
      await controller.startIfReady();
      final posts = apiCalls.where((r) => r.path.endsWith('/refresh')).toList();
      expect(posts, hasLength(2));
      expect(
        posts.first.headers['Idempotency-Key'],
        posts.last.headers['Idempotency-Key'],
      );
      expect(controller.savedCount, 2);
    },
  );

  test(
    'logout during list POST blocks late ACK, canonical reads and detail writes',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      apiRespond = (r) async {
        if (r.path.endsWith('/refresh')) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      controller.initialize();
      final run = controller.startIfReady();
      await entered.future;
      session.change(authenticated: false);
      release.complete();
      await run;
      expect(controller.consumed, isFalse);
      expect(controller.rosterProgress, isEmpty);
      expect(apiCalls.where((r) => r.path.startsWith('/v2/')), isEmpty);
      expect(armoryCalls, isEmpty);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );

  test(
    'multiple owned rosters retain successful refresh when a later roster fails preparation',
    () async {
      const otherReg = '77777777-7777-4777-8777-777777777777';
      const otherAccount = '88888888-8888-4888-8888-888888888888';
      final versions = {registrationId: 1, otherReg: 1};
      final replay = <String, Map<String, dynamic>>{};
      final settings = {
        ...settingsJson(),
        'configuration_state': 'unconfigured',
        'activity_character_ids': <String>[],
        'representative_character_id': null,
      };
      Map<String, dynamic> reg(String id) => {
        ...registrationJson(),
        'registration_id': id,
        'game_account_id': id == registrationId ? account : otherAccount,
        'is_main': id == registrationId,
        'version': versions[id],
        'roster_revision': versions[id]! + 1,
        'settings': settings,
        'character_count': 0,
      };
      var failSecond = true;
      apiRespond = (r) {
        if (r.path == '/v1/me/game-accounts') {
          return {
            'items': [reg(registrationId), reg(otherReg)],
            'next_cursor': null,
          };
        }
        final id = r.path.split('/')[4];
        if (r.path.endsWith('/refresh')) {
          if (id == otherReg && failSecond) {
            throw failure(r);
          }
          return replay.putIfAbsent(r.headers['Idempotency-Key'] as String, () {
            versions[id] = versions[id]! + 1;
            return {
              'registration': reg(id),
              'added_count': 0,
              'suspect_count': 0,
              'requires_refresh': false,
            };
          });
        }
        if (r.path.endsWith('/characters')) {
          final row = reg(id);
          return {
            ...wire.roster(items: []),
            'registration_id': id,
            'game_account_id': row['game_account_id'],
            'is_main': row['is_main'],
            'registration_version': versions[id],
            'roster_revision': row['roster_revision'],
            'settings': settings,
          };
        }
        throw StateError('Unexpected ${r.path}');
      };
      await run();
      expect(controller.consumed, isFalse);
      expect(controller.rosterProgress.map((p) => p.phase), [
        RosterRefreshPhase.updated,
        RosterRefreshPhase.failed,
      ]);
      expect(armoryCalls, isEmpty);
      failSecond = false;
      await controller.startIfReady();
      expect(controller.consumed, isTrue);
      expect(
        controller.rosterProgress.every(
          (p) => p.phase == RosterRefreshPhase.updated,
        ),
        isTrue,
      );
      expect(
        apiCalls.where(
          (r) => r.path == '/v1/me/game-accounts/$registrationId/refresh',
        ),
        hasLength(1),
      );
      final second = apiCalls
          .where((r) => r.path == '/v1/me/game-accounts/$otherReg/refresh')
          .toList();
      expect(second, hasLength(2));
      expect(
        second.first.headers['Idempotency-Key'],
        second.last.headers['Idempotency-Key'],
      );
    },
  );

  test(
    'fresh list excludes suspect activity and never auto-selects newly added UUID',
    () async {
      const added = '66666666-6666-4666-8666-666666666666';
      apiRespond = (r) {
        final json = serve(r);
        if (r.path.endsWith('/refresh')) {
          return {
            ...json,
            'added_count': 1,
            'suspect_count': 1,
            'requires_refresh': true,
          };
        }
        if (r.path.endsWith('/characters')) {
          final rows = json['items'] as List;
          rows[0] = {
            ...rows[0] as Map<String, dynamic>,
            'usable': false,
            'blocked_reason': 'CHARACTER_UNUSABLE',
            'lifecycle_state': 'suspect',
            'roster_status': 'suspect',
            'eligible': false,
          };
          rows.add(wire.item(id: added, name: 'new-unselected'));
        }
        return json;
      };
      await run();
      expect(controller.consumed, isTrue);
      expect(controller.savedCount, 1);
      expect(controller.excludedCount, 1);
      expect(
        controller.items.any((i) => i.target.ref.characterId == added),
        isFalse,
      );
      expect(controller.rosterProgress.single.added, 1);
      expect(controller.rosterProgress.single.suspect, 1);
      expect(armoryCalls, hasLength(1));
      expect(armoryCalls.single.path, contains('second'));
    },
  );
  test(
    'unknown settings or key readiness block all metadata and armory IO without consuming once',
    () async {
      access = const ScopedRefreshAccess(keyVersion: 1);
      await run();
      expect(controller.consumed, isFalse);
      expect(apiCalls, isEmpty);
      expect(armoryCalls, isEmpty);
      access = const ScopedRefreshAccess(
        niceGroupEnabled: true,
        settingsVersion: 1,
      );
      signals.changed();
      await controller.startIfReady();
      expect(controller.consumed, isFalse);
      expect(apiCalls, isEmpty);
      access = const ScopedRefreshAccess(
        niceGroupEnabled: true,
        settingsVersion: 1,
        keyVersion: 1,
      );
      signals.changed();
      await controller.startIfReady();
      expect(controller.savedCount, 2);
    },
  );
  test(
    'failed full roster does not classify, start a detail run or consume once',
    () async {
      failRoster = true;
      await run();
      expect(controller.consumed, isFalse);
      expect(armoryCalls, isEmpty);
      expect(controller.phase, ScopedRefreshPhase.blocked);
      failRoster = false;
      await controller.startIfReady();
      expect(controller.savedCount, 2);
    },
  );
  test(
    'NiceGroup OFF excludes duplicate class based on complete roster and makes zero detail/write calls',
    () async {
      apiRespond = (r) {
        final data = serve(r);
        if (r.path.endsWith('/characters')) {
          ((data['items'] as List).first
                  as Map<String, dynamic>)['item_level'] =
              '1700.00';
        }
        return data;
      };
      access = const ScopedRefreshAccess(
        niceGroupEnabled: false,
        settingsVersion: 1,
        keyVersion: 1,
      );
      await run();
      expect(controller.excludedCount, 2);
      expect(armoryCalls, isEmpty);
      expect(apiCalls.where((r) => r.method == 'PUT'), isEmpty);
      expect(await db.select(db.scopedRoleRecords).get(), isEmpty);
    },
  );
  test(
    'uncertain role/catalog preserves both roles and produces incomplete detail results',
    () async {
      className = '바드';
      await run();
      expect(controller.savedCount, 0);
      expect(controller.incompleteCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
      expect(
        (await db.select(db.scopedRoleRecords).get()).every(
          (r) => jsonDecode(r.payload)['raw'] == null,
        ),
        isTrue,
      );
    },
  );
  test(
    'server write failure is local success with durable pending; server retry has no armory/key prerequisite',
    () async {
      failPut = true;
      await run();
      expect(controller.savedCount, 2);
      expect(controller.incompleteCount, 0);
      expect(controller.pendingServerCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), hasLength(2));
      access = const ScopedRefreshAccess(
        niceGroupEnabled: false,
        settingsVersion: 2,
      );
      signals.changed();
      failPut = false;
      await controller.retryServerSaved();
      expect(controller.pendingServerCount, 0);
      expect(armoryCalls, hasLength(2));
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'key invalidation during provider response prevents raw/outbox commit inside actual runtime',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      armoryRespond = (r) async {
        entered.complete();
        await release.future;
        return fixtures.armory(name: 'sample');
      };
      controller.initialize();
      final flight = controller.startIfReady();
      await entered.future;
      access = const ScopedRefreshAccess(
        niceGroupEnabled: true,
        settingsVersion: 1,
        keyVersion: 2,
      );
      signals.changed();
      release.complete();
      await flight;
      expect(controller.savedCount, 0);
      expect(controller.incompleteCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
      expect(
        (await db.select(db.scopedRoleRecords).get()).every(
          (r) => jsonDecode(r.payload)['raw'] == null,
        ),
        isTrue,
      );
    },
  );
  test(
    'registration changes after detail starts fail the A1 atomic observation fence',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      armoryRespond = (r) async {
        entered.complete();
        await release.future;
        return fixtures.armory(name: 'sample');
      };
      controller.initialize();
      final flight = controller.startIfReady();
      await entered.future;
      registrationVersion++;
      await runtime.refreshRegistrations();
      release.complete();
      await flight;
      expect(controller.savedCount, 0);
      expect(controller.incompleteCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
      expect(armoryCalls, hasLength(1));
    },
  );
  test(
    'provider identity mismatch does not write through to another canonical character',
    () async {
      armoryRespond = (r) => fixtures.armory(name: 'foreign-name');
      await run();
      expect(controller.savedCount, 0);
      expect(controller.incompleteCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
    },
  );
  test(
    'account command gate blocks initial run without IO or consuming once',
    () async {
      access = const ScopedRefreshAccess(
        niceGroupEnabled: true,
        settingsVersion: 1,
        keyVersion: 1,
        accountChangesPending: true,
      );
      await run();
      expect(controller.consumed, isFalse);
      expect(apiCalls, isEmpty);
      expect(armoryCalls, isEmpty);
      access = const ScopedRefreshAccess(
        niceGroupEnabled: true,
        settingsVersion: 1,
        keyVersion: 1,
      );
      signals.changed();
      await controller.startIfReady();
      expect(controller.savedCount, 2);
    },
  );
  test(
    'read invalidation without row changes cancels delayed automatic save',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      armoryRespond = (r) async {
        entered.complete();
        await release.future;
        return fixtures.armory(name: 'sample');
      };
      controller.initialize();
      final flight = controller.startIfReady();
      await entered.future;
      runtime.invalidateReads();
      signals.changed();
      expect(controller.isBusy, isFalse);
      release.complete();
      await flight;
      expect(controller.savedCount, 0);
      expect(controller.incompleteCount, 2);
      expect(await db.select(db.scopedRoleCommands).get(), isEmpty);
      expect(
        (await db.select(db.scopedRoleRecords).get()).every(
          (r) => jsonDecode(r.payload)['raw'] == null,
        ),
        isTrue,
      );
    },
  );
  test(
    'default-disabled runtime remains IO-free even with ready settings and key',
    () async {
      await runtime.close();
      var opens = 0;
      runtime = ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        databaseFactory: () {
          opens++;
          return ScopedAccountCacheDatabase(NativeDatabase.memory());
        },
      );
      source = RuntimeStartupRefreshSource(
        runtime: runtime,
        remote: source.remote,
        catalog: Catalog(),
        readAccess: () => access,
        changes: signals,
        cooldown: cooldown,
      );
      controller.dispose();
      controller = ScopedStartupRefreshController(source);
      await run();
      expect(controller.consumed, isFalse);
      expect(opens, 0);
      expect(apiCalls, isEmpty);
      expect(armoryCalls, isEmpty);
    },
  );
}
