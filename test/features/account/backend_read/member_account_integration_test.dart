import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/app/backend_account_lifecycle.dart';
import 'package:lost_party/app/backend_member_account.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_lostark_key.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_settings_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_account_view_model.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/presentation/pages/member_account_page.dart';
import 'member_lostark_key_test.dart' as key_fixture;
import 'member_settings_test.dart' as settings_fixture;

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
  late BackendAccountLifecycle lifecycle;
  late BackendMemberAccount binding;
  late MemberAccountViewModel model;
  late MemberLostArkKey key;
  late MemberSettingsViewModel settingsModel;
  late key_fixture.KeyApi keyApi;
  late settings_fixture.SettingsApiFake settingsApi;
  late Map<String, Map<String, dynamic>> preferences;
  late Map<String, dynamic> presentation;

  late ScopedStartupRefreshController controller;

  late List<RequestOptions> apiCalls, armoryCalls;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) apiRespond,
      armoryRespond;
  late Map<String, Map<String, dynamic>> roleSummaries;
  late DateTime clock;
  int registrationVersion = 1, selectionVersion = 1;
  int rosterRevision = 2;
  late Map<String, Map<String, dynamic>> refreshReplies;
  String selectedRepresentative = characterId;
  String className = '버서커';
  bool failRoster = false, failPut = false;
  Map<String, dynamic> settings() => {
    ...settingsJson(),
    'settings_version': selectionVersion,
    'representative_character_id': selectedRepresentative,
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
    if (r.path.endsWith('/representative')) {
      if (r.method == 'PUT') {
        if (failPut) throw failure(r);
        final b = r.data as Map<String, dynamic>;
        selectedRepresentative = b['character_id'] as String;
        selectionVersion++;
      }
      return {
        'registration_id': registrationId,
        'game_account_id': account,
        'is_main': true,
        'registration_version': registrationVersion,
        'settings_version': selectionVersion,
        'ownership_revision': 1,
        'roster_revision': rosterRevision,
        'representative_character_id': selectedRepresentative,
        'configuration_state': 'configured',
        'next_change_at': null,
      };
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
    if (r.path.endsWith('/presentation-settings')) {
      if (r.method == 'GET') {
        return {...presentation, 'registration_version': registrationVersion};
      }
      if (failPut) throw failure(r);
      final b = r.data as Map<String, dynamic>;
      presentation = {
        ...presentation,
        'registration_version': registrationVersion,
        'version': presentation['version'] + 1,
        'visible_count': b['visible_count'],
        'saved_at': clock.toIso8601String(),
      };
      return presentation;
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
        'preferences':
            preferences[id] ??
            {
              'version': 1,
              'preferred_role': null,
              'visible': true,
              'display_order': null,
              'saved_at': null,
            },
      };
    }
    if (r.method == 'PUT' && r.path.endsWith('/personal-preferences')) {
      if (failPut) throw failure(r);
      final b = r.data as Map<String, dynamic>;
      preferences[id] = {
        'version': (b['expected_version'] as int) + 1,
        'preferred_role': b['preferred_role'],
        'visible': b['visible'],
        'display_order': b['display_order'],
        'saved_at': clock.toIso8601String(),
      };
      return {
        ...preferences[id]!,
        'character_id': id,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
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
    registrationVersion = selectionVersion = 1;
    rosterRevision = 2;
    refreshReplies = {};
    selectedRepresentative = characterId;
    className = '버서커';
    failRoster = failPut = false;
    roleSummaries = {};
    preferences = {};
    presentation = {
      'registration_id': registrationId,
      'game_account_id': account,
      'registration_version': 1,
      'ownership_revision': 1,
      'version': 1,
      'visible_count': 6,
      'saved_at': null,
    };
    apiCalls = [];
    armoryCalls = [];
    signals = Signals();

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
    lifecycle = BackendAccountLifecycle(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () => db,
      enabled: true,
    );
    runtime = lifecycle.runtime!;
    keyApi = key_fixture.KeyApi()..token = key_fixture.jwt;
    key = MemberLostArkKey(
      keyApi,
      session,
      key_fixture.DeviceStore(),
      key_fixture.GuestStore(),
      cooldown,
    );
    settingsApi = settings_fixture.SettingsApiFake();
    settingsApi.current['nice_group_auto_refresh_enabled'] = true;
    settingsModel = MemberSettingsViewModel(settingsApi, session);
    binding = BackendMemberAccount(
      lifecycle: lifecycle,
      settings: settingsModel,
      key: key,
      remote: LostArkCharacterRemoteDataSource(
        apiClient: LostArkApiClient(
          apiTokenStore: key,
          dio: provider,
          cooldown: cooldown,
          scopeIdentity: () =>
              (session.userId, session.generation, key.value?.version),
        ),
      ),
      catalog: Catalog(),
      cooldown: cooldown,
    );
    model = binding.model;
    controller = binding.runner;
  });
  tearDown(() async {
    binding.dispose();
    key.dispose();
    settingsModel.dispose();
    await lifecycle.close();
    session.dispose();
    signals.dispose();
    cooldown.dispose();
    backend.close();
    provider.close();
  });
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 1000; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('Member work did not settle: ${model.failure}, ${controller.failure}');
  }

  Future<void> run() async {
    await until(() => !key.busy && !settingsModel.busy);
    binding.initialize();
    await controller.startIfReady();
    await model.refresh();
    await until(() => !model.loading && !controller.isBusy);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await until(() => !model.loading && !controller.isBusy);
  }

  test(
    'app binding shares roster preparation; full checks and profile restore converge',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      apiRespond = (r) async {
        if (r.path == '/v1/me/game-accounts' && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      binding.initialize();
      await entered.future;
      final joined = runtime.loadMemberRoster();
      final fenced = expectLater(
        joined,
        throwsA(
          anyOf(isA<ScopedCacheException>(), isA<AccountReadException>()),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        apiCalls.where((r) => r.path == '/v1/me/game-accounts'),
        hasLength(2), // Provider preparation then the shared current read.
      );
      release.complete();
      await fenced;
      await run();
      expect(controller.savedCount, 2);
      expect(armoryCalls, hasLength(2));
      expect(model.failure, isNull);
      expect(model.sections.single.displayReady, isTrue);
      for (final row in model.sections.single.characters) {
        expect(row.failure, isNull);
        expect(row.dealer!.rawMatchesDisplay, isTrue);
        expect(row.dealer!.hasPending, isFalse);
      }
      await model.refresh();
      await controller.startIfReady();
      expect(armoryCalls, hasLength(2));
    },
  );

  test(
    'missing key restores member preferences but never consumes automatic inspection',
    () async {
      keyApi.token = null;
      await key.reload();
      await run();
      expect(controller.consumed, isFalse);
      expect(armoryCalls, isEmpty);
      expect(model.sections.single.displayReady, isTrue);
      expect(
        model.sections.single.characters.every(
          (r) => r.dealer?.rawMatchesDisplay == false,
        ),
        isTrue,
      );
    },
  );

  test(
    'NiceGroup OFF preserves summaries, excludes full inspection and restores hidden preferences',
    () async {
      settingsApi.current['nice_group_auto_refresh_enabled'] = false;
      await settingsModel.reload();
      apiRespond = (r) {
        final result = serve(r);
        if (r.path.endsWith('/characters')) {
          for (final item in result['items'] as List) {
            item['item_level'] = '1700.00';
          }
        }
        return result;
      };
      preferences[secondCharacterId] = {
        'version': 2,
        'preferred_role': null,
        'visible': false,
        'display_order': 0,
        'saved_at': clock.toIso8601String(),
      };
      await run();
      expect(controller.consumed, isTrue);
      expect(controller.excludedCount, 2);
      expect(
        model.representativeChoice(
          runtime.reference(registrationId),
          model.sections.single.characters.last.ref,
        ),
        isNull,
      );
      expect(armoryCalls, isEmpty);
      expect(
        model.failure,
        isNull,
        reason: 'Suspect roster must remain readable',
      );
      expect(model.sections.single.characters, hasLength(2));
      expect(model.sections.single.visible, hasLength(1));
    },
  );

  test(
    'preference commits locally before failed PUT and explicit retry keeps exact command',
    () async {
      keyApi.token = null;
      await key.reload();
      await run();
      final row = model.sections.single.characters.first;
      final reg = runtime.reference(registrationId);
      final entered = Completer<void>(), release = Completer<void>();
      failPut = true;
      apiRespond = (r) async {
        if (r.method == 'PUT' && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      final save = model.savePreferences(
        reg,
        row.ref,
        PreferenceValues(visible: false, displayOrder: 9),
      );
      await entered.future;
      expect(
        model.character(row.ref)!.preferences!.preferences.visible,
        isFalse,
      );
      expect(model.character(row.ref)!.preferences!.hasPending, isTrue);
      release.complete();
      await save;
      final first = apiCalls.lastWhere((r) => r.method == 'PUT');
      expect(model.character(row.ref)!.preferences!.hasPending, isTrue);
      failPut = false;
      await model.resolveSettings(reg, ref: row.ref);
      final replay = apiCalls.lastWhere((r) => r.method == 'PUT');
      expect(replay.data, first.data);
      expect(
        replay.headers['Idempotency-Key'],
        first.headers['Idempotency-Key'],
      );
      expect(model.failure, isNull);
      expect(
        model.character(row.ref)!.preferences!.hasPending,
        isFalse,
        reason: model.character(row.ref)!.preferences!.command?.errorCode,
      );
      expect(armoryCalls, isEmpty);
    },
  );

  test(
    'logout clears private rows synchronously and rejects late profile completion',
    () async {
      keyApi.token = null;
      await key.reload();
      await run();
      final entered = Completer<void>(), release = Completer<void>();
      apiRespond = (r) async {
        if (r.path.endsWith('/personal-profile') && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      final restore = model.refresh();
      await entered.future;
      session.change(authenticated: false);
      expect(model.sections, isEmpty);
      release.complete();
      await restore;
      expect(model.sections, isEmpty);
      expect(model.signedIn, isFalse);
    },
  );

  test(
    'profile failure leaves unresolved settings explicit instead of inventing defaults',
    () async {
      keyApi.token = null;
      await key.reload();
      apiRespond = (r) {
        if (r.path.endsWith('/personal-profile')) throw failure(r);
        return serve(r);
      };
      await run();
      final section = model.sections.single;
      expect(section.displayReady, isFalse);
      expect(
        section.characters.every(
          (r) => r.preferences == null && r.failure != null,
        ),
        isTrue,
      );
      expect(armoryCalls, isEmpty);
    },
  );

  test(
    'per-character upload resolution updates batch pending count without more Armory',
    () async {
      failPut = true;
      await run();
      expect(controller.pendingServerCount, 2);
      final row = model.sections.single.characters.first;
      failPut = false;
      await model.resolveRole(
        runtime.reference(registrationId),
        row.ref,
        CharacterBuildRole.dealer,
      );
      expect(model.character(row.ref)!.dealer!.hasPending, isFalse);
      expect(controller.pendingServerCount, 1);
      expect(armoryCalls, hasLength(2));
    },
  );

  test(
    'command gate invalidates a pending write ACK while retaining its durable command',
    () async {
      keyApi.token = null;
      await key.reload();
      await run();
      final row = model.sections.single.characters.first;
      final entered = Completer<void>(), release = Completer<void>();
      apiRespond = (r) async {
        if (r.method == 'PUT' && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      final saving = model.savePreferences(
        runtime.reference(registrationId),
        row.ref,
        PreferenceValues(displayOrder: 2),
      );
      await entered.future;
      lifecycle.model!.beginCommand();
      release.complete();
      await saving;
      final retained = await runtime.readCachedPersonalSettings(
        runtime.reference(registrationId),
        character: row.ref,
      );
      expect(retained!.hasPending, isTrue);
      expect(model.canEdit, isFalse);
      await lifecycle.model!.finishCommand();
      await model.refresh();
      expect(model.character(row.ref)!.preferences!.hasPending, isTrue);
      expect(armoryCalls, isEmpty);
    },
  );

  test(
    'representative double submit sends only representative fields and reloads confirmed ordering',
    () async {
      await run();
      final reg = runtime.reference(registrationId);
      final ref = model.sections.single.characters.last.ref;
      final choice = model.representativeChoice(reg, ref)!;
      final originalActivity =
          model.sections.single.registration.settings.activityIds;
      await Future.wait([
        model.changeRepresentative(choice),
        model.changeRepresentative(choice),
      ]);
      final puts = apiCalls
          .where((r) => r.method == 'PUT' && r.path.endsWith('/representative'))
          .toList();
      expect(puts, hasLength(1));
      expect((puts.single.data as Map).keys.toSet(), {
        'character_id',
        'expected_registration_version',
        'expected_settings_version',
        'expected_ownership_revision',
        'expected_roster_revision',
      });
      expect(
        model.representative(registrationId)?.characterId,
        secondCharacterId,
      );
      expect(
        model.sections.single.visible.first.ref.characterId,
        secondCharacterId,
      );
      expect(
        model.sections.single.registration.settings.activityIds,
        originalActivity,
      );
      expect(armoryCalls, hasLength(2));
    },
  );

  test(
    'lost representative response preserves crown; retry reuses key and body and obeys Retry-After',
    () async {
      await run();
      final reg = runtime.reference(registrationId);
      final choice = model.representativeChoice(
        reg,
        model.sections.single.characters.last.ref,
      )!;
      var fail = true;
      apiRespond = (r) {
        if (r.method == 'PUT' && r.path.endsWith('/representative') && fail) {
          throw DioException.badResponse(
            statusCode: 409,
            requestOptions: r,
            response: Response(
              requestOptions: r,
              statusCode: 409,
              headers: Headers.fromMap({
                'retry-after': ['2'],
              }),
              data: {
                'error': {'code': 'REQUEST_IN_PROGRESS'},
              },
            ),
          );
        }
        return serve(r);
      };
      await model.changeRepresentative(choice);
      expect(model.representativePending(registrationId), isTrue);
      expect(model.representative(registrationId)?.characterId, characterId);
      expect(
        model.representativeChoice(
          reg,
          model.sections.single.characters.first.ref,
        ),
        isNull,
      );
      await model.retryRepresentative(reg);
      expect(
        apiCalls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
        ),
        hasLength(1),
      );
      clock = clock.add(const Duration(seconds: 3));
      fail = false;
      await model.retryRepresentative(reg);
      final puts = apiCalls
          .where((r) => r.method == 'PUT' && r.path.endsWith('/representative'))
          .toList();
      expect(puts, hasLength(2));
      expect(
        puts[0].headers['Idempotency-Key'],
        puts[1].headers['Idempotency-Key'],
      );
      expect(puts[0].data, puts[1].data);
      expect(model.representativePending(registrationId), isFalse);
      expect(
        model.representative(registrationId)?.characterId,
        secondCharacterId,
      );
    },
  );

  test(
    'changed settings after confirmation and old member choice never write',
    () async {
      await run();
      final choice = model.representativeChoice(
        runtime.reference(registrationId),
        model.sections.single.characters.last.ref,
      )!;
      selectionVersion++;
      await model.changeRepresentative(choice);
      expect(
        apiCalls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
        ),
        isEmpty,
      );
      final fresh = model.representativeChoice(
        runtime.reference(registrationId),
        model.sections.single.characters.last.ref,
      )!;
      session.change(authenticated: false);
      await model.changeRepresentative(fresh);
      expect(
        apiCalls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'late representative response cannot restore signed out member state',
    () async {
      await run();
      final choice = model.representativeChoice(
        runtime.reference(registrationId),
        model.sections.single.characters.last.ref,
      )!;
      final entered = Completer<void>(), release = Completer<void>();
      apiRespond = (r) async {
        if (r.method == 'PUT' && r.path.endsWith('/representative')) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      final saving = model.changeRepresentative(choice);
      await entered.future;
      session.change(authenticated: false);
      release.complete();
      await saving;
      expect(model.sections, isEmpty);
      expect(model.representative(registrationId), isNull);
      expect(model.representativePending(registrationId), isFalse);
    },
  );

  test(
    'representative unavailability does not break role restore and blocks unsafe writes',
    () async {
      apiRespond = (r) {
        if (r.path.endsWith('/representative')) throw failure(r);
        return serve(r);
      };
      await run();
      final row = model.sections.single.characters.last;
      expect(row.dealer?.displaySummary, isNotNull);
      expect(
        model.representativeChoice(runtime.reference(registrationId), row.ref),
        isNull,
      );
      expect(model.representativeFailure(registrationId), isNotNull);
    },
  );

  test(
    'confirmed GET resolves a committed write whose response was lost without replay',
    () async {
      await run();
      final choice = model.representativeChoice(
        runtime.reference(registrationId),
        model.sections.single.characters.last.ref,
      )!;
      apiRespond = (r) {
        final result = serve(r);
        if (r.method == 'PUT' && r.path.endsWith('/representative')) {
          throw failure(r);
        }
        return result;
      };
      await model.changeRepresentative(choice);
      expect(model.representativePending(registrationId), isTrue);
      expect(model.representative(registrationId)?.characterId, characterId);
      await model.refresh();
      expect(model.representativePending(registrationId), isFalse);
      expect(
        model.representative(registrationId)?.characterId,
        secondCharacterId,
      );
      expect(
        apiCalls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'a displayed but unusable or unselected character has no representative command',
    () async {
      apiRespond = (r) {
        final result = serve(r);
        if (r.path.endsWith('/characters')) {
          final rows = result['items'] as List;
          rows[1] = <String, dynamic>{
            ...rows[1] as Map<String, dynamic>,
            'usable': false,
            'blocked_reason': 'CHARACTER_UNUSABLE',
            'lifecycle_state': 'suspect',
            'roster_status': 'suspect',
            'eligible': false,
          };
        }
        return result;
      };
      keyApi.token = null;
      await key.reload();
      await run();
      expect(
        model.failure,
        isNull,
        reason: 'Suspect roster must remain readable',
      );
      expect(model.sections.single.characters, hasLength(2));
      final reg = runtime.reference(registrationId);
      expect(
        model.representativeChoice(
          reg,
          model.sections.single.characters.last.ref,
        ),
        isNull,
      );
      expect(
        model.representativeChoice(
          reg,
          model.sections.single.characters.first.ref,
        ),
        isNull,
      );
      expect(
        apiCalls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets('representative confirmation cannot write after member change', (
    tester,
  ) async {
    await tester.runAsync(run);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberAccountPage(
          model: model,
          settings: settingsModel,
          onSettings: () {},
          onKey: () {},
          onVerify: () {},
          onManage: () {},
          onHistory: () {},
          onServerStatus: (_) {},
        ),
      ),
    );
    final crown = find.byTooltip('second을 대표 캐릭터로 변경');
    await tester.ensureVisible(crown);
    await tester.tap(crown);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('취소')).dx,
      lessThan(tester.getCenter(find.text('변경')).dx),
    );
    session.change(authenticated: false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '변경'))
          .onPressed,
      isNull,
    );
    expect(
      apiCalls.where(
        (r) => r.method == 'PUT' && r.path.endsWith('/representative'),
      ),
      isEmpty,
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an open preference dialog cannot approve a different member session',
    (tester) async {
      await tester.runAsync(() async {
        keyApi.token = null;
        await key.reload();
        await run();
      });
      final row = model.sections.single.characters.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editMemberPreferences(
                  context,
                  model,
                  runtime.reference(registrationId),
                  row,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final cancel = tester.getCenter(find.text('취소'));
      final accept = tester.getCenter(find.text('변경'));
      expect(cancel.dx, lessThan(accept.dx));
      session.change(authenticated: false);
      await tester.tap(find.text('변경'));
      await tester.pumpAndSettle();
      expect(apiCalls.where((r) => r.method == 'PUT'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'disposing a member page leaves app runner alive and detail view reads only member raw',
    (tester) async {
      await tester.runAsync(run);
      final row = model.sections.single.characters.first;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberCharacterPage(
            model: model,
            registration: runtime.reference(registrationId),
            ref: row.ref,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text('sample'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await model.refresh();
        await controller.startIfReady();
      });
      expect(controller.consumed, isTrue);
      expect(armoryCalls, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
