import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/membership_actions.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/backend_recruitment_detail_page.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_read_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_detail_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/membership_plan_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import '../account/backend_read/member_cycles_test.dart' as f1;

Map<String, dynamic> copy(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
final samples =
    (jsonDecode(
              File('test/fixtures/membership_readers.json').readAsStringSync(),
            )
            as Map)['examples']
        as List;
Map<String, dynamic> sample(String name) =>
    copy(samples.singleWhere((s) => s['name'] == name)['value']);
MembershipReadView parse(
  Map<String, dynamic> raw, {
  MembershipRecordAnchor? anchor,
}) => MembershipReadView(
  raw['data']['target']['room_id'],
  raw['scope']['target_cycle_key'],
  raw['scope']['reader_kind'],
  raw,
  anchor: anchor,
);

Map<String, dynamic> normalDetail() {
  final raw = sample('known_generation_null_leader_detail'),
      content = cycles.detail(cycles.c);
  final room = content['data']['room'], old = raw['data']['target'];
  raw['data']['target'] = {
    ...old,
    'room_id': room['room_id'],
    'room_revision': room['revision'],
    'title': room['title'],
    'room_cycle_id': room['room_cycle_id'],
    'target_generation': room['target_generation'],
    'target_revision': room['target_revision'],
    'target_state': 'open',
    'generation_state': 'open',
    'leadership': room['leadership'],
  };
  final viewer = raw['data']['viewer'];
  viewer['membership_id'] = base.membershipId;
  viewer['cycle_member_id'] = room['leadership']['leader_cycle_member_id'];
  viewer['role'] = 'leader';
  viewer['cycle_member_state'] = 'participating';
  viewer['record_locator'] = {
    'membership_id': viewer['membership_id'],
    'cycle_member_id': viewer['cycle_member_id'],
    'room_cycle_id': room['room_cycle_id'],
    'target_cycle_key': cycles.c,
    'target_generation': room['target_generation'],
  };
  raw['data']['recovery'] = {
    ...raw['data']['recovery'],
    'state': 'none',
    'reason': null,
    'revision': null,
    'remaining_review_reasons': [],
  };
  raw['data']['permissions']['manage_target'] = {
    'allowed': true,
    'reason': null,
    'next_change_at': null,
  };
  raw['data']['content'] = content;
  return raw;
}

class Actions implements MembershipActionGateway {
  int reads = 0;
  @override
  Future<MembershipActionContext> membershipContext(
    String room,
    String view,
  ) async {
    reads++;
    throw const AccountReadException('ROOM_MEMBERSHIP_REQUIRED');
  }

  @override
  Future<MembershipActionResult> writeMembershipAction(
    MembershipActionPreview p,
    String key,
    Map<String, dynamic> body,
  ) => throw UnimplementedError();
}

void main() {
  for (final example in samples) {
    test('published synthetic reader: ${example['name']}', () {
      final raw = copy(example['value']);
      if (raw['scope']['reader_kind'] == 'memberships') {
        if (example['name'] == 'ended_records_page') {
          // Published design vectors reuse the same CM for three statuses.
          // Preserve the source fixture, but never accept these as three rows.
          expect(
            () => MembershipReadPage(raw['scope']['target_cycle_key'], raw),
            throwsFormatException,
          );
          return;
        }
        final page = MembershipReadPage(raw['scope']['target_cycle_key'], raw);
        expect(page.items, isNotEmpty);
        for (final p in page.items) {
          CycleOwnRow.profile(p, raw['scope']['target_cycle_key']);
        }
      } else {
        parse(raw);
      }
    });
  }
  test('normal full detail envelope reuses unchanged parser', () {
    final raw = normalDetail(), p = parse(raw);
    final value = BackendRecruitmentRepository.parseCycleDetail(
      p.projection.content!,
      p.room,
      p.target,
    );
    final old = BackendRecruitmentRepository.parseCycleDetail(
      cycles.detail(cycles.c),
      p.room,
      p.target,
    );
    expect(value.title, old.title);
    expect(value.members, old.members);
    expect(value.formation, old.formation);
  });
  for (final mutate in <String, void Function(Map<String, dynamic>)>{
    'profile typo': (j) => j['scope']['policy_version'] = 'other',
    'wrong target': (j) => j['data']['target']['target_cycle_key'] = cycles.n,
    'foreign record member': (j) =>
        j['data']['record']['locator']['membership_id'] = base.membershipId,
    'foreign record CM': (j) =>
        j['data']['record']['locator']['cycle_member_id'] = base.roomId,
    'foreign generation': (j) =>
        j['data']['record']['locator']['target_generation'] = 99,
    'invented record content': (j) => j['data']['content'] = {},
    'record menu permission': (j) =>
        j['data']['permissions']['read_action_menu'] = {
          'allowed': true,
          'reason': null,
          'next_change_at': null,
        },
    'record mutable access': (j) => j['data']['access']['read_only'] = false,
    'duplicate assignment': (j) => (j['data']['record']['assignments'] as List)
        .add(copy(j['data']['record']['assignments'][0])),
    'wrong round linkage': (j) =>
        j['data']['record']['assignments'][0]['raid_id'] = 'other',
    'extra private field': (j) => j['data']['record']['private'] = {},
  }.entries) {
    test('reject ${mutate.key}', () {
      final raw = sample('ended_cancelled_detail');
      mutate.value(raw);
      expect(() => parse(raw), throwsFormatException);
    });
  }
  test('unknown generation stays null without fabricated leader/card', () {
    final p = parse(sample('unknown_generation_recovery_detail')).projection;
    expect(p.target['target_generation'], null);
    expect(p.content, null);
    expect(p.locator?.wire['target_generation'], null);
    expect(p.recovery['state'], 'unverified');
  });
  test('record data and all arrays are immutable', () {
    final p = parse(sample('ended_completed_detail')).projection;
    expect(() => p.record!.assignments.clear(), throwsUnsupportedError);
    expect(
      () => p.record!.assignments.first['state'] = 'active',
      throwsUnsupportedError,
    );
    expect(() => p.viewer['mode'] = 'participant', throwsUnsupportedError);
  });
  test(
    'multiple old CM records under same persistent member stay distinct',
    () {
      final raw = sample('ended_records_page'),
          target = raw['scope']['target_cycle_key'] as String;
      final rows = raw['data']['items'] as List;
      rows.removeRange(1, rows.length);
      final second = copy(rows.first);
      second['viewer']['cycle_member_id'] =
          '00000000-0000-4000-8000-000000000099';
      second['viewer']['record_locator']['cycle_member_id'] =
          '00000000-0000-4000-8000-000000000099';
      second['viewer']['membership_id'] = rows.first['viewer']['membership_id'];
      rows.add(second);
      final page = CycleOwnPage.profile(target, raw);
      expect(page.rows.map((r) => r.identity).toSet().length, page.rows.length);
      expect(page.rows.every((r) => r.isEndedParticipation), true);
    },
  );
  test('duplicate exact participation identity is rejected', () {
    final raw = sample('ended_records_page');
    (raw['data']['items'] as List).add(copy(raw['data']['items'][0]));
    expect(() => MembershipReadPage(cycles.c, raw), throwsFormatException);
  });
  for (final query in [
    'membership_id=${base.membershipId}',
    'cycle_member_id=${base.membershipId}',
    'membership_id=${base.membershipId}&cycle_member_id=${base.membershipId}',
    'reader_profile=typo',
    'target_cycle_key=${cycles.c}&target_cycle_key=${cycles.n}',
  ]) {
    test('malformed route rejected before reads: $query', () {
      expect(
        () => MembershipRecordAnchor.fromQuery(
          Uri.parse('/recruitments/${base.roomId}?$query'),
        ),
        throwsFormatException,
      );
    });
  }
  test('record link carries pair and profile after round trip', () {
    final a = MembershipRecordAnchor(
      base.membershipId,
      '00000000-0000-4000-8000-000000000099',
    );
    final uri = Uri.parse(
      membershipDetailLocation(base.roomId, cycles.c, anchor: a),
    );
    final parsed = MembershipRecordAnchor.fromQuery(uri)!;
    expect(parsed.membership, a.membership);
    expect(parsed.cycleMember, a.cycleMember);
    expect(uri.queryParameters['reader_profile'], membershipReaderProfile);
  });
  test('requested reader kind cannot be replaced by response kind', () {
    final raw = sample('ended_cancelled_detail');
    raw['scope']['reader_kind'] = 'plan';
    expect(
      () => MembershipReadView(
        raw['data']['target']['room_id'],
        cycles.c,
        'detail',
        raw,
      ),
      throwsFormatException,
    );
  });

  group('scoped HTTP and screen models', () {
    late base.Api api;
    late MembershipReadRepository reader;
    late ReadSessionFake session;
    late cycles.CycleGateway gateway;
    late Actions actions;
    late BackendRecruitmentDetailViewModel model;
    late Map<String, dynamic> wire;
    Completer<Map<String, dynamic>>? waiting;
    setUp(() {
      wire = sample('ended_cancelled_detail');
      waiting = null;
      api = base.Api()..respond = (_, q) async => waiting?.future ?? copy(wire);
      reader = MembershipReadRepository(api);
      session = ReadSessionFake();
      gateway = cycles.CycleGateway();
      actions = Actions();
      model = BackendRecruitmentDetailViewModel(
        gateway: gateway,
        session: session,
        roomId: wire['data']['target']['room_id'],
        target: cycles.c,
        reader: reader,
        membershipGateway: actions,
        recordAnchor: MembershipRecordAnchor(
          wire['data']['viewer']['membership_id'],
          wire['data']['viewer']['cycle_member_id'],
        ),
      );
    });
    tearDown(() {
      model.dispose();
      session.dispose();
    });
    test(
      'record GET uses exact anchor, no key/fallback/menu/preview/write',
      () async {
        await model.load();
        expect(model.profile!.projection.isRecord, true);
        expect(model.value, null);
        expect(model.readOnly, true);
        expect(actions.reads, 0);
        expect(api.requests, hasLength(1));
        expect(api.requests.single['method'], 'GET');
        expect(api.requests.single['key'], null);
        expect(api.requests.single['query'], {
          'target_cycle_key': cycles.c,
          'reader_profile': membershipReaderProfile,
          ...model.recordAnchor!.query,
        });
        model.selectCycle(cycles.n);
        expect(model.target, cycles.c);
        expect(api.requests, hasLength(1));
      },
    );
    test(
      'anchored old date survives rollover; unanchored old date rejected',
      () async {
        wire['scope']['server_now'] = '2026-11-05T03:00:00Z';
        wire['scope']['current_cycle_key'] = '2026-11-04';
        await model.load();
        expect(model.failure, null);
        expect(model.target, cycles.c);
        expect(() => parse(wire), throwsFormatException);
      },
    );
    test(
      'foreign/new member substituted for original record is rejected',
      () async {
        wire['data']['viewer']['membership_id'] = base.membershipId;
        await model.load();
        expect(model.profile, null);
        expect(model.failure, 'INVALID_RESPONSE');
        expect(actions.reads, 0);
      },
    );
    test(
      'unsupported profile response never falls back to old endpoint',
      () async {
        wire['scope']['policy_version'] = 'other';
        await model.load();
        expect(model.failure, 'INVALID_RESPONSE');
        expect(api.requests, hasLength(1));
        expect(actions.reads, 0);
      },
    );
    test('member change during record read discards former record', () async {
      waiting = Completer<Map<String, dynamic>>();
      final work = model.load();
      session.change(authenticated: false);
      waiting!.complete(copy(wire));
      await work;
      expect(model.profile, null);
      expect(model.value, null);
      expect(actions.reads, 0);
    });
    test(
      'plan record uses same pair with no resume opt-in or command',
      () async {
        wire = sample('ended_cancelled_plan');
        final plan = MembershipPlanViewModel(
          reader: reader,
          session: session,
          scopeKey: () => session.userId ?? '',
          room: model.roomId,
          target: cycles.c,
          anchor: model.recordAnchor,
        );
        addTearDown(plan.dispose);
        await plan.load();
        expect(plan.profile!.projection.record, isNotNull);
        expect(plan.value, null);
        expect(plan.readOnly, true);
        expect(api.requests.single['query'], {
          'target_cycle_key': cycles.c,
          'reader_profile': membershipReaderProfile,
          ...model.recordAnchor!.query,
        });
      },
    );
    test(
      'known-generation plan content reuses strict schedule parser',
      () async {
        wire = sample('known_generation_null_leader_plan');
        final plan = MembershipPlanViewModel(
          reader: reader,
          session: session,
          scopeKey: () => session.userId ?? '',
          room: wire['data']['target']['room_id'],
          target: cycles.c,
        );
        addTearDown(plan.dispose);
        await plan.load();
        expect(plan.failure, null);
        expect(plan.value, isNotNull);
      },
    );
    test('disposed plan ignores delayed read', () async {
      wire = sample('ended_cancelled_plan');
      waiting = Completer<Map<String, dynamic>>();
      final plan = MembershipPlanViewModel(
        reader: reader,
        session: session,
        scopeKey: () => session.userId ?? '',
        room: model.roomId,
        target: cycles.c,
        anchor: model.recordAnchor,
      );
      final work = plan.load();
      plan.dispose();
      waiting!.complete(copy(wire));
      await work;
      expect(plan.profile, null);
      expect(plan.value, null);
    });
    test(
      'normal profile uses full detail and independent action menu',
      () async {
        wire = normalDetail();
        final current = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: base.roomId,
          target: cycles.c,
          reader: reader,
          membershipGateway: actions,
        );
        addTearDown(current.dispose);
        await current.load();
        expect(current.failure, null);
        expect(current.value?.title, '레이드 A 모집');
        expect(actions.reads, 1);
      },
    );
    test(
      'late current-target profile cannot overwrite newly selected target',
      () async {
        wire = sample('unknown_generation_recovery_detail');
        waiting = Completer<Map<String, dynamic>>();
        final current = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: model.roomId,
          target: cycles.c,
          reader: reader,
          membershipGateway: actions,
        );
        addTearDown(current.dispose);
        final old = current.load();
        await Future<void>.delayed(Duration.zero);
        final oldGate = waiting!;
        waiting = null;
        wire['scope']['target_cycle_key'] = cycles.n;
        wire['data']['target']['target_cycle_key'] = cycles.n;
        wire['data']['viewer']['record_locator']['target_cycle_key'] = cycles.n;
        current.selectCycle(cycles.n);
        await Future<void>.delayed(Duration.zero);
        final oldWire = copy(wire);
        oldWire['scope']['target_cycle_key'] = cycles.c;
        oldWire['data']['target']['target_cycle_key'] = cycles.c;
        oldWire['data']['viewer']['record_locator']['target_cycle_key'] =
            cycles.c;
        oldGate.complete(oldWire);
        await old;
        expect(current.target, cycles.n);
        expect(current.profile?.target, cycles.n);
      },
    );
    test(
      'unanchored record pins original CM for refresh and freezes week choice',
      () async {
        final current = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: model.roomId,
          target: cycles.c,
          reader: reader,
          membershipGateway: actions,
        );
        addTearDown(current.dispose);
        await current.load();
        current.selectCycle(cycles.n);
        expect(current.target, cycles.c);
        wire['scope']['server_now'] = '2026-11-05T03:00:00Z';
        wire['scope']['current_cycle_key'] = '2026-11-04';
        await current.load();
        expect(current.failure, null);
        expect(
          api.requests.last['query']['cycle_member_id'],
          current.recordIdentity!.cycleMember,
        );
        expect(actions.reads, 0);
      },
    );
    testWidgets(
      'record page and schedule issue only anchored GETs and no new actions',
      (tester) async {
        final changes = ChangeNotifier();
        final c = CycleParticipationController(
          gateway: CycleInteractionRepository(api: api, recruitment: gateway),
          session: session,
          changes: changes,
          scopeKey: () => session.userId ?? '',
        );
        addTearDown(c.dispose);
        addTearDown(changes.dispose);
        api.respond = (path, q) async => sample(
          path.endsWith('/plan')
              ? 'ended_cancelled_plan'
              : 'ended_cancelled_detail',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BackendRecruitmentDetailPage(
              gateway: gateway,
              session: session,
              roomId: model.roomId,
              target: cycles.c,
              reader: reader,
              recordAnchor: model.recordAnchor,
              participation: c,
              onLogin: () {},
              onCreateAnother: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('모집 해산'), findsNothing);
        expect(find.text('모두 탈퇴'), findsNothing);
        expect(find.text('내 캐릭터 변경'), findsNothing);
        expect(find.text('주차 완료'), findsNothing);
        await tester.ensureVisible(find.text('일정 확인'));
        await tester.tap(find.text('일정 확인'));
        await tester.pumpAndSettle();
        expect(api.requests, hasLength(2));
        expect(
          api.requests.every(
            (r) =>
                r['method'] == 'GET' &&
                r['query']['membership_id'] == model.recordAnchor!.membership &&
                r['query']['cycle_member_id'] ==
                    model.recordAnchor!.cycleMember,
          ),
          true,
        );
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  test(
    'profile own-list paging preserves same member with different CM and state cache',
    () async {
      final session = ReadSessionFake(), changes = ChangeNotifier();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final calls = <RequestOptions>[];
      final raw = sample('ended_records_page');
      (raw['data']['items'] as List).removeRange(
        1,
        (raw['data']['items'] as List).length,
      );
      raw['data']['next_cursor'] = 'page2';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            calls.add(r);
            final page = copy(raw);
            if (r.queryParameters['cursor'] != null) {
              page['data']['next_cursor'] = null;
              page['data']['items'][0]['viewer']['cycle_member_id'] =
                  '00000000-0000-4000-8000-000000000099';
              page['data']['items'][0]['viewer']['record_locator']['cycle_member_id'] =
                  '00000000-0000-4000-8000-000000000099';
            }
            h.resolve(Response(requestOptions: r, statusCode: 200, data: page));
          },
        ),
      );
      final repo = CycleReadRepository(
        DioBackendAccountReadApi(dio, session),
        membershipProfile: true,
      );
      final m = CycleReadViewModel(
        repository: repo,
        changes: changes,
        scopeKey: () => session.userId ?? '',
      );
      addTearDown(m.dispose);
      addTearDown(changes.dispose);
      addTearDown(session.dispose);
      addTearDown(() => dio.close(force: true));
      m.select(cycles.c, section: 2);
      await f1.settled(() => !m.loading);
      await m.load(more: true);
      expect(m.failure, null);
      expect(m.rows, hasLength(2));
      expect(m.rows.map((r) => r.identity).toSet(), hasLength(2));
      expect(
        calls.every(
          (r) =>
              r.queryParameters['reader_profile'] == membershipReaderProfile &&
              r.queryParameters['state'] == 'ended',
        ),
        true,
      );
      final count = calls.length;
      m.select(cycles.n, section: 2);
      await f1.settled(() => !m.loading);
      m.select(cycles.c, section: 2);
      expect(m.rows, hasLength(2));
      expect(calls.length, count + 1);
    },
  );
}
