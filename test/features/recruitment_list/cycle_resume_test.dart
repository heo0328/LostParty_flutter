import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_resume.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;
import 'cycle_management_test.dart' as f4;
import 'cycle_outcome_test.dart' as f6;

const c = f1.current,
    n = f1.next,
    room = v1.roomId,
    pid = '11111111-1111-4111-8111-111111111111';
String ref(String char) => List.filled(64, char).join();
Map<String, dynamic> copy(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
Map<String, dynamic> reviewWire({bool creation = false, bool empty = false}) =>
    {
      'display': <String, dynamic>{
        'version': 1,
        'status': 'ready',
        'room_id': room,
        'room_cycle_id': f2.cycleId,
        'target_cycle_key': c,
        'target_generation': 1,
        'proposal_id': creation ? null : pid,
        'proposal_revision': creation ? null : 2,
        'proposal_plan_revision': creation ? null : 3,
        'origin': empty ? 'explicit' : 'retained',
        'settings_revision': 2,
        'basis_revision': ref('a'),
        'display_revision': ref('b'),
        'items': [
          {
            'item_id': v1.itemId,
            'source_round_id': f2.nextCycleId,
            'raid_id': 'raid_a',
            'difficulty_id': 'hard',
            'catalog_version': 'v2',
            'duration_minutes': 60,
            'duration_source': 'explicit',
          },
        ],
        'groups': empty
            ? <Map<String, dynamic>>[]
            : [
                <String, dynamic>{
                  'group_ref': ref('c'),
                  'planning_mode': 'manual',
                  'occurrence_mode': 'one_of',
                  'day_scope': 'selected_weekdays',
                  'required': true,
                  'auto_confirm_additional_members': null,
                  'alternatives': [
                    <String, dynamic>{
                      'alternative_ref': ref('d'),
                      'weekday': 1,
                      'starts_local': '20:00',
                      'leader_latest_start_local': null,
                      'item_ids': [v1.itemId],
                      'session_id': null,
                      'starts_at': '2026-10-26T11:00:00Z',
                      'ends_at': '2026-10-26T12:00:00Z',
                      'time_state': 'bounded',
                      'materialization': 'on_apply',
                    },
                  ],
                },
              ],
        'effect': <String, dynamic>{
          'eligible_count': 8,
          'accepted_count': creation ? 0 : 2,
          'required_votes': 6,
          'new_round_count': 1,
          'new_assignment_count': 8,
          'completed_preserved_count': 1,
          'superseded_proposal_count': 0,
          'creator_accept_on_submit': true,
          'my_immediate_session_count_on_accept': empty ? 0 : 1,
        },
        'permission': f1.permit(),
      },
      'confirmation': {
        'context_token': 'review-token',
        'issued_at': f2.nowStamp,
        'expires_at': '2026-10-22T03:02:00Z',
      },
    };
Map<String, dynamic> proposal(Map<String, dynamic> review) => {
  'proposal_id': pid,
  'kind': 'weekly_resume',
  'revision': 2,
  'proposal_plan_revision': 3,
  'created_from_plan_revision': 4,
  'state': 'pending',
  'target_round_ids': [f2.nextCycleId],
  'eligible_count': 8,
  'accepted_count': 2,
  'required_votes': 6,
  'my_response': 'pending',
  'permissions': {'respond_proposal': f1.permit()},
  'resume_review': review,
};

void main() {
  late v1.Api api;
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late CycleInteractionRepository repo;
  late CycleParticipationController controller;
  late Map<String, dynamic> plan, review;
  late List<String> refreshes;
  late bool lost, applied, wrongAck;
  late Map<String, Map<String, dynamic>> saved;
  Completer<void>? pause;
  Map<String, dynamic> Function(Map<String, dynamic>)? mutatePreview;
  List<Map<String, dynamic>> writes() =>
      api.requests.where((r) => r['key'] != null).toList();
  List<Map<String, dynamic>> previews() => api.requests
      .where((r) => r['method'] == 'POST' && r['key'] == null)
      .toList();
  setUp(() {
    api = v1.Api();
    session = ReadSessionFake();
    changes = ChangeNotifier();
    repo = CycleInteractionRepository(api: api, recruitment: f2.CycleGateway());
    plan = f6.planWire();
    plan['data']['target_state'] = 'stopped_incomplete';
    plan['data']['game_items'][0]['round_state'] = 'stopped_incomplete';
    plan['data']['my_assignments'][0]['state'] = 'stopped_incomplete';
    review = reviewWire();
    refreshes = [];
    saved = {};
    lost = applied = wrongAck = false;
    pause = null;
    mutatePreview = null;
    api.respond = (path, q) async {
      final request = api.requests.last;
      if (request['method'] == 'GET') {
        if (path.endsWith('/plan')) {
          await pause?.future;
          final j = copy(plan);
          final p = proposal(copy(review));
          if (q?['include_resume_display'] != 'true') p.remove('resume_review');
          (j['data']['proposals'] as List).add(p);
          return j;
        }
        if (path.endsWith('/settings')) {
          final j = f4.managementWire('settings', target: c);
          j['scope'] = copy(plan['scope']);
          return j;
        }
        throw StateError(path);
      }
      final body = request['body'] as Map<String, dynamic>;
      if (q?['preview_only'] == 'true') {
        expect(request['key'], isNull);
        expect(body.containsKey('resume_context_token'), isFalse);
        final r = reviewWire(
          creation: true,
          empty: body['schedule_groups'] != null,
        );
        if (body['schedule_groups'] is List &&
            (body['schedule_groups'] as List).isNotEmpty) {
          r['display']['groups'] = copy(review)['display']['groups'];
        }
        return {
          'scope': copy(plan['scope']),
          'data': {
            'kind': 'weekly_resume_preview',
            'resume_review': mutatePreview?.call(r) ?? r,
          },
        };
      }
      final key = request['key'] as String;
      saved.putIfAbsent(
        key,
        () => {
          'scope': copy(plan['scope']),
          'data': <String, dynamic>{
            'command_id': key,
            'outcome': applied ? 'applied' : 'recorded',
            'executed_at': f2.nowStamp,
            'room_id': room,
            'target_cycle_key': c,
            'revisions': [
              {'resource': 'proposal', 'id': pid, 'revision': 3},
            ],
          },
        },
      );
      if (lost) {
        lost = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      final ack = copy(saved[key]!);
      if (applied) {
        plan =
            jsonDecode(jsonEncode(plan).replaceAll(f2.nextCycleId, pid))
                as Map<String, dynamic>;
        plan['data']['target_state'] = 'open';
        plan['data']['game_items'][0]['round_state'] = 'active';
        plan['data']['my_assignments'][0]['state'] = 'active';
      }
      if (wrongAck) ack['scope']['target_generation'] = 9;
      return ack;
    };
    controller = CycleParticipationController(
      gateway: repo,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
      now: () => DateTime.parse(f2.nowStamp),
      onMutation: (t) async => refreshes.add(t),
    );
  });
  tearDown(() {
    controller.dispose();
    session.dispose();
    changes.dispose();
  });
  Future<CycleResumePreview> create({List<dynamic>? groups}) =>
      repo.resumePreview(room, c, groups: groups);
  Future<CycleResumePreview> respond() =>
      repo.resumePreview(room, c, proposalId: pid);

  test(
    'single member and completed creator do not imply automatic creator accept',
    () async {
      mutatePreview = (r) {
        r['display']['effect']['eligible_count'] = 1;
        r['display']['effect']['required_votes'] = 1;
        r['display']['effect']['creator_accept_on_submit'] = false;
        return r;
      };
      final p = await create();
      expect(p.review.effect['creator_accept_on_submit'], isFalse);
      await controller.resume(p);
      expect(controller.notice, contains('제안이 등록'));
      expect(writes(), hasLength(1));
    },
  );
  for (final mode in ['coordinated', 'unscheduled', 'manual_multiple']) {
    test('$mode preserves undetermined/selection materialization', () {
      final r = reviewWire();
      final g = r['display']['groups'][0];
      final a = g['alternatives'][0];
      if (mode == 'manual_multiple') {
        final b = copy(a);
        b['alternative_ref'] = ref('e');
        g['alternatives'].add(b);
        for (final alt in g['alternatives']) {
          alt['materialization'] = 'after_group_selection';
        }
      } else {
        g['planning_mode'] = mode;
        a['starts_at'] = a['ends_at'] = null;
        a['time_state'] = 'undetermined';
        a['materialization'] = mode == 'coordinated'
            ? 'after_coordination'
            : 'not_scheduled';
      }
      expect(
        CycleResumeReview(
          r,
          plan['scope'],
          room,
          c,
          proposal: proposal(r),
        ).canConfirm,
        isTrue,
      );
    });
  }
  test(
    'completed proposal is displayable with permission false and no confirmation',
    () async {
      review['display']['permission'] = f1.permit(false);
      review['confirmation'] = null;
      final p = await respond();
      expect(p.review.canConfirm, isFalse);
      expect(p.review.display['status'], 'ready');
    },
  );
  test(
    'final expiry rejection releases pending and permits fresh explicit confirmation',
    () async {
      final p = await respond();
      final original = api.respond;
      api.respond = (path, q) async {
        if (api.requests.last['key'] != null) {
          throw const AccountReadException(
            'COMMAND_CONTEXT_EXPIRED',
            status: 409,
          );
        }
        return original!(path, q);
      };
      await controller.resume(p, response: 'accept');
      expect(controller.hasPending, isFalse);
      expect(controller.failure, 'COMMAND_CONTEXT_EXPIRED');
      expect(refreshes, [c]);
    },
  );
  test('new create cannot consume applied ACK as proposal receipt', () async {
    applied = true;
    await controller.resume(await create());
    expect(controller.hasPending, isTrue);
    expect(refreshes, isEmpty);
    expect(controller.notice, isNull);
  });
  test(
    'old original recorded ACK remains recorded after device week rollover',
    () async {
      lost = true;
      await controller.resume(await respond(), response: 'accept');
      plan['scope']['server_now'] = '2026-10-27T21:00:00Z';
      await controller.retry();
      expect(controller.hasPending, isFalse);
      expect(refreshes, [c]);
      expect(controller.notice, contains('아직 재개되지 않았습니다'));
    },
  );

  test(
    'read-only preview has no key/pending/mutation; null differs from []',
    () async {
      final retained = await controller.resumePreview(room, c);
      expect(retained!.originalBody['schedule_groups'], isNull);
      expect(retained.review.display['origin'], 'retained');
      final empty = await controller.resumePreview(room, c, groups: []);
      expect(empty!.originalBody['schedule_groups'], isEmpty);
      expect(empty.review.display['groups'], isEmpty);
      expect(retained.signature, isNot(empty.signature));
      expect(previews(), hasLength(2));
      expect(writes(), isEmpty);
      expect(refreshes, isEmpty);
      expect(controller.hasPending, isFalse);
    },
  );
  test(
    'create rechecks then submits identical nine-field body plus token; recorded != applied',
    () async {
      final p = await create();
      await controller.resume(p);
      expect(writes(), hasLength(1));
      expect(previews(), hasLength(2));
      expect(writes().single['body'], {
        ...p.originalBody,
        'resume_context_token': 'review-token',
      });
      expect(
        writes().single['path'],
        '/v2/raid-rooms/$room/weekly-resume-proposals',
      );
      expect(refreshes, [c]);
      expect(controller.notice, contains('제안이 등록'));
      expect(controller.notice, isNot(contains('재개되었습니다')));
    },
  );
  for (final value in ['accept', 'reject']) {
    test(
      '$value uses actual proposal binding, latest token and six CAS fields',
      () async {
        final p = await respond();
        review['confirmation']['context_token'] = 'new-token';
        await controller.resume(p, response: value);
        expect(controller.failure, isNull);
        expect(previews(), isEmpty);
        expect(
          writes().single['path'],
          '/v2/raid-schedule-proposals/$pid/responses',
        );
        expect(writes().single['body'], {
          ...p.originalBody,
          'response': value,
          'resume_context_token': 'new-token',
        });
        expect(controller.notice, contains('아직 재개되지 않았습니다'));
        expect(refreshes, [c]);
      },
    );
  }
  test(
    'applied response announces actual resume; refresh target remains C',
    () async {
      applied = true;
      await controller.resume(await respond(), response: 'accept');
      expect(controller.notice, contains('주차가 재개되었습니다'));
      expect(controller.notice, contains('참가 확인 대기 2건'));
      expect(api.requests.last['path'], '/v2/me/raid-rooms/$room/plan');
      expect(refreshes, [c]);
    },
  );
  test(
    'applied ACK followed by new plan read failure stays final and never reissues write',
    () async {
      applied = true;
      final p = await respond();
      final original = api.respond;
      api.respond = (path, q) async {
        if (path.endsWith('/plan') && saved.isNotEmpty) {
          throw const AccountReadException('NETWORK_UNAVAILABLE');
        }
        return original!(path, q);
      };
      await controller.resume(p, response: 'accept');
      expect(controller.hasPending, isFalse);
      expect(controller.failure, isNull);
      expect(writes(), hasLength(1));
      expect(controller.notice, contains('재개되었습니다'));
      expect(controller.notice, contains('새 일정을 다시'));
      await controller.retry();
      expect(writes(), hasLength(1));
    },
  );
  test(
    'unknown result retry never replaces original body/key/token or calls preview again',
    () async {
      lost = true;
      await controller.resume(await respond(), response: 'reject');
      expect(controller.hasPending, isTrue);
      expect(refreshes, isEmpty);
      final first = copy(writes().single), length = api.requests.length;
      review['confirmation']['context_token'] = 'changed';
      review['display']['display_revision'] = ref('e');
      await controller.retry();
      expect(api.requests.length, length + 1);
      expect(writes().last, first);
      expect(controller.hasPending, isFalse);
      expect(refreshes, [c]);
    },
  );
  test(
    'wrong ACK generation retains pending; preview/read cannot resolve it',
    () async {
      wrongAck = true;
      await controller.resume(await create());
      expect(controller.hasPending, isTrue);
      expect(refreshes, isEmpty);
      expect(await controller.resumePlan(room, c), isNull);
      expect(controller.notice, isNull);
    },
  );
  for (final kind in ['legacy', 'stale', 'permission', 'missing_token']) {
    test(
      '$kind blocks both new accept and reject despite old proposal permission',
      () async {
        if (kind == 'legacy') {
          review['display']['status'] = 'legacy_unverifiable';
          review['display']['basis_revision'] = null;
          review['display']['settings_revision'] = null;
        }
        if (kind == 'stale') review['display']['status'] = 'stale';
        if (kind != 'missing_token') {
          review['display']['permission'] = f1.permit(false);
        }
        review['confirmation'] = null;
        final p = await respond();
        expect(p.review.canConfirm, isFalse);
        await controller.resume(p, response: 'accept');
        expect(writes(), isEmpty);
      },
    );
  }
  for (final field in [
    'display_revision',
    'basis_revision',
    'proposal_revision',
    'target_generation',
    'effect',
    'permission',
  ]) {
    test('$field changes after confirmation: no command POST', () async {
      final p = await respond();
      if (field == 'effect') {
        review['display']['effect']['eligible_count'] = 7;
      } else if (field == 'permission') {
        review['display']['permission'] = f1.permit(false);
        review['confirmation'] = null;
      } else {
        review['display'][field] =
            field.endsWith('revision') && !field.startsWith('proposal')
            ? ref('e')
            : 3;
      }
      await controller.resume(p, response: 'accept');
      expect(writes(), isEmpty);
      expect(controller.failure, isNotNull);
    });
  }
  test(
    'missing review fails opt-in; default plan remains closed and readable',
    () async {
      final raw = copy(plan);
      raw['data']['proposals'].add(
        proposal(copy(review))..remove('resume_review'),
      );
      expect(() => CycleResumePlan(room, c, raw), throwsFormatException);
      expect(
        (await repo.scheduleRead(room, c, 'plan')).data['proposals'],
        hasLength(2),
      );
    },
  );
  test('late member switch and duplicate submit cannot write', () async {
    final p = await create();
    pause = Completer<void>();
    final work = controller.resume(p);
    await controller.resume(p);
    session.change(authenticated: true, user: 'other');
    pause!.complete();
    await work;
    expect(writes(), isEmpty);
    expect(refreshes, isEmpty);
  });
  test(
    'explicit groups frozen before first await and body deeply immutable',
    () async {
      final groups = <dynamic>[
        {
          'items': ['original'],
        },
      ];
      pause = Completer<void>();
      final work = create(groups: groups);
      groups[0]['items'][0] = 'changed';
      pause!.complete();
      final p = await work;
      expect((p.originalBody['schedule_groups'] as List)[0]['items'], [
        'original',
      ]);
      expect(
        () => p.originalBody['schedule_groups'] = [],
        throwsUnsupportedError,
      );
      expect(
        () => (p.review.display['items'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'request32KiB and response1MiB errors do not fall back to unprotected reads',
    () async {
      final large = List.filled(33000, 'x').join();
      expect(
        await controller.resumePreview(
          room,
          c,
          groups: [
            {'large': large},
          ],
        ),
        isNull,
      );
      expect(controller.failure, 'REQUEST_TOO_LARGE');
      expect(previews(), isEmpty);
      final raw = copy(plan);
      raw['data']['proposals'].add(proposal(copy(review)));
      raw['data']['schedule_state'] = List.filled(1024 * 1024 + 1, 'x').join();
      expect(
        () => CycleResumePlan(room, c, raw),
        throwsA(
          isA<AccountReadException>().having(
            (e) => e.code,
            'code',
            'RESPONSE_TOO_LARGE',
          ),
        ),
      );
      expect(writes(), isEmpty);
    },
  );
  for (final change in [
    'extra',
    'fake_session',
    'end',
    'expired',
    'too_long',
    'future',
  ]) {
    test('strict review rejects $change', () async {
      mutatePreview = (r) {
        final d = r['display'], a = d['groups'][0]['alternatives'][0];
        if (change == 'extra') d['extra'] = true;
        if (change == 'fake_session') a['session_id'] = pid;
        if (change == 'end') a['ends_at'] = '2026-10-26T12:05:00Z';
        if (change == 'expired') {
          r['confirmation']['issued_at'] = '2026-10-22T02:59:00Z';
          r['confirmation']['expires_at'] = f2.nowStamp;
        }
        if (change == 'too_long') {
          r['confirmation']['expires_at'] = '2026-10-22T03:03:00Z';
        }
        if (change == 'future') d['target_cycle_key'] = n;
        return r;
      };
      expect(await controller.resumePreview(room, c), isNull);
      expect(writes(), isEmpty);
    });
  }
  test(
    'KST last Wednesday 00:05 maps to cycle end date; legacy undetermined is readable',
    () async {
      final r = reviewWire();
      final a = r['display']['groups'][0]['alternatives'][0];
      a['weekday'] = 3;
      a['starts_local'] = '00:05';
      a['starts_at'] = '2026-10-27T15:05:00Z';
      a['ends_at'] = '2026-10-27T16:05:00Z';
      expect(
        CycleResumeReview(
          r,
          plan['scope'],
          room,
          c,
          proposal: proposal(r),
        ).canConfirm,
        isTrue,
      );
      r['display']['status'] = 'legacy_unverifiable';
      r['display']['basis_revision'] = null;
      r['display']['settings_revision'] = null;
      r['display']['permission'] = f1.permit(false);
      r['confirmation'] = null;
      a['starts_local'] = a['starts_at'] = a['ends_at'] = null;
      a['time_state'] = 'undetermined';
      expect(
        CycleResumeReview(
          r,
          plan['scope'],
          room,
          c,
          proposal: proposal(r),
        ).canConfirm,
        isFalse,
      );
    },
  );
}
