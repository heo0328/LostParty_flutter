import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import 'package:lost_party/features/account/data/scoped_startup_refresh_source.dart';
import 'package:lost_party/features/account/domain/scoped_startup_refresh.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/character_analysis_client.dart';
import 'package:lost_party/features/account/data/local/scoped_account_cache_database.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/repositories/scoped_role_repository.dart';
import 'package:lost_party/features/account/data/mappers/server_analysis_detail_mapper.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/domain/role_summary.dart';
import 'package:lost_party/features/account/domain/analysis_candidates.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import '../../../support/server_account_read_fakes.dart';
import '../../../support/server_analysis_fixtures.dart';
import '../../../support/startup_batch_fakes.dart';
import 'server_character_lifecycle_client_test.dart' as wire;

const account = '44444444-4444-4444-8444-444444444444';
void main() {
  late Dio dio;
  late ReadSessionFake session;
  late ScopedAccountRuntime runtime;
  late DioBackendAccountReadApi api;
  late ApiCooldown cooldown;
  late CharacterAnalysisClient client;
  late MemoryAnalysisJournal journal;
  late Map<String, dynamic> dealer;
  late List<RequestOptions> posts;
  late Map<String, dynamic> Function(Map<String, dynamic>) analysis;
  late ScopedRolePlan plan;
  Map<String, dynamic> profile([String id = characterId]) => {
    'character_id': id,
    'game_account_id': account,
    'ownership_revision': 1,
    'lifecycle_revision': 1,
    'lifecycle_state': 'active',
    'dealer': dealer,
    'support': emptyAnalysisHead(),
    'preferences': {
      'version': 1,
      'preferred_role': null,
      'visible': true,
      'display_order': null,
      'saved_at': null,
    },
  };
  Map<String, dynamic> saved(Map<String, dynamic> body) => {
    'evaluated_at': analysisStamp,
    'items': [
      for (final command in body['items'])
        {
          'command_id': command['command_id'],
          'character_id': command['character_id'],
          'state': 'saved',
          'status': 200,
          'retry': 'none',
          'detected_role': 'dealer',
          'error': null,
          'result': {
            'character_id': command['character_id'],
            'game_account_id': account,
            'ownership_revision': 1,
            'lifecycle_revision': 1,
            'role': 'dealer',
            'analysis': serverAnalysisHead(
              version: command['expected_summary_versions']['dealer'] + 1,
            ),
          },
        },
    ],
  };
  void guard() =>
      runtime.requireCurrent(accountReadScope(session), runtime.scope);
  setUp(() async {
    session = ReadSessionFake()
      ..userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dealer = emptyAnalysisHead();
    posts = [];
    analysis = saved;
    late Map<String, dynamic> Function(RequestOptions) respond;
    respond = (r) {
      final batch = startupBatchReply(
        r,
        respond,
        DateTime.parse(analysisStamp),
      );
      if (batch != null) return batch;
      if (r.path == '/v1/me/game-accounts') {
        final value = registrationPageJson();
        value['items'][0]['settings']['activity_character_ids'] = [
          characterId,
          secondCharacterId,
        ];
        return value;
      }
      if (r.path.endsWith('/characters')) {
        final value = wire.roster(
          items: [
            {...wire.item(), 'class_name': '버서커'},
            {
              ...wire.item(id: secondCharacterId, name: 'second'),
              'class_name': '버서커',
            },
          ],
        );
        value['settings']['activity_character_ids'] = [
          characterId,
          secondCharacterId,
        ];
        return value;
      }
      if (r.path.endsWith('/personal-profile')) {
        return profile(r.path.split('/')[4]);
      }
      if (r.path == '/v2/me/character-analysis/refresh') {
        posts.add(r);
        return analysis(Map<String, dynamic>.from(r.data as Map));
      }
      throw StateError('Unexpected ${r.path}');
    };
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          try {
            h.resolve(
              Response(requestOptions: r, statusCode: 200, data: respond(r)),
            );
          } catch (e) {
            h.reject(
              e is DioException ? e : DioException(requestOptions: r, error: e),
            );
          }
        },
      ),
    );
    cooldown = ApiCooldown(now: () => DateTime.parse(analysisStamp));
    api = DioBackendAccountReadApi(dio, session, cooldown: cooldown);
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () =>
          ScopedAccountCacheDatabase(NativeDatabase.memory()),
      enabled: true,
    );
    journal = MemoryAnalysisJournal();
    client = CharacterAnalysisClient(
      api,
      journal: journal,
      now: () => DateTime.parse(analysisStamp),
    );
    await runtime.loadMemberRoster();
    plan = await runtime.prepareRoleBuild(
      ScopedRegistrationRef(runtime.scope, registrationId),
      ScopedCharacterRef(
        runtime.scope,
        accountId: account,
        characterId: characterId,
      ),
    );
  });
  tearDown(() async {
    await runtime.close();
    cooldown.dispose();
    dio.close();
    session.dispose();
  });
  test(
    'server collection command has no key/raw/summary/forced role and timeout60',
    () async {
      final result = (await client.execute([plan], 'manual', guard)).single;
      expect(result.state, 'saved');
      expect(posts.single.headers['Idempotency-Key'], isNull);
      expect(posts.single.receiveTimeout, const Duration(seconds: 60));
      expect((posts.single.data as Map)['items'][0].keys.toSet(), {
        'command_id',
        'character_id',
        'expected_ownership_revision',
        'expected_lifecycle_revision',
        'expected_summary_versions',
        'trigger',
      });
      await runtime.applyAnalysis(plan, result.role!, result.head!.toJson());
      final cached = await runtime.readCachedRoleBuild(
        plan.registration,
        plan.ref,
        CharacterBuildRole.dealer,
      );
      expect(cached!.server.detail, isNotNull);
      expect(cached.displaySummary!.combatPower, '12345.67');
    },
  );
  test('storage refusal sends no server command', () async {
    journal.failWrite = true;
    await expectLater(
      client.execute([plan], 'manual', guard),
      throwsA(isA<AccountReadException>()),
    );
    expect(posts, isEmpty);
  });
  Map<String, dynamic> candidateContext(String purpose) => {
    'candidate_id': '33333333-3333-4333-8333-333333333333',
    'expected_generation': 1,
    'expected_policy_revision': 2,
    'expected_settings_version': 1,
    'purpose': purpose,
  };
  test(
    'candidate manual retry uses fresh context and manual trigger',
    () async {
      final result = await client.execute(
        [plan],
        'automatic',
        guard,
        candidateContexts: {characterId: candidateContext('manual_retry')},
      );
      final sent = (posts.single.data as Map)['items'][0];
      expect(sent['trigger'], 'manual');
      expect(sent['candidate_context'], candidateContext('manual_retry'));
      expect(result.single.state, 'saved');
    },
  );
  test(
    'candidate recovery keeps server original despite newer local snapshot',
    () async {
      final original = {
        'command_id': '11111111-1111-4111-8111-111111111111',
        'character_id': characterId,
        'expected_ownership_revision': 1,
        'expected_lifecycle_revision': 1,
        'expected_summary_versions': {
          'dealer': plan.profile.dealer.version,
          'support': plan.profile.support.version,
        },
        'trigger': 'automatic',
        'candidate_context': candidateContext('automatic_candidate'),
      };
      await client.execute(
        [plan],
        'manual',
        guard,
        candidateContexts: {characterId: candidateContext('manual_retry')},
        originalCommands: {characterId: original},
      );
      expect((posts.single.data as Map)['items'][0], original);
    },
  );
  test(
    'new candidate skipped outcomes are terminal without pending replay',
    () async {
      for (final code in [
        'ANALYSIS_CANDIDATE_COMPLETED',
        'ANALYSIS_CANDIDATE_RETRY_REQUIRED',
      ]) {
        analysis = (body) {
          final command = (body['items'] as List).single;
          return {
            'evaluated_at': analysisStamp,
            'items': [
              {
                'command_id': command['command_id'],
                'character_id': characterId,
                'state': 'skipped',
                'status': 200,
                'retry': 'none',
                'detected_role': null,
                'result': null,
                'error': {
                  'code': code,
                  'message': code,
                  'request_id': 'candidate',
                  'retry_after_seconds': null,
                  'retry_at': null,
                },
              },
            ],
          };
        };
        final result = await client.execute(
          [plan],
          'automatic',
          guard,
          candidateContexts: {
            characterId: candidateContext('automatic_candidate'),
          },
        );
        expect(result.single.failure!.code, code);
        expect(jsonDecode((await journal.read(runtime.scope))!), isEmpty);
      }
    },
  );
  test(
    'acknowledged save remains successful when journal cleanup fails',
    () async {
      analysis = (body) {
        journal.failWrite = true;
        return saved(body);
      };
      final result = (await client.execute([plan], 'manual', guard)).single;
      expect(result.state, 'saved');
      expect(result.head, isNotNull);
      expect(result.failure!.code, 'LOCAL_STORAGE_UNAVAILABLE');
      expect(posts, hasLength(1));
      expect(jsonDecode(journal.values.values.single), isNotEmpty);
    },
  );
  test(
    'expired uncertain command requires current state before a new command',
    () async {
      analysis = (_) => throw StateError('lost response');
      await expectLater(
        client.execute([plan], 'manual', guard),
        throwsA(isA<AccountReadException>()),
      );
      final later = CharacterAnalysisClient(
        api,
        journal: journal,
        now: () => DateTime.parse(analysisStamp).add(const Duration(hours: 25)),
      );
      await expectLater(
        later.execute([plan], 'manual', guard),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'IDEMPOTENCY_EXPIRED',
          ),
        ),
      );
      expect(posts, hasLength(1));
    },
  );
  test(
    'definitive upstream failure leaves the stored head and observations unchanged',
    () async {
      final before = await runtime.readCachedRoleBuild(
        plan.registration,
        plan.ref,
        CharacterBuildRole.dealer,
      );
      analysis = (body) => {
        'evaluated_at': analysisStamp,
        'items': [
          {
            'command_id': body['items'][0]['command_id'],
            'character_id': characterId,
            'status': 503,
            'state': 'failed',
            'retry': 'new_command',
            'detected_role': null,
            'result': null,
            'error': {
              'code': 'UPSTREAM_UNAVAILABLE',
              'message': 'safe',
              'request_id': 'upstream-1',
              'retry_at': null,
              'retry_after_seconds': 30,
            },
          },
        ],
      };
      final result = (await client.execute([plan], 'manual', guard)).single;
      expect(result.state, 'failed');
      expect(result.failure!.requestId, 'upstream-1');
      final after = await runtime.readCachedRoleBuild(
        plan.registration,
        plan.ref,
        CharacterBuildRole.dealer,
      );
      expect(after!.server.toJson(), before!.server.toJson());
      expect(jsonDecode(journal.values.values.single), isEmpty);
      expect(cooldown.seconds, 30);
      await expectLater(
        client.execute([plan], 'manual', guard),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'UPSTREAM_RATE_LIMITED',
          ),
        ),
      );
      expect(posts, hasLength(1));
      // The same shared wait must not block reading the stored profile.
      await runtime.prepareRoleBuild(plan.registration, plan.ref);
    },
  );
  test('lost response recovers exact original command and body', () async {
    analysis = (_) => throw StateError('response lost');
    await expectLater(
      client.execute([plan], 'automatic', guard),
      throwsA(isA<AccountReadException>()),
    );
    final original = jsonEncode(posts.single.data);
    analysis = saved;
    await client.execute([plan], 'manual', guard);
    expect(jsonEncode(posts.last.data), original);
    expect(jsonDecode(journal.values.values.single), isEmpty);
  });
  for (final field in ['command_id', 'character_id']) {
    test('malformed $field correlation preserves recovery input', () async {
      analysis = (b) {
        final r = saved(b);
        r['items'][0][field] = secondCharacterId;
        return r;
      };
      await expectLater(
        client.execute([plan], 'manual', guard),
        throwsA(isA<AccountReadException>()),
      );
      expect(jsonDecode(journal.values.values.single), isNotEmpty);
    });
  }
  for (final pair in [
    ('not_processed', 503, 'BATCH_NOT_PROCESSED'),
    ('in_progress', 409, 'REQUEST_IN_PROGRESS'),
    ('unknown', 503, 'SERVICE_UNAVAILABLE'),
  ]) {
    test(
      '${pair.$1} preserves same command and structured retry metadata',
      () async {
        analysis = (b) => {
          'evaluated_at': analysisStamp,
          'items': [
            {
              'command_id': b['items'][0]['command_id'],
              'character_id': characterId,
              'state': pair.$1,
              'status': pair.$2,
              'retry': 'same_command',
              'detected_role': null,
              'result': null,
              'error': {
                'code': pair.$3,
                'message': 'safe',
                'request_id': 'request-1',
                'retry_after_seconds': 2,
                'retry_at': '2026-10-16T00:00:02Z',
              },
            },
          ],
        };
        final r = (await client.execute([plan], 'manual', guard)).single;
        expect(r.failure!.requestId, 'request-1');
        expect(r.failure!.retryAfter, const Duration(seconds: 2));
        expect(jsonDecode(journal.values.values.single), isNotEmpty);
        await expectLater(
          client.execute([plan], 'manual', guard),
          throwsA(isA<AccountReadException>()),
        );
        expect(posts, hasLength(1));
      },
    );
  }
  test(
    'lower/null/error values are latest saved head and opposite role is retained',
    () async {
      final first = (await client.execute([plan], 'manual', guard)).single;
      await runtime.applyAnalysis(plan, first.role!, first.head!.toJson());
      dealer = first.head!.toJson();
      for (final power in ['1', null]) {
        plan = await runtime.prepareRoleBuild(plan.registration, plan.ref);
        analysis = (b) {
          final r = saved(b);
          r['items'][0]['result']['analysis'] = serverAnalysisHead(
            version: plan.profile.dealer.version + 1,
            power: power,
            integrity: 'error',
          );
          return r;
        };
        final r = (await client.execute([plan], 'manual', guard)).single;
        await runtime.applyAnalysis(plan, r.role!, r.head!.toJson());
        dealer = r.head!.toJson();
        final current = await runtime.readCachedRoleBuild(
          plan.registration,
          plan.ref,
          CharacterBuildRole.dealer,
        );
        expect(current!.displaySummary!.combatPower, power);
        expect(current.displaySummary!.integrity.name, 'error');
        expect(
          (await runtime.readCachedRoleBuild(
            plan.registration,
            plan.ref,
            CharacterBuildRole.support,
          ))!.server.version,
          1,
        );
      }
    },
  );
  test('detail is a display projection, not an armory re-analysis', () {
    final value = serverAnalysisDetail(analysisDetail());
    expect(value.gemEffects, hasLength(11));
    expect(value.runeCount, 8);
    expect(value.catalogDetection!.branchDisplayName, '예시 계열');
  });
  test('obsolete client summary source is rejected', () {
    final head = serverAnalysisHead();
    head['summary']['source'] = 'flutter_analysis';
    expect(() => StoredRoleSummary.fromJson(head), throwsFormatException);
  });
  test(
    'budget-only continuation retains the unstarted command ID and body',
    () async {
      final notifier = ChangeNotifier();
      final cooldown = ApiCooldown(now: () => DateTime.parse(analysisStamp));
      final source = RuntimeStartupRefreshSource(
        runtime: runtime,
        changes: notifier,
        cooldown: cooldown,
        client: client,
        readAccess: () => const ScopedRefreshAccess(
          niceGroupEnabled: true,
          settingsVersion: 1,
        ),
      );
      addTearDown(() {
        source.dispose();
        notifier.dispose();
        cooldown.dispose();
      });
      final snapshot = await runtime.loadMemberRoster();
      final targets = projectScopedRefreshTargets(
        runtime.scope,
        snapshot.rosters,
        niceGroupEnabled: true,
      );
      var requests = 0;
      analysis = (body) {
        final response = saved(body);
        if (requests++ == 0) {
          final command = body['items'][1];
          response['items'][1] = {
            'command_id': command['command_id'],
            'character_id': command['character_id'],
            'status': 503,
            'state': 'not_processed',
            'retry': 'same_command',
            'detected_role': null,
            'result': null,
            'error': {
              'code': 'BATCH_NOT_PROCESSED',
              'message': 'safe',
              'request_id': 'budget',
              'retry_after_seconds': null,
              'retry_at': null,
            },
          };
        }
        return response;
      };
      final results = <String, ScopedRefreshItem>{};
      await source.refreshBatch(
        ScopedRefreshBatch(
          scope: runtime.scope,
          session: accountReadScope(session),
          settingsVersion: 1,
          niceGroupEnabled: true,
          observationGeneration: runtime.readGeneration,
          targets: targets,
        ),
        targets,
        guard,
        (r) => results[r.target.ref.characterId] = r,
        (_, e) => throw StateError('$e'),
      );
      expect(posts, hasLength(2));
      expect((posts.first.data as Map)['items'], hasLength(2));
      expect((posts.last.data as Map)['items'], hasLength(1));
      expect(
        jsonEncode((posts.last.data as Map)['items'][0]),
        jsonEncode((posts.first.data as Map)['items'][1]),
      );
      expect(
        results.values.every((r) => r.status == ScopedRefreshStatus.saved),
        isTrue,
      );
    },
  );
  test('summary only bootstrap cannot pretend to contain detail', () {
    final head = serverAnalysisHead()..remove('detail');
    expect(() => StoredRoleSummary.fromJson(head), throwsFormatException);
    expect(StoredRoleSummary.fromJson(head, summaryOnly: true).detail, isNull);
  });
  test(
    'blocked discovery is shown as failure without an automatic analysis call',
    () async {
      final projection = AnalysisCandidates({
        'policy_version': 'analysis-candidates-1',
        'policy_revision': 1,
        'baseline': 'observed',
        'game_account_id': account,
        'registration_id': registrationId,
        'ownership_revision': 1,
        'settings_version': 1,
        'complete': true,
        'candidates': [
          {
            'candidate_id': '33333333-3333-4333-8333-333333333333',
            'character_id': characterId,
            'generation': 1,
            'reason': 'first_threshold',
            'state': 'blocked',
            'eligibility': 'eligible',
            'next_attempt_at': null,
            'last_error': null,
            'unresolved_command': null,
            'completed_at': null,
            'completed_command_id': null,
          },
        ],
      });
      final roster = (await runtime.loadMemberRoster()).rosters.single;
      final target = ScopedRefreshTarget(
        roster.registration,
        plan.ref,
        roster.characters.first,
        candidate: projection.items.single,
      );
      final source = RuntimeStartupRefreshSource(
        runtime: runtime,
        readAccess: () => const ScopedRefreshAccess(
          niceGroupEnabled: true,
          settingsVersion: 1,
        ),
        changes: ChangeNotifier(),
        cooldown: cooldown,
        client: client,
      );
      addTearDown(source.dispose);
      final failures = <String>[];
      await source.refreshBatch(
        ScopedRefreshBatch(
          scope: runtime.scope,
          session: accountReadScope(session),
          settingsVersion: 1,
          niceGroupEnabled: true,
          observationGeneration: runtime.readGeneration,
          targets: [target],
        ),
        [target],
        guard,
        (_) => fail('unexpected saved result'),
        (_, error) {
          failures.add((error as AccountReadException).code);
          return false;
        },
      );
      expect(failures, ['ANALYSIS_CANDIDATE_RETRY_REQUIRED']);
      expect(posts, isEmpty);
    },
  );
}
