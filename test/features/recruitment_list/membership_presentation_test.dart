import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/membership_actions.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_detail_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import 'membership_actions_test.dart' as fixtures;
import 'cycle_recruitment_test.dart' as cycles;

class MenuGateway implements MembershipActionGateway {
  late Future<MembershipActionContext> Function(String, String) read;
  @override
  Future<MembershipActionContext> membershipContext(String room, String view) =>
      read(room, view);
  @override
  Future<MembershipActionResult> writeMembershipAction(
    MembershipActionPreview p,
    String key,
    Map<String, dynamic> body,
  ) => throw UnimplementedError();
}

void main() {
  test('own cancelled target exits; opposite target does not', () {
    final c = fixtures.context(fixtures.fixture('no-successor-context'));
    final raw = fixtures.fixture('no-successor-result');
    final r = MembershipActionResult(
      raw,
      c.select('leave_target'),
      raw['data']['command_id'],
    );
    expect(r.exitsTarget(c.view), true);
    expect(r.exitsTarget('2026-10-28'), false);
  });
  test('relation-only ACK exits even without a target effect', () {
    final c = fixtures.context(fixtures.fixture('empty-effects-context'));
    final raw = fixtures.fixture('empty-effects-result');
    final r = MembershipActionResult(
      raw,
      c.select('leave_all'),
      raw['data']['command_id'],
    );
    expect(r.affected, isEmpty);
    expect(r.exitsTarget(c.view), true);
  });
  test(
    'opposite-week dissolution preserves current screen and actor relation',
    () {
      final raw = fixtures.fixture('eight-members-two-targets-context');
      raw['scope']['view_cycle_key'] = '2026-10-21';
      raw['data']['options']['leave_target'] = {
        'visible': false,
        'permission': {
          'allowed': false,
          'reason': 'NOT_PARTICIPATING',
          'next_change_at': null,
        },
        'impact': null,
        'confirmation': null,
      };
      final impact = raw['data']['options']['dissolve_led_targets']['impact'];
      impact['affected_cycle_keys'] = ['2026-10-28'];
      impact['targets'] = [impact['targets'].last];
      final effect = impact['room_effect'];
      effect['kind'] = 'preserve';
      effect['actor_membership_will_end'] = false;
      effect['ended_persistent_membership_count'] = 0;
      for (final rule in [
        'room_revision_rule',
        'actor_membership_revision_rule',
      ]) {
        effect[rule]['comparison'] = 'equal';
        effect[rule]['exact_after'] = effect[rule]['before'];
      }
      final p = fixtures.context(raw).select('dissolve_led_targets');
      final ack = fixtures.fixture('eight-members-two-targets-result');
      ack['scope']['view_cycle_key'] = p.view;
      ack['data']['affected_cycle_keys'] = p.affected;
      ack['data']['effects'] = [ack['data']['effects'].last];
      ack['data']['actor_membership_ended'] = false;
      ack['data']['room_ended'] = false;
      ack['data']['ended_persistent_membership_count'] = 0;
      ack['data']['room_revision'] = 1;
      ack['data']['actor_membership_revision'] = 1;
      final r = MembershipActionResult(ack, p, ack['data']['command_id']);
      expect(r.exitsTarget('2026-10-21'), false);
      expect(r.exitsTarget('2026-10-28'), true);
    },
  );

  late ReadSessionFake session;
  late cycles.CycleGateway gateway;
  late MenuGateway menu;
  late BackendRecruitmentDetailViewModel model;
  MembershipActionContext snapshot(String room, String view) {
    final raw = fixtures.fixture('empty-effects-context');
    raw['data']['room_id'] = room;
    raw['scope']['view_cycle_key'] = view;
    return MembershipActionContext(room, view, raw);
  }

  setUp(() {
    session = ReadSessionFake();
    gateway = cycles.CycleGateway();
    gateway.onCycleDetail = (_) =>
        throw const AccountReadException('ROOM_MEMBERSHIP_REQUIRED');
    menu = MenuGateway()..read = (room, view) async => snapshot(room, view);
    model = BackendRecruitmentDetailViewModel(
      gateway: gateway,
      session: session,
      roomId: '00000000-0000-4000-8000-000000000001',
      target: cycles.c,
      membershipGateway: menu,
    );
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });
  test(
    'menu remains independently available when default detail is denied',
    () async {
      await model.load();
      expect(model.value, isNull);
      expect(model.failure, 'ROOM_MEMBERSHIP_REQUIRED');
      expect(
        model.membershipMenu!.options['leave_all']['permission']['allowed'],
        true,
      );
      expect(
        model.membershipMenu!.options['leave_target']['permission']['allowed'],
        false,
      );
    },
  );
  test('old cycle menu cannot overwrite newly selected cycle', () async {
    final gate = Completer<MembershipActionContext>();
    menu.read = (room, view) =>
        view == cycles.c ? gate.future : Future.value(snapshot(room, view));
    final old = model.load();
    await Future<void>.delayed(Duration.zero);
    model.selectCycle(cycles.n);
    await Future<void>.delayed(Duration.zero);
    expect(model.membershipMenu?.view, cycles.n);
    gate.complete(snapshot(model.roomId, cycles.c));
    await old;
    expect(model.membershipMenu?.view, cycles.n);
  });
  test('logout during menu read discards its permission and detail', () async {
    final gate = Completer<MembershipActionContext>();
    menu.read = (_, _) => gate.future;
    final work = model.load();
    await Future<void>.delayed(Duration.zero);
    session.change(authenticated: false);
    gate.complete(snapshot(model.roomId, cycles.c));
    await work;
    expect(model.membershipMenu, isNull);
    expect(model.value, isNull);
  });
  test('failed refresh drops stale allowed menu', () async {
    await model.load();
    menu.read = (_, _) =>
        throw const AccountReadException('NETWORK_UNAVAILABLE');
    await model.load();
    expect(model.membershipMenu, isNull);
    expect(model.membershipFailure, 'NETWORK_UNAVAILABLE');
  });
}
