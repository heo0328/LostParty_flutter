import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/data/member_weekly_store.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/domain/member_raid_models.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/entities/character_weekly_raid_display_preference.dart';
import 'package:lost_party/features/account/domain/services/weekly_raid_display_projector.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_account_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_weekly_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

const account = '44444444-4444-4444-8444-444444444444';
const member = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class WeeklyMemoryStore implements MemberWeeklyStore {
  final data = <StorageScope, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(StorageScope s) async => data[s];
  @override
  Future<void> write(StorageScope s, String value) async {
    if (failWrite) throw StateError('disk');
    data[s] = value;
  }
}

class _Section extends MemberAccountSection {
  _Section(super.registration, super.characters) : super(cached: false);
  @override
  List<MemberCharacterState> get visible => characters;
}

class WeeklyMember extends ChangeNotifier implements MemberAccountViewModel {
  WeeklyMember(this.runtime);
  @override
  final ScopedAccountRuntime runtime;
  @override
  bool get signedIn => runtime.canRead;
  @override
  bool loading = false;
  @override
  String? failure;
  @override
  List<MemberAccountSection> sections = [];
  @override
  MemberCharacterState? character(ScopedCharacterRef ref) => sections
      .expand((s) => s.characters)
      .where(
        (c) => c.ref.characterId == ref.characterId && c.ref.scope == ref.scope,
      )
      .firstOrNull;
  @override
  bool detailsAvailable(ScopedCharacterRef ref) =>
      signedIn &&
      !loading &&
      failure == null &&
      sections.any(
        (s) =>
            !s.cached &&
            s.registration.ownershipStatus == 'owned' &&
            s.characters.any(
              (c) =>
                  c.ref.characterId == ref.characterId &&
                  c.observation.usable == true,
            ),
      );
  void setCount(int n) {
    final rows = List.generate(n, (i) {
      final id =
          '00000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}';
      final ref = ScopedCharacterRef(
        runtime.scope,
        accountId: account,
        characterId: id,
      );
      return MemberCharacterState(
        ref,
        CacheCharacterObservation(
          characterId: id,
          accountId: account,
          serverName: 'server',
          characterName: 'character$i',
          lifecycleState: 'active',
          lifecycleRevision: 1,
          usable: true,
          blockedReason: null,
          profile: {
            'item_level': '1750.83',
            'character_level': 70,
            'class_name': '바드',
          },
        ),
        cached: false,
      );
    });
    sections = [
      _Section(
        CacheRegistrationSnapshot(
          registrationId: registrationId,
          accountId: account,
          version: 1,
          isMain: true,
          label: 'main',
          ownershipStatus: 'owned',
          ownershipRevision: 1,
          rosterRevision: 1,
          settings: CacheSettings(
            version: 1,
            state: 'configured',
            activityIds: rows.map((r) => r.ref.characterId).toList(),
            representativeId: rows.firstOrNull?.ref.characterId,
          ),
          fetchedAt: DateTime.utc(2026, 10, 16),
          sourceContract: 'test',
        ),
        rows,
      ),
    ];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, dynamic> catalogWire() {
  final raw =
      jsonDecode(
            File('assets/raid_catalog/raid_catalog.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    'schema_version': 2,
    'catalog_version': raw['catalogVersion'],
    'updated_at': raw['updatedAt'],
    'raids': [
      for (var i = 0; i < (raw['raids'] as List).length; i++)
        {
          'raid_id': raw['raids'][i]['raidId'],
          'official_name': raw['raids'][i]['officialName'],
          'display_name': raw['raids'][i]['displayName'],
          'aliases': raw['raids'][i]['aliases'],
          'display_order': i + 1,
          'party_size': raw['raids'][i]['partySize'],
          'party_count': raw['raids'][i]['partyCount'],
          'required_support_count': raw['raids'][i]['requiredSupportCount'],
          'max_dealer_count_per_class':
              raw['raids'][i]['maxDealerCountPerClass'],
          'gate_count': raw['raids'][i]['gateCount'],
          'is_active': raw['raids'][i]['isActive'],
          'difficulties': [
            for (final d in raw['raids'][i]['difficulties'])
              {
                'difficulty_id': d['difficultyId'],
                'name': d['name'],
                'display_alias': d['displayAlias'],
                'display_order': d['displayOrder'],
                'min_item_level': '${d['minItemLevel']}.00',
                'clear_gold': d['clearGold'],
                'bound_gold': d['boundGold'],
                'is_active': d['isActive'],
              },
          ],
        },
    ],
  };
}

void main() {
  late ReadSessionFake session;
  late Dio dio;
  late ScopedAccountRuntime runtime;
  late MemberRaidClient client;
  late WeeklyMember model;
  late WeeklyMemoryStore store;
  late MemberWeeklyViewModel weekly;
  late DateTime clock;
  late List<RequestOptions> calls;
  late Map<String, Map<String, dynamic>> states, replays;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  var currentCycle = '2026-10-14';
  Map<String, dynamic> cycle() {
    final start = DateTime.parse(
      '${currentCycle}T06:00:00Z',
    ).subtract(const Duration(hours: 9));
    return {
      'server_time': clock.toIso8601String(),
      'cycle_key': currentCycle,
      'starts_at': start.toIso8601String(),
      'ends_at': start.add(const Duration(days: 7)).toIso8601String(),
      'timezone': 'Asia/Seoul',
    };
  }

  Map<String, dynamic> entry(String id, String raid) => {
    'character_id': id,
    'raid_id': raid,
    'cycle_key': currentCycle,
    'revision': 1,
    'ownership_revision': 1,
    'lifecycle_revision': 1,
    'state': 'incomplete',
    'completion_sources': <dynamic>[],
    'participation': null,
    'can_mark_completed': true,
    'can_clear_manual_completion': false,
    'mark_blocked_reason': null,
  };
  DioException bad(
    RequestOptions r,
    String code, {
    int status = 409,
    int? retry,
  }) => DioException.badResponse(
    statusCode: status,
    requestOptions: r,
    response: Response(
      requestOptions: r,
      statusCode: status,
      headers: Headers.fromMap({
        if (retry != null) 'retry-after': ['$retry'],
      }),
      data: {
        'error': {'code': code, 'request_id': 'test'},
      },
    ),
  );
  Map<String, dynamic> serve(RequestOptions r) {
    if (r.path == '/v1/raid-catalog') return catalogWire();
    if (r.path == '/v1/raid-cycle') return cycle();
    if (r.path == '/v1/me/raid-weekly-states') {
      return {
        'current_cycle': cycle(),
        'cycle_key': currentCycle,
        'catalog_version': '2026.08.20',
        'entries': [
          for (final id in r.queryParameters['character_id'] as List)
            for (final raid in catalogWire()['raids'] as List)
              states['$id:${raid['raid_id']}:$currentCycle'] ??
                  entry(id as String, raid['raid_id'] as String),
        ],
      };
    }
    if (r.path.endsWith('/manual-completion')) {
      final key = r.headers['Idempotency-Key'] as String;
      if (replays[key] case final ack?) return ack;
      final id = r.path.split('/')[4],
          raid = r.path.split('/')[6],
          body = r.data as Map;
      final k = '$id:$raid:$currentCycle',
          old = states[k] ?? entry(id, raid),
          completed = body['completed'] == true;
      final sources = (old['completion_sources'] as List)
          .where((s) => s['source'] != 'manual')
          .toList();
      if (completed) {
        sources.add({
          'source': 'manual',
          'completed_at': clock.toIso8601String(),
          'difficulty_id': body['difficulty_id'],
          'party_id': null,
        });
      }
      final value = {
        ...old,
        'revision': old['revision'] + 1,
        'state': sources.isNotEmpty ? 'completed' : 'incomplete',
        'completion_sources': sources,
        'can_clear_manual_completion': completed,
      };
      states[k] = value;
      return replays[key] = value;
    }
    throw StateError('Unexpected ${r.path}');
  }

  setUp(() {
    session = ReadSessionFake()..userId = member;
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final api = DioBackendAccountReadApi(dio, session);
    runtime = ScopedAccountRuntime(
      api: api,
      registrations: ServerAccountReadRepository(api, session),
      databaseFactory: () =>
          throw StateError('Weekly must not open the old/local DB'),
      enabled: true,
    );
    client = MemberRaidClient(api);
    model = WeeklyMember(runtime)..setCount(2);
    store = WeeklyMemoryStore();
    clock = DateTime.utc(2026, 10, 16);
    currentCycle = '2026-10-14';
    calls = [];
    states = {};
    replays = {};
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
    weekly = MemberWeeklyViewModel(
      model: model,
      client: client,
      store: store,
      now: () => clock,
    );
  });
  tearDown(() async {
    weekly.dispose();
    model.dispose();
    await runtime.close();
    session.dispose();
    dio.close();
  });
  ScopedCharacterRef ref() => model.sections.single.characters.first.ref;
  Future<void> load() async {
    await weekly.refresh();
    expect(weekly.failure, isNull);
  }

  test(
    'public catalog/cycle never requests tokens and preserves decimal levels',
    () async {
      session.change(authenticated: false);
      final cat = await client.catalog(), c = await client.cycle();
      expect(cat.raids, hasLength(5));
      expect(c.key, '2026-10-14');
      expect(session.accessCalls, 0);
      expect(calls.every((r) => r.headers['Authorization'] == null), isTrue);
      final json = catalogWire();
      json['raids'][0]['difficulties'][0]['min_item_level'] = '1700.75';
      final exact = memberRaidCatalog(json);
      expect(exact.raids.first.difficulties.first.exactMinItemLevel, '1700.75');
      expect(
        WeeklyRaidDisplayProjector.eligibleCandidates(
          catalog: exact,
          itemLevel: 1700.5,
        ).any((c) => c.raidId == 'kazeros_act4'),
        isFalse,
      );
    },
  );
  test(
    'reads 51 characters in repeated-key batches and never writes on GET',
    () async {
      model.setCount(51);
      await load();
      final reads = calls
          .where((r) => r.path.endsWith('raid-weekly-states'))
          .toList();
      expect(
        reads.map((r) => (r.queryParameters['character_id'] as List).length),
        [50, 1],
      );
      expect(reads.first.uri.queryParametersAll['character_id'], hasLength(50));
      expect(
        reads.first.uri.queryParametersAll.containsKey('character_id[]'),
        isFalse,
      );
      expect(calls.every((r) => r.method == 'GET'), isTrue);
      expect(weekly.items(ref()), hasLength(3));
      expect(weekly.ready, isTrue);
    },
  );
  test(
    'missing/duplicate/foreign/cross-cycle entries never become unchecked writable defaults',
    () async {
      for (final defect in [
        'missing',
        'duplicate',
        'foreign',
        'cycle',
        'version',
      ]) {
        respond = (r) {
          final data = serve(r);
          if (r.path == '/v1/me/raid-weekly-states') {
            final entries = data['entries'] as List;
            if (defect == 'missing') entries.removeLast();
            if (defect == 'duplicate') entries[1] = entries.first;
            if (defect == 'foreign') {
              entries[0] = {...entries[0], 'character_id': characterId};
            }
            if (defect == 'cycle') {
              entries[0] = {...entries[0], 'cycle_key': '2026-10-07'};
            }
            if (defect == 'version') data['catalog_version'] = 'changed';
          }
          return data;
        };
        await weekly.refresh();
        expect(weekly.ready, isFalse, reason: defect);
        expect(weekly.items(ref()).every((i) => !i.canToggle), isTrue);
      }
    },
  );
  test(
    'manual completion and correction use server GET and keep party evidence',
    () async {
      await load();
      final raid = weekly.items(ref()).first;
      await weekly.change(ref(), raid, true);
      expect(weekly.failure, isNull);
      expect(weekly.hasPending, isFalse);
      expect(weekly.entry(ref(), raid.raidId)!.manual, isTrue);
      final k = '${ref().characterId}:${raid.raidId}:$currentCycle';
      states[k] = {
        ...states[k]!,
        'completion_sources': [
          ...states[k]!['completion_sources'] as List,
          {
            'source': 'party',
            'completed_at': clock.toIso8601String(),
            'difficulty_id': raid.difficultyId,
            'party_id': registrationId,
          },
        ],
      };
      await weekly.refresh();
      await weekly.change(ref(), weekly.items(ref()).first, false);
      expect(weekly.entry(ref(), raid.raidId)!.completed, isTrue);
      expect(weekly.entry(ref(), raid.raidId)!.manual, isFalse);
      expect(weekly.entry(ref(), raid.raidId)!.party, isTrue);
      expect(
        weekly.items(ref()).first.statusMessage,
        isNull,
        reason:
            'Party completion evidence does not prove a retained room membership.',
      );
      expect(weekly.canChange(ref(), raid.raidId), isFalse);
      final puts = calls.where((r) => r.method == 'PUT').toList();
      expect((puts.last.data as Map)['difficulty_id'], isNull);
    },
  );
  test(
    'lost ACK survives controller restart with the exact same key/body and no optimistic check',
    () async {
      await load();
      final raid = weekly.items(ref()).first;
      var lose = true;
      respond = (r) {
        final data = serve(r);
        if (r.method == 'PUT' && lose) {
          lose = false;
          throw DioException(requestOptions: r);
        }
        return data;
      };
      await weekly.change(ref(), raid, true);
      expect(weekly.hasPending, isTrue);
      expect(weekly.entry(ref(), raid.raidId)!.completed, isFalse);
      weekly.dispose();
      weekly = MemberWeeklyViewModel(
        model: model,
        client: client,
        store: store,
        now: () => clock,
      );
      await load();
      expect(weekly.hasPending, isTrue);
      await weekly.retry();
      expect(weekly.hasPending, isFalse);
      expect(weekly.entry(ref(), raid.raidId)!.completed, isTrue);
      final puts = calls.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(2));
      expect(puts.first.data, puts.last.data);
      expect(
        puts.first.headers['Idempotency-Key'],
        puts.last.headers['Idempotency-Key'],
      );
      expect(replays, hasLength(1));
    },
  );
  test(
    'ACK followed by GET failure retries GET only and retains durable command',
    () async {
      await load();
      var put = false, failRead = true;
      final raid = weekly.items(ref()).first;
      respond = (r) {
        if (put && failRead && r.path == '/v1/me/raid-weekly-states') {
          throw DioException(requestOptions: r);
        }
        final data = serve(r);
        if (r.method == 'PUT') put = true;
        return data;
      };
      await weekly.change(ref(), raid, true);
      expect(weekly.hasPending, isTrue);
      expect(weekly.ready, isFalse);
      failRead = false;
      await weekly.retry();
      expect(weekly.hasPending, isFalse);
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
    },
  );
  test(
    'disk failure prevents transmission and never changes the visible check',
    () async {
      await load();
      store.failWrite = true;
      final raid = weekly.items(ref()).first;
      await weekly.change(ref(), raid, true);
      expect(weekly.failure, 'LOCAL_STORAGE_FAILED');
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      expect(weekly.entry(ref(), raid.raidId)!.completed, isFalse);
    },
  );
  test(
    'rate-limit retry waits and does not spin or generate a new command',
    () async {
      await load();
      var first = true;
      respond = (r) {
        if (r.method == 'PUT' && first) {
          first = false;
          throw bad(r, 'REQUEST_IN_PROGRESS', retry: 3);
        }
        return serve(r);
      };
      await weekly.change(ref(), weekly.items(ref()).first, true);
      expect(weekly.retrySeconds, 3);
      await weekly.retry();
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      clock = clock.add(const Duration(seconds: 3));
      await weekly.retry();
      expect(calls.where((r) => r.method == 'PUT'), hasLength(2));
      expect(weekly.hasPending, isFalse);
    },
  );
  test(
    'participation and party-only completion are never locally overridden',
    () async {
      final id = ref().characterId, raid = 'serca';
      states['$id:$raid:$currentCycle'] = {
        ...entry(id, raid),
        'state': 'participating',
        'participation': {
          'party_id': registrationId,
          'difficulty_id': 'hard',
          'joined_at': clock.toIso8601String(),
        },
        'can_mark_completed': false,
        'mark_blocked_reason': 'PARTICIPATION_CONFIRMATION_REQUIRED',
      };
      await load();
      final item = weekly.items(ref()).firstWhere((i) => i.raidId == raid);
      expect(item.canToggle, isFalse);
      expect(item.statusMessage, '현재 참가 중인 레이드입니다.');
      await weekly.change(ref(), item, true);
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  test(
    'definitive conflict requires a new GET/current-state decision, never automatic new key',
    () async {
      await load();
      respond = (r) {
        if (r.method == 'PUT') throw bad(r, 'REVISION_CONFLICT');
        return serve(r);
      };
      await weekly.change(ref(), weekly.items(ref()).first, true);
      expect(weekly.pendingFailed, isTrue);
      expect(weekly.canUseCurrent, isFalse);
      await weekly.retry();
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      await weekly.refresh();
      await weekly.useCurrent();
      expect(weekly.hasPending, isFalse);
      expect(
        weekly.entry(ref(), weekly.items(ref()).first.raidId)!.completed,
        isFalse,
      );
    },
  );
  test(
    'server week boundary disables stale checks and old ACK cannot create next-week completion',
    () async {
      await load();
      final raid = weekly.items(ref()).first;
      clock = DateTime.utc(2026, 10, 20, 21);
      currentCycle = '2026-10-21';
      expect(weekly.canChange(ref(), raid.raidId), isFalse);
      await weekly.refresh();
      expect(weekly.cycle!.key, currentCycle);
      expect(weekly.entry(ref(), raid.raidId)!.cycleKey, currentCycle);
    },
  );
  test(
    'late previous-member PUT cannot update next-member state and preserves the old pending request',
    () async {
      await load();
      final captured = runtime.scope, reply = Completer<Map<String, dynamic>>();
      respond = (r) => r.method == 'PUT' ? reply.future : serve(r);
      final work = weekly.change(ref(), weekly.items(ref()).first, true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final put = calls.last;
      session.change(authenticated: true, user: characterId);
      model.setCount(1);
      reply.complete(
        entry(model.sections.first.characters.first.ref.characterId, 'serca'),
      );
      await work;
      expect(weekly.hasPending, isFalse);
      expect(store.data[captured], contains(put.headers['Idempotency-Key']));
      expect(weekly.ready, isFalse);
    },
  );
  test(
    'display choice uses member scope and zero count does not alter the server ledger',
    () async {
      await load();
      await weekly.saveDisplay(
        ref(),
        CharacterWeeklyRaidDisplayPreference(
          characterId: 0,
          displayCount: 0,
          raidIds: [],
        ),
      );
      expect(weekly.items(ref()), isEmpty);
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      weekly.dispose();
      weekly = MemberWeeklyViewModel(
        model: model,
        client: client,
        store: store,
        now: () => clock,
      );
      await load();
      expect(weekly.items(ref()), isEmpty);
      session.change(authenticated: true, user: characterId);
      model.setCount(1);
      await load();
      expect(weekly.items(ref()), hasLength(3));
    },
  );
  test(
    'roster display applies atomically and restores the member setting without ledger writes',
    () async {
      model.setCount(2);
      await load();
      final token = weekly.rosterDisplayToken(registrationId)!;
      await weekly.saveRosterDisplay(registrationId, 1, token);
      for (final row in model.sections.single.characters) {
        expect(weekly.items(row.ref), hasLength(1));
      }
      store.failWrite = true;
      await weekly.saveRosterDisplay(registrationId, 0, token);
      for (final row in model.sections.single.characters) {
        expect(weekly.items(row.ref), hasLength(1));
      }
      expect(weekly.failure, 'LOCAL_STORAGE_FAILED');
      store.failWrite = false;
      weekly.dispose();
      weekly = MemberWeeklyViewModel(
        model: model,
        client: client,
        store: store,
        now: () => clock,
      );
      model.setCount(2);
      await load();
      for (final row in model.sections.single.characters) {
        expect(weekly.items(row.ref), hasLength(1));
      }
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      model.setCount(3);
      await weekly.saveRosterDisplay(registrationId, 0, token);
      expect(
        weekly.items(ref()),
        hasLength(1),
        reason: 'A stale roster dialog cannot apply to a changed roster.',
      );
    },
  );
  test(
    'ownership/lifecycle revision mismatches cannot enable a write',
    () async {
      await load();
      final id = ref().characterId, raid = weekly.items(ref()).first.raidId;
      for (final field in ['ownership_revision', 'lifecycle_revision']) {
        states['$id:$raid:$currentCycle'] = {...entry(id, raid), field: 2};
        await weekly.refresh();
        expect(weekly.canChange(ref(), raid), isFalse);
        await weekly.change(ref(), weekly.items(ref()).first, true);
      }
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  test(
    'cycle ending during batched GET never publishes an editable result',
    () async {
      respond = (r) {
        final result = serve(r);
        if (r.path == '/v1/me/raid-weekly-states') {
          clock = DateTime.utc(2026, 10, 20, 21);
        }
        return result;
      };
      await weekly.refresh();
      expect(weekly.failure, 'CYCLE_CHANGED');
      expect(weekly.ready, isFalse);
      expect(weekly.items(ref()).every((r) => !r.canToggle), isTrue);
    },
  );
  test(
    'an uncertain request expires without transmitting another PUT',
    () async {
      await load();
      respond = (r) {
        if (r.method == 'PUT') throw bad(r, 'NETWORK_UNAVAILABLE');
        return serve(r);
      };
      await weekly.change(ref(), weekly.items(ref()).first, true);
      clock = clock.add(const Duration(hours: 24));
      await weekly.retry();
      expect(weekly.failure, 'REQUEST_EXPIRED');
      expect(weekly.pendingFailed, isTrue);
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
    },
  );
  test(
    'switching members during post-ACK GET completes without leaking or throwing',
    () async {
      await load();
      final reply = Completer<Map<String, dynamic>>();
      respond = (r) =>
          r.path == '/v1/me/raid-weekly-states' ? reply.future : serve(r);
      final work = weekly.change(ref(), weekly.items(ref()).first, true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      session.change(authenticated: true, user: characterId);
      model.setCount(1);
      reply.complete({});
      await work;
      expect(weekly.hasPending, isFalse);
      expect(weekly.ready, isFalse);
    },
  );
  test(
    'manual save preserves row information through PUT, GET and cleanup',
    () async {
      await load();
      final target = weekly.items(ref()).first;
      final putStarted = Completer<void>(), releasePut = Completer<void>();
      final getStarted = Completer<void>(), releaseGet = Completer<void>();
      var wrote = false;
      respond = (r) async {
        if (r.method == 'PUT') {
          putStarted.complete();
          await releasePut.future;
          wrote = true;
        } else if (wrote && r.path == '/v1/me/raid-weekly-states') {
          getStarted.complete();
          await releaseGet.future;
        }
        return serve(r);
      };
      final snapshots = <bool>[];
      void observe() {
        if (weekly.hasPending) {
          snapshots.add(weekly.busy);
        }
        expect(
          weekly.items(ref()).every((r) => r.statusMessage == null),
          isTrue,
        );
      }

      weekly.addListener(observe);
      final work = weekly.change(ref(), target, true);
      await putStarted.future;
      expect(weekly.items(ref()).first.isCompleted, isFalse);
      expect(weekly.canChange(ref(), target.raidId), isFalse);
      await weekly.retry();
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      releasePut.complete();
      await getStarted.future;
      expect(weekly.busy, isTrue);
      expect(weekly.items(ref()).first.isCompleted, isFalse);
      releaseGet.complete();
      await work;
      expect(snapshots, isNotEmpty);
      expect(snapshots.every((v) => v), isTrue);
      expect(weekly.items(ref()).first.isCompleted, isTrue);
      expect(weekly.items(ref()).first.statusMessage, isNull);
      expect(weekly.busy, isFalse);
      weekly.removeListener(observe);
      respond = serve;
      await weekly.change(ref(), weekly.items(ref()).first, false);
      expect(weekly.items(ref()).first.isCompleted, isFalse);
      expect(weekly.items(ref()).first.statusMessage, isNull);
    },
  );
}
