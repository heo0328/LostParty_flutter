import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/raid_room_usage_repository.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/beta/coordination_wait.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/raid_room_usage_controller.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'beta_foundation_test.dart' as beta;
import 'membership_readers_test.dart' as records;
import 'cycle_recruitment_test.dart' as cycles;

Map<String, dynamic> usage({int used = 3, int limit = 10}) => {
  'policy_version': 'member-room-limits-v1',
  'evaluated_at': '2026-10-26T09:00:00Z',
  'limits_revision': 1,
  'usage_revision': 2,
  'limit_source': 'default',
  'updated_at': null,
  'limits': {'group_capacity': 15, 'joined_groups': 5, 'raid_rooms': limit},
  'usage': <String, dynamic>{
    'joined_groups': {
      'used': 0,
      'remaining': 5,
      'state': 'within',
      'can_increase': true,
    },
    'raid_rooms': {
      'used': used,
      'remaining': limit > used ? limit - used : 0,
      'state': used > limit
          ? 'exceeded'
          : used == limit
          ? 'at_limit'
          : 'within',
      'can_increase': used < limit,
    },
  },
  'issues': [],
};

void main() {
  test(
    'opt-in validates non-null content and rejects absent/malformed explanation',
    () async {
      final api = base.Api();
      final raw = cycles.detail(cycles.c);
      final s = beta.schedule();
      final d = raw['data'] as Map<String, dynamic>;
      d['beta_schedule'] = s;
      d['room']['beta_schedule'] = s;
      d['recruitment_identity'] = {'number': 1, 'password': '00009'};
      d['permissions'] = {
        for (final key in ['view_detail', 'view_plan'])
          key: {'allowed': true, 'reason': null, 'next_change_at': null},
      };
      d['my_membership'] = {
        'membership_id': base.membershipId,
        'revision': 1,
        'group_member': false,
        'target_role': 'leader',
        'cycle_member_id': base.membershipId,
        'cycle_member_revision': 1,
        'joined_order': '1',
      };
      d['my_application'] = null;
      api.respond = (_, _) async => raw;
      final repo = ApplicationDisplayReader(
        api,
        contractMode: RecruitmentContractMode.betaWire2,
      );
      await repo.applicationDisplayDetail(base.roomId, cycles.c);
      await expectLater(
        repo.applicationDisplayDetail(
          base.roomId,
          cycles.c,
          includeCoordinationWait: true,
        ),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
      s['coordination_wait'] = {
        'status': 'waiting_members',
        'missing_members': 1,
      };
      final result = await repo.applicationDisplayDetail(
        base.roomId,
        cycles.c,
        includeCoordinationWait: true,
      );
      expect(
        coordinationWaitMessage(result.detail.betaData),
        '1명 더 모이면 조율합니다.',
      );
      expect(
        result.detail.betaData!['beta_schedule'].containsKey(
          'coordination_wait',
        ),
        false,
      );
      s['coordination_wait'] = {
        'status': 'waiting_members',
        'missing_members': null,
      };
      await expectLater(
        repo.applicationDisplayDetail(
          base.roomId,
          cycles.c,
          includeCoordinationWait: true,
        ),
        throwsA(isA<AccountReadException>()),
      );
    },
  );
  test('server metric semantics, unavailable and malformed reads', () {
    expect(RaidRoomUsage.fromJson(usage()).label, '3/10');
    expect(RaidRoomUsage.fromJson(usage(used: 10)).label, '10/10');
    final raw = usage();
    raw['usage']['raid_rooms'] = <String, dynamic>{
      'used': null,
      'remaining': null,
      'state': 'unavailable',
      'can_increase': null,
    };
    expect(RaidRoomUsage.fromJson(raw).label, '—/—');
    raw['usage']['raid_rooms']['used'] = 0;
    expect(() => RaidRoomUsage.fromJson(raw), throwsFormatException);
    final wrong = usage();
    wrong['usage']['raid_rooms']['remaining'] = 10;
    expect(() => RaidRoomUsage.fromJson(wrong), throwsFormatException);
  });

  test(
    'one command covers C/N, in-flight mutations re-read, failures never zero',
    () async {
      final session = ReadSessionFake(),
          changes = ChangeNotifier(),
          api = base.Api();
      final pending = <Completer<Map<String, dynamic>>>[];
      api.respond = (path, q) {
        expect(path, '/v1/me/usage-limits');
        expect(q, isNull);
        final c = Completer<Map<String, dynamic>>();
        pending.add(c);
        return c.future;
      };
      final model = RaidRoomUsageController(
        repository: RaidRoomUsageRepository(api),
        session: session,
        changes: changes,
        scopeKey: () => '${session.userId}/${session.generation}',
      );
      addTearDown(() {
        model.dispose();
        changes.dispose();
        session.dispose();
      });
      final first = model.refresh();
      model.commandApplied('same-CN-key');
      model.commandApplied('same-CN-key');
      expect(pending, hasLength(1));
      pending[0].complete(usage());
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(2));
      expect(model.label, '—/—');
      pending[1].complete(usage(used: 4));
      await first;
      expect(model.label, '4/10');
      model.commandApplied('same-CN-key');
      expect(pending, hasLength(2));
      final read = model.refresh();
      pending.last.completeError(
        const AccountReadException('NETWORK_UNAVAILABLE'),
      );
      await read;
      expect(model.label, '—/—');
    },
  );

  test('account/environment switch and dispose fence late responses', () async {
    final session = ReadSessionFake(),
        changes = ChangeNotifier(),
        api = base.Api();
    final pending = <Completer<Map<String, dynamic>>>[];
    api.respond = (_, _) {
      final c = Completer<Map<String, dynamic>>();
      pending.add(c);
      return c.future;
    };
    var environment = 'one';
    final model = RaidRoomUsageController(
      repository: RaidRoomUsageRepository(api),
      session: session,
      changes: changes,
      scopeKey: () => '$environment/${session.userId}/${session.generation}',
    );
    environment = 'two';
    changes.notifyListeners();
    expect(pending, hasLength(2));
    pending[1].complete(usage(used: 2));
    await model.refresh();
    expect(model.label, '2/10');
    pending[0].complete(usage(used: 9));
    await Future<void>.delayed(Duration.zero);
    expect(model.label, '2/10');
    final read = model.refresh();
    model.dispose();
    pending.last.complete(usage());
    await read;
    changes.dispose();
    session.dispose();
  });

  test(
    'boundary expires the server week without a write or revision change',
    () async {
      final session = ReadSessionFake(),
          changes = ChangeNotifier(),
          api = base.Api();
      var count = 0;
      api.respond = (_, _) async {
        count++;
        return usage()
          ..['evaluated_at'] = count == 1
              ? '2026-10-27T20:59:59.999Z'
              : '2026-10-27T21:00:00Z';
      };
      final model = RaidRoomUsageController(
        repository: RaidRoomUsageRepository(api),
        session: session,
        changes: changes,
        scopeKey: () => session.userId!,
      );
      await model.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(count, greaterThan(1));
      model.dispose();
      changes.dispose();
      session.dispose();
    },
  );

  test(
    'wait metadata is separate from canonical schedule and command identity',
    () {
      final canonical = beta.schedule();
      final explained = {
        ...canonical,
        'coordination_wait': {
          'status': 'waiting_members',
          'missing_members': 2,
        },
      };
      BetaSchedule(explained);
      final plain = betaDisplayData({'beta_schedule': canonical});
      final waiting = betaDisplayData({'beta_schedule': explained});
      expect(
        scheduleStable(plain!['beta_schedule']),
        scheduleStable(waiting!['beta_schedule']),
      );
      expect(coordinationWaitMessage(waiting), '2명 더 모이면 조율합니다.');
      expect(
        () => waiting['beta_schedule']['coordination_state'] = 'ended',
        throwsUnsupportedError,
      );
      expect(
        coordinationWaitMessage(betaDisplayData({'beta_schedule': null})),
        isNull,
      );
    },
  );

  test('closed wait states and strictly terminated stored memo', () {
    for (final state in [
      'no_earlier_candidate',
      'pending',
      'unavailable',
      'not_applicable',
    ]) {
      final v = {'status': state, 'missing_members': null};
      BetaContract.definition('Proposed_CoordinationWait', v);
      expect(
        CoordinationWait.fromJson(v).message,
        state == 'not_applicable' ? isNull : isNotEmpty,
      );
      expect(
        () => CoordinationWait.fromJson({...v, 'missing_members': 1}),
        throwsFormatException,
      );
    }
    for (final count in [0, 9]) {
      expect(
        () => CoordinationWait.fromJson({
          'status': 'waiting_members',
          'missing_members': count,
        }),
        throwsFormatException,
      );
    }
    expect(() => ApplicationMemo('정상\n'), throwsFormatException);
    ApplicationMemo(r'한글 A0!@#$%&()*+');
  });

  test(
    'opt-in query is scoped, required when requested, null recovery stays null',
    () async {
      final api = base.Api();
      final raw = records.sample('known_generation_null_leader_detail');
      raw['data']['beta_schedule'] = null;
      raw['data']['recruitment_identity'] = null;
      api.respond = (_, _) async => raw;
      final repo = MembershipReadRepository(
        api,
        contractMode: RecruitmentContractMode.betaWire2,
      );
      final room = raw['data']['target']['room_id'] as String;
      final target = raw['scope']['target_cycle_key'] as String;
      final result = await repo.detail(
        room,
        target,
        includeCoordinationWait: true,
      );
      expect(result.betaData!['beta_schedule'], isNull);
      expect(api.requests.last['query']['include_coordination_wait'], 'true');
      await repo.detail(room, target);
      expect(
        api.requests.last['query'].containsKey('include_coordination_wait'),
        false,
      );
    },
  );
}
