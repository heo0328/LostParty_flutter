import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_read_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as base;

Map<String, dynamic> copy(Object v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
final samples =
    (jsonDecode(File('test/fixtures/cycle_archive.json').readAsStringSync())
            as Map)['examples']
        as Map;
Map<String, dynamic> row(String name) =>
    copy(samples[name]['data']['items'][0]);
const explicit = 'explicit_generation_review_membership',
    unknown = 'explicit_unknown_generation_review_membership';

void main() {
  test(
    'published review with known generation remains visible and opens detail',
    () {
      final r = CycleOwnRow(row(explicit), f1.next, false);
      expect(r.isActiveParticipation, true);
      expect(r.isEndedParticipation, false);
      expect(r.canView, true);
    },
  );
  test(
    'unknown generation actual review keeps advisory row without invented card or link',
    () {
      final r = CycleOwnRow(row(unknown), f1.next, false);
      expect(r.recoveryOnly, true);
      expect(r.isActiveParticipation, true);
      expect(r.card, null);
      expect(r.canView, false);
      expect(r.isEndedParticipation, false);
    },
  );
  for (final state in [
    'completed',
    'stopped',
    'cancelled',
    'not_selected',
    'legacy_intent',
  ]) {
    test('$state is not active; only actual endings are records', () {
      final j = row(explicit);
      j['target_participation_state'] = state;
      j['room']['target_state'] = state == 'completed' ? 'completed' : 'open';
      final r = CycleOwnRow(j, f1.next, false);
      expect(r.isActiveParticipation, false);
      expect(
        r.isEndedParticipation,
        {'completed', 'stopped', 'cancelled'}.contains(state),
      );
    });
  }
  test('persistent ended/history and archived rooms cannot remain active', () {
    for (final field in ['state', 'history_only', 'room']) {
      final j = row(explicit);
      if (field == 'state') j[field] = 'ended';
      if (field == 'history_only') j[field] = true;
      if (field == 'room') {
        j['room']['state'] = 'ended';
        j['room']['phase'] = 'ended';
      }
      final r = CycleOwnRow(j, f1.next, false);
      expect(r.isActiveParticipation, false);
      expect(r.isEndedParticipation, true);
    }
  });
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing actual CM': (j) => j['cycle_member_id'] = null,
    'fabricated generation': (j) => j['target_generation'] = 1,
    'invented assignments': (j) => j['assignments'] = [{}],
    'false permission': (j) => j['permissions']['view_plan']['allowed'] = true,
  }.entries) {
    test('reject invalid recovery row ${mutation.key}', () {
      final j = row(unknown);
      mutation.value(j);
      expect(() => CycleOwnRow(j, f1.next, false), throwsFormatException);
    });
  }
  test('row/card cycle evidence cannot mix generations/revisions', () {
    final j = row(explicit);
    j['target_revision']++;
    expect(() => CycleOwnRow(j, f1.next, false), throwsFormatException);
  });

  late ReadSessionFake session;
  late Dio dio;
  late DioBackendAccountReadApi api;
  late CycleReadRepository repo;
  late List<RequestOptions> calls;
  late ChangeNotifier changes;
  late CycleReadViewModel m;
  late FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  Map<String, dynamic> page(
    List<Map<String, dynamic>> rows, {
    String? cursor,
  }) => {
    'scope': f1.scope(f1.next),
    'data': {
      'items': rows,
      'membership_head': 1,
      'next_cursor': cursor,
      'evaluated_at': '2026-10-23T07:40:32Z',
    },
  };
  setUp(() {
    session = ReadSessionFake();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    api = DioBackendAccountReadApi(dio, session);
    repo = CycleReadRepository(api);
    calls = [];
    changes = ChangeNotifier();
    respond = (_) => page([
      row(explicit),
      {
        ...row(unknown),
        'membership_id': '00000000-0000-4000-8000-000000000001',
      },
    ]);
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
    m = CycleReadViewModel(
      repository: repo,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
    );
  });
  tearDown(() {
    m.dispose();
    changes.dispose();
    session.dispose();
    dio.close(force: true);
  });
  test(
    'record query uses ended, ordinary membership uses current, all is not requested',
    () async {
      await repo.own(f1.next);
      await repo.own(f1.next, history: true);
      expect(calls.map((r) => r.queryParameters['state']), [
        'current',
        'ended',
      ]);
      expect(calls.every((r) => r.headers['Idempotency-Key'] == null), true);
    },
  );
  test(
    'current page includes actual recovery rows without fabricated detail link',
    () async {
      m.select(f1.next);
      await f1.settled(() => !m.loading);
      expect(m.failure, null);
      expect(m.visibleRows, hasLength(2));
      expect(m.visibleRows.last.canView, false);
    },
  );
  test(
    'records exclude not-selected even from an old all-like response and retain stopped',
    () async {
      final j = row(explicit);
      j['target_participation_state'] = 'stopped';
      final none = row(explicit);
      none['membership_id'] = '00000000-0000-4000-8000-000000000001';
      none['target_participation_state'] = 'not_selected';
      respond = (_) => page([j, none]);
      m.select(f1.next, section: 2);
      await f1.settled(() => !m.loading);
      expect(calls.single.queryParameters['state'], 'ended');
      expect(m.visibleRows.single.participationState, 'stopped');
    },
  );
  test(
    'pagination keeps real recovery rows and rejects repeated cursor',
    () async {
      respond = (_) => page([row(unknown)], cursor: 'same');
      m.select(f1.next);
      await f1.settled(() => !m.loading);
      expect(m.visibleRows, hasLength(1));
      expect(m.cursor, 'same');
      await m.load(more: true);
      expect(m.failure, 'INVALID_RESPONSE');
      expect(m.rows, hasLength(1));
    },
  );
  test('old member response cannot replace new member data', () async {
    final gate = Completer<Map<String, dynamic>>();
    respond = (_) => gate.future;
    m.select(f1.next);
    session.change(authenticated: false);
    gate.complete(page([row(explicit)]));
    await Future<void>.delayed(Duration.zero);
    expect(m.rows, isEmpty);
  });
  test(
    'published archived detail/plan open directly without public card GET',
    () async {
      final a = base.Api();
      final raw = copy(samples['archived_member_detail']);
      final room = raw['data']['room']['room_id'] as String;
      a.respond = (path, _) async {
        expect(path, '/v2/raid-rooms/$room/detail');
        return copy(raw);
      };
      final backend = BackendRecruitmentRepository(
        api: a,
        accounts: ServerAccountReadRepository(ReadApiFake(), session),
        raids: MemberRaidClient(api),
        twoCycleEnabled: true,
      );
      final detail = await backend.cycleDetail(room, f1.current);
      expect(detail.room['state'], 'ended');
      expect(detail.room['target_state'], 'completed');
      expect(detail.members, isNotEmpty);
      final plan = CycleScheduleView(
        room,
        f1.current,
        'plan',
        copy(samples['archived_member_plan']),
      );
      expect(plan.data['target_state'], 'completed');
      expect(plan.data['formation_history'], isNotEmpty);
      expect(
        (plan.data['permissions'] as Map).values.every(
          (p) => p['allowed'] == false,
        ),
        true,
      );
      expect(a.requests, hasLength(1));
    },
  );
}
