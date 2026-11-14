import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/scoped_account_runtime.dart';
import 'package:lost_party/features/account/data/v2_character_management_gateway.dart';
import 'package:lost_party/features/account/data/management_command_journal.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/character_management_context.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/character_management_view_model.dart';
import '../../../support/server_account_read_fakes.dart';
import 'character_management_gateway_test.dart' show NoLocalAccounts;

// Fixed synthetic contract: backend 026a74fa67c36d72fb9d6d94d8bafcf707d4ffe9.
final examples =
    jsonDecode(
          File(
            'test/features/account/backend_read/fixtures/character_management_examples.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
Map<String, dynamic> context([String name = 'configured']) {
  final value =
      jsonDecode(jsonEncode((examples['contexts'] as Map)[name]))
          as Map<String, dynamic>;
  value['scope']['policy_version'] = 'character-management-2';
  value['scope']['is_main'] = true;
  for (final row in value['data']['characters']) {
    row['combat_power'] = null;
    row['combat_power_observed_at'] = null;
    row['item_level_observed_at'] = row['item_level'] == null
        ? null
        : value['data']['evaluated_at'];
  }
  return value;
}

class MemoryJournal implements ManagementJournalStorage {
  final values = <String, String>{};
  bool failWrite = false;
  String key(StorageScope s, String id) => '${s.environment}/${s.userId}/$id';
  @override
  Future<String?> read(StorageScope s, String id) async => values[key(s, id)];
  @override
  Future<void> write(StorageScope s, String id, String? value) async {
    if (failWrite) throw StateError('disk failed');
    if (value == null) {
      values.remove(key(s, id));
    } else {
      values[key(s, id)] = value;
    }
  }
}

void main() {
  test(
    'policy2 subordinate null representative keeps every activity movable',
    () {
      final json = context();
      json['scope']['is_main'] = false;
      json['data']['representative_character_id'] = null;
      final value = CharacterManagementContext.fromJson(json);
      final body = value.command(
        value.activityIds,
        null,
        ordered: value.activityIds,
      );
      expect(body['policy_version'], 'character-management-2');
      expect(body['representative_character_id'], isNull);
      CharacterManagementContext.validateCommandBody(body);
      expect(
        () => value.command(value.activityIds, value.activityIds.first),
        throwsFormatException,
      );
    },
  );

  test(
    'automatic representative uses exact decimal and keeps valid representative',
    () {
      final json = context();
      json['data']['representative_character_id'] = null;
      final rows = json['data']['characters'] as List;
      rows[0]['item_level'] = '1700';
      rows[1]['item_level'] = '1700.000000000000000001';
      final value = CharacterManagementContext.fromJson(json);
      expect(
        value.automaticRepresentative(value.activityIds),
        rows[1]['character_id'],
      );
      json['data']['representative_character_id'] = rows[0]['character_id'];
      final kept = CharacterManagementContext.fromJson(json);
      expect(
        kept.automaticRepresentative(kept.activityIds),
        rows[0]['character_id'],
      );
      expect(compareManagementDecimal(null, '0'), greaterThan(0));
      expect(compareManagementDecimal('1.01', '1.0101'), greaterThan(0));
    },
  );

  group('closed DTO and degraded recovery context', () {
    test('1000 context and 200 activity limits reject rather than truncate', () {
      final j = context();
      final data = j['data'] as Map;
      final template = Map<String, dynamic>.from(data['characters'][0] as Map);
      final rows = List.generate(
        1001,
        (i) => {
          ...template,
          'character_id':
              '00000000-0000-4000-8000-${i.toRadixString(16).padLeft(12, '0')}',
        },
      );
      void setRows(int count) {
        data['characters'] = rows.take(count).toList();
        data['ordered_all_character_ids'] = rows
            .take(count)
            .map((r) => r['character_id'])
            .toList();
      }

      setRows(1000);
      expect(
        CharacterManagementContext.fromJson(j).characters,
        hasLength(1000),
      );
      setRows(1001);
      expect(() => CharacterManagementContext.fromJson(j), throwsA(anything));
      setRows(1000);
      data['activity_character_ids'] = rows
          .take(201)
          .map((r) => r['character_id'])
          .toList();
      expect(() => CharacterManagementContext.fromJson(j), throwsA(anything));
    });
    test('name limit counts Unicode code points', () {
      final j = context();
      j['data']['characters'][0]['character_name'] = List.filled(
        64,
        '😀',
      ).join();
      expect(
        CharacterManagementContext.fromJson(j).characters.first.name.runes,
        hasLength(64),
      );
      j['data']['characters'][0]['character_name'] += '😀';
      expect(() => CharacterManagementContext.fromJson(j), throwsA(anything));
    });
    for (final name in (examples['contexts'] as Map).keys.cast<String>()) {
      test('accepts $name without treating state as current eligibility', () {
        final value = CharacterManagementContext.fromJson(context(name));
        expect(value.characters.map((r) => r.id), value.orderedIds);
      });
    }
    test(
      'rejects unknown/missing fields, uppercase IDs, malformed date and row order',
      () {
        final changes = <void Function(Map<String, dynamic>)>[
          (j) => j['extra'] = 1,
          (j) => (j['data'] as Map).remove('order_digest'),
          (j) => (j['scope'] as Map)['registration_id'] =
              'AAAAAAAA-0000-4000-8000-000000000001',
          (j) => (j['data'] as Map)['evaluated_at'] = '2026-02-31T00:00:00Z',
          (j) => ((j['data'] as Map)['characters'] as List).removeLast(),
          (j) => ((j['data'] as Map)['characters'] as List).first['usable'] =
              false,
        ];
        for (final change in changes) {
          final j = context();
          change(j);
          expect(
            () => CharacterManagementContext.fromJson(j),
            throwsA(anything),
          );
        }
      },
    );
    test('requires semantic exact subset and nonnull optional order', () {
      for (final entry in examples['puts'].values) {
        CharacterManagementContext.validateCommandBody(
          Map<String, dynamic>.from(entry),
        );
      }
      for (final entry in examples['semantic_rejections']) {
        expect(
          () => CharacterManagementContext.validateCommandBody(
            Map<String, dynamic>.from(entry['body']),
          ),
          throwsA(anything),
        );
      }
    });
    test('freezes input and preserves arbitrary precision level text', () {
      final j = context();
      final data = j['data'] as Map;
      data['characters'][0]['item_level'] =
          '1700.00000000000000000000000000001';
      final value = CharacterManagementContext.fromJson(j);
      data['characters'][0]['item_level'] = '0';
      expect(
        value.characters.first.level,
        '1700.00000000000000000000000000001',
      );
    });
  });
  group('v2 app-owned write lane', () {
    late ReadSessionFake session;
    late Dio dio;
    late ScopedAccountRuntime runtime;
    late V2CharacterManagementGateway gateway;
    late MemoryJournal journal;
    late Map<String, dynamic> current;
    late List<RequestOptions> calls;
    late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
    late String reg;
    bool main = true;
    setUp(() {
      session = ReadSessionFake()
        ..userId = '00000000-0000-4000-8000-000000000099';
      journal = MemoryJournal();
      current = context();
      reg = (current['scope'] as Map)['registration_id'] as String;
      calls = [];
      main = true;
      dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      respond = (r) => jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) async {
            calls.add(r);
            try {
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: r.path.endsWith('/representative')
                      ? {
                          ...Map<String, dynamic>.from(current['scope'] as Map)
                            ..remove('policy_version'),
                          'is_main': main,
                          'representative_character_id':
                              current['data']['representative_character_id'],
                          'configuration_state':
                              current['data']['configuration_state'],
                          'next_change_at': null,
                        }
                      : await respond(r),
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
      final api = DioBackendAccountReadApi(dio, session);
      runtime = ScopedAccountRuntime(
        api: api,
        registrations: ServerAccountReadRepository(api, session),
        databaseFactory: () => throw StateError('No legacy cache writes'),
        enabled: true,
      );
      gateway = V2CharacterManagementGateway(
        runtime,
        reg,
        otherWorkPending: () => false,
        journal: journal,
      );
    });
    tearDown(() async {
      gateway.dispose();
      await runtime.close();
      dio.close(force: true);
      session.dispose();
    });
    test(
      'policy1 journal preserves original request and historical ACK',
      () async {
        final ctx = CharacterManagementContext.fromJson(current);
        final original = ctx.command(ctx.activityIds, ctx.representativeId)
          ..remove('policy_version');
        journal.values[journal.key(runtime.scope, reg)] = jsonEncode({
          'schema': 1,
          'registration_id': reg,
          'key': '00000000-0000-4000-8000-000000000088',
          'body': original,
          'acknowledged': false,
        });
        respond = (r) {
          if (r.method == 'PUT') {
            expect(r.data, original);
            return jsonDecode(jsonEncode(examples['contexts']['configured']))
                as Map<String, dynamic>;
          }
          return current;
        };
        final s = await gateway.load();
        await gateway.save(
          selectedIds: s.selectedIds.toList(),
          representativeId: s.account.representativeCharacterId,
          displayLimit: 1,
          saveDisplayOrder: false,
        );
        expect(journal.values, isEmpty);
        expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      },
    );

    Future<void> save({bool order = false}) async {
      final s = await gateway.load();
      await gateway.save(
        selectedIds: s.selectedIds.toList(),
        representativeId: s.account.representativeCharacterId!,
        displayLimit: 1,
        saveDisplayOrder: order,
      );
    }

    test(
      'one PUT only, omit order on toggle/representative, then current GET',
      () async {
        await save();
        final writes = calls.where((r) => r.method == 'PUT').toList();
        expect(writes, hasLength(1));
        expect(
          writes.single.path,
          endsWith('/v2/me/game-accounts/$reg/character-settings'),
        );
        expect(
          (writes.single.data as Map).containsKey('ordered_character_ids'),
          false,
        );
        expect(calls.last.method, 'GET');
        expect(journal.values, isEmpty);
        expect(gateway.pending, false);
      },
    );
    test('network loss and page re-entry retain exact key and body', () async {
      final s = await gateway.load();
      var failed = false;
      respond = (r) {
        if (r.method == 'PUT' && !failed) {
          failed = true;
          throw DioException(requestOptions: r);
        }
        return context();
      };
      Future<void> write() => gateway.save(
        selectedIds: s.selectedIds.toList(),
        representativeId: s.account.representativeCharacterId!,
        displayLimit: 1,
        saveDisplayOrder: false,
      );
      await expectLater(write(), throwsA(isA<AccountReadException>()));
      final original = calls.last;
      expect(gateway.pending, true);
      gateway.dispose();
      gateway = V2CharacterManagementGateway(
        runtime,
        reg,
        otherWorkPending: () => false,
        journal: journal,
      );
      await gateway.load();
      await write();
      final replay = calls.where((r) => r.method == 'PUT').last;
      expect(
        replay.headers['Idempotency-Key'],
        original.headers['Idempotency-Key'],
      );
      expect(replay.data, original.data);
      expect(journal.values, isEmpty);
    });
    test('GET failure after ACK retries GET without another PUT', () async {
      final s = await gateway.load();
      var acknowledged = false;
      var fail = true;
      respond = (r) {
        if (r.method == 'PUT') {
          acknowledged = true;
        } else if (acknowledged && fail) {
          throw DioException(requestOptions: r);
        }
        return context();
      };
      Future<void> write() => gateway.save(
        selectedIds: s.selectedIds.toList(),
        representativeId: s.account.representativeCharacterId!,
        displayLimit: 1,
        saveDisplayOrder: false,
      );
      await expectLater(write(), throwsA(anything));
      expect(gateway.pending, true);
      fail = false;
      await write();
      expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      expect(gateway.pending, false);
    });
    test(
      'definite conflict reads current state before a new explicit command',
      () async {
        final s = await gateway.load();
        var conflict = true;
        respond = (r) {
          if (r.method == 'PUT' && conflict) {
            throw DioException(
              requestOptions: r,
              response: Response(
                requestOptions: r,
                statusCode: 409,
                data: {
                  'error': {'code': 'REVISION_CONFLICT'},
                },
              ),
            );
          }
          return context();
        };
        Future<void> write() => gateway.save(
          selectedIds: s.selectedIds.toList(),
          representativeId: s.account.representativeCharacterId!,
          displayLimit: 1,
          saveDisplayOrder: false,
        );
        await expectLater(write(), throwsA(isA<AccountReadException>()));
        expect(calls.last.method, 'GET');
        expect(gateway.pending, false);
        final first = calls.singleWhere((r) => r.method == 'PUT');
        conflict = false;
        await write();
        final second = calls.where((r) => r.method == 'PUT').last;
        expect(
          second.headers['Idempotency-Key'],
          isNot(first.headers['Idempotency-Key']),
        );
        expect(journal.values, isEmpty);
      },
    );
    test('journal write failure prevents network command', () async {
      final s = await gateway.load();
      journal.failWrite = true;
      await expectLater(
        gateway.save(
          selectedIds: s.selectedIds.toList(),
          representativeId: s.account.representativeCharacterId!,
          displayLimit: 1,
        ),
        throwsA(anything),
      );
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
    });
    test(
      'secondary registration cannot select an account representative',
      () async {
        main = false;
        current['scope']['is_main'] = false;
        current['data']['representative_character_id'] = null;
        final vm = CharacterManagementViewModel(
          accountRepository: NoLocalAccounts(),
          managementGateway: gateway,
        );
        addTearDown(vm.dispose);
        await vm.initialize();
        expect(vm.account!.isMain, false);
        expect(vm.canChooseAccountRepresentative, false);
        expect(vm.canSetRepresentative(vm.selectedCharacters.last), false);
        final s = await gateway.load();
        await expectLater(
          gateway.save(
            selectedIds: s.selectedIds.toList(),
            representativeId: s.selectedIds.last,
            displayLimit: 1,
            saveDisplayOrder: false,
          ),
          throwsA(isA<AccountReadException>()),
        );
        expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      },
    );
    test(
      'corrupt stored body fails closed without overwriting or PUT',
      () async {
        journal.values[journal.key(runtime.scope, reg)] = '{"schema":1}';
        await expectLater(gateway.load(), throwsA(isA<AccountReadException>()));
        expect(journal.values.values.single, '{"schema":1}');
        expect(calls, isEmpty);
      },
    );
    test(
      'concurrent command rejected and changed auth discards late response',
      () async {
        final s = await gateway.load();
        final reply = Completer<Map<String, dynamic>>();
        final started = Completer<void>();
        respond = (r) {
          if (r.method == 'PUT') {
            started.complete();
            return reply.future;
          }
          return context();
        };
        Future<void> write() => gateway.save(
          selectedIds: s.selectedIds.toList(),
          representativeId: s.account.representativeCharacterId!,
          displayLimit: 1,
          saveDisplayOrder: false,
        );
        final first = write();
        final rejected = expectLater(
          first,
          throwsA(isA<AccountReadException>()),
        );
        await started.future;
        await expectLater(write(), throwsA(isA<AccountReadException>()));
        session.change(
          authenticated: true,
          user: '00000000-0000-4000-8000-000000000098',
        );
        reply.complete(context());
        await rejected;
        expect(gateway.current, false);
        expect(calls.where((r) => r.method == 'PUT'), hasLength(1));
      },
    );
    test(
      'recovery GET never automatically removes stored missing selection',
      () async {
        current = context('configured_with_unusable_residue');
        final s = await gateway.load();
        expect(s.residueCount, 1);
        expect(s.warning, isNotNull);
        expect(calls.where((r) => r.method == 'PUT'), isEmpty);
        await expectLater(
          gateway.save(
            selectedIds: s.usableIds.toList(),
            representativeId: s.usableIds.first,
            displayLimit: 1,
          ),
          throwsA(isA<AccountReadException>()),
        );
        expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      },
    );
    test(
      'VM preserves canonical order and keeps representative outside movable subset',
      () async {
        final data = current['data'] as Map;
        data['activity_character_ids'] = List.of(
          data['ordered_all_character_ids'],
        );
        final vm = CharacterManagementViewModel(
          accountRepository: NoLocalAccounts(),
          managementGateway: gateway,
        );
        addTearDown(vm.dispose);
        await vm.initialize();
        expect(vm.immediateSave, true);
        expect(vm.message, isNull);
        vm.reorderMovable(0, 2);
        await vm.save();
        expect(vm.message, isNull);
        final body = calls.singleWhere((r) => r.method == 'PUT').data as Map;
        expect(body['ordered_character_ids'], [
          data['ordered_all_character_ids'][2],
          data['ordered_all_character_ids'][1],
        ]);
        expect(
          (body['ordered_character_ids'] as List),
          isNot(contains(data['representative_character_id'])),
        );
      },
    );
  });
}
