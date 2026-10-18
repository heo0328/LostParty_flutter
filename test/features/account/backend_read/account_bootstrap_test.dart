import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/account_bootstrap.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_character_lifecycle.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_account_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';

import '../../../support/server_account_read_fakes.dart';
import 'member_account_integration_test.dart' show Catalog;
import 'member_weekly_test.dart' show WeeklyMemoryStore, catalogWire;
import 'scoped_startup_refresh_controller_test.dart' show FakeSource;

Map<String, dynamic> example([String key = 'owned_activity_defaults']) =>
    (jsonDecode(
              File(
                'test/fixtures/account_bootstrap/backend-8d03e962.examples.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>)[key]
        as Map<String, dynamic>;
Map<String, dynamic> registration(Map<String, dynamic> data) =>
    (data['registrations'] as List).single as Map<String, dynamic>;

void main() {
  test(
    'published complete examples decode without widening existing page limit',
    () {
      expect(
        AccountBootstrap.fromJson(example('empty')).registrations,
        isEmpty,
      );
      final json = example();
      final data = AccountBootstrap.fromJson(json);
      expect(data.registrations.single.profiles, hasLength(1));
      expect(data.weekly.entries, hasLength(5));
      final page = registration(json)['characters'] as Map<String, dynamic>;
      page['items'] = List.generate(
        51,
        (i) => {
          ...(page['items'] as List).first as Map<String, dynamic>,
          'character_id':
              '00000000-0000-4000-8000-${(100 + i).toString().padLeft(12, '0')}',
          'character_name': 'name$i',
        },
      );
      expect(
        () => LifecycleCharacterPage.fromJson(page),
        throwsFormatException,
      );
      expect(
        LifecycleCharacterPage.fromJson(page, maximumItems: 200).items,
        hasLength(51),
      );
    },
  );

  test(
    'incomplete, unknown, duplicate, missing and foreign nested data reject',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (j) => j['complete'] = false,
        (j) => j['unknown'] = true,
        (j) => j['registrations'] = [registration(j), registration(j)],
        (j) => registration(j)['personal_profiles'] = [],
        (j) =>
            (registration(j)['characters'] as Map)['next_cursor'] = 'partial',
        (j) =>
            ((registration(j)['personal_profiles'] as List).single
                    as Map)['game_account_id'] =
                'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        (j) => ((j['weekly_states'] as Map)['entries'] as List).add(
          ((j['weekly_states'] as Map)['entries'] as List).first,
        ),
        (j) =>
            ((j['weekly_states'] as Map)['entries'] as List)
                    .first['ownership_revision'] =
                9,
      ];
      for (final mutate in mutations) {
        final json = example();
        mutate(json);
        expect(() => AccountBootstrap.fromJson(json), throwsFormatException);
      }
    },
  );

  test(
    'unavailable is explicit and does not accept a missing usable profile',
    () {
      final json = example(), r = registration(json);
      final id = (r['personal_profiles'] as List).single['character_id'];
      r['personal_profiles'] = [];
      r['unavailable_characters'] = [
        {'character_id': id, 'code': 'IDENTITY_CONFLICT'},
      ];
      (json['weekly_states'] as Map)['entries'] = [];
      expect(() => AccountBootstrap.fromJson(json), throwsFormatException);
      final row = ((r['characters'] as Map)['items'] as List).single as Map;
      row['usable'] = false;
      row['blocked_reason'] = 'IDENTITY_CONFLICT';
      expect(
        AccountBootstrap.fromJson(json).registrations.single.unavailable[id],
        'IDENTITY_CONFLICT',
      );
    },
  );

  group('scoped import and live member/weekly connection', () {
    late ReadSessionFake session;
    late Dio dio;
    late ScopedAccountCacheDatabase db;
    late ScopedAccountRuntime runtime;
    late DioBackendAccountReadApi api;
    late List<RequestOptions> calls;
    late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
    late FakeSource source;
    late ScopedStartupRefreshController runner;
    late ChangeNotifier signals;
    late MemberAccountViewModel model;
    MemberWeeklyViewModel? weekly;
    setUp(() {
      session = ReadSessionFake()
        ..userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      calls = [];
      respond = (r) {
        if (r.path == '/v2/me/account-bootstrap') return example();
        if (r.path == '/v1/raid-catalog') return catalogWire();
        throw StateError('Unexpected request ${r.path}');
      };
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
                e is DioException
                    ? e
                    : DioException(requestOptions: r, error: e),
              );
            }
          },
        ),
      );
      api = DioBackendAccountReadApi(dio, session);
      db = ScopedAccountCacheDatabase(NativeDatabase.memory());
      runtime = ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        databaseFactory: () => db,
        enabled: true,
        bootstrapEnabled: true,
      );
      source = FakeSource();
      runner = ScopedStartupRefreshController(source);
      signals = ChangeNotifier();
      model = MemberAccountViewModel(
        runtime: runtime,
        runner: runner,
        catalog: Catalog(),
        gateChanges: signals,
        commandPending: () => false,
      );
      weekly = null;
    });
    tearDown(() async {
      weekly?.dispose();
      model.dispose();
      runner.dispose();
      source.dispose();
      signals.dispose();
      await runtime.close();
      session.dispose();
      dio.close();
    });

    test(
      'normal member restore and weekly consume one private GET; explicit weekly refresh is fresh',
      () async {
        weekly = MemberWeeklyViewModel(
          model: model,
          client: MemberRaidClient(api),
          store: WeeklyMemoryStore(),
          now: () => DateTime.utc(2026, 10, 18, 8),
        );
        weekly!.initialize();
        await model.refresh();
        for (var i = 0; i < 1000 && !weekly!.initialDisplaySettled; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(model.failure, isNull);
        expect(model.sections.single.cached, isFalse);
        expect(model.sections.single.characters.single.preferences, isNotNull);
        expect(model.sections.single.characters.single.dealer, isNotNull);
        expect(weekly!.failure, isNull);
        expect(weekly!.initialDisplaySettled, isTrue);
        for (final raid in weekly!.catalog!.raids) {
          expect(
            weekly!.entry(
              model.sections.single.characters.single.ref,
              raid.raidId,
            ),
            isNotNull,
          );
        }
        expect(
          calls
              .where(
                (r) =>
                    r.path.startsWith('/v2/') || r.path.startsWith('/v1/me/'),
              )
              .map((r) => r.path),
          ['/v2/me/account-bootstrap'],
        );
        expect(calls.where((r) => r.path == '/v1/raid-cycle'), isEmpty);
        // An explicit retry/refresh must not replay the old bootstrap observation.
        final oldRespond = respond;
        respond = (r) => r.path == '/v1/raid-cycle'
            ? (example()['weekly_states']
                      as Map<String, dynamic>)['current_cycle']
                  as Map<String, dynamic>
            : r.path == '/v1/me/raid-weekly-states'
            ? example()['weekly_states'] as Map<String, dynamic>
            : oldRespond(r);
        await weekly!.refresh();
        expect(
          calls.where((r) => r.path == '/v1/me/raid-weekly-states'),
          hasLength(1),
        );
      },
    );

    test(
      'pending preferences survive subsequent bootstrap, with no PUT',
      () async {
        final result = await runtime.restoreBootstrap();
        final r = result.data.registrations.single, p = r.profiles.single;
        final ref = ScopedRegistrationRef(
          runtime.scope,
          r.snapshot.registrationId,
        );
        final character = ScopedCharacterRef(
          runtime.scope,
          accountId: p.accountId,
          characterId: p.characterId,
        );
        // Existing preparation uses a current profile; fixture it without changing production writes.
        final old = respond;
        respond = (r) => r.path.endsWith('/personal-profile')
            ? (registration(example())['personal_profiles'] as List).single
                  as Map<String, dynamic>
            : old(r);
        final plan = await runtime.preparePersonalSettings(
          ref,
          character: character,
        );
        await runtime.saveCharacterPreferences(
          plan,
          PreferenceValues(visible: false, displayOrder: 7),
        );
        await runtime.restoreBootstrap();
        final state = await runtime.readCachedPersonalSettings(
          ref,
          character: character,
        );
        expect(state!.hasPending, isTrue);
        expect(state.preferences.visible, isFalse);
        expect(state.preferences.displayOrder, 7);
        expect(calls.where((r) => r.method != 'GET'), isEmpty);
        expect(
          await runtime.readCachedRoleBuild(
            ref,
            character,
            CharacterBuildRole.dealer,
          ),
          isNotNull,
        );
      },
    );

    test(
      'member change and generation invalidation discard delayed response before cache import',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        respond = (r) async {
          entered.complete();
          await release.future;
          return example();
        };
        final pending = runtime.restoreBootstrap();
        final rejected = expectLater(
          pending,
          throwsA(isA<AccountReadException>()),
        );
        await entered.future;
        runtime.invalidateReads();
        release.complete();
        await rejected;
        expect(runtime.bootstrap, isNull);
        expect(await runtime.readRegistrations(), isEmpty);
        final entered2 = Completer<void>(), release2 = Completer<void>();
        respond = (r) async {
          entered2.complete();
          await release2.future;
          return example();
        };
        final pending2 = runtime.restoreBootstrap();
        final rejected2 = expectLater(
          pending2,
          throwsA(isA<AccountReadException>()),
        );
        await entered2.future;
        session.change(
          authenticated: true,
          user: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        );
        release2.complete();
        await rejected2;
        expect(await runtime.readRegistrations(), isEmpty);
      },
    );

    test(
      'malformed snapshot leaves current roster intact and does not fall back silently',
      () async {
        await model.refresh();
        final old = respond;
        respond = (r) {
          if (r.path == '/v2/me/account-bootstrap') {
            return {...example(), 'complete': false};
          }
          return old(r);
        };
        calls.clear();
        await model.refresh();
        expect(model.failure, 'INVALID_RESPONSE');
        expect(model.sections.single.characters, hasLength(1));
        expect(calls, hasLength(1));
        expect(await runtime.readRegistrations(), hasLength(1));
      },
    );

    for (final code in [
      'NOT_FOUND',
      'BOOTSTRAP_LIMIT_EXCEEDED',
      'BOOTSTRAP_RESPONSE_TOO_LARGE',
    ]) {
      test('explicit unsupported/size fallback: $code', () async {
        final r = registration(example());
        respond = (request) {
          if (request.path == '/v2/me/account-bootstrap') {
            throw DioException.badResponse(
              statusCode: code == 'NOT_FOUND' ? 404 : 409,
              requestOptions: request,
              response: Response(
                requestOptions: request,
                statusCode: code == 'NOT_FOUND' ? 404 : 409,
                data: {
                  'error': {'code': code, 'request_id': 'bootstrap-test'},
                },
              ),
            );
          }
          if (request.path == '/v1/me/game-accounts') {
            return {
              'items': [r['registration']],
              'next_cursor': null,
            };
          }
          if (request.path.endsWith('/characters')) {
            return r['characters'] as Map<String, dynamic>;
          }
          if (request.path.endsWith('/representative')) {
            return r['representative'] as Map<String, dynamic>;
          }
          if (request.path.endsWith('/presentation-settings')) {
            return r['presentation'] as Map<String, dynamic>;
          }
          if (request.path.endsWith('/personal-profile')) {
            return (r['personal_profiles'] as List).single
                as Map<String, dynamic>;
          }
          throw StateError('Unexpected fallback request');
        };
        await model.refresh();
        expect(model.failure, isNull);
        expect(model.sections.single.characters.single.preferences, isNotNull);
        expect(
          calls.where((r) => r.path == '/v2/me/account-bootstrap'),
          hasLength(1),
        );
        expect(
          calls.where((r) => r.path == '/v1/me/game-accounts'),
          hasLength(1),
        );
      });
    }

    test('empty account is a complete read, not a fallback or write', () async {
      respond = (r) => example('empty');
      await model.refresh();
      expect(model.failure, isNull);
      expect(model.sections, isEmpty);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'GET');
      expect(runtime.bootstrap!.data.registrations, isEmpty);
    });

    test(
      'fresh bootstrap at the same generation replaces weekly observation',
      () async {
        final clock = DateTime.utc(2026, 10, 18, 8);
        weekly = MemberWeeklyViewModel(
          model: model,
          client: MemberRaidClient(api),
          store: WeeklyMemoryStore(),
          now: () => clock,
        );
        weekly!.initialize();
        await model.refresh();
        for (var i = 0; i < 1000 && !weekly!.initialDisplaySettled; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        final generation = runtime.readGeneration;
        final observed = runtime.bootstrap;
        calls.clear();
        await model.refresh();
        for (var i = 0; i < 1000 && weekly!.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(runtime.readGeneration, generation);
        expect(identical(observed, runtime.bootstrap), isFalse);
        expect(weekly!.failure, isNull);
        expect(weekly!.initialDisplaySettled, isTrue);
        expect(calls.map((r) => r.path), ['/v2/me/account-bootstrap']);
      },
    );
  });
}
