import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import 'cycle_read_repository.dart';
import 'cycle_schedule.dart';

const cycleOutcomeLabels = {
  'complete_item': '레이드 완료',
  'personal_completion': '나만 완료',
  'close_weekly': '이번 주 미완료 종료',
};

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final e in value.entries) e.key as String: _freeze(e.value),
    });
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

/// The confirmation binds the actual plan and the server-calculated impact.
/// A context token alone is never treated as permission or a successful write.
class CycleOutcomePreview {
  CycleOutcomePreview(
    this.plan,
    this.action,
    this.round,
    Map<String, dynamic> raw,
  ) : wire = _freeze(jsonDecode(jsonEncode(raw))) as Map<String, dynamic> {
    roleCheck(cycleOutcomeLabels.containsKey(action));
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    data = roleMap(wire['data']);
    CycleReadScope(scope, plan.target);
    roleId(scope['room_cycle_id']);
    rolePositive(scope['target_generation']);
    rolePositive(scope['target_revision']);
    for (final k in [
      'current_cycle_key',
      'room_cycle_id',
      'target_generation',
      'target_revision',
    ]) {
      roleCheck(scope[k] == plan.scope[k]);
    }
    roleShape(
      data,
      'room_id command actor_membership_id actor_membership_revision room_revision members_revision plan_revision target_round_id effect_scope impact permission issued_at expires_at context_token target_cycle_key leadership actor_cycle_member_id actor_cycle_member_revision',
    );
    roleCheck(
      data['room_id'] == plan.room &&
          data['command'] == action &&
          data['target_cycle_key'] == plan.target &&
          data['target_round_id'] == round,
    );
    roleCheck((action == 'close_weekly') == (round == null));
    for (final k in [
      'actor_membership_revision',
      'room_revision',
      'members_revision',
      'plan_revision',
      'actor_cycle_member_revision',
    ]) {
      rolePositive(data[k]);
    }
    final mine = roleMap(plan.data['my_membership']);
    roleCheck(
      roleId(data['actor_membership_id']) == mine['membership_id'] &&
          data['actor_membership_revision'] == mine['revision'] &&
          roleId(data['actor_cycle_member_id']) == mine['cycle_member_id'] &&
          data['actor_cycle_member_revision'] ==
              mine['cycle_member_revision'] &&
          data['members_revision'] == plan.data['members_revision'] &&
          data['plan_revision'] == plan.data['revision'],
    );
    final leader = roleMap(data['leadership']);
    roleShape(
      leader,
      'leader_cycle_member_id leadership_revision leader_membership_id',
    );
    rolePositive(leader['leadership_revision']);
    for (final k in ['leader_cycle_member_id', 'leader_membership_id']) {
      if (leader[k] != null) roleId(leader[k]);
    }
    roleCheck(
      scheduleStable(leader) == scheduleStable(plan.data['leadership']),
    );
    roleCheck(
      data['effect_scope'] ==
          const {
            'complete_item': 'item_round',
            'personal_completion': 'personal_item',
            'close_weekly': 'target_cycle',
          }[action],
    );
    impact = roleMap(data['impact']);
    roleShape(
      impact,
      'round_ids membership_count assignment_count reservation_segment_count completed_preserved_count',
    );
    final rounds = raidList(impact['round_ids']);
    roleCheck(rounds.length <= 5 && rounds.toSet().length == rounds.length);
    for (final id in rounds) {
      roleId(id);
      roleCheck(
        items.any((i) => i['round_id'] == id && i['round_state'] == 'active'),
      );
    }
    if (round != null) {
      roleId(round);
      roleCheck(items.any((i) => i['round_id'] == round));
      roleCheck(rounds.every((r) => r == round));
    }
    for (final k in [
      'membership_count',
      'assignment_count',
      'reservation_segment_count',
      'completed_preserved_count',
    ]) {
      raidNonnegative(impact[k]);
    }
    roleCheck(
      impact['membership_count'] <= plan.data['app_capacity'] &&
          impact['assignment_count'] <=
              plan.data['app_capacity'] * items.length &&
          (action != 'personal_completion' ||
              (impact['membership_count'] <= 1 &&
                  impact['assignment_count'] <= 1)),
    );
    permission = CyclePermission.fromJson(roleMap(data['permission']));
    final issued = roleUtc(data['issued_at']),
        expires = roleUtc(data['expires_at']);
    final now = roleUtc(scope['server_now']);
    roleCheck(!issued.isAfter(now) && expires.isAfter(issued));
    roleCheck(raidText(data['context_token']).length <= 4096);
    if (!expires.isAfter(now)) {
      throw const AccountReadException('COMMAND_CONTEXT_EXPIRED');
    }
    final playable = DateTime.parse('${plan.target}T01:00:00Z');
    roleCheck(roleUtc(scope['playable_from']) == playable);
    if (permission.allowed) {
      roleCheck(
        plan.target == scope['current_cycle_key'] &&
            !now.isBefore(playable) &&
            plan.data['target_state'] == 'open' &&
            rounds.isNotEmpty &&
            impact['membership_count'] > 0 &&
            impact['assignment_count'] > 0 &&
            {'leader', 'member'}.contains(plan.data['my_target_role']),
      );
      if (action == 'complete_item') {
        roleCheck(
          leader['leader_cycle_member_id'] == data['actor_cycle_member_id'] &&
              plan.data['my_target_role'] == 'leader',
        );
      }
      if (action == 'personal_completion') {
        roleCheck(
          raidList(
            plan.data['my_assignments'],
          ).any((a) => a['round_id'] == round && a['state'] == 'active'),
        );
      }
    }
    // Capture the semantic signature before any later UI or network work.
    signature = scheduleStable({
      'plan': plan.wire,
      'context': {
        'scope': scope,
        'data': {
          for (final e in data.entries)
            if (!{'context_token', 'issued_at', 'expires_at'}.contains(e.key))
              e.key: e.value,
        },
      },
    });
  }
  final CycleScheduleView plan;
  final String action;
  final String? round;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope, data, impact;
  late final CyclePermission permission;
  late final String signature;
  List<Map<String, dynamic>> get items =>
      raidList(plan.data['game_items']).map(roleMap).toList();
  String get path => action == 'close_weekly'
      ? '/v2/raid-rooms/${plan.room}/weekly-incomplete-closures'
      : '/v2/raid-rounds/$round/${action == 'complete_item' ? 'completion' : 'personal-completion'}';
  Map<String, dynamic> body() {
    if (!permission.allowed) {
      throw AccountReadException(permission.reason ?? 'PERMISSION_DENIED');
    }
    return {
      'expected_cycle_key': scope['current_cycle_key'],
      'context_token': data['context_token'],
      'target_cycle_key': plan.target,
      'expected_target_revision': scope['target_revision'],
    };
  }
}

class CycleOutcomeReader {
  CycleOutcomeReader(this.api);
  final BackendRegistrationApi api;
  Future<CycleOutcomePreview> preview(
    String room,
    String target,
    String action, {
    String? round,
  }) async {
    roleId(room);
    raidCycleKey(target);
    roleCheck(
      cycleOutcomeLabels.containsKey(action) &&
          ((action == 'close_weekly') == (round == null)),
    );
    if (round != null) roleId(round);
    final plan = await CycleScheduleReader(api).read(room, target, 'plan');
    final raw = (await api.request(
      '/v2/raid-rooms/$room/command-context',
      query: {
        'target_cycle_key': target,
        'command': action,
        'round_id': ?round,
      },
    ))!;
    return CycleOutcomePreview(plan, action, round, raw);
  }
}
