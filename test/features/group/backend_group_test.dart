import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/group/data/backend/group_contract.dart';
import 'package:lost_party/features/group/data/backend/group_models.dart';
import 'package:lost_party/features/group/data/backend/group_repository.dart';
import 'package:lost_party/features/group/presentation/viewmodels/backend_group_view_model.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import '../recruitment_list/backend_recruitment_test.dart' as old;
import '../../support/server_account_read_fakes.dart';

const gid = '11111111-1111-4111-8111-111111111111';
const mid = '22222222-2222-4222-8222-222222222222';
const stamp = '2026-10-29T00:00:00Z';
const groupPath = '/v1/groups/$gid/leave';
Map<String, dynamic> cas() => {
  'expected_group_revision': 1,
  'expected_members_revision': 1,
  'expected_membership_id': mid,
  'expected_membership_revision': 1,
};
Map<String, dynamic> ack() => {
  'group_id': gid,
  'membership_id': mid,
  'membership_revision': 2,
  'ended_at': stamp,
};
Map<String, dynamic> summary() => {
  'group_id': gid,
  'name': '그룹',
  'revision': 1,
  'member_count': 1,
  'representative': {
    'display': {
      'server_name': '서버',
      'character_name': '기사',
      'class_name': '바드',
    },
    'status': 'valid',
  },
  'leader_display': null,
};

class MemoryJournal implements GroupJournal {
  final values = <String, String>{};
  bool failWrite = false, failDelete = false;
  void Function(String?)? afterWrite;
  @override
  Future<String?> read(String scope) async => values[scope];
  @override
  Future<void> write(String scope, String? value) async {
    if (failWrite || value == null && failDelete) {
      throw StateError('storage failure');
    }
    if (value == null) {
      values.remove(scope);
    } else {
      values[scope] = value;
    }
    afterWrite?.call(value);
  }
}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  int calls = 0;
  final bodies = <String>[], keys = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    bodies.add(
      body == null ? '' : utf8.decode(await body.expand((v) => v).toList()),
    );
    keys.add(options.headers['Idempotency-Key']?.toString() ?? '');
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody reply(Object value, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
void main() {
  test(
    'retained group state is opt-in, validated separately and absent from old parser',
    () async {
      final api = old.Api();
      api.respond = (_, query) async {
        expect(query?['include_group_state'], 'true');
        return {
          'scope': <String, dynamic>{},
          'data': <String, dynamic>{},
          'group_state': {'group_id': gid, 'name': '이전 그룹', 'state': 'ended'},
        };
      };
      final result = await readRecruitment(
        api: api,
        mode: RecruitmentContractMode.legacy,
        path: '/v2/raid-rooms/$gid/detail',
        includeGroupState: true,
        parse: (raw) {
          expect(raw.containsKey('group_state'), false);
          return raw;
        },
      );
      expect(retainedGroupLabel(result.metadata), contains('해산된 그룹'));
      api.respond = (_, _) async => {
        'scope': {},
        'data': {},
        'group_state': {'group_id': gid, 'name': null, 'state': 'invented'},
      };
      await expectLater(
        readRecruitment(
          api: api,
          mode: RecruitmentContractMode.legacy,
          path: '/v2/raid-rooms/$gid/detail',
          includeGroupState: true,
          parse: (j) => j,
        ),
        throwsFormatException,
      );
    },
  );

  late ReadSessionFake session;
  late MemoryJournal journal;
  late GroupChanges changes;
  late Dio dio;
  GroupRepository repo() =>
      GroupRepository(dio, session, changes, journal: journal);
  setUp(() {
    session = ReadSessionFake()..userId = gid;
    journal = MemoryJournal();
    changes = GroupChanges();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  });
  tearDown(() {
    dio.close(force: true);
    changes.dispose();
    session.dispose();
  });
  test(
    'member changes during ACK persistence do not notify the new member or resurrect a request',
    () async {
      final r = repo();
      final adapter = Adapter((_) async => reply(ack()));
      dio.httpClientAdapter = adapter;
      journal.afterWrite = (value) {
        if (value != null && jsonDecode(value)['state'] == 'acknowledged') {
          session.change(authenticated: true, user: mid);
        }
      };
      await expectLater(
        r.command('POST', groupPath, cas()),
        throwsA(isA<AccountReadException>()),
      );
      expect(changes.version, 0);
      expect(journal.values, isEmpty);
      expect(adapter.calls, 1);
    },
  );
  test('strict DTO rejects missing, unknown fields and invalid IDs', () {
    GroupContract.response('GET', '/v1/groups/$gid', 200, summary());
    expect(
      () => GroupContract.response('GET', '/v1/groups/$gid', 200, {
        ...summary(),
        'owner': gid,
      }),
      throwsFormatException,
    );
    expect(
      () => GroupContract.request('POST', groupPath, {}, {
        ...cas(),
        'expected_membership_id': 'old-player',
      }),
      throwsFormatException,
    );
    expect(
      () => GroupContract.request('GET', '/v1/groups', {'limit': 0}, null),
      throwsFormatException,
    );
  });
  test(
    'raw original is persisted before HTTP; uncertain retry reuses exact bytes and key',
    () async {
      var fail = true;
      final r = repo();
      final adapter = Adapter((o) async {
        expect(journal.values, isNotEmpty);
        if (fail) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return reply(ack());
      });
      dio.httpClientAdapter = adapter;
      await expectLater(
        r.command('POST', groupPath, cas()),
        throwsA(isA<AccountReadException>()),
      );
      final original = await r.pending();
      expect(original, isNotNull);
      fail = false;
      original!['retry_at'] = null;
      journal.values[r.storageScope] = jsonEncode(original);
      await r.recover();
      expect(adapter.bodies[0], adapter.bodies[1]);
      expect(adapter.keys[0], adapter.keys[1]);
      expect(journal.values, isEmpty);
      expect(changes.version, 1);
    },
  );
  test(
    'failure to save means no HTTP; duplicate input cannot change pending request',
    () async {
      final r = repo();
      final gate = Completer<ResponseBody>();
      final adapter = Adapter((_) => gate.future);
      dio.httpClientAdapter = adapter;
      journal.failWrite = true;
      await expectLater(r.command('POST', groupPath, cas()), throwsStateError);
      expect(adapter.calls, 0);
      journal.failWrite = false;
      final first = r.command('POST', groupPath, cas());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectLater(
        r.command('POST', groupPath, cas()),
        throwsA(isA<AccountReadException>()),
      );
      gate.complete(reply(ack()));
      await first;
      expect(adapter.calls, 1);
    },
  );
  test(
    'late response after member transition never grants access or emits current changes',
    () async {
      final gate = Completer<ResponseBody>();
      dio.httpClientAdapter = Adapter((_) => gate.future);
      final r = repo(), pending = r.command('POST', groupPath, cas());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      session.change(authenticated: true, user: mid);
      gate.complete(reply(ack()));
      await expectLater(pending, throwsA(isA<AccountReadException>()));
      expect(changes.version, 0);
      expect(await r.pending(), isNull);
      expect(journal.values.length, 1);
    },
  );
  test(
    'acknowledged journal survives failed cleanup and recovery never resends old leave',
    () async {
      final r = repo(), adapter = Adapter((_) async => reply(ack()));
      dio.httpClientAdapter = adapter;
      journal.failDelete = true;
      await expectLater(r.command('POST', groupPath, cas()), throwsStateError);
      expect((await r.pending())!['state'], 'acknowledged');
      journal.failDelete = false;
      await r.recover();
      expect(adapter.calls, 1);
      expect(journal.values, isEmpty);
    },
  );
  test(
    'successful command followed by refresh failure stays successful',
    () async {
      final r = repo();
      final adapter = Adapter(
        (o) async => o.method == 'POST'
            ? reply(ack())
            : reply({
                'error': {'code': 'GROUP_FEATURE_NOT_READY'},
              }, 503),
      );
      dio.httpClientAdapter = adapter;
      final m = BackendGroupViewModel(r, GroupPageKind.home);
      final result = await m.act('POST', groupPath, cas());
      expect(result, isNotNull);
      expect(m.notice, isNotNull);
      expect(m.failure, isA<AccountReadException>());
      expect(journal.values, isEmpty);
      expect(adapter.calls, 2);
      m.dispose();
    },
  );
  test(
    'cursor stale restarts only once and does not silently truncate',
    () async {
      var calls = 0;
      dio.httpClientAdapter = Adapter((o) async {
        calls++;
        if (calls <= 2) {
          return reply({
            'error': {'code': 'CURSOR_STALE'},
          }, 409);
        }
        return reply({'items': [], 'next_cursor': null});
      });
      await expectLater(
        repo().all('/v1/groups', query: {'q': 'test'}),
        throwsA(isA<AccountReadException>()),
      );
      expect(calls, 2);
    },
  );
  test(
    'missing requested profile is not interpreted as a complete display',
    () async {
      dio.httpClientAdapter = Adapter(
        (_) async =>
            reply({'items': [], 'next_cursor': null, 'directory_revision': 1}),
      );
      await expectLater(
        repo().get(
          '/v1/me/groups',
          query: {'reader_profile': 'group-display-1'},
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'role errors and last success remain distinct; no synthesized gem counts',
    () {
      final text = groupSpecText({
        'state': 'partial',
        'item_level': null,
        'dealer': {
          'combat_power': '100',
          'analysis': {
            'integrity_status': 'error',
            'issues': [
              {'code': 'GEM_SLOT_COUNT', 'severity': 'error'},
            ],
          },
        },
        'support': {'combat_power': null, 'analysis': null},
      });
      expect(text, contains('보석 오류'));
      expect(text, contains('마지막 성공'));
      expect(text, isNot(contains('/11')));
    },
  );
}
