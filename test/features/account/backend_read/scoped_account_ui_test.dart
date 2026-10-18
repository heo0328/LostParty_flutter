import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/backend_account_lifecycle.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_registration_view_model.dart';
import 'package:lost_party/features/account/presentation/pages/scoped_character_retirements_page.dart';
import 'package:lost_party/features/account/presentation/scoped_account_routes.dart';
import 'package:lost_party/features/account/presentation/widgets/scoped_server_accounts_panel.dart';

import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart'
    as wire
    show roster, history;

const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const rosterPath = '/v2/me/game-accounts/$registrationId/characters';
const historyPath = '/v2/me/character-retirements';

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late ServerAccountReadRepository reads;
  late BackendAccountLifecycle binding;
  late ScopedAccountCacheDatabase db;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  late List<RequestOptions> calls;
  var opens = 0;
  setUp(() {
    opens = 0;
    calls = [];
    session = ReadSessionFake()..userId = member;
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
    reads = ServerAccountReadRepository(api, session);
    db = ScopedAccountCacheDatabase(NativeDatabase.memory());
    binding = BackendAccountLifecycle(
      api: api,
      registrations: reads,
      enabled: true,
      databaseFactory: () {
        opens++;
        return db;
      },
    );
  });
  tearDown(() async {
    await binding.close();
    if (opens == 0) await db.close();
    dio.close();
    session.dispose();
  });
  int requests(String path) => calls.where((r) => r.path == path).length;
  Future<void> openRoster() =>
      binding.model!.openRoster(binding.runtime!.reference(registrationId));
  GoRouter router({required bool enabled, String? location}) => GoRouter(
    initialLocation: location ?? '/account/server/$registrationId',
    routes: [
      GoRoute(
        path: '/account',
        builder: (_, _) => const Scaffold(),
        routes: serverAccountReadRoutes(
          model: enabled ? binding.model : null,
          legacyCharacters: (_, id) => Scaffold(body: Text('legacy:$id')),
          onLogin: (_) {},
        ),
      ),
    ],
  );

  test('default OFF binding allocates neither runtime nor IO', () async {
    final disabled = BackendAccountLifecycle(
      api: api,
      registrations: reads,
      databaseFactory: () => throw StateError('disabled DB'),
    );
    expect(disabled.enabled, isFalse);
    expect(disabled.runtime, isNull);
    final scope = accountReadScope(session);
    disabled.onCommandStarted(scope);
    disabled.onCommandFinished(scope);
    await disabled.refresh(scope);
    await disabled.close();
    expect(calls, isEmpty);
    expect(opens, 0);
  });

  test(
    'command gate invalidates current observations and blocks overlapping GET',
    () async {
      await openRoster();
      final m = binding.model!;
      expect(m.roster(registrationId).current, isTrue);
      final count = calls.length;
      final scope = accountReadScope(session);
      binding.onCommandStarted(scope);
      expect(m.commandInProgress, isTrue);
      expect(m.roster(registrationId).current, isFalse);
      await openRoster();
      await m.refreshRegistrations();
      expect(calls.length, count);
      binding.onCommandFinished(scope);
      await m.refreshRegistrations();
      await openRoster();
      expect(m.commandInProgress, isFalse);
      expect(m.roster(registrationId).current, isTrue);
      expect(calls.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test('late command completion cannot unlock a different member', () async {
    final old = accountReadScope(session);
    session.change(authenticated: true, user: other);
    final current = accountReadScope(session);
    binding.onCommandStarted(current);
    binding.onCommandFinished(old);
    expect(binding.model!.commandInProgress, isTrue);
    expect(calls, isEmpty);
    binding.onCommandFinished(current);
    await binding.model!.refreshRegistrations();
    expect(binding.model!.commandInProgress, isFalse);
  });

  test(
    'verified callback supersedes a metadata GET already in flight',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      respond = (r) {
        if (!started.isCompleted) {
          started.complete();
          return pending.future;
        }
        return registrationPageJson(empty: true);
      };
      final old = binding.model!.initialize();
      await started.future;
      final refreshed = binding.refresh(accountReadScope(session));
      pending.complete(registrationPageJson());
      await Future.wait([old, refreshed]);
      expect(requests('/v1/me/game-accounts'), 2);
      expect(binding.model!.registrationsCurrent, isTrue);
      expect(binding.model!.registrations, isEmpty);
    },
  );

  for (final uncertain in [false, true]) {
    test(
      'actual write callbacks preserve pending=$uncertain across read refresh',
      () async {
        await openRoster();
        final pending = Completer<Map<String, dynamic>>();
        final started = Completer<void>();
        respond = (r) {
          if (r.method != 'GET') {
            started.complete();
            return pending.future;
          }
          return r.path == '/v1/me/game-accounts'
              ? registrationPageJson()
              : wire.roster();
        };
        final writes = ServerRegistrationViewModel(
          api,
          reads,
          session,
          onCommandStarted: binding.onCommandStarted,
          onCommandFinished: binding.onCommandFinished,
        );
        try {
          final flight = writes.edit(
            ServerAccountRegistration.fromJson(registrationJson()),
            'changed',
            true,
          );
          await started.future;
          expect(binding.model!.commandInProgress, isTrue);
          expect(binding.model!.roster(registrationId).current, isFalse);
          if (uncertain) {
            pending.completeError(
              DioException(
                requestOptions: calls.last,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            pending.complete(registrationJson());
          }
          await flight;
          await binding.model!.refreshRegistrations();
          await openRoster();
          expect(binding.model!.commandInProgress, isFalse);
          expect(writes.hasPending, uncertain);
          expect(calls.where((r) => r.method != 'GET'), hasLength(1));
        } finally {
          writes.dispose();
        }
      },
    );
  }

  testWidgets('OFF production routes retain V1 detail without new IO', (
    tester,
  ) async {
    final routes = router(enabled: false);
    await tester.pumpWidget(MaterialApp.router(routerConfig: routes));
    await tester.pumpAndSettle();
    expect(find.text('legacy:$registrationId'), findsOneWidget);
    expect(calls, isEmpty);
    expect(opens, 0);
    await tester.pumpWidget(const SizedBox());
    routes.dispose();
  });

  testWidgets(
    'ON detail uses V2 while explicit power route retains existing page',
    (tester) async {
      await tester.runAsync(openRoster);
      final routes = router(enabled: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: routes));
      await tester.pumpAndSettle();
      expect(find.text('원정대 캐릭터'), findsOneWidget);
      expect(find.text('legacy:$registrationId'), findsNothing);
      expect(requests(rosterPath), 1);
      expect(requests('/v1/me/game-accounts/$registrationId/characters'), 0);
      routes.go('/account/server/$registrationId/power');
      await tester.pumpAndSettle();
      expect(find.text('legacy:$registrationId'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      routes.dispose();
    },
  );

  testWidgets('V2 404 stays failed instead of empty or fallback success', (
    tester,
  ) async {
    respond = (r) {
      if (r.path == '/v1/me/game-accounts') return registrationPageJson();
      throw DioException.badResponse(
        statusCode: 404,
        requestOptions: r,
        response: Response(
          requestOptions: r,
          statusCode: 404,
          data: {
            'error': {'code': 'NOT_FOUND'},
          },
        ),
      );
    };
    await tester.runAsync(openRoster);
    final routes = router(enabled: true);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: routes));
      await openRoster();
    });
    await tester.pumpAndSettle();
    expect(binding.model!.roster(registrationId).failure, isNotNull);
    expect(find.text('legacy:$registrationId'), findsNothing);
    expect(find.text('조회된 캐릭터가 없습니다.'), findsNothing);
    expect(requests('/v1/me/game-accounts/$registrationId/characters'), 0);
    await tester.pumpWidget(const SizedBox());
    routes.dispose();
  });

  testWidgets(
    'history entry remains available for a member with no registrations',
    (tester) async {
      respond = (_) => registrationPageJson(empty: true);
      await tester.runAsync(() => binding.model!.initialize());
      var entered = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScopedServerAccountsPanel(
              model: binding.model!,
              onLogin: () {},
              onManage: () async {},
              onOpen: (_) async {},
              onHistory: () async {
                entered++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('등록한 원정대가 없습니다.'), findsOneWidget);
      final entry = find.text('사라진 캐릭터명 기록');
      expect(entry, findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(entered, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('logout removes history immediately and never opens a local DB', (
    tester,
  ) async {
    await tester.runAsync(() => binding.model!.openHistory());
    await tester.pumpWidget(
      MaterialApp(
        home: ScopedCharacterRetirementsPage(
          model: binding.model!,
          onLogin: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('sample'), findsWidgets);
    session.change(authenticated: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('sample'), findsNothing);
    expect(binding.model!.history.items, isEmpty);
    expect(opens, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'leaving history discards a late page without disposal notifications',
    (tester) async {
      late Completer<Map<String, dynamic>> pending;
      late Future<void> flight;
      await tester.runAsync(() async {
        pending = Completer<Map<String, dynamic>>();
        final started = Completer<void>();
        respond = (_) {
          started.complete();
          return pending.future;
        };
        flight = binding.model!.openHistory();
        await started.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ScopedCharacterRetirementsPage(
            model: binding.model!,
            onLogin: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        pending.complete(wire.history());
        await flight;
      });
      expect(binding.model!.history.open, isFalse);
      expect(binding.model!.history.items, isEmpty);
      expect(tester.takeException(), isNull);
      expect(opens, 0);
    },
  );
}
