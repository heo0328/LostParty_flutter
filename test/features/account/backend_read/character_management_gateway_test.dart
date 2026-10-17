import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/scoped_character_management_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/services/character_usage_level_policy.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_management_view_model.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart' as wire;

class NoLocalAccounts implements AccountRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Local account repository must not be used');
}

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late ScopedAccountCacheDatabase db;
  late ScopedAccountRuntime runtime;
  late ScopedCharacterManagementGateway gateway;
  late CharacterManagementViewModel model;
  late Map<String, dynamic> settings, presentation;
  late List<Map<String, dynamic>> items;
  late Map<String, Map<String, dynamic>> preferences;
  late List<RequestOptions> calls;
  late Map<String, Map<String, dynamic>> replays;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  bool main = true, owned = true, failGet = false;

  Map<String, dynamic> empty() => {
    'version': 1,
    'summary': null,
    'saved_at': null,
  };
  Map<String, dynamic> serve(RequestOptions r) {
    if (failGet && r.method == 'GET') throw DioException(requestOptions: r);
    if (r.path == '/v1/me/game-accounts') {
      return {
        'items': [
          {
            ...registrationJson(),
            'is_main': main,
            'ownership_status': owned ? 'owned' : 'ownership_lost',
            'settings': settings,
          },
        ],
        'next_cursor': null,
      };
    }
    if (r.path.endsWith('/characters')) {
      return {
        ...wire.roster(items: items),
        'settings': settings,
        'is_main': main,
      };
    }
    if (r.path.endsWith('/character-settings')) {
      final key = r.headers['Idempotency-Key'] as String;
      if (replays[key] case final existing?) return existing;
      final b = r.data as Map<String, dynamic>;
      if (b['expected_settings_version'] != settings['settings_version']) {
        throw DioException.badResponse(
          statusCode: 409,
          requestOptions: r,
          response: Response(
            requestOptions: r,
            statusCode: 409,
            data: {
              'error': {'code': 'REVISION_CONFLICT', 'request_id': 'cas'},
            },
          ),
        );
      }
      settings = {
        ...settings,
        'activity_character_ids': b['activity_character_ids'],
        'representative_character_id': b['representative_character_id'],
        'configuration_state': 'configured',
        'settings_version': (settings['settings_version'] as int) + 1,
      };
      return replays[key] = Map.of(settings);
    }
    if (r.path.endsWith('/presentation-settings')) {
      if (r.method == 'PUT') {
        final b = r.data as Map;
        presentation = {
          ...presentation,
          'version': b['expected_version'] + 1,
          'visible_count': b['visible_count'],
          'saved_at': DateTime.now().toUtc().toIso8601String(),
        };
      }
      return presentation;
    }
    final id = r.path.split('/')[4];
    if (r.path.endsWith('/personal-profile')) {
      return {
        'character_id': id,
        'game_account_id': wire.account,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
        'lifecycle_state': 'active',
        'dealer': empty(),
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
    if (r.path.endsWith('/personal-preferences')) {
      final b = r.data as Map;
      preferences[id] = {
        'version': b['expected_version'] + 1,
        'preferred_role': b['preferred_role'],
        'visible': b['visible'],
        'display_order': b['display_order'],
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      };
      return {
        ...preferences[id]!,
        'character_id': id,
        'ownership_revision': 1,
        'lifecycle_revision': 1,
      };
    }
    throw StateError('Unexpected ${r.method} ${r.path}');
  }

  setUp(() {
    main = owned = true;
    failGet = false;
    settings = {
      ...settingsJson(),
      'configuration_state': 'unconfigured',
      'activity_character_ids': <String>[],
      'representative_character_id': null,
    };
    items = [
      wire.item(),
      {
        ...wire.item(id: secondCharacterId, name: 'highest'),
        'item_level': '1750.00',
      },
    ];
    calls = [];
    replays = {};
    preferences = {};
    presentation = {
      'registration_id': registrationId,
      'game_account_id': wire.account,
      'registration_version': 1,
      'ownership_revision': 1,
      'version': 1,
      'visible_count': 6,
      'saved_at': null,
    };
    session = ReadSessionFake()..userId = wire.member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    respond = serve;
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
    final api = DioBackendAccountReadApi(dio, session);
    db = ScopedAccountCacheDatabase(NativeDatabase.memory());
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      enabled: true,
      databaseFactory: () => db,
      ownsDatabase: false,
    );
    gateway = ScopedCharacterManagementGateway(
      runtime,
      registrationId,
      otherWorkPending: () => false,
    );
    model = CharacterManagementViewModel(
      accountRepository: NoLocalAccounts(),
      managementGateway: gateway,
    );
  });
  tearDown(() async {
    model.dispose();
    gateway.dispose();
    await runtime.close();
    await db.close();
    dio.close();
    session.dispose();
  });
  List<RequestOptions> writes() =>
      calls.where((r) => r.path.endsWith('/character-settings')).toList();

  test(
    'initial highest is draft only; selected UUIDs and representative save atomically',
    () async {
      await model.initialize();
      expect(model.message, isNull);
      expect(
        model.selectedCharacters.single.serverCharacterId,
        secondCharacterId,
      );
      expect(model.draftRepresentativeId, model.selectedCharacters.single.id);
      expect(writes(), isEmpty);
      model.toggleActivity(
        model.rosterCharacters.firstWhere(
          (c) => c.serverCharacterId == characterId,
        ),
      );
      await model.save();
      expect(model.message, isNull);
      expect(writes(), hasLength(1));
      final b = writes().single.data as Map;
      expect(
        b['activity_character_ids'],
        containsAll([characterId, secondCharacterId]),
      );
      expect(b['representative_character_id'], secondCharacterId);
      expect(
        b.keys,
        unorderedEquals([
          'activity_character_ids',
          'representative_character_id',
          'expected_settings_version',
          'expected_ownership_revision',
          'expected_roster_revision',
        ]),
      );
      expect(
        model.account!.representativeCharacterId,
        model.draftRepresentativeId,
      );
      expect(model.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'existing representative and display preferences survive level reversal and save',
    () async {
      settings = settingsJson();
      preferences[characterId] = {
        'version': 2,
        'preferred_role': 'support',
        'visible': false,
        'display_order': 8,
        'saved_at': serverTime,
      };
      await model.initialize();
      expect(model.selectedCharacters.single.serverCharacterId, characterId);
      final rep = model.draftRepresentativeId;
      model.toggleActivity(
        model.rosterCharacters.firstWhere(
          (c) => c.serverCharacterId == secondCharacterId,
        ),
      );
      expect(model.draftRepresentativeId, rep);
      await model.save();
      expect(model.message, isNull);
      expect(settings['representative_character_id'], characterId);
      expect(preferences[characterId]!['visible'], isFalse);
      expect(preferences[characterId]!['preferred_role'], 'support');
      await model.initialize();
      expect(model.draftRepresentativeId, rep);
      expect(writes(), hasLength(1));
    },
  );

  test(
    'minimum and lifecycle eligibility are separate; old invalid selections are preserved',
    () async {
      settings = settingsJson();
      items[0] = {...items[0], 'item_level': '1699.99'};
      await model.initialize();
      expect(model.selectedCount, 1);
      expect(writes(), isEmpty);
      await model.save();
      expect(writes(), isEmpty);
      expect(settings['activity_character_ids'], [characterId]);
      final other = model.rosterCharacters.firstWhere(
        (c) => c.serverCharacterId == secondCharacterId,
      );
      model.toggleActivity(other);
      model.setRepresentative(other);
      model.toggleActivity(
        model.rosterCharacters.firstWhere(
          (c) => c.serverCharacterId == characterId,
        ),
      );
      await model.save();
      expect(model.message, isNull);
      expect(settings['activity_character_ids'], [secondCharacterId]);
    },
  );

  test(
    'lost ownership between editor load and save never sends a settings PUT',
    () async {
      await model.initialize();
      owned = false;
      await model.save();
      expect(writes(), isEmpty);
      expect(model.message, isNotNull);
    },
  );

  test(
    'lost response retries frozen UUID body/key even after page re-entry',
    () async {
      await model.initialize();
      var lose = true;
      respond = (r) {
        final result = serve(r);
        if (lose && r.path.endsWith('/character-settings')) {
          lose = false;
          throw DioException(requestOptions: r);
        }
        return result;
      };
      await model.save();
      expect(gateway.pending, isTrue);
      expect(model.canToggleActivity(model.rosterCharacters.first), isFalse);
      model.dispose();
      model = CharacterManagementViewModel(
        accountRepository: NoLocalAccounts(),
        managementGateway: gateway,
      );
      await model.initialize();
      await model.save();
      expect(gateway.pending, isFalse);
      expect(model.message, isNull);
      expect(writes(), hasLength(2));
      expect(
        writes()[0].headers['Idempotency-Key'],
        writes()[1].headers['Idempotency-Key'],
      );
      expect(jsonEncode(writes()[0].data), jsonEncode(writes()[1].data));
    },
  );

  test(
    'ACK followed by failed GET is not treated as a failed write or sent twice',
    () async {
      await model.initialize();
      respond = (r) {
        final result = serve(r);
        if (r.path.endsWith('/character-settings')) failGet = true;
        return result;
      };
      await model.save();
      expect(gateway.pending, isTrue);
      expect(model.account!.representativeCharacterId, isNull);
      failGet = false;
      respond = serve;
      await model.save();
      expect(model.message, isNull);
      expect(writes(), hasLength(1));
      expect(gateway.pending, isFalse);
    },
  );

  test(
    'preference failure retains activity ACK and durable pending preferences',
    () async {
      await model.initialize();
      var failPreference = true;
      respond = (r) {
        if (failPreference && r.path.endsWith('/personal-preferences')) {
          failPreference = false;
          throw DioException(requestOptions: r);
        }
        return serve(r);
      };
      await model.save();
      expect(gateway.pending, isTrue);
      expect(settings['representative_character_id'], secondCharacterId);
      await model.save();
      expect(model.message, isNull);
      expect(gateway.pending, isFalse);
      expect(writes(), hasLength(1));
    },
  );

  test(
    'a final reload failure retains the acknowledged command without another PUT',
    () async {
      await model.initialize();
      respond = (r) {
        final result = serve(r);
        if (r.method == 'PUT' && r.path.endsWith('/personal-preferences')) {
          // Default count is already 6, so the next full roster reload fails.
          failGet = true;
        }
        return result;
      };
      await model.save();
      expect(gateway.pending, isTrue);
      expect(settings['representative_character_id'], secondCharacterId);
      failGet = false;
      respond = serve;
      await model.save();
      expect(model.message, isNull);
      expect(writes(), hasLength(1));
    },
  );

  test(
    'historical ACK never overwrites a later representative or preferences',
    () async {
      await model.initialize();
      var lose = true;
      respond = (r) {
        final result = serve(r);
        if (lose && r.path.endsWith('/character-settings')) {
          lose = false;
          throw DioException(requestOptions: r);
        }
        return result;
      };
      await model.save();
      settings = {
        ...settings,
        'settings_version': 3,
        'representative_character_id': characterId,
        'activity_character_ids': [characterId],
      };
      await model.save();
      expect(model.message, isNotNull);
      expect(settings['representative_character_id'], characterId);
      expect(
        calls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/personal-preferences'),
        ),
        isEmpty,
      );
      await model.initialize();
      expect(model.selectedCharacters.single.serverCharacterId, characterId);
      expect(
        model.account!.representativeCharacterId,
        model.selectedCharacters.single.id,
      );
    },
  );

  test(
    'logout while PUT is running clears editor and blocks late personal writes',
    () async {
      await model.initialize();
      final entered = Completer<void>(), release = Completer<void>();
      respond = (r) async {
        if (r.path.endsWith('/character-settings')) {
          entered.complete();
          await release.future;
        }
        return serve(r);
      };
      final save = model.save();
      await entered.future;
      session.change(authenticated: false);
      expect(model.account, isNull);
      release.complete();
      await save;
      expect(
        calls.where(
          (r) => r.method == 'PUT' && r.path.endsWith('/personal-preferences'),
        ),
        isEmpty,
      );
      expect(runtime.characterSettingsBusy, isFalse);
      expect(model.canSave, isFalse);
    },
  );

  test(
    'shared lock prevents a second editor write and releases on failure',
    () async {
      await model.initialize();
      final owner = Object();
      runtime.lockCharacterSettings(owner);
      await model.save();
      expect(writes(), isEmpty);
      runtime.unlockCharacterSettings(owner);
      await model.save();
      expect(model.message, isNull);
      expect(runtime.characterSettingsBusy, isFalse);
    },
  );

  test(
    'sub-roster uses the same atomic setting API without changing main status',
    () async {
      main = false;
      await model.initialize();
      await model.save();
      expect(model.message, isNull);
      expect(model.account!.isMain, isFalse);
      expect(writes(), hasLength(1));
    },
  );

  test(
    'failed first GET never becomes an empty roster/initial representative',
    () async {
      failGet = true;
      await model.initialize();
      expect(model.account, isNull);
      expect(model.draftRepresentativeId, isNull);
      expect(writes(), isEmpty);
    },
  );

  test(
    'shared level policy rejects unknown and nonfinite values and includes 1700',
    () {
      const p = CharacterUsageLevelPolicy();
      for (final value in [
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        1699.99,
      ]) {
        expect(p.isInUsageRange(value), isFalse);
      }
      expect(p.isInUsageRange(1700), isTrue);
    },
  );
}
