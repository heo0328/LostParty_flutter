import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/repositories/scoped_character_cache_repository.dart';
import 'package:lost_party/features/account/data/server_character_lifecycle_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_character_lifecycle.dart';

import '../../../support/server_account_read_fakes.dart';

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const account = '44444444-4444-4444-8444-444444444444';
const historyId = '55555555-5555-4555-8555-555555555555';
const rosterPath = '/v2/me/game-accounts/$registrationId/characters';
const historyPath = '/v2/me/character-retirements';
Map<String, dynamic> item({String id = characterId, String name = 'sample'}) =>
    {
      ...characterJson(id: id, name: name),
      'lifecycle_state': 'active',
      'lifecycle_revision': 1,
      'usable': true,
      'blocked_reason': null,
    };
Map<String, dynamic> roster({String? cursor, List<dynamic>? items}) => {
  'registration_id': registrationId,
  'game_account_id': account,
  'is_main': true,
  'registration_version': 1,
  'ownership_status': 'owned',
  'ownership_revision': 1,
  'roster_revision': 2,
  'settings': settingsJson(),
  'items': items ?? [item()],
  'next_cursor': cursor,
  'server_fetched_at': serverTime,
};
Map<String, dynamic> retirement({String id = historyId}) => {
  'history_id': id,
  'character_id': characterId,
  'game_account_id': account,
  'server_name': 'sample-server',
  'character_name': 'sample',
  'class_name': 'sample-class',
  'combat_power': null,
  'item_level': '1700.00',
  'power_fetched_at': null,
  'item_level_fetched_at': serverTime,
  'retired_at': serverTime,
  'lifecycle_revision': 2,
};
Map<String, dynamic> history({
  String? cursor,
  int revision = 1,
  List<dynamic>? items,
}) => {
  'items': items ?? [retirement()],
  'next_cursor': cursor,
  'history_revision': revision,
};
Matcher error(String code) =>
    throwsA(isA<AccountReadException>().having((e) => e.code, 'code', code));

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late ScopedAccountCacheDatabase db;
  late ScopedCharacterCacheRepository cache;
  late ServerCharacterLifecycleClient client;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  late List<RequestOptions> calls;
  setUp(() {
    session = ReadSessionFake()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    calls = [];
    respond = (options) => options.path == '/v1/me/game-accounts'
        ? registrationPageJson()
        : options.path == historyPath
        ? history()
        : roster();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          calls.add(options);
          try {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: await respond(options),
              ),
            );
          } catch (e) {
            handler.reject(
              e is DioException
                  ? e
                  : DioException(requestOptions: options, error: e),
            );
          }
        },
      ),
    );
    db = ScopedAccountCacheDatabase(NativeDatabase.memory());
    cache = ScopedCharacterCacheRepository(
      db,
      session,
      baseUrl: dio.options.baseUrl,
    );
    client = ServerCharacterLifecycleClient(
      DioBackendAccountReadApi(dio, session),
    );
  });
  tearDown(() async {
    client.dispose();
    cache.dispose();
    session.dispose();
    dio.close();
    await db.close();
  });
  ScopedRegistrationRef ref() =>
      ScopedRegistrationRef(cache.scope, registrationId);
  Future<void> prepare() => client.refreshRegistrations(cache);

  test(
    'all four DTO shapes match pinned OpenAPI and reject each missing or extra property',
    () {
      final spec = jsonDecode(
        File(
          'docs/backend-migration/contracts/issue8-c91af2e.openapi.json',
        ).readAsStringSync(),
      );
      final fixtures = <String, Map<String, dynamic>>{
        'LifecycleCharacterOut': item(),
        'LifecycleCharactersOut': roster(),
        'RetirementOut': retirement(),
        'RetirementPage': history(),
      };
      final decoders = <String, void Function(Map<String, dynamic>)>{
        'LifecycleCharacterOut': LifecycleCharacter.fromJson,
        'LifecycleCharactersOut': LifecycleCharacterPage.fromJson,
        'RetirementOut': CharacterRetirement.fromJson,
        'RetirementPage': CharacterRetirementPage.fromJson,
      };
      for (final entry in fixtures.entries) {
        expect(
          entry.value.keys.toSet(),
          (spec['components']['schemas'][entry.key]['required'] as List)
              .toSet(),
        );
        decoders[entry.key]!(entry.value);
        for (final key in entry.value.keys) {
          expect(
            () => decoders[entry.key]!(Map.of(entry.value)..remove(key)),
            throwsFormatException,
            reason: '${entry.key}.$key',
          );
        }
        expect(
          () => decoders[entry.key]!({...entry.value, 'extra': true}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'strict nullable, types, enums, UTC/calendar, IDs and positive revisions',
    () {
      final invalid = [
        {'is_main': 1},
        {'registration_version': 0},
        {'ownership_revision': 0},
        {'roster_revision': '2'},
        {'registration_id': 'local-1'},
        {'ownership_status': 'verified'},
        {'game_account_id': null},
        {'items': null},
        {'next_cursor': ''},
        {'server_fetched_at': '2026-02-30T00:00:00Z'},
        {'server_fetched_at': '2026-10-14T00:00:00'},
      ];
      for (final change in invalid) {
        expect(
          () => LifecycleCharacterPage.fromJson({...roster(), ...change}),
          throwsFormatException,
        );
      }
      for (final change in [
        {'lifecycle_state': 'unknown'},
        {'lifecycle_revision': null},
        {'lifecycle_revision': 0},
        {'usable': 'true'},
        {'lifecycle_state': 'suspect'},
        {'blocked_reason': 'UNKNOWN'},
        {'power_stale': null},
        {'character_level': '70'},
        {'combat_power': double.nan},
      ]) {
        expect(
          () => LifecycleCharacter.fromJson({...item(), ...change}),
          throwsFormatException,
        );
      }
      expect(
        () => CharacterRetirement.fromJson(retirement()..['retired_at'] = null),
        throwsFormatException,
      );
      expect(
        () => CharacterRetirementPage.fromJson(
          history()..['history_revision'] = 0,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'observation raw strings/nulls are retained and wire is deeply immutable',
    () {
      final wire = roster();
      final parsed = LifecycleCharacterPage.fromJson(wire);
      final c = parsed.items.single;
      (wire['items'] as List).clear();
      expect(parsed.items, hasLength(1));
      expect(c.wire['item_level'], '1700.00');
      expect(c.wire['combat_power'], isNull);
      expect(() => c.wire['usable'] = false, throwsUnsupportedError);
      expect(
        () => (parsed.settingsWire['activity_character_ids'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('existing SettingsOut optional true default stays compatible', () {
    final data = roster();
    (data['settings'] as Map).remove('selection_complete');
    expect(
      LifecycleCharacterPage.fromJson(data).settings.selectionComplete,
      isTrue,
    );
  });

  test(
    'Bearer GET and complete two-page roster maps atomically to S1 receipt',
    () async {
      await prepare();
      respond = (r) => r.queryParameters['cursor'] == null
          ? roster(cursor: 'page-2')
          : roster(
              items: [item(id: secondCharacterId, name: 'second')],
            );
      final receipt = await client.refreshRoster(cache, ref());
      final view = (await cache.readRoster(ref(), receipt: receipt))!;
      expect(view.validated, isTrue);
      expect(view.complete, isTrue);
      expect(view.characters, hasLength(2));
      expect(view.registration.sourceContract, lifecycleContract);
      expect(view.registration.label, 'sample-account');
      for (final request in calls.where((r) => r.path == rosterPath)) {
        expect(request.method, 'GET');
        expect(request.data, isNull);
        expect(request.headers['Authorization'], 'Bearer test-access');
        expect(request.queryParameters['limit'], 50);
        expect(
          request.queryParameters.keys.toSet().difference({'cursor', 'limit'}),
          isEmpty,
        );
      }
      expect(calls.last.queryParameters['cursor'], 'page-2');
    },
  );

  test(
    'power and observation timestamps may differ across structural pages',
    () async {
      await prepare();
      respond = (r) =>
          r.queryParameters['cursor'] == null
                ? roster(cursor: 'p2')
                : roster(
                    items: [
                      item(id: secondCharacterId, name: 'second')..addAll({
                        'combat_power': '123.45',
                        'power_stale': false,
                        'power_status': 'available',
                        'power_fetched_at': '2026-10-15T00:00:00Z',
                        'power_checked_at': '2026-10-15T00:00:00Z',
                      }),
                    ],
                  )
            ..['server_fetched_at'] = '2026-10-15T00:00:00Z';
      await client.refreshRoster(cache, ref());
      final view = (await cache.readRoster(ref()))!;
      expect(view.characters, hasLength(2));
      expect(view.characters.last.profileJson, contains('123.45'));
    },
  );

  test(
    'preview uses documented registration generation and suppresses cached power without canonical ID',
    () async {
      respond = (r) {
        if (r.path == '/v1/me/game-accounts') {
          return {
            'items': [
              registrationJson()..addAll({
                'game_account_id': null,
                'ownership_status': 'unverified',
                'ownership_revision': null,
                'roster_revision': null,
                'settings': settingsJson(),
              }),
            ],
            'next_cursor': null,
          };
        }
        return roster(
          items: [
            item()..addAll({
              'character_id': null,
              'lifecycle_state': 'preview',
              'lifecycle_revision': null,
              'roster_status': 'preview',
              'last_confirmed_at': null,
              'requires_refresh': true,
              'eligible': false,
              'usable': false,
              'blocked_reason': 'OWNERSHIP_REQUIRED',
              'power_stale': false,
              'combat_power': '123.45',
              'power_status': 'available',
            }),
          ],
        )..addAll({
          'game_account_id': null,
          'ownership_status': 'unverified',
          'ownership_revision': null,
          'roster_revision': 1,
        });
      };
      await prepare();
      expect(await client.refreshRoster(cache, ref()), isNull);
      final view = (await cache.readRoster(ref()))!;
      expect(view.characters, isEmpty);
      expect(view.registration.displayJson, isNot(contains('123.45')));
      expect(view.registration.displayJson, contains('"usable":false'));
    },
  );

  test(
    'ownership-lost preview cannot manufacture canonical characters or a grant',
    () async {
      respond = (r) {
        if (r.path == '/v1/me/game-accounts') {
          return {
            'items': [
              registrationJson()..['ownership_status'] = 'ownership_lost',
            ],
            'next_cursor': null,
          };
        }
        return roster(
          items: [
            item()..addAll({
              'character_id': null,
              'lifecycle_revision': null,
              'lifecycle_state': 'preview',
              'usable': false,
              'eligible': false,
              'requires_refresh': true,
              'roster_status': 'preview',
              'blocked_reason': 'OWNERSHIP_REQUIRED',
            }),
          ],
        )..['ownership_status'] = 'ownership_lost';
      };
      await prepare();
      await client.refreshRoster(cache, ref());
      expect((await cache.readRoster(ref()))!.characters, isEmpty);
    },
  );

  test(
    'partial failure preserves complete cache and invalidates old receipt',
    () async {
      await prepare();
      final receipt = await client.refreshRoster(cache, ref());
      respond = (r) => r.queryParameters['cursor'] == null
          ? roster(cursor: 'p2')
          : <String, dynamic>{'bad': true};
      await expectLater(
        client.refreshRoster(cache, ref()),
        error('INVALID_RESPONSE'),
      );
      final view = (await cache.readRoster(ref(), receipt: receipt))!;
      expect(view.characters, hasLength(1));
      expect(view.complete, isTrue);
      expect(view.validated, isFalse);
    },
  );

  for (final field in [
    'is_main',
    'registration_version',
    'game_account_id',
    'ownership_status',
    'ownership_revision',
    'roster_revision',
    'settings',
  ]) {
    test('changed $field on later page rejects entire batch', () async {
      await prepare();
      final changes = <String, dynamic>{
        'is_main': false,
        'registration_version': 2,
        'game_account_id': historyId,
        'ownership_status': 'ownership_lost',
        'ownership_revision': 2,
        'roster_revision': 3,
        'settings': settingsJson()..['settings_version'] = 2,
      };
      respond = (r) {
        if (r.queryParameters['cursor'] == null) return roster(cursor: 'p2');
        final data = roster(items: []);
        data[field] = changes[field];
        return data;
      };
      await expectLater(
        client.refreshRoster(cache, ref()),
        error('CURSOR_STALE'),
      );
      expect((await cache.readRoster(ref()))!.complete, isFalse);
    });
  }

  test('same version with changed ineligible settings is also stale', () async {
    await prepare();
    respond = (r) {
      if (r.queryParameters['cursor'] == null) return roster(cursor: 'p2');
      return roster(items: [])
        ..['settings'] = (settingsJson()
          ..['ineligible_character_ids'] = [characterId]);
    };
    await expectLater(
      client.refreshRoster(cache, ref()),
      error('CURSOR_STALE'),
    );
  });

  test(
    'metadata mismatch demands fresh registrations rather than overwrite',
    () async {
      await prepare();
      respond = (_) => roster()..['registration_version'] = 2;
      await expectLater(
        client.refreshRoster(cache, ref()),
        error('REVISION_CONFLICT'),
      );
      expect((await cache.readRoster(ref()))!.complete, isFalse);
    },
  );

  for (final mode in [
    'duplicate-id',
    'duplicate-name',
    'repeated-cursor',
    'empty-following',
    'wrong-registration',
    'overflow',
  ]) {
    test('$mode is rejected without partial DB writes', () async {
      await prepare();
      respond = (r) {
        if (mode == 'wrong-registration') {
          return roster()..['registration_id'] = historyId;
        }
        if (mode == 'overflow') {
          final page = calls.where((c) => c.path == rosterPath).length;
          return roster(
            cursor: 'p$page',
            items: List.generate(
              50,
              (i) => item(
                id: '${(page * 100 + i).toRadixString(16).padLeft(8, '0')}-2222-4222-8222-222222222222',
                name: '$page-$i',
              ),
            ),
          );
        }
        if (r.queryParameters['cursor'] == null) return roster(cursor: 'p2');
        return switch (mode) {
          'duplicate-id' => roster(items: [item(name: 'other')]),
          'duplicate-name' => roster(items: [item(id: secondCharacterId)]),
          'empty-following' => roster(cursor: 'p3', items: []),
          _ => roster(
            cursor: 'p2',
            items: [item(id: secondCharacterId, name: 'other')],
          ),
        };
      };
      await expectLater(
        client.refreshRoster(cache, ref()),
        error('INVALID_RESPONSE'),
      );
      expect((await cache.readRoster(ref()))!.complete, isFalse);
    });
  }

  test(
    'member switch during request blocks late result and no roster is written',
    () async {
      await prepare();
      final oldRef = ref();
      final pending = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final operation = client.refreshRoster(cache, oldRef);
      final check = expectLater(operation, error('SESSION_CHANGED'));
      await started.future;
      session.change(authenticated: true, user: historyId);
      pending.complete(roster());
      await check;
      expect(await cache.readRegistrations(cache.scope), isEmpty);
    },
  );

  test(
    'cache environment mismatch is rejected before any network request',
    () async {
      cache.changeEnvironment('https://other.test/api');
      await expectLater(prepare(), error('SCOPE_MISMATCH'));
      expect(calls, isEmpty);
    },
  );

  test('transport environment mutation rejects in-flight response', () async {
    await prepare();
    respond = (_) {
      dio.options.baseUrl = 'https://other.test/api';
      return roster();
    };
    await expectLater(
      client.refreshRoster(cache, ref()),
      error('ENVIRONMENT_CHANGED'),
    );
  });

  test('latest roster read wins when earlier request finishes last', () async {
    await prepare();
    final pending = Completer<Map<String, dynamic>>(),
        started = Completer<void>();
    var count = 0;
    respond = (_) {
      if (++count == 1) {
        started.complete();
        return pending.future;
      }
      return roster();
    };
    final old = client.refreshRoster(cache, ref());
    final check = expectLater(
      old,
      throwsA(
        isA<ScopedCacheException>().having((e) => e.code, 'code', 'STALE_READ'),
      ),
    );
    await started.future;
    await client.refreshRoster(cache, ref());
    pending.complete(roster());
    await check;
    expect((await cache.readRoster(ref()))!.complete, isTrue);
  });

  test(
    'history pages are explicit, typed and do not alter roster tables',
    () async {
      respond = (r) => r.queryParameters['cursor'] == null
          ? history(cursor: 'h2')
          : history(items: []);
      final first = await client.readRetirements();
      expect(first.page.items.single.itemLevel, '1700.00');
      expect(first.page.items.single.combatPower, isNull);
      expect(first.page.items.single.characterId, characterId);
      expect(calls, hasLength(1));
      final second = await client.readRetirements(next: first.next);
      expect(second.page.items, isEmpty);
      expect(second.next, isNull);
      expect(calls.last.queryParameters, {'limit': 50, 'cursor': 'h2'});
      expect(await db.select(db.cacheScopes).get(), isEmpty);
      await expectLater(
        client.readRetirements(next: first.next),
        error('STALE_READ'),
      );
    },
  );

  test(
    'history revision changes and duplicate items/cursors are rejected',
    () async {
      for (final mode in ['revision', 'duplicate', 'cursor']) {
        respond = (_) => history(cursor: 'h2');
        final first = await client.readRetirements();
        respond = (_) => mode == 'revision'
            ? history(revision: 2, items: [])
            : mode == 'duplicate'
            ? history()
            : history(
                cursor: 'h2',
                items: [retirement(id: secondCharacterId)],
              );
        await expectLater(
          client.readRetirements(next: first.next),
          error(mode == 'revision' ? 'CURSOR_STALE' : 'INVALID_RESPONSE'),
        );
      }
    },
  );

  test(
    'history continuation cannot cross member, same-member session, or client',
    () async {
      respond = (_) => history(cursor: 'h2');
      final first = await client.readRetirements();
      final other = ServerCharacterLifecycleClient(
        DioBackendAccountReadApi(dio, session),
      );
      await expectLater(
        other.readRetirements(next: first.next),
        error('STALE_READ'),
      );
      other.dispose();
      session.change(authenticated: true, user: member);
      await expectLater(
        client.readRetirements(next: first.next),
        error('STALE_READ'),
      );
      final again = await client.readRetirements();
      session.change(authenticated: true, user: historyId);
      await expectLater(
        client.readRetirements(next: again.next),
        error('STALE_READ'),
      );
    },
  );

  test(
    'fresh history traversal supersedes old continuation and late first-page response',
    () async {
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      var count = 0;
      respond = (_) {
        if (++count == 1) {
          started.complete();
          return pending.future;
        }
        return history();
      };
      final old = client.readRetirements();
      final check = expectLater(old, error('STALE_READ'));
      await started.future;
      await client.readRetirements();
      pending.complete(history());
      await check;
      respond = (_) => history(cursor: 'h2');
      final first = await client.readRetirements();
      await client.readRetirements();
      await expectLater(
        client.readRetirements(next: first.next),
        error('STALE_READ'),
      );
    },
  );

  test('guest and disposed clients cannot start reads', () async {
    client.dispose();
    await expectLater(client.readRetirements(), error('DISPOSED'));
    session.change(authenticated: false);
    await expectLater(client.readRetirements(), error('LOGIN_REQUIRED'));
    expect(calls, isEmpty);
  });

  test(
    'server cursor/auth/permission/rate errors retain metadata and never erase cache',
    () async {
      await prepare();
      await client.refreshRoster(cache, ref());
      for (final (code, status) in [
        ('CURSOR_STALE', 409),
        ('CHARACTER_UNUSABLE', 409),
        ('IDENTITY_CONFLICT', 409),
        ('REGISTRATION_NOT_FOUND', 404),
        ('OWNERSHIP_REQUIRED', 403),
        ('RATE_LIMITED', 429),
      ]) {
        respond = (r) => throw DioException.badResponse(
          statusCode: status,
          requestOptions: r,
          response: Response(
            requestOptions: r,
            statusCode: status,
            headers: Headers.fromMap({
              'retry-after': ['7'],
            }),
            data: {
              'error': {'code': code, 'request_id': 'request-1'},
            },
          ),
        );
        await expectLater(
          client.refreshRoster(cache, ref()),
          throwsA(
            isA<AccountReadException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.status, 'status', status)
                .having((e) => e.requestId, 'requestId', 'request-1')
                .having(
                  (e) => e.retryAfter,
                  'retryAfter',
                  const Duration(seconds: 7),
                ),
          ),
        );
        expect((await cache.readRoster(ref()))!.characters, hasLength(1));
      }
    },
  );

  test(
    'single Bearer refresh is reused for V2 GET after ACCESS_EXPIRED',
    () async {
      var attempts = 0;
      respond = (r) {
        if (++attempts == 1) {
          throw DioException.badResponse(
            statusCode: 401,
            requestOptions: r,
            response: Response(
              requestOptions: r,
              statusCode: 401,
              data: {
                'error': {'code': 'ACCESS_EXPIRED'},
              },
            ),
          );
        }
        return history(items: []);
      };
      await client.readRetirements();
      expect(session.refreshCalls, 1);
      expect(calls, hasLength(2));
      expect(calls.last.headers['Authorization'], 'Bearer refreshed-access');
    },
  );

  test(
    'network failure on second page keeps prior roster and is not empty success',
    () async {
      await prepare();
      await client.refreshRoster(cache, ref());
      respond = (r) {
        if (r.queryParameters['cursor'] == null) return roster(cursor: 'p2');
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      };
      await expectLater(
        client.refreshRoster(cache, ref()),
        error('NETWORK_UNAVAILABLE'),
      );
      expect((await cache.readRoster(ref()))!.characters, hasLength(1));
    },
  );

  test(
    'registration-list failure preserves current metadata and complete observation',
    () async {
      await prepare();
      await client.refreshRoster(cache, ref());
      respond = (r) => throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
      await expectLater(prepare(), error('NETWORK_UNAVAILABLE'));
      expect(await cache.readRegistrations(cache.scope), hasLength(1));
      expect((await cache.readRoster(ref()))!.characters, hasLength(1));
    },
  );

  test(
    'new ID with same name is distinct and omitted ID is retained only as old observation',
    () async {
      await prepare();
      await client.refreshRoster(cache, ref());
      respond = (r) => r.path == '/v1/me/game-accounts'
          ? {
              'items': [registrationJson()..['roster_revision'] = 3],
              'next_cursor': null,
            }
          : (roster(items: [item(id: secondCharacterId)])
              ..['roster_revision'] = 3);
      await prepare();
      await client.refreshRoster(cache, ref());
      expect(
        (await cache.readRoster(ref()))!.characters.single.characterId,
        secondCharacterId,
      );
      final old = await cache.readCharacter(
        ScopedCharacterRef(
          cache.scope,
          accountId: account,
          characterId: characterId,
        ),
      );
      expect(old!.characterId, characterId);
    },
  );

  test(
    'suspect and claim conflict are saved as blocked observations',
    () async {
      await prepare();
      for (final (state, reason) in [
        ('suspect', 'CHARACTER_UNUSABLE'),
        ('active', 'IDENTITY_CONFLICT'),
      ]) {
        respond = (_) => roster(
          items: [
            item()..addAll({
              'lifecycle_state': state,
              'lifecycle_revision': state == 'active' ? 2 : 1,
              'usable': false,
              'eligible': false,
              'requires_refresh': true,
              'blocked_reason': reason,
            }),
          ],
        );
        await client.refreshRoster(cache, ref());
        final c = (await cache.readRoster(ref()))!.characters.single;
        expect(c.usable, isFalse);
        expect(c.blockedReason, reason);
      }
    },
  );

  test(
    'retired item in active response and preview with canonical ID are rejected',
    () {
      expect(
        () => LifecycleCharacterPage.fromJson(
          roster(
            items: [
              item()..addAll({
                'lifecycle_state': 'retired',
                'usable': false,
                'blocked_reason': 'CHARACTER_UNUSABLE',
              }),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => LifecycleCharacter.fromJson(
          item()..addAll({
            'lifecycle_state': 'preview',
            'usable': false,
            'blocked_reason': 'OWNERSHIP_REQUIRED',
          }),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'same-member logout/relogin invalidates in-flight roster response',
    () async {
      await prepare();
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final read = client.refreshRoster(cache, ref());
      final check = expectLater(read, error('SESSION_CHANGED'));
      await started.future;
      session.change(authenticated: false);
      session.change(authenticated: true, user: member);
      pending.complete(roster());
      await check;
      expect((await cache.readRoster(ref()))!.complete, isFalse);
    },
  );

  test('history late result after member switch is not returned', () async {
    final pending = Completer<Map<String, dynamic>>(),
        started = Completer<void>();
    respond = (_) {
      started.complete();
      return pending.future;
    };
    final read = client.readRetirements();
    final check = expectLater(read, error('SESSION_CHANGED'));
    await started.future;
    session.change(authenticated: true, user: historyId);
    pending.complete(history());
    await check;
  });
}
