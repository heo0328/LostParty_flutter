import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/scoped_account_view_model.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart'
    as wire
    show roster, history, retirement, item;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const rosterPath = '/v2/me/game-accounts/$registrationId/characters';
const historyPath = '/v2/me/character-retirements';

class RuntimeSession extends ReadSessionFake {
  void ping() => notifyListeners();
}

class TrackingDatabase extends ScopedAccountCacheDatabase {
  TrackingDatabase(super.executor);
  int closes = 0;
  @override
  Future<void> close() {
    closes++;
    return super.close();
  }
}

class TrackingReads extends ServerAccountReadRepository {
  TrackingReads(super.api, super.session);
  final shares = <bool>[];
  Completer<void>? joined;
  @override
  Future<List<ServerAccountRegistration>> loadRegistrations({
    bool shareInFlight = false,
  }) {
    shares.add(shareInFlight);
    if (shares.length == 2) joined?.complete();
    return super.loadRegistrations(shareInFlight: shareInFlight);
  }
}

void main() {
  late RuntimeSession session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late TrackingReads reads;
  late TrackingDatabase db;
  late ScopedAccountRuntime runtime;
  late ScopedAccountViewModel model;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  late List<RequestOptions> calls;
  late DateTime clock;
  var opens = 0;

  setUp(() {
    opens = 0;
    clock = DateTime.utc(2026, 10, 15);
    calls = [];
    session = RuntimeSession()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    respond = (r) => r.path == '/v1/me/game-accounts'
        ? registrationPageJson()
        : r.path == historyPath
        ? wire.history()
        : wire.roster();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          calls.add(r);
          try {
            h.resolve(
              Response(
                requestOptions: r,
                data: await respond(r),
                statusCode: 200,
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
    api = DioBackendAccountReadApi(dio, session);
    reads = TrackingReads(api, session);
    db = TrackingDatabase(NativeDatabase.memory());
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: reads,
      enabled: true,
      databaseFactory: () {
        opens++;
        return db;
      },
      ownsDatabase: false,
    );
    model = ScopedAccountViewModel(runtime, now: () => clock);
  });
  tearDown(() async {
    model.dispose();
    await runtime.close();
    await db.close();
    dio.close();
    session.dispose();
  });
  ScopedRegistrationRef ref() => runtime.reference(registrationId);
  int requests(String path) => calls.where((r) => r.path == path).length;

  test(
    'construction and disabled/guest reads have no DB or HTTP side effects',
    () async {
      expect(opens, 0);
      expect(calls, isEmpty);
      final disabled = ScopedAccountRuntime(
        api: api,
        registrations: reads,
        databaseFactory: () {
          fail('disabled DB');
        },
      );
      final vm = ScopedAccountViewModel(disabled);
      await vm.initialize();
      await vm.openHistory();
      await vm.openRoster(ref());
      expect(vm.canRead, isFalse);
      expect(calls, isEmpty);
      vm.dispose();
      await disabled.close();
      session.change(authenticated: false);
      await model.initialize();
      await model.openHistory();
      expect(opens, 0);
      expect(calls, isEmpty);
    },
  );

  test(
    'metadata initializes once, preserves typed count and remains distinct from full roster',
    () async {
      final first = model.initialize(), second = model.initialize();
      expect(identical(first, second), isTrue);
      await first;
      expect(opens, 1);
      expect(model.hydrated, isTrue);
      expect(model.registrationsCurrent, isTrue);
      expect(model.metadata.single.characterCount, 2);
      expect(model.registrations, hasLength(1));
      expect(
        model.roster(registrationId).coverage,
        ScopedRosterCoverage.metadataOnly,
      );
      await model.initialize();
      session.ping();
      await model.initialize();
      expect(requests('/v1/me/game-accounts'), 1);
      expect(requests(rosterPath), 0);
      expect(() => model.registrations.clear(), throwsUnsupportedError);
    },
  );

  test(
    'initial registration GET joins existing V1 flight, explicit refresh starts new GET',
    () async {
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      reads.joined = Completer<void>();
      respond = (_) {
        if (!started.isCompleted) started.complete();
        return pending.future;
      };
      final v1 = reads.loadRegistrations(shareInFlight: true);
      await started.future;
      final initial = model.initialize();
      await reads.joined!.future;
      pending.complete(registrationPageJson());
      await Future.wait([v1, initial]);
      expect(requests('/v1/me/game-accounts'), 1);
      expect(reads.shares, [true, true]);
      respond = (_) => registrationPageJson();
      await model.refreshRegistrations();
      expect(requests('/v1/me/game-accounts'), 2);
      expect(reads.shares.last, isFalse);
    },
  );

  test(
    'reentrant consumer notification shares the already assigned metadata flight',
    () async {
      Future<void>? repeated;
      model.addListener(() {
        if (model.loading && repeated == null) repeated = model.initialize();
      });
      final first = model.initialize();
      await first;
      await repeated;
      expect(requests('/v1/me/game-accounts'), 1);
    },
  );

  test(
    'disk empty is not server empty and failed first GET is not an empty success',
    () async {
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final load = model.initialize();
      await started.future;
      expect(model.hydrated, isTrue);
      expect(model.registrations, isEmpty);
      expect(model.registrationsCurrent, isFalse);
      expect(model.loading, isTrue);
      pending.completeError(Exception('offline'));
      await load;
      expect(model.failure!.code, 'NETWORK_UNAVAILABLE');
      expect(model.registrationsCurrent, isFalse);
      respond = (_) => registrationPageJson(empty: true);
      await model.refreshRegistrations();
      expect(model.registrationsCurrent, isTrue);
      expect(model.registrations, isEmpty);
    },
  );

  test(
    'selected complete roster gets receipt and simultaneous/reentered opens share it',
    () async {
      await model.initialize();
      await Future.wait([model.openRoster(ref()), model.openRoster(ref())]);
      final state = model.roster(registrationId);
      expect(state.current, isTrue);
      expect(state.observation!.validated, isTrue);
      expect(state.coverage, ScopedRosterCoverage.canonical);
      expect(state.observation!.characters, hasLength(1));
      model.closeRoster();
      await model.openRoster(ref());
      expect(requests(rosterPath), 1);
      await model.openRoster(ref(), refresh: true);
      expect(requests(rosterPath), 2);
      expect(opens, 1);
    },
  );

  test(
    'null-head preview has current observation stamp without canonical receipt',
    () async {
      final settings = settingsJson()
        ..addAll({
          'configuration_state': 'unconfigured',
          'activity_character_ids': <String>[],
          'representative_character_id': null,
          'ownership_revision': null,
        });
      respond = (r) => r.path == '/v1/me/game-accounts'
          ? {
              'items': [
                registrationJson()..addAll({
                  'game_account_id': null,
                  'ownership_status': 'unverified',
                  'verification_status': 'unverified',
                  'ownership_revision': null,
                  'roster_revision': null,
                  'settings': settings,
                }),
              ],
              'next_cursor': null,
            }
          : (wire.roster(
              items: [
                wire.item()..addAll({
                  'character_id': null,
                  'lifecycle_revision': null,
                  'lifecycle_state': 'preview',
                  'roster_status': 'preview',
                  'eligible': false,
                  'usable': false,
                  'blocked_reason': 'OWNERSHIP_REQUIRED',
                  'power_stale': false,
                  'combat_power': '123.45',
                }),
              ],
            )..addAll({
              'game_account_id': null,
              'ownership_status': 'unverified',
              'ownership_revision': null,
              'roster_revision': 1,
              'settings': settings,
            }));
      await model.openRoster(ref());
      final state = model.roster(registrationId);
      expect(state.current, isTrue);
      expect(state.coverage, ScopedRosterCoverage.preview);
      expect(state.observation!.complete, isFalse);
      expect(state.observation!.validated, isFalse);
      expect(state.observation!.characters, isEmpty);
      expect(
        state.observation!.registration.displayJson,
        isNot(contains('123.45')),
      );
      model.invalidate();
      expect(model.roster(registrationId).current, isFalse);
    },
  );

  test(
    'failed full read keeps prior observation but drops freshness and receipt',
    () async {
      await model.openRoster(ref());
      respond = (_) => <String, dynamic>{'invalid': true};
      await model.openRoster(ref(), refresh: true);
      final state = model.roster(registrationId);
      expect(state.current, isFalse);
      expect(state.observation!.validated, isFalse);
      expect(state.observation!.characters, hasLength(1));
      expect(state.failure!.code, 'INVALID_RESPONSE');
    },
  );

  test(
    'metadata refresh invalidates pending roster then queues one selected re-read',
    () async {
      await model.initialize();
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      var rosterCalls = 0;
      respond = (r) {
        if (r.path == '/v1/me/game-accounts') return registrationPageJson();
        if (++rosterCalls == 1) {
          started.complete();
          return pending.future;
        }
        return wire.roster();
      };
      final old = model.openRoster(ref());
      await started.future;
      final metadata = model.refreshRegistrations();
      expect(model.roster(registrationId).current, isFalse);
      pending.complete(wire.roster(items: [wire.item(name: 'stale-name')]));
      await old;
      await metadata;
      await model.openRoster(ref());
      expect(rosterCalls, 2);
      expect(model.roster(registrationId).current, isTrue);
      expect(
        model
            .roster(registrationId)
            .observation!
            .characters
            .single
            .characterName,
        'sample',
      );
      expect(model.roster(registrationId).failure, isNull);
    },
  );

  test(
    'removed registration clears current display without deleting retained rows',
    () async {
      await model.openRoster(ref());
      respond = (_) => registrationPageJson(empty: true);
      await model.refreshRegistrations();
      await model.openRoster(ref());
      expect(model.registrations, isEmpty);
      expect(model.registrationsCurrent, isTrue);
      expect(model.roster(registrationId).observation, isNull);
      expect(
        model.roster(registrationId).failure!.code,
        'REGISTRATION_NOT_FOUND',
      );
      expect(await db.select(db.cachedCharacters).get(), hasLength(1));
    },
  );

  test(
    'revision conflict retries metadata first only on explicit action',
    () async {
      await model.openRoster(ref());
      final before = calls.length;
      respond = (_) => wire.roster()..['roster_revision'] = 3;
      await model.openRoster(ref(), refresh: true);
      expect(model.needsMetadata, isTrue);
      expect(
        model.roster(registrationId).failure!.kind,
        ScopedReadFailureKind.conflict,
      );
      expect(calls.length, before + 1);
      respond = (r) => r.path == '/v1/me/game-accounts'
          ? registrationPageJson()
          : wire.roster();
      await model.openRoster(ref(), refresh: true);
      expect(calls[before + 1].path, '/v1/me/game-accounts');
      expect(model.roster(registrationId).current, isTrue);
    },
  );

  test(
    'session change synchronously clears private rows and blocks old HTTP result',
    () async {
      await model.initialize();
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      respond = (r) {
        if (r.path == rosterPath) {
          started.complete();
          return pending.future;
        }
        return registrationPageJson();
      };
      final old = model.openRoster(ref());
      await started.future;
      session.change(authenticated: false);
      expect(model.registrations, isEmpty);
      expect(model.metadata, isEmpty);
      expect(model.failure, isNull);
      expect(model.roster(registrationId).observation, isNull);
      session.change(authenticated: true, user: other);
      pending.complete(wire.roster());
      await old;
      await model.initialize();
      expect(model.roster(registrationId).observation, isNull);
      expect(model.registrationsCurrent, isTrue);
      expect(model.failure, isNull);
      expect(await db.select(db.cachedCharacters).get(), isEmpty);
    },
  );

  test(
    'same-member reauthentication downgrades disk cache and re-queries metadata',
    () async {
      await model.openRoster(ref());
      final count = requests('/v1/me/game-accounts');
      session.change(authenticated: true, user: member);
      expect(model.registrations, isEmpty);
      expect(model.roster(registrationId).current, isFalse);
      await model.initialize();
      expect(requests('/v1/me/game-accounts'), count + 1);
      expect(model.roster(registrationId).observation, isNull);
      await model.openRoster(ref());
      expect(model.roster(registrationId).current, isTrue);
    },
  );

  test(
    'late DB factory completion cannot expose previous member cache',
    () async {
      final delayed = Completer<ScopedAccountCacheDatabase>();
      final otherRuntime = ScopedAccountRuntime(
        api: api,
        registrations: reads,
        enabled: true,
        databaseFactory: () => delayed.future,
        ownsDatabase: false,
      );
      final vm = ScopedAccountViewModel(otherRuntime);
      final initial = vm.initialize();
      await Future<void>.delayed(Duration.zero);
      session.change(authenticated: true, user: other);
      expect(vm.registrations, isEmpty);
      delayed.complete(db);
      await initial;
      await vm.initialize();
      expect(vm.registrationsCurrent, isTrue);
      expect(vm.failure, isNull);
      expect((await db.select(db.cacheScopes).get()).single.userId, other);
      vm.dispose();
      await otherRuntime.close();
    },
  );

  test(
    'environment mismatch is reported and never publishes a current result',
    () async {
      await model.initialize();
      respond = (_) {
        dio.options.baseUrl = 'https://other.test/api';
        return wire.roster();
      };
      await model.openRoster(ref());
      expect(model.roster(registrationId).current, isFalse);
      expect(
        model.roster(registrationId).failure!.kind,
        ScopedReadFailureKind.configuration,
      );
    },
  );

  test(
    'runtime validates debug HTTP, shared identity and actual URI prefixes',
    () async {
      await model.openRoster(ref());
      expect(calls.last.uri.path, '/api$rosterPath');
      expect(calls.last.uri.queryParameters['limit'], '50');
      expect(calls.last.data, isNull);
      expect(calls.last.headers['Authorization'], 'Bearer test-access');
      for (final url in [
        'https://example.test/a//b',
        'http://example.test',
        'https://user@example.test',
        'https://example.test?a=1',
      ]) {
        dio.options.baseUrl = url;
        expect(
          () => ScopedAccountRuntime(
            api: api,
            registrations: reads,
            databaseFactory: () => db,
          ),
          throwsA(
            isA<AccountReadException>().having(
              (e) => e.code,
              'code',
              'INVALID_ENVIRONMENT',
            ),
          ),
        );
      }
      dio.options.baseUrl = 'http://example.test/api/';
      final debug = ScopedAccountRuntime(
        api: api,
        registrations: reads,
        allowHttp: true,
        databaseFactory: () => db,
      );
      await debug.close();
      dio.options.baseUrl = 'https://example.test/api';
      expect(
        () => ScopedAccountRuntime(
          api: api,
          registrations: TrackingReads(api, RuntimeSession()),
          databaseFactory: () => db,
        ),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'SCOPE_MISMATCH',
          ),
        ),
      );
    },
  );

  test(
    'history is independent of registration/key and never opens a DB',
    () async {
      respond = (_) => wire.history(cursor: 'next');
      await model.openHistory();
      await model.openHistory();
      expect(opens, 0);
      expect(calls, hasLength(1));
      expect(model.history.hasMore, isTrue);
      respond = (_) =>
          wire.history(items: [wire.retirement(id: secondCharacterId)]);
      await Future.wait([model.loadMoreHistory(), model.loadMoreHistory()]);
      expect(calls, hasLength(2));
      expect(model.history.items, hasLength(2));
      expect(model.history.current, isTrue);
      expect(model.history.hasMore, isFalse);
      expect(() => model.history.items.clear(), throwsUnsupportedError);
      model.closeHistory();
      expect(model.history.items, isEmpty);
      expect(model.history.open, isFalse);
    },
  );

  test(
    'failed consumed continuation requires explicit restart, not duplicate retry',
    () async {
      respond = (_) => wire.history(cursor: 'next');
      await model.openHistory();
      respond = (_) => throw Exception('offline');
      await model.loadMoreHistory();
      expect(model.history.needsRestart, isTrue);
      expect(model.history.current, isFalse);
      expect(model.history.items, hasLength(1));
      await model.loadMoreHistory();
      expect(calls, hasLength(2));
      respond = (_) => wire.history(
        items: [wire.retirement(id: secondCharacterId)],
        revision: 2,
      );
      await model.restartHistory();
      expect(calls.last.queryParameters.containsKey('cursor'), isFalse);
      expect(model.history.items.single.historyId, secondCharacterId);
      expect(model.history.revision, 2);
    },
  );

  test(
    'history restart replaces stale revision and empty first page is a real empty state',
    () async {
      respond = (_) => wire.history(cursor: 'next');
      await model.openHistory();
      respond = (_) => wire.history(items: [], revision: 2);
      await model.loadMoreHistory();
      expect(model.history.needsRestart, isTrue);
      expect(model.history.failure!.code, 'CURSOR_STALE');
      await model.restartHistory();
      expect(model.history.items, isEmpty);
      expect(model.history.loaded, isTrue);
      expect(model.history.current, isTrue);
      expect(model.history.needsRestart, isFalse);
    },
  );

  test(
    'history close/reopen and signout suppress late errors and rows',
    () async {
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final old = model.openHistory();
      await started.future;
      model.closeHistory();
      respond = (_) => wire.history(items: []);
      await model.openHistory();
      pending.complete(wire.history());
      await old;
      expect(model.history.items, isEmpty);
      expect(model.history.current, isTrue);
      expect(model.history.failure, isNull);
      session.change(authenticated: false);
      expect(model.history.items, isEmpty);
      expect(model.history.open, isFalse);
    },
  );

  test(
    'deadline is fixed at receipt, retry is blocked, expiration never polls',
    () async {
      respond = (r) => throw DioException.badResponse(
        statusCode: 429,
        requestOptions: r,
        response: Response(
          requestOptions: r,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['7'],
          }),
          data: {
            'error': {'code': 'RATE_LIMITED'},
          },
        ),
      );
      await model.openHistory();
      final deadline = model.history.failure!.deadline;
      expect(model.historyRetrySeconds, 7);
      clock = clock.add(const Duration(seconds: 3));
      expect(model.historyRetrySeconds, 4);
      expect(model.history.failure!.deadline, deadline);
      await model.restartHistory();
      expect(calls, hasLength(1));
      clock = clock.add(const Duration(seconds: 5));
      expect(model.historyRetrySeconds, 0);
      expect(calls, hasLength(1));
      respond = (_) => wire.history(items: []);
      await model.restartHistory();
      expect(calls, hasLength(2));
      expect(model.history.failure, isNull);
    },
  );

  test('retryAt takes precedence and missing deadline is not invented', () {
    final failure = ScopedReadFailure(
      AccountReadException(
        'RATE_LIMITED',
        retryAfter: const Duration(seconds: 30),
        retryAt: clock.add(const Duration(seconds: 4)),
      ),
      clock,
    );
    expect(failure.secondsLeft(clock), 4);
    expect(
      ScopedReadFailure(
        const AccountReadException('NETWORK_UNAVAILABLE'),
        clock,
      ).deadline,
      isNull,
    );
  });

  test(
    'DB open failure is storage failure and explicit retry reuses policy without deletion',
    () async {
      var attempts = 0;
      final failedRuntime = ScopedAccountRuntime(
        api: api,
        registrations: reads,
        enabled: true,
        databaseFactory: () {
          if (++attempts == 1) throw StateError('disk unavailable');
          return db;
        },
        ownsDatabase: false,
      );
      final vm = ScopedAccountViewModel(failedRuntime);
      await vm.initialize();
      expect(vm.failure!.kind, ScopedReadFailureKind.storage);
      expect(calls, isEmpty);
      expect(vm.registrationsCurrent, isFalse);
      await vm.refreshRegistrations();
      expect(vm.registrationsCurrent, isTrue);
      expect(attempts, 2);
      vm.dispose();
      await failedRuntime.close();
    },
  );

  test(
    'closing during lazy open drains work and closes owned connection exactly once',
    () async {
      final delayed = Completer<ScopedAccountCacheDatabase>();
      final ownedDb = TrackingDatabase(NativeDatabase.memory());
      final ownedRuntime = ScopedAccountRuntime(
        api: api,
        registrations: reads,
        enabled: true,
        databaseFactory: () => delayed.future,
      );
      final vm = ScopedAccountViewModel(ownedRuntime);
      final initial = vm.initialize();
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      final close = ownedRuntime.close();
      delayed.complete(ownedDb);
      await Future.wait([initial, close]);
      await ownedRuntime.close();
      expect(ownedDb.closes, 1);
      expect(calls, isEmpty);
      expect(session.isAuthenticated, isTrue);
    },
  );

  test(
    'disposing state suppresses pending results and does not close borrowed connection',
    () async {
      final pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final load = model.initialize();
      await started.future;
      model.dispose();
      pending.complete(registrationPageJson());
      await load;
      await runtime.close();
      expect(db.closes, 0);
      expect(session.isAuthenticated, isTrue);
      expect(model.registrations, isEmpty);
      expect(await db.select(db.cacheScopes).get(), isEmpty);
      // teardown must not call ChangeNotifier.dispose twice.
      model = ScopedAccountViewModel(runtime);
    },
  );

  test(
    'real temporary DB persists only stale observations across runtimes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lostparty-scoped-runtime-',
      );
      final file = File('${directory.path}/cache.sqlite');
      ScopedAccountRuntime diskRuntime() => ScopedAccountRuntime(
        api: api,
        registrations: reads,
        enabled: true,
        databaseFactory: () => ScopedAccountCacheDatabase(NativeDatabase(file)),
      );
      final firstRuntime = diskRuntime();
      final first = ScopedAccountViewModel(firstRuntime);
      await first.openRoster(firstRuntime.reference(registrationId));
      first.dispose();
      await firstRuntime.close();
      final secondRuntime = diskRuntime();
      final second = ScopedAccountViewModel(secondRuntime);
      respond = (_) => throw Exception('offline');
      await second.openRoster(secondRuntime.reference(registrationId));
      expect(second.registrations, hasLength(1));
      expect(second.registrationsCurrent, isFalse);
      expect(
        second.roster(registrationId).observation!.characters,
        hasLength(1),
      );
      expect(second.roster(registrationId).current, isFalse);
      expect(second.roster(registrationId).observation!.validated, isFalse);
      second.dispose();
      await secondRuntime.close();
      await file.delete();
      await directory.delete();
    },
  );

  test(
    'no unselected roster or history is fetched by repeated initialization',
    () async {
      await model.initialize();
      await model.initialize();
      expect(calls.map((r) => r.path).toList(), ['/v1/me/game-accounts']);
    },
  );

  test(
    'different roster reads are serialized without mixing account snapshots',
    () async {
      final secondReg = registrationJson()
        ..addAll({
          'registration_id': secondCharacterId,
          'game_account_id': other,
          'is_main': false,
        });
      final secondRoster =
          wire.roster(
            items: [wire.item(id: secondCharacterId, name: 'second')],
          )..addAll({
            'registration_id': secondCharacterId,
            'game_account_id': other,
            'is_main': false,
          });
      respond = (_) => {
        'items': [registrationJson(), secondReg],
        'next_cursor': null,
      };
      await model.initialize();
      final started = Completer<void>(),
          pending = Completer<Map<String, dynamic>>();
      respond = (r) {
        if (r.path == rosterPath) {
          started.complete();
          return pending.future;
        }
        return secondRoster;
      };
      final first = model.openRoster(ref());
      await started.future;
      final second = model.openRoster(runtime.reference(secondCharacterId));
      await Future<void>.delayed(Duration.zero);
      expect(requests('/v2/me/game-accounts/$secondCharacterId/characters'), 0);
      pending.complete(wire.roster());
      await Future.wait([first, second]);
      expect(
        model.roster(registrationId).observation!.registration.accountId,
        wire.roster()['game_account_id'],
      );
      expect(
        model.roster(secondCharacterId).observation!.registration.accountId,
        other,
      );
      expect(model.roster(secondCharacterId).current, isTrue);
    },
  );

  test(
    'external token invalidation in same session requires explicit metadata recovery',
    () async {
      await model.initialize();
      final started = Completer<void>(),
          pending = Completer<Map<String, dynamic>>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final read = model.openRoster(ref());
      await started.future;
      runtime.invalidateReads();
      pending.complete(wire.roster());
      await read;
      expect(model.needsMetadata, isTrue);
      expect(model.roster(registrationId).current, isFalse);
      expect(model.roster(registrationId).failure!.code, 'STALE_READ');
      expect(requests('/v1/me/game-accounts'), 1);
    },
  );
}
