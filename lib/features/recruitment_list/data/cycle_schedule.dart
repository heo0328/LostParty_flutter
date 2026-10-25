import 'dart:convert';
import 'beta/beta_interaction_api.dart';
import 'beta/beta_contract.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/play_availability.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import 'cycle_read_repository.dart';
import '../domain/policies/weekly_raid_reset_policy.dart';
import '../domain/policies/recruitment_start_policy.dart';

String scheduleStable(Object? v) {
  Object? clean(Object? x) {
    if (x is Map) {
      final keys =
          x.keys
              .cast<String>()
              .where(
                (k) =>
                    !{'server_now', 'server_time', 'evaluated_at'}.contains(k),
              )
              .toList()
            ..sort();
      return {for (final k in keys) k: clean(x[k])};
    }
    if (x is List) return x.map(clean).toList();
    return x;
  }

  return jsonEncode(clean(v));
}

void schedulePermit(Object? raw) {
  final p = CyclePermission.fromJson(roleMap(raw));
  if (!p.allowed) throw AccountReadException(p.reason ?? 'PERMISSION_DENIED');
}

void _permissions(Object? raw) {
  for (final v in roleMap(raw).values) {
    CyclePermission.fromJson(roleMap(v));
  }
}

void _unique(List list, String key) {
  roleCheck(
    list.map((v) => roleId(roleMap(v)[key])).toSet().length == list.length,
  );
}

void _interval(Object? raw) {
  final v = roleMap(raw);
  roleShape(v, 'starts_at ends_at');
  roleCheck(roleUtc(v['starts_at']).isBefore(roleUtc(v['ends_at'])));
}

DateTime cycleScheduleStart(String target, int weekday, String clock) {
  final minute =
      int.parse(clock.substring(0, 2)) * 60 + int.parse(clock.substring(3));
  var local = const RecruitmentStartPolicy()
      .dateForDay(
        DateTime.parse('${target}T00:00:00Z'),
        weekday,
        targetCycleKey: target,
      )
      .add(Duration(minutes: minute));
  if (weekday == 3 && minute < 360) {
    local = local.add(const Duration(days: 7));
  }
  return local.subtract(const Duration(hours: 9));
}

/// Scoped read models. A successful GET is never evidence that a command applied.
class CycleScheduleView {
  CycleScheduleView(
    this.room,
    this.target,
    this.kind,
    Map<String, dynamic> raw, {
    this.id,
    this.betaData,
  }) : wire = jsonDecode(jsonEncode(raw)) as Map<String, dynamic> {
    roleId(room);
    raidCycleKey(target);
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    data = roleMap(wire['data']);
    CycleReadScope(scope, target);
    if (kind != 'overlaps') {
      roleId(scope['room_cycle_id']);
      rolePositive(scope['target_revision']);
      rolePositive(scope['target_generation']);
    }
    if (kind == 'plan') {
      roleShape(
        data,
        'room_id revision members_revision server_time app_capacity game_items schedule_state schedule_groups sessions session_segments my_membership my_assignments my_participations proposals permissions leadership my_target_role formation_slots formation_history unplaced_assignments target_cycle_key target_state',
      );
      roleCheck(data['room_id'] == room && data['target_cycle_key'] == target);
      rolePositive(data['revision']);
      rolePositive(data['members_revision']);
      roleUtc(data['server_time']);
      roleCheck(
        {4, 8}.contains(data['app_capacity']) &&
            {'leader', 'member', 'none'}.contains(data['my_target_role']),
      );
      _permissions(data['permissions']);
      final lead = roleMap(data['leadership']);
      roleShape(
        lead,
        'leader_cycle_member_id leadership_revision leader_membership_id',
      );
      rolePositive(lead['leadership_revision']);
      final mine = roleMap(data['my_membership']);
      roleShape(
        mine,
        'membership_id revision group_member target_role cycle_member_id cycle_member_revision joined_order',
      );
      roleId(mine['membership_id']);
      roleId(mine['cycle_member_id']);
      rolePositive(mine['cycle_member_revision']);
      final items = raidList(data['game_items']);
      roleCheck(items.isNotEmpty && items.length <= 5);
      _unique(items, 'item_id');
      for (final raw in items) {
        final i = roleMap(raw);
        roleShape(
          i,
          'item_id revision raid_id difficulty_id catalog_version game_party_size round_id round_revision round_state',
        );
        roleId(i['round_id']);
        rolePositive(i['revision']);
        rolePositive(i['round_revision']);
        roleCheck({4, 8}.contains(i['game_party_size']));
      }
      final sessions = raidList(data['sessions']);
      _unique(sessions, 'session_id');
      for (final raw in sessions) {
        final s = roleMap(raw);
        roleShape(
          s,
          'session_id revision round_ids required mode state schedule_revision starts_at ends_at duration_minutes duration_source duration_policy_version earliest_start latest_start join_deadline candidate_state permissions',
        );
        rolePositive(s['revision']);
        rolePositive(s['schedule_revision']);
        raidBool(s['required']);
        _permissions(s['permissions']);
        for (final k in [
          'starts_at',
          'ends_at',
          'earliest_start',
          'latest_start',
          'join_deadline',
        ]) {
          if (s[k] != null) roleUtc(s[k]);
        }
        if (s['state'] == 'confirmed') {
          roleCheck(
            s['starts_at'] != null &&
                s['ends_at'] != null &&
                roleUtc(s['starts_at']).isBefore(roleUtc(s['ends_at'])),
          );
        }
        for (final r in raidList(s['round_ids'])) {
          roleCheck(items.any((i) => i['round_id'] == r));
        }
      }
      final groups = raidList(data['schedule_groups']);
      _unique(groups, 'group_id');
      for (final raw in groups) {
        final g = roleMap(raw);
        roleShape(
          g,
          'group_id revision client_group_key occurrence_mode planning_mode day_scope required auto_confirm_additional_members alternatives selected_session_id resolution candidate_state permissions',
        );
        rolePositive(g['revision']);
        raidBool(g['required']);
        _permissions(g['permissions']);
        for (final rawA in raidList(g['alternatives'])) {
          final a = roleMap(rawA);
          roleShape(
            a,
            'alternative_id session_id weekday starts_local leader_latest_start_local item_ids',
          );
          roleId(a['alternative_id']);
          roleCheck(
            a['weekday'] is int && a['weekday'] >= 1 && a['weekday'] <= 7,
          );
          for (final k in ['starts_local', 'leader_latest_start_local']) {
            roleCheck(
              a[k] == null ||
                  (a[k] is String &&
                      RegExp(
                        r'^(?:[01][0-9]|2[0-3]):[0-5][05]$',
                      ).hasMatch(a[k])),
            );
          }
          for (final i in raidList(a['item_ids'])) {
            roleCheck(items.any((v) => v['item_id'] == i));
          }
        }
      }
      for (final raw in raidList(data['my_assignments'])) {
        final a = roleMap(raw);
        roleShape(
          a,
          'assignment_id revision membership_id item_id round_id character_id selected_role state ended_at raid_participation_state completion_source completed_at target_cycle_key',
        );
        roleId(a['assignment_id']);
        rolePositive(a['revision']);
        roleCheck(
          a['target_cycle_key'] == target &&
              a['membership_id'] == mine['membership_id'],
        );
      }
      final parts = raidList(data['my_participations']);
      _unique(parts, 'participation_id');
      for (final raw in parts) {
        final p = roleMap(raw);
        roleShape(
          p,
          'participation_id revision session_id assignment_ids state required participating confirmation_state confirmed_at confirmed_schedule_revision reservation_state overlap_warning warnings permissions',
        );
        rolePositive(p['revision']);
        roleCheck(sessions.any((s) => s['session_id'] == p['session_id']));
        _permissions(p['permissions']);
      }
      for (final raw in raidList(data['session_segments'])) {
        final set = roleMap(raw);
        roleShape(set, 'session_id segments');
        roleCheck(sessions.any((s) => s['session_id'] == set['session_id']));
        for (final rawS in raidList(set['segments'])) {
          final s = roleMap(rawS);
          roleShape(
            s,
            'segment_id item_id round_id starts_at ends_at duration_minutes duration_source policy_version state released_reason',
          );
          roleId(s['segment_id']);
          roleCheck(
            items.any(
              (i) =>
                  i['item_id'] == s['item_id'] &&
                  i['round_id'] == s['round_id'],
            ),
          );
        }
      }
      for (final raw in raidList(data['proposals'])) {
        final p = roleMap(raw);
        roleId(p['proposal_id']);
        rolePositive(p['revision']);
        rolePositive(p['proposal_plan_revision']);
        _permissions(p['permissions']);
        if (p.containsKey('target_session_ids')) {
          roleShape(
            p,
            'proposal_id revision proposal_plan_revision created_from_plan_revision state target_session_ids base_schedules proposed_sessions votes my_response permissions',
          );
          final targetIds = raidList(p['target_session_ids']);
          roleCheck(
            targetIds.isNotEmpty &&
                targetIds.toSet().length == targetIds.length,
          );
          for (final id in targetIds) {
            roleId(id);
          }
          if (p['state'] == 'pending') {
            roleCheck(
              targetIds.every(
                (id) => sessions.any((s) => s['session_id'] == id),
              ),
            );
          }
          final proposed = raidList(p['proposed_sessions']);
          _unique(proposed, 'session_id');
          roleCheck(
            proposed.length == targetIds.length &&
                proposed.every((s) => targetIds.contains(s['session_id'])),
          );
          for (final rawSet in proposed) {
            final set = roleMap(rawSet);
            roleShape(set, 'session_id segments');
            for (final rawS in raidList(set['segments'])) {
              final seg = roleMap(rawS);
              roleShape(
                seg,
                'segment_id item_id round_id starts_at ends_at duration_minutes duration_source policy_version state released_reason',
              );
              roleCheck(
                roleUtc(seg['starts_at']).isBefore(roleUtc(seg['ends_at'])),
              );
              roleId(seg['item_id']);
              roleId(seg['round_id']);
              if (p['state'] == 'pending') {
                roleCheck(
                  items.any(
                    (i) =>
                        i['item_id'] == seg['item_id'] &&
                        i['round_id'] == seg['round_id'],
                  ),
                );
              }
            }
          }
          for (final rawV in raidList(p['votes'])) {
            final v = roleMap(rawV);
            roleShape(
              v,
              'session_id eligible_count accepted_count required_votes satisfied',
            );
            roleCheck(
              v['eligible_count'] is int &&
                  v['eligible_count'] >= 0 &&
                  v['eligible_count'] <= 8 &&
                  v['accepted_count'] is int &&
                  v['accepted_count'] >= 0 &&
                  v['accepted_count'] <= v['eligible_count'] &&
                  v['required_votes'] is int &&
                  v['required_votes'] >= 0 &&
                  v['required_votes'] <= 8,
            );
            raidBool(v['satisfied']);
          }
        } else {
          roleShape(
            p,
            'proposal_id kind revision proposal_plan_revision created_from_plan_revision state target_round_ids eligible_count accepted_count required_votes my_response permissions',
          );
        }
      }
    } else if (kind == 'submission') {
      _submission(data, target);
    } else if (kind == 'context') {
      roleShape(
        data,
        'room_id members_revision plan_revision evaluated_at members target_session_id permissions target_cycle_key',
      );
      roleCheck(
        data['room_id'] == room &&
            data['target_cycle_key'] == target &&
            data['target_session_id'] == id,
      );
      rolePositive(data['members_revision']);
      rolePositive(data['plan_revision']);
      roleUtc(data['evaluated_at']);
      _permissions(data['permissions']);
      schedulePermit(roleMap(data['permissions'])['view_schedule_context']);
      final members = raidList(data['members']);
      roleCheck(members.length <= 8);
      _unique(members, 'cycle_member_id');
      for (final raw in members) {
        final m = roleMap(raw);
        roleShape(
          m,
          'membership_id display submission anonymous_busy cycle_member_id',
        );
        roleId(m['membership_id']);
        _submission(roleMap(m['submission']), target);
        roleCheck(
          m['submission']['cycle_member_id'] == m['cycle_member_id'] &&
              m['submission']['membership_id'] == m['membership_id'],
        );
        final busy = roleMap(m['anonymous_busy']);
        roleShape(busy, 'state revision intervals');
        rolePositive(busy['revision']);
        roleCheck({'ready', 'unavailable'}.contains(busy['state']));
        for (final i in raidList(busy['intervals'])) {
          _interval(i);
        }
      }
    } else if (kind == 'candidate') {
      roleShape(
        data,
        'group_id revision plan_revision evaluated_at state earliest_start latest_start',
      );
      roleCheck(
        data['group_id'] == id &&
            {'ready', 'no_candidate', 'search_limited'}.contains(data['state']),
      );
      rolePositive(data['revision']);
      rolePositive(data['plan_revision']);
      roleUtc(data['evaluated_at']);
      for (final k in ['earliest_start', 'latest_start']) {
        if (data[k] != null) roleUtc(data[k]);
      }
      roleCheck(data['state'] != 'ready' || data['earliest_start'] != null);
    } else if (kind == 'overlaps') {
      roleShape(
        data,
        'items pair_count affected_room_count reservation_count revision next_cursor evaluated_at target_cycle_key',
      );
      roleCheck(data['target_cycle_key'] == target);
      raidText(data['revision']);
      roleUtc(data['evaluated_at']);
      for (final k in [
        'pair_count',
        'affected_room_count',
        'reservation_count',
      ]) {
        roleCheck(data[k] is int && data[k] >= 0);
      }
      final pairs = raidList(data['items']);
      roleCheck(
        pairs.length <= 20 &&
            pairs.map((v) => v['pair_id']).toSet().length == pairs.length,
      );
      for (final raw in pairs) {
        final p = roleMap(raw);
        roleShape(p, 'starts_at ends_at pair_id left right');
        raidText(p['pair_id']);
        roleCheck(roleUtc(p['starts_at']).isBefore(roleUtc(p['ends_at'])));
        for (final side in ['left', 'right']) {
          final e = roleMap(p[side]);
          roleShape(
            e,
            'starts_at ends_at reservation_id room_id item_ids session_id character_id character_display raid_display room_title',
          );
          for (final k in [
            'reservation_id',
            'room_id',
            'session_id',
            'character_id',
          ]) {
            roleId(e[k]);
          }
          roleCheck(roleUtc(e['starts_at']).isBefore(roleUtc(e['ends_at'])));
        }
      }
      roleCheck(
        data['next_cursor'] == null ||
            (data['next_cursor'] is String &&
                (data['next_cursor'] as String).isNotEmpty &&
                (data['next_cursor'] as String).length <= 2048),
      );
    } else {
      throw const FormatException('Unknown schedule read');
    }
  }
  final String room, target, kind;
  final String? id;
  final Map<String, dynamic> wire;
  final Map<String, dynamic>? betaData;
  late final Map<String, dynamic> scope, data;
  Map<String, dynamic> find(String field, String key, String id) =>
      raidList(data[field]).map(roleMap).where((m) => m[key] == id).single;
  String get signature => scheduleStable(wire);
}

void _submission(Map<String, dynamic> d, String target) {
  roleShape(
    d,
    'membership_id state revision source_personal_version intervals normalized_intervals submitted_at target_cycle_key cycle_member_id cycle_member_revision',
  );
  roleId(d['membership_id']);
  roleId(d['cycle_member_id']);
  rolePositive(d['revision']);
  rolePositive(d['cycle_member_revision']);
  roleCheck(
    d['target_cycle_key'] == target &&
        {'missing', 'ready', 'unavailable'}.contains(d['state']),
  );
  for (final row in raidList(d['intervals'])) {
    PlayTimeRow.fromJson(roleMap(row));
  }
  for (final raw in raidList(d['normalized_intervals'])) {
    final i = roleMap(raw);
    roleShape(i, 'start_minute end_minute');
    roleCheck(
      i['start_minute'] is int &&
          i['end_minute'] is int &&
          i['start_minute'] >= 0 &&
          i['end_minute'] <= 10080 &&
          i['start_minute'] < i['end_minute'],
    );
  }
  if (d['source_personal_version'] != null) {
    rolePositive(d['source_personal_version']);
  }
  if (d['submitted_at'] != null) roleUtc(d['submitted_at']);
  if (d['state'] == 'missing') {
    roleCheck(
      d['source_personal_version'] == null &&
          raidList(d['intervals']).isEmpty &&
          raidList(d['normalized_intervals']).isEmpty &&
          d['submitted_at'] == null,
    );
  }
}

class CycleSchedulePreview {
  CycleSchedulePreview(
    this.plan,
    this.action, {
    this.id,
    this.extra,
    this.personal,
  });
  final CycleScheduleView plan;
  final String action;
  final String? id;
  final CycleScheduleView? extra;
  final PlayAvailability? personal;
  String get signature => scheduleStable({
    'plan': plan.wire,
    'beta_schedule': plan.betaData?['beta_schedule'],
    'extra': extra?.wire,
    'personal_version': personal?.version,
    'personal_exists': personal?.exists,
    'intervals': personal?.intervals.map((r) => r.toJson()).toList(),
  });
  String get method =>
      {'submission', 'groups'}.contains(action) ? 'PUT' : 'POST';
  String get path => action == 'submission'
      ? '/v2/me/raid-rooms/${plan.room}/availability-submission'
      : action == 'confirm'
      ? '/v2/raid-sessions/$id/participation-confirmations'
      : action == 'select'
      ? '/v2/raid-schedule-groups/$id/selections'
      : action == 'respond'
      ? '/v2/raid-schedule-proposals/$id/responses'
      : '/v2/raid-rooms/${plan.room}/${action == 'groups' ? 'schedule-groups' : 'schedule-proposals'}';
  Map<String, dynamic>? get submissionEvidence => action != 'submission'
      ? null
      : {
          'membership_id': extra!.data['membership_id'],
          'cycle_member_id': extra!.data['cycle_member_id'],
          'cycle_member_revision': extra!.data['cycle_member_revision'],
          'source_personal_version': personal!.version,
          'intervals': personal!.intervals.map((r) => r.toJson()).toList(),
          'revision':
              extra!.data['source_personal_version'] == personal!.version
              ? extra!.data['revision']
              : rolePositive(extra!.data['revision']) + 1,
        };
  Map<String, dynamic> body(Map<String, dynamic> input) {
    final d = plan.data, mine = roleMap(d['my_membership']);
    roleCheck({'leader', 'member'}.contains(d['my_target_role']));
    final base = <String, dynamic>{
      'expected_cycle_key': plan.scope['current_cycle_key'],
      'target_cycle_key': plan.target,
      'expected_target_revision': plan.scope['target_revision'],
    };
    if (action == 'submission') {
      roleCheck(
        (personal!.exists || plan.betaData != null) &&
            extra!.data['cycle_member_id'] == mine['cycle_member_id'] &&
            extra!.data['cycle_member_revision'] ==
                mine['cycle_member_revision'],
      );
      return {
        ...base,
        'expected_personal_version': personal!.version,
        'expected_submission_revision': extra!.data['revision'],
        'expected_cycle_member_revision': mine['cycle_member_revision'],
      };
    }
    if (action == 'confirm') {
      final s = plan.find('sessions', 'session_id', id!),
          p = plan.find('my_participations', 'session_id', id!);
      schedulePermit(roleMap(p['permissions'])['confirm_participation']);
      roleCheck(p['state'] == 'active' && s['state'] == 'confirmed');
      return {
        ...base,
        'expected_schedule_revision': s['schedule_revision'],
        'expected_participation_revision': p['revision'],
        'expected_cycle_member_revision': mine['cycle_member_revision'],
      };
    }
    if (action == 'respond') {
      final p = plan.find('proposals', 'proposal_id', id!);
      roleCheck(p.containsKey('target_session_ids') && p['state'] == 'pending');
      final response = input['response'];
      roleCheck({'accept', 'reject'}.contains(response));
      schedulePermit(roleMap(p['permissions'])['respond_proposal']);
      return {
        ...base,
        'expected_proposal_revision': p['revision'],
        'expected_proposal_plan_revision': p['proposal_plan_revision'],
        'response': response,
        'expected_cycle_member_revision': mine['cycle_member_revision'],
      };
    }
    roleCheck(d['my_target_role'] == 'leader');
    base.addAll({
      'expected_plan_revision': d['revision'],
      'expected_members_revision': d['members_revision'],
      'expected_leadership_revision': roleMap(
        d['leadership'],
      )['leadership_revision'],
    });
    if (action == 'groups') {
      schedulePermit(roleMap(d['permissions'])['edit_schedule_groups']);
      if (plan.betaData != null) {
        final enabled = input['early_coordination_enabled'];
        raidBool(enabled);
        final additional = input['early_additional_members'];
        roleCheck(
          enabled == true
              ? additional is int &&
                    additional >= 1 &&
                    additional < d['app_capacity']
              : additional == null,
        );
        final immediate = input['accept_immediate_confirmation'];
        raidBool(immediate);
        if (enabled == true && immediate != true) {
          throw const AccountReadException('IMMEDIATE_CONFIRMATION_REQUIRED');
        }
        return {
          ...base,
          'early_coordination_enabled': enabled,
          'early_additional_members': additional,
          'accept_immediate_confirmation': immediate,
        };
      }
      final groups = raidList(input['groups']);
      final keys = <String>{};
      roleCheck(groups.isEmpty || groups.any((g) => g['required'] == true));
      for (final raw in groups) {
        final g = roleMap(raw);
        roleShape(
          g,
          'client_group_key existing_group_id expected_group_revision occurrence_mode planning_mode required auto_confirm_additional_members day_scope alternatives',
        );
        roleCheck(keys.add(raidText(g['client_group_key'])));
        raidBool(g['required']);
        roleCheck(
          {'one_of', 'each'}.contains(g['occurrence_mode']) &&
              {
                'manual',
                'coordinated',
                'unscheduled',
              }.contains(g['planning_mode']) &&
              {
                'selected_weekdays',
                'any_current_cycle',
              }.contains(g['day_scope']),
        );
        if (g['existing_group_id'] != null) {
          final old = plan.find(
            'schedule_groups',
            'group_id',
            roleId(g['existing_group_id']),
          );
          roleCheck(old['revision'] == g['expected_group_revision']);
        } else {
          roleCheck(g['expected_group_revision'] == null);
        }
        final threshold = g['auto_confirm_additional_members'];
        roleCheck(
          g['planning_mode'] == 'coordinated'
              ? (threshold is int &&
                    threshold >= 1 &&
                    threshold < d['app_capacity'])
              : threshold == null,
        );
        final alternatives = raidList(g['alternatives']);
        roleCheck(
          (g['day_scope'] == 'any_current_cycle'
              ? (g['planning_mode'] == 'coordinated' &&
                    g['occurrence_mode'] == 'one_of' &&
                    alternatives.isEmpty)
              : alternatives.isNotEmpty),
        );
        final alternativeKeys = <String>{};
        for (final rawA in alternatives) {
          final a = roleMap(rawA);
          roleShape(
            a,
            'client_alternative_key existing_session_id expected_session_revision weekday starts_local leader_latest_start_local item_ids',
          );
          roleCheck(
            alternativeKeys.add(raidText(a['client_alternative_key'])) &&
                a['existing_session_id'] == null &&
                a['expected_session_revision'] == null &&
                a['weekday'] is int &&
                a['weekday'] >= 1 &&
                a['weekday'] <= 7,
          );
          for (final k in ['starts_local', 'leader_latest_start_local']) {
            roleCheck(
              a[k] == null ||
                  (a[k] is String &&
                      RegExp(
                        r'^(?:[01][0-9]|2[0-3]):[0-5][05]$',
                      ).hasMatch(a[k])),
            );
          }
          roleCheck(
            (a['starts_local'] != null) == (g['planning_mode'] == 'manual'),
          );
          if (a['starts_local'] != null) {
            final clock = a['starts_local'] as String;
            _start(cycleScheduleStart(plan.target, a['weekday'] as int, clock));
            if (a['leader_latest_start_local'] != null) {
              roleCheck(
                clock.compareTo(a['leader_latest_start_local'] as String) <= 0,
              );
            }
          }
          final ids = raidList(a['item_ids']),
              expected = raidList(
                d['game_items'],
              ).map((i) => i['item_id']).toSet();
          roleCheck(
            ids.toSet().length == ids.length &&
                ids.length == expected.length &&
                expected.containsAll(ids),
          );
        }
      }
      return {...base, 'groups': groups};
    }
    if (action == 'select') {
      final g = plan.find('schedule_groups', 'group_id', id!);
      schedulePermit(roleMap(g['permissions'])['select']);
      final alt = input['alternative_id'];
      roleCheck(g['planning_mode'] != 'manual' || alt != null);
      roleCheck(g['occurrence_mode'] != 'each' || alt != null);
      roleCheck(
        alt == null ||
            raidList(g['alternatives']).any((a) => a['alternative_id'] == alt),
      );
      if (g['planning_mode'] == 'coordinated') {
        roleCheck(
          extra!.data['state'] == 'ready' &&
              extra!.data['revision'] == g['revision'] &&
              extra!.data['plan_revision'] == d['revision'],
        );
      }
      return {
        ...base,
        'expected_group_revision': g['revision'],
        'alternative_id': alt,
      };
    }
    roleCheck(action == 'propose');
    final targets = raidList(input['targets']);
    roleCheck(targets.isNotEmpty);
    _unique(targets, 'session_id');
    for (final raw in targets) {
      final t = roleMap(raw);
      roleShape(
        t,
        'session_id expected_schedule_revision starts_at item_durations',
      );
      final s = plan.find('sessions', 'session_id', roleId(t['session_id']));
      schedulePermit(roleMap(s['permissions'])['propose_schedule']);
      roleCheck(t['expected_schedule_revision'] == s['schedule_revision']);
      roleUtc(t['starts_at']);
      _start(roleUtc(t['starts_at']));
      final durations = raidList(t['item_durations']);
      _unique(durations, 'item_id');
      final segments = plan.find(
        'session_segments',
        'session_id',
        t['session_id'],
      );
      final ids = raidList(
        segments['segments'],
      ).where((s) => s['state'] == 'planned').map((s) => s['item_id']).toSet();
      roleCheck(
        durations.length == ids.length &&
            durations.every((v) => ids.contains(v['item_id'])),
      );
      for (final rawD in durations) {
        final v = roleMap(rawD);
        roleShape(v, 'item_id duration_minutes');
        final minutes = v['duration_minutes'];
        roleCheck(
          minutes == null ||
              (minutes is int &&
                  minutes >= 10 &&
                  minutes <= 1440 &&
                  minutes % 5 == 0),
        );
      }
    }
    return {...base, 'targets': targets};
  }

  void _start(DateTime value) {
    final week = const WeeklyRaidResetPolicy().weekFor(value);
    if (week.key != plan.target) {
      throw const AccountReadException('TARGET_CYCLE_OUT_OF_RANGE');
    }
    if (value.isBefore(
      roleUtc(plan.scope['server_now']).add(const Duration(minutes: 30)),
    )) {
      throw const AccountReadException('SCHEDULE_BEFORE_FLOOR');
    }
    if (value.isBefore(week.startedAt.add(const Duration(hours: 4)))) {
      throw const AccountReadException('MAINTENANCE_WINDOW');
    }
    roleCheck(
      value.minute % 5 == 0 &&
          value.second == 0 &&
          value.millisecond == 0 &&
          value.microsecond == 0,
    );
  }
}

class CycleScheduleReader {
  CycleScheduleReader(this.api);
  final BackendRegistrationApi api;
  Future<CycleScheduleView> read(
    String room,
    String target,
    String kind, {
    String? id,
    String? cursor,
  }) async {
    roleId(room);
    raidCycleKey(target);
    roleCheck(
      {'plan', 'submission', 'context', 'overlaps', 'candidate'}.contains(kind),
    );
    if (id != null) roleId(id);
    roleCheck(kind != 'candidate' || id != null);
    roleCheck(kind == 'overlaps' || cursor == null);
    final path = kind == 'overlaps'
        ? '/v2/me/raid-schedule-overlaps'
        : kind == 'candidate'
        ? '/v2/raid-schedule-groups/$id/candidates'
        : '/v2/me/raid-rooms/$room/${{'plan': 'plan', 'submission': 'availability-submission', 'context': 'schedule-context'}[kind]}';
    final query = {
      'target_cycle_key': target,
      if (kind == 'context' && id != null) 'target_session_id': id,
      if (kind == 'overlaps') 'limit': 20,
      'cursor': ?cursor,
    };
    if (api is BetaInteractionApi) {
      final decoded = await (api as BetaInteractionApi).requestDecoded(
        path,
        query: query,
      );
      return CycleScheduleView(
        room,
        target,
        kind,
        decoded.value,
        id: id,
        betaData:
            betaFreeze({
                  'beta_schedule': decoded.metadata?['data']?['beta_schedule'],
                  'availability_copy':
                      decoded.metadata?['data']?['availability_copy'],
                  if (kind == 'context')
                    'availability_copies': {
                      for (final member
                          in (decoded.metadata?['data']?['members'] as List? ??
                              []))
                        member['cycle_member_id'] as String:
                            member['submission']?['availability_copy'],
                    },
                })
                as Map<String, dynamic>,
      );
    }
    final raw = (await api.request(path, query: query))!;
    return CycleScheduleView(room, target, kind, raw, id: id);
  }

  Future<CycleSchedulePreview> preview(
    String room,
    String target,
    String action, {
    String? id,
  }) async {
    roleCheck(
      {
        'submission',
        'confirm',
        'groups',
        'select',
        'propose',
        'respond',
      }.contains(action),
    );
    final plan = await read(room, target, 'plan');
    CycleScheduleView? extra;
    PlayAvailability? personal;
    if (action == 'submission') {
      extra = await read(room, target, 'submission');
      personal = PlayAvailability.fromJson(
        (await api.request('/v1/me/play-availability'))!,
      );
    }
    if (action == 'select' &&
        plan.find('schedule_groups', 'group_id', id!)['planning_mode'] ==
            'coordinated') {
      extra = await read(room, target, 'candidate', id: id);
    }
    if (extra != null) {
      roleCheck(
        extra.scope['room_cycle_id'] == plan.scope['room_cycle_id'] &&
            extra.scope['target_generation'] ==
                plan.scope['target_generation'] &&
            extra.scope['target_revision'] == plan.scope['target_revision'],
      );
    }
    return CycleSchedulePreview(
      plan,
      action,
      id: id,
      extra: extra,
      personal: personal,
    );
  }
}

void validateSubmissionAck(
  Map<String, dynamic> wire,
  String room,
  String target,
  Map<String, dynamic> expected,
  Map<String, dynamic> scope,
) {
  final value = CycleScheduleView(room, target, 'submission', wire);
  roleCheck(
    value.scope['room_cycle_id'] == scope['room_cycle_id'] &&
        value.scope['target_generation'] == scope['target_generation'],
  );
  for (final k in expected.keys) {
    roleCheck(scheduleStable(value.data[k]) == scheduleStable(expected[k]));
  }
  roleCheck(
    value.data['state'] == 'ready' && value.data['submitted_at'] != null,
  );
}
