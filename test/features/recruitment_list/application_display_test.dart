import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/application_display_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_detail_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as f2;
import 'cycle_interaction_test.dart' as f3;

const room = '00000000-0000-0000-0000-000000000001';
final examples =
    (jsonDecode(
              File('test/fixtures/application_display.json').readAsStringSync(),
            )
            as Map)['examples']
        as List;
Map<String, dynamic> copy(Object v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
Map<String, dynamic> wire([String name = 'role_success_precision']) =>
    withLevelExtension(
      copy(examples.singleWhere((v) => v['name'] == name)['response']),
    );
// Preserve the earlier authored fixture. State/HTTP tests use an explicit
// synthetic extension; old profile responses themselves are rejected below.
Map<String, dynamic> withLevelExtension(Map<String, dynamic> value) {
  if ((value['data'] as Map).containsKey('items')) {
    for (final item in value['data']['items']) {
      final display = item['display'] as Map;
      display['item_level'] = display['item_level'] as String?;
      display['item_level_source'] = display['item_level'] == null
          ? 'unavailable'
          : 'application_snapshot';
      display['item_level_fetched_at'] = null;
    }
  }
  return value;
}

// The authored detail vectors omit room items while referencing assignments.
// Keep them unchanged; use a separate internally coherent synthetic room for VM tests.
Map<String, dynamic> detailWire(String name) {
  final j = wire(name);
  final a = j['data']['members'][0]['assignments'][0];
  j['data']['room']['items'] = [
    {
      'item_id': a['item_id'],
      'round_id': a['round_id'],
      'raid_id': 'raid_a',
      'difficulty_id': 'hard',
      'game_party_size': 4,
    },
  ];
  j['data']['room']['game_items'] = copy({
    'items': j['data']['room']['items'],
  })['items'];
  return j;
}

ApplicationDisplayPage page(Map<String, dynamic> j) =>
    ApplicationDisplayPage(j, room, f2.c);

class ListGateway extends f3.TestGateway {
  ListGateway(super.api, super.recruitment);
  int reads = 0;
  Future<ApplicationDisplayPage> Function(String?)? read;
  @override
  Future<ApplicationDisplayPage> applicationDisplayPage(
    String r,
    String t, {
    String? cursor,
  }) async {
    reads++;
    return read == null ? page(wire()) : read!(cursor);
  }
}

class DetailGateway extends f2.CycleGateway {
  Map<String, dynamic> value = detailWire('detail_pending');
  Future<ApplicationDisplayDetail> Function(String)? read;
  int oldReads = 0;
  @override
  Future<ApplicationDisplayDetail> applicationDisplayDetail(
    String id,
    String target, {
    bool includeCoordinationWait = false,
  }) async => read == null
      ? ApplicationDisplayDetail.fromJson(value, id, target)
      : read!(target);
  @override
  Future<BackendRecruitmentDetail> cycleDetail(String id, String target) async {
    oldReads++;
    throw StateError('Display read must not use write preflight');
  }
}

void main() {
  for (final e in examples.where((v) => v['status'] == 200)) {
    test('authored contract vector ${e['name']} (not runtime)', () {
      final j = copy(e['response']);
      if ((j['data'] as Map).containsKey('items')) {
        if ((j['data']['items'] as List).isNotEmpty) {
          expect(() => page(j), throwsFormatException);
        }
        expect(page(withLevelExtension(j)), isA<ApplicationDisplayPage>());
      } else {
        expect(
          () => ApplicationDisplayDetail.fromJson(j, room, f2.c),
          throwsFormatException,
        );
      }
    });
  }
  final changes = <String, void Function(Map<String, dynamic>)>{
    'missing nullable': (j) => j['data']['items'][0].remove('analysis'),
    'unknown field': (j) => j['data']['items'][0]['eligibility'] = true,
    'wrong room': (j) => j['data']['items'][0]['room_id'] = base.roomId,
    'wrong T': (j) => j['data']['items'][0]['target_cycle_key'] = f2.n,
    'wrong generation': (j) => j['data']['items'][0]['target_generation'] = 2,
    'wrong role': (j) => j['data']['items'][0]['selected_role'] = 'support',
    'mixed version': (j) => j['data']['items'][0]['analysis']['version'] = 3,
    'mixed issues': (j) => j['data']['items'][0]['analysis']['issues'] = [
      {'code': 'FAIL', 'severity': 'error'},
    ],
    'connection reason with data': (j) =>
        j['data']['items'][0]['display_reason'] = 'CHARACTER_DATA_UNAVAILABLE',
    'invalid power state': (j) =>
        j['data']['items'][0]['comparison']['state'] = 'below',
    'missing success evidence': (j) =>
        j['data']['items'][0]['comparison']['success_summary_version'] = null,
    'missing comparison without reason': (j) =>
        j['data']['items'][0]['comparison'] = null,
    'boolean revision': (j) => j['data']['applications_revision'] = true,
    'mixed evaluated time': (j) =>
        j['data']['evaluated_at'] = '2026-10-24T12:00:01Z',
    'duplicate': (j) => j['data']['items'].add(copy(j['data']['items'][0])),
    'oversize cursor': (j) => j['data']['next_cursor'] = 'x' * 2049,
  };
  for (final e in changes.entries) {
    test('reject ${e.key}', () {
      final j = wire();
      e.value(j);
      expect(() => page(j), throwsFormatException);
    });
  }
  test(
    'immutable snapshot and retained success/current errors remain separate',
    () {
      final j = wire('current_error_retained_success'), p = page(j);
      final item = p.items.single;
      expect(item.status, contains('마지막 성공'));
      expect(item.status, contains('분석 오류'));
      final actual = item.comparison!['actual'];
      j['data']['items'][0]['comparison']['actual'] = '0';
      expect(item.comparison!['actual'], actual);
      expect(
        () => item.analysis!.wire['issues'].clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('response size is bounded', () {
    final j = wire();
    j['padding'] = 'x' * (1024 * 1024);
    expect(
      () => page(j),
      throwsA(
        isA<AccountReadException>().having(
          (v) => v.code,
          'code',
          'RESPONSE_TOO_LARGE',
        ),
      ),
    );
  });
  for (final field in ['my_application', 'revision', 'state', 'expires_at']) {
    test('detail rejects missing $field', () {
      final j = detailWire('detail_pending');
      if (field == 'my_application') {
        j['data'].remove(field);
      } else {
        j['data']['my_application'].remove(field);
      }
      expect(
        () => ApplicationDisplayDetail.fromJson(j, room, f2.c),
        throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
      );
    });
  }
  test('pending cannot be accepted at exact server expiry boundary', () {
    final j = detailWire('detail_pending');
    j['data']['my_application']['expires_at'] = j['scope']['server_now'];
    expect(
      () => ApplicationDisplayDetail.fromJson(j, room, f2.c),
      throwsFormatException,
    );
  });
  test('GET profile query is exact, no fallback or write key', () async {
    final api = base.Api(), reader = ApplicationDisplayReader(base.Api());
    api.respond = (p, q) async =>
        p.endsWith('/detail') ? detailWire('detail_pending') : wire();
    final real = ApplicationDisplayReader(api);
    await real.applicationDisplayPage(room, f2.c, cursor: 'page');
    await real.applicationDisplayDetail(room, f2.c);
    expect(api.requests[0]['query'], {
      'target_cycle_key': f2.c,
      'reader_profile': applicationDisplayProfile,
      'state': 'pending',
      'limit': 20,
      'cursor': 'page',
    });
    expect(api.requests[1]['query'], {
      'target_cycle_key': f2.c,
      'reader_profile': applicationDisplayProfile,
    });
    expect(
      api.requests.every((r) => r['method'] == 'GET' && r['key'] == null),
      true,
    );
    expect(reader, isA<ApplicationDisplayGateway>());
    api.respond = (_, _) async =>
        throw const AccountReadException('INVALID_REQUEST', status: 400);
    await expectLater(
      real.applicationDisplayDetail(room, f2.c),
      throwsA(isA<AccountReadException>()),
    );
    expect(api.requests.length, 3);
  });
  group('list lifetime and pages', () {
    late ListGateway gateway;
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late CycleParticipationController controller;
    late ApplicationDisplayViewModel m;
    String environment = 'one';
    setUp(() {
      environment = 'one';
      session = ReadSessionFake();
      changes = ChangeNotifier();
      gateway = ListGateway(base.Api(), f2.CycleGateway());
      controller = CycleParticipationController(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: () => '$environment/${session.userId}/${session.generation}',
        now: () => DateTime.parse(f2.nowStamp),
      );
      m = ApplicationDisplayViewModel(
        controller: controller,
        room: room,
        target: f2.c,
      );
    });
    tearDown(() {
      m.dispose();
      controller.dispose();
      changes.dispose();
      session.dispose();
    });
    test(
      'opening is explicit, existing mutation refresh remains scoped',
      () async {
        expect(gateway.reads, 0);
        await m.load();
        expect(m.rows.length, 1);
        await controller.changed(room, f2.n);
        await Future<void>.delayed(Duration.zero);
        expect(gateway.reads, 1);
        await controller.changed(room, f2.c);
        await Future<void>.delayed(Duration.zero);
        expect(gateway.reads, 2);
      },
    );
    for (final mode in [
      'duplicate',
      'loop',
      'generation',
      'revision',
      'service',
      'empty-final',
      'valid-analysis-update',
    ]) {
      test('next page $mode', () async {
        var count = 0;
        gateway.read = (cursor) async {
          final j = wire();
          if (count++ == 0) {
            j['data']['next_cursor'] = 'next';
            return page(j);
          }
          if (mode == 'service') {
            throw const AccountReadException(
              'SERVICE_UNAVAILABLE',
              status: 503,
            );
          }
          if (mode != 'duplicate') {
            j['data']['items'][0]['application_id'] =
                '00000000-0000-0000-0000-000000000009';
          }
          if (mode == 'loop') j['data']['next_cursor'] = 'next';
          if (mode == 'empty-final') j['data']['items'] = [];
          if (mode == 'generation') {
            j['scope']['target_generation'] = 2;
            j['data']['items'][0]['target_generation'] = 2;
          }
          if (mode == 'revision') j['data']['applications_revision'] = 3;
          if (mode == 'valid-analysis-update') {
            j['scope']['server_now'] = '2026-10-24T12:00:01Z';
            j['scope']['target_revision'] = 2;
            j['data']['evaluated_at'] = j['scope']['server_now'];
          }
          return page(j);
        };
        await m.load();
        await m.load(more: true);
        expect(m.rows.length, mode == 'valid-analysis-update' ? 2 : 0);
        expect(m.failure, mode == 'valid-analysis-update' ? isNull : isNotNull);
      });
    }
    for (final action in ['logout', 'member', 'environment', 'dispose']) {
      test('late read ignored after $action', () async {
        final wait = Completer<ApplicationDisplayPage>();
        gateway.read = (_) => wait.future;
        final local = ApplicationDisplayViewModel(
          controller: controller,
          room: room,
          target: f2.c,
        );
        final f = local.load();
        if (action == 'logout') session.change(authenticated: false);
        if (action == 'member') {
          session.change(authenticated: true, user: 'other');
        }
        if (action == 'environment') {
          environment = 'two';
          changes.notifyListeners();
        }
        if (action == 'dispose') local.dispose();
        wait.complete(page(wire()));
        await f;
        expect(local.rows, isEmpty);
        if (action != 'dispose') local.dispose();
      });
    }
    test('access loss clears already visible cards', () async {
      await m.load();
      session.change(authenticated: false);
      expect(m.rows, isEmpty);
      expect(m.cursor, isNull);
    });
    test('duplicate taps cause one GET', () async {
      final wait = Completer<ApplicationDisplayPage>();
      gateway.read = (_) => wait.future;
      final f = m.load();
      await m.load();
      expect(gateway.reads, 1);
      wait.complete(page(wire()));
      await f;
    });
    test('same-target mutation supersedes an in-flight old page', () async {
      final wait = Completer<ApplicationDisplayPage>();
      var calls = 0;
      gateway.read = (_) => calls++ == 0
          ? wait.future
          : Future.value(page(wire('empty_pending_page')));
      final old = m.load();
      await controller.changed(room, f2.c);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.reads, 2);
      wait.complete(page(wire()));
      await old;
      expect(m.rows, isEmpty);
      expect(m.failure, isNull);
    });
  });
  group('detail status ownership', () {
    late DetailGateway gateway;
    late ReadSessionFake session;
    late BackendRecruitmentDetailViewModel m;
    setUp(() {
      gateway = DetailGateway();
      session = ReadSessionFake();
      m = BackendRecruitmentDetailViewModel(
        gateway: gateway,
        session: session,
        roomId: room,
        target: f2.c,
      );
    });
    tearDown(() {
      m.dispose();
      session.dispose();
    });
    for (final name in [
      'detail_pending',
      'detail_expired_boundary',
      'detail_withdrawn',
      'detail_rejected',
      'detail_cancelled',
      'detail_accepted',
      'no_current_generation_history',
      'accepted_current_participation',
    ]) {
      test('$name chooses pending only from live status', () async {
        gateway.value = detailWire(name);
        await m.load();
        expect(m.failure, isNull);
        expect(m.waitingForApproval, name == 'detail_pending');
        expect(
          m.canStartAdmission,
          name != 'detail_pending' && name != 'accepted_current_participation',
        );
        expect(gateway.oldReads, 0);
      });
    }
    test(
      'failed refresh removes old entry permission, never maps failure to none',
      () async {
        gateway.value = detailWire('detail_withdrawn');
        await m.load();
        expect(m.canStartAdmission, true);
        gateway.read = (_) async => throw const AccountReadException(
          'SERVICE_UNAVAILABLE',
          status: 503,
        );
        await m.load();
        expect(m.canStartAdmission, false);
        expect(m.applicationKnown, false);
        expect(m.failure, 'SERVICE_UNAVAILABLE');
      },
    );
    test(
      'logout while detail pending cannot publish stale application',
      () async {
        final wait = Completer<ApplicationDisplayDetail>();
        gateway.read = (_) => wait.future;
        final f = m.load();
        await Future<void>.delayed(Duration.zero);
        session.change(authenticated: false);
        wait.complete(
          ApplicationDisplayDetail.fromJson(
            detailWire('detail_pending'),
            room,
            f2.c,
          ),
        );
        await f;
        expect(m.value, isNull);
        expect(m.application, isNull);
        expect(m.canStartAdmission, false);
      },
    );
    test('current participant takes priority over pending history', () async {
      gateway.value = detailWire('accepted_current_participation');
      gateway.value['data']['my_application'] = detailWire(
        'detail_pending',
      )['data']['my_application'];
      await m.load();
      expect(m.waitingForApproval, false);
      expect(m.canStartAdmission, false);
    });
    test('late C response cannot overwrite N detail', () async {
      final wait = Completer<ApplicationDisplayDetail>();
      final next = detailWire('detail_withdrawn');
      next['scope']['target_cycle_key'] = f2.n;
      next['scope']['phase'] = 'future';
      next['data']['room']['target_cycle_key'] = f2.n;
      next['data']['room']['phase'] = 'future';
      for (final slot in next['data']['formation_slots']) {
        slot['target_cycle_key'] = f2.n;
      }
      gateway.read = (t) async => t == f2.c
          ? wait.future
          : ApplicationDisplayDetail.fromJson(next, room, f2.n);
      final f = m.load();
      await Future<void>.delayed(Duration.zero);
      m.selectCycle(f2.n);
      await Future<void>.delayed(Duration.zero);
      wait.complete(
        ApplicationDisplayDetail.fromJson(
          detailWire('detail_pending'),
          room,
          f2.c,
        ),
      );
      await f;
      expect(m.target, f2.n);
      expect(m.value?.targetKey, f2.n);
      expect(m.waitingForApproval, false);
      expect(m.canStartAdmission, true);
    });
  });
}
