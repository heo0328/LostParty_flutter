import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../domain/policies/party_cycle_policy.dart';
import 'cycle_member_actions.dart' show actionTime;
import 'cycle_schedule.dart' show scheduleStable;

const membershipActionNames = {
  'leave_target',
  'leave_all',
  'dissolve_led_targets',
  'recover_leadership',
};

abstract interface class MembershipActionGateway {
  Future<MembershipActionContext> membershipContext(String room, String view);
  Future<MembershipActionResult> writeMembershipAction(
    MembershipActionPreview preview,
    String key,
    Map<String, dynamic> body,
  );
}

Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable(
        v.map((k, x) => MapEntry(k as String, _freeze(x))),
      )
    : v is List
    ? List<dynamic>.unmodifiable(v.map(_freeze))
    : v;
Map<String, dynamic> _snapshot(Map<String, dynamic> v) =>
    _freeze(jsonDecode(jsonEncode(v))) as Map<String, dynamic>;
int _rev(Object? v) {
  final n = rolePositive(v);
  roleCheck(n <= 2147483647);
  return n;
}

int _count(Object? v) {
  roleCheck(v is int && v >= 0 && v <= 2147483647);
  return v as int;
}

void _text(Object? v, int max, {bool nullable = false}) =>
    roleCheck((nullable && v == null) || (v is String && v.length <= max));
List<Map<String, dynamic>> _objects(Object? v, int max) {
  final a = raidList(v);
  roleCheck(a.length <= max);
  return a.map(roleMap).toList();
}

List<String> _ids(Object? v, int max) {
  final a = raidList(v);
  roleCheck(a.length <= max);
  final ids = a.map(roleId).toList();
  roleCheck(ids.toSet().length == ids.length);
  return ids;
}

void _unique(List<Map<String, dynamic>> values, String key) =>
    roleCheck(values.map((v) => v[key]).toSet().length == values.length);
bool _sameIds(Object? a, Object? b) =>
    scheduleStable(_ids(a, 5)..sort()) == scheduleStable(_ids(b, 5)..sort());

String _nextCycle(String current) {
  const policy = PartyCyclePolicy();
  return policy.keyFor(policy.fromKey(current)!.endsAt);
}

void _scope(Map<String, dynamic> s, String view) {
  roleShape(s, 'server_now current_cycle_key view_cycle_key policy_version');
  final now = actionTime(s['server_now']);
  final c = raidCycleKey(s['current_cycle_key']);
  roleCheck(const PartyCyclePolicy().keyFor(now) == c);
  final next = _nextCycle(c);
  roleCheck(
    s['policy_version'] == 'membership-actions-1' &&
        s['view_cycle_key'] == view &&
        (view == c || view == next),
  );
}

List<String> _cycles(Object? value, Map<String, dynamic> scope) {
  final keys = raidList(value).map(raidCycleKey).toList();
  roleCheck(keys.length <= 2 && keys.toSet().length == keys.length);
  final c = scope['current_cycle_key'] as String;
  final n = _nextCycle(c);
  roleCheck(
    keys.every((k) => k == c || k == n) &&
        scheduleStable(keys) == scheduleStable([...keys]..sort()),
  );
  return keys;
}

void _permission(Map<String, dynamic> p) {
  roleShape(p, 'allowed reason next_change_at');
  raidBool(p['allowed']);
  _text(p['reason'], 64, nullable: true);
  if (p['next_change_at'] != null) actionTime(p['next_change_at']);
  roleCheck(p['allowed'] != true || p['reason'] == null);
}

void _lead(Map<String, dynamic> p, {bool planned = false}) {
  roleShape(
    p,
    'leader_cycle_member_id leader_membership_id leadership_revision${planned ? ' status recovery_reason' : ''}',
  );
  _rev(p['leadership_revision']);
  for (final k in ['leader_cycle_member_id', 'leader_membership_id']) {
    if (p[k] != null) roleId(p[k]);
  }
  roleCheck(
    (p['leader_cycle_member_id'] == null) ==
        (p['leader_membership_id'] == null),
  );
  if (planned) {
    roleCheck({'active', 'pending_review', 'closed'}.contains(p['status']));
    _text(p['recovery_reason'], 64, nullable: true);
    roleCheck(p['status'] != 'active' || p['leader_cycle_member_id'] != null);
  }
}

void _rule(Map<String, dynamic> r, Object? before) {
  roleShape(r, 'before comparison exact_after');
  roleCheck(_rev(r['before']) == _rev(before));
  roleCheck({'equal', 'increase'}.contains(r['comparison']));
  if (r['exact_after'] != null) _rev(r['exact_after']);
  roleCheck(
    r['comparison'] == 'equal'
        ? r['exact_after'] == before
        : r['exact_after'] == null ||
              (r['exact_after'] as int) > (before as int),
  );
}

void _after(Map<String, dynamic> r, Object? value) {
  final n = _rev(value), before = _rev(r['before']);
  roleCheck(r['comparison'] == 'equal' ? n == before : n > before);
  roleCheck(r['exact_after'] == null || n == r['exact_after']);
}

void _order(Object? v) {
  roleCheck(
    v == null ||
        (v is String && v.length <= 20 && RegExp(r'^[1-9][0-9]*$').hasMatch(v)),
  );
}

const _states = {
  'participating',
  'review_required',
  'cancelled',
  'removed',
  'completed',
  'stopped',
};
void _member(Map<String, dynamic> m, {required bool planned}) {
  roleShape(
    m,
    'membership_id cycle_member_id cycle_member_revision state cancelled_assignment_ids preserved_completed_assignment_ids${planned ? ' character_id character_name joined_order revision_rule planned_state' : ''}',
  );
  roleId(m['membership_id']);
  roleId(m['cycle_member_id']);
  _rev(m['cycle_member_revision']);
  roleCheck(_states.contains(m['state']));
  final cancelled = _ids(m['cancelled_assignment_ids'], 5),
      completed = _ids(m['preserved_completed_assignment_ids'], 5);
  roleCheck(!cancelled.any(completed.contains));
  if (planned) {
    if (m['character_id'] != null) roleId(m['character_id']);
    _text(m['character_name'], 64, nullable: true);
    _order(m['joined_order']);
    _rule(roleMap(m['revision_rule']), m['cycle_member_revision']);
    roleCheck(_states.contains(m['planned_state']));
  }
}

void _target(Map<String, dynamic> t) {
  roleShape(
    t,
    'target_cycle_key room_cycle_id target_generation target_revision members_revision plan_revision target_state generation_state planned_target_state planned_generation_state revision_rules leadership_before transition affected_members successor leadership_after cleanup',
  );
  raidCycleKey(t['target_cycle_key']);
  roleId(t['room_cycle_id']);
  _rev(t['target_generation']);
  for (final k in ['target_state', 'planned_target_state']) {
    roleCheck({'open', 'review_required', 'closed'}.contains(t[k]));
  }
  for (final k in ['generation_state', 'planned_generation_state']) {
    roleCheck(
      {
        'open',
        'review_required',
        'cancelled',
        'completed',
        'stopped',
      }.contains(t[k]),
    );
  }
  roleCheck(
    {
      'leave',
      'automatic_successor',
      'leadership_pending',
      'close_empty',
      'dissolve',
      'recover',
      'eligibility_cleanup',
    }.contains(t['transition']),
  );
  final rules = roleMap(t['revision_rules']);
  roleShape(rules, 'target members plan leadership');
  final before = roleMap(t['leadership_before']),
      after = roleMap(t['leadership_after']);
  _lead(before);
  _lead(after, planned: true);
  for (final entry in {
    'target': t['target_revision'],
    'members': t['members_revision'],
    'plan': t['plan_revision'],
    'leadership': before['leadership_revision'],
  }.entries) {
    _rule(roleMap(rules[entry.key]), entry.value);
  }
  _after(roleMap(rules['leadership']), after['leadership_revision']);
  final members = _objects(t['affected_members'], 8);
  for (final m in members) {
    _member(m, planned: true);
  }
  _unique(members, 'cycle_member_id');
  _unique(members, 'membership_id');
  if (t['successor'] != null) {
    final s = roleMap(t['successor']);
    roleShape(
      s,
      'membership_id cycle_member_id cycle_member_revision planned_cycle_member_revision character_id character_name joined_order',
    );
    for (final k in ['membership_id', 'cycle_member_id', 'character_id']) {
      roleId(s[k]);
    }
    _rev(s['cycle_member_revision']);
    _rev(s['planned_cycle_member_revision']);
    _text(s['character_name'], 64, nullable: true);
    _order(s['joined_order']);
    roleCheck(
      s['joined_order'] != null &&
          after['leader_cycle_member_id'] == s['cycle_member_id'] &&
          after['leader_membership_id'] == s['membership_id'],
    );
  }
  final cleanup = roleMap(t['cleanup']);
  roleShape(
    cleanup,
    'released_reservation_count ended_participation_count cancelled_application_count cancelled_session_count',
  );
  for (final v in cleanup.values) {
    _count(v);
  }
}

/// Immutable server-owned menu. No client inference of eligibility or successors.
class MembershipActionContext {
  MembershipActionContext(this.room, this.view, Map<String, dynamic> raw)
    : wire = _snapshot(raw) {
    roleId(room);
    raidCycleKey(view);
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    _scope(scope, view);
    data = roleMap(wire['data']);
    roleShape(data, 'room_id room_revision actor options');
    roleCheck(data['room_id'] == room);
    _rev(data['room_revision']);
    final actor = roleMap(data['actor']);
    roleShape(actor, 'membership_id membership_revision');
    roleId(actor['membership_id']);
    _rev(actor['membership_revision']);
    options = roleMap(data['options']);
    roleShape(options, membershipActionNames.join(' '));
    for (final name in membershipActionNames) {
      final o = roleMap(options[name]);
      roleShape(o, 'visible permission impact confirmation');
      raidBool(o['visible']);
      final p = roleMap(o['permission']);
      _permission(p);
      if (p['allowed'] != true) {
        roleCheck(o['impact'] == null && o['confirmation'] == null);
        continue;
      }
      roleCheck(o['visible'] == true);
      final impact = roleMap(o['impact']);
      roleShape(
        impact,
        'action affected_cycle_keys targets room_effect existing_completion_preserved display_revision',
      );
      roleCheck(
        impact['action'] == name &&
            impact['existing_completion_preserved'] == true,
      );
      roleCheck(
        impact['display_revision'] is String &&
            RegExp(
              r'^[0-9a-f]{64}$',
            ).hasMatch(impact['display_revision'] as String),
      );
      final keys = _cycles(impact['affected_cycle_keys'], scope),
          targets = _objects(impact['targets'], 2);
      roleCheck(
        scheduleStable(keys) ==
            scheduleStable(targets.map((t) => t['target_cycle_key']).toList()),
      );
      roleCheck(keys.isNotEmpty || name == 'leave_all');
      if (name == 'leave_target' || name == 'recover_leadership') {
        roleCheck(keys.length == 1 && keys.single == view);
      }
      for (final t in targets) {
        _target(t);
        if (name == 'dissolve_led_targets') {
          roleCheck(
            roleMap(t['leadership_before'])['leader_membership_id'] ==
                actor['membership_id'],
          );
        }
      }
      final effect = roleMap(impact['room_effect']);
      roleShape(
        effect,
        'kind actor_membership_will_end ended_persistent_membership_count preserves_unaffected_cycles room_revision_rule actor_membership_revision_rule',
      );
      roleCheck(
        {'preserve', 'preserve_review', 'end'}.contains(effect['kind']) &&
            effect['preserves_unaffected_cycles'] == true,
      );
      raidBool(effect['actor_membership_will_end']);
      _count(effect['ended_persistent_membership_count']);
      _rule(roleMap(effect['room_revision_rule']), data['room_revision']);
      _rule(
        roleMap(effect['actor_membership_revision_rule']),
        actor['membership_revision'],
      );
      if (name == 'leave_all') {
        roleCheck(effect['actor_membership_will_end'] == true);
      }
      final confirmation = roleMap(o['confirmation']);
      roleShape(confirmation, 'context_token issued_at expires_at');
      final token = confirmation['context_token'];
      roleCheck(
        token is String &&
            token.isNotEmpty &&
            utf8.encode(token).length <= 4096,
      );
      final issued = actionTime(confirmation['issued_at']),
          expires = actionTime(confirmation['expires_at']),
          now = actionTime(scope['server_now']);
      roleCheck(
        !now.isBefore(issued) &&
            now.isBefore(expires) &&
            expires.difference(issued) <= const Duration(seconds: 120),
      );
    }
  }
  final String room, view;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope, data, options;
  MembershipActionPreview select(String action) =>
      MembershipActionPreview._(this, action);
}

class MembershipActionPreview {
  MembershipActionPreview._(this.context, this.action) {
    roleCheck(membershipActionNames.contains(action));
    option = roleMap(context.options[action]);
    final permission = roleMap(option['permission']);
    if (permission['allowed'] != true) {
      throw AccountReadException(
        permission['reason'] as String? ?? 'PERMISSION_DENIED',
      );
    }
    impact = roleMap(option['impact']);
    // Only the selected option is confirmation evidence; token/time refresh is harmless.
    signature = scheduleStable({
      'scope': {
        for (final e in context.scope.entries)
          if (e.key != 'server_now') e.key: e.value,
      },
      'room': room,
      'room_revision': context.data['room_revision'],
      'actor': context.data['actor'],
      'action': action,
      'visible': option['visible'],
      'permission': option['permission'],
      'impact': impact,
    });
  }
  final MembershipActionContext context;
  final String action;
  late final Map<String, dynamic> option, impact;
  late final String signature;
  String get room => context.room;
  String get view => context.view;
  String get path => '/v2/raid-rooms/$room/membership-actions';
  List<String> get affected =>
      List<String>.unmodifiable(impact['affected_cycle_keys'] as List);
  Map<String, dynamic> body() => {
    'expected_cycle_key': context.scope['current_cycle_key'],
    'view_cycle_key': view,
    'actor_membership_id': roleMap(context.data['actor'])['membership_id'],
    'expected_actor_membership_revision': roleMap(
      context.data['actor'],
    )['membership_revision'],
    'action': action,
    'context_token': roleMap(option['confirmation'])['context_token'],
  };
}

/// A write ACK is compared with the original Impact, never a later GET/current week.
class MembershipActionResult {
  MembershipActionResult(
    Map<String, dynamic> raw,
    MembershipActionPreview p,
    String key,
  ) : this.fromEvidence(raw, MembershipAckEvidence.fromPreview(p), key);
  MembershipActionResult.fromEvidence(
    Map<String, dynamic> raw,
    MembershipAckEvidence p,
    String key,
  ) : wire = _snapshot(raw) {
    roleId(key);
    roleShape(wire, 'scope data');
    final scope = roleMap(wire['scope']);
    _scope(scope, p.view);
    roleCheck(scope['current_cycle_key'] == p.scope['current_cycle_key']);
    data = roleMap(wire['data']);
    roleShape(
      data,
      'command_id action outcome executed_at room_id room_revision actor_membership_id actor_membership_revision actor_membership_ended affected_cycle_keys effects room_ended ended_persistent_membership_count',
    );
    roleCheck(
      data['command_id'] == key &&
          data['room_id'] == p.room &&
          data['action'] == p.action &&
          data['outcome'] == 'applied',
    );
    actionTime(data['executed_at']);
    final actor = p.actor, effect = roleMap(p.impact['room_effect']);
    roleCheck(data['actor_membership_id'] == actor['membership_id']);
    _after(roleMap(effect['room_revision_rule']), data['room_revision']);
    _after(
      roleMap(effect['actor_membership_revision_rule']),
      data['actor_membership_revision'],
    );
    roleCheck(
      raidBool(data['actor_membership_ended']) ==
              effect['actor_membership_will_end'] &&
          raidBool(data['room_ended']) == (effect['kind'] == 'end'),
    );
    roleCheck(
      _count(data['ended_persistent_membership_count']) ==
          effect['ended_persistent_membership_count'],
    );
    final keys = _cycles(data['affected_cycle_keys'], scope),
        results = _objects(data['effects'], 2);
    roleCheck(
      scheduleStable(keys) == scheduleStable(p.affected) &&
          results.length == keys.length,
    );
    final plans = _objects(p.impact['targets'], 2);
    for (var i = 0; i < results.length; i++) {
      final r = results[i], t = plans[i];
      roleShape(
        r,
        'target_cycle_key room_cycle_id target_generation target_revision members_revision plan_revision target_state generation_state leadership leadership_status recovery_reason members',
      );
      for (final k in [
        'target_cycle_key',
        'room_cycle_id',
        'target_generation',
      ]) {
        roleCheck(r[k] == t[k]);
      }
      roleCheck(
        r['target_state'] == t['planned_target_state'] &&
            r['generation_state'] == t['planned_generation_state'],
      );
      final rules = roleMap(t['revision_rules']);
      for (final entry in {
        'target': 'target_revision',
        'members': 'members_revision',
        'plan': 'plan_revision',
      }.entries) {
        _after(roleMap(rules[entry.key]), r[entry.value]);
      }
      final leadership = roleMap(r['leadership']),
          planned = roleMap(t['leadership_after']);
      _lead(leadership);
      for (final k in [
        'leader_cycle_member_id',
        'leader_membership_id',
        'leadership_revision',
      ]) {
        roleCheck(leadership[k] == planned[k]);
      }
      roleCheck(
        r['leadership_status'] == planned['status'] &&
            r['recovery_reason'] == planned['recovery_reason'],
      );
      final members = _objects(r['members'], 8),
          expected = _objects(t['affected_members'], 8);
      roleCheck(members.length == expected.length);
      _unique(members, 'cycle_member_id');
      _unique(members, 'membership_id');
      for (final m in members) {
        _member(m, planned: false);
        final matching = expected.where(
          (v) => v['cycle_member_id'] == m['cycle_member_id'],
        );
        roleCheck(matching.length == 1);
        final before = matching.single;
        roleCheck(
          m['membership_id'] == before['membership_id'] &&
              m['state'] == before['planned_state'],
        );
        _after(roleMap(before['revision_rule']), m['cycle_member_revision']);
        for (final k in [
          'cancelled_assignment_ids',
          'preserved_completed_assignment_ids',
        ]) {
          roleCheck(_sameIds(m[k], before[k]));
        }
      }
    }
  }
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> data;
  String get room => data['room_id'] as String;
  String get view => roleMap(wire['scope'])['view_cycle_key'] as String;
  String get action => data['action'] as String;
  bool get actorEnded => data['actor_membership_ended'] as bool;

  /// Only explicit cancellation/removal of the actor ends the viewed participation.
  /// A different target's closure must not navigate away from a preserved target.
  bool exitsTarget(String target) =>
      actorEnded ||
      (data['effects'] as List).any(
        (effect) =>
            effect['target_cycle_key'] == target &&
            (effect['members'] as List).any(
              (member) =>
                  member['membership_id'] == data['actor_membership_id'] &&
                  {'cancelled', 'removed'}.contains(member['state']),
            ),
      );
  List<String> get affected =>
      List<String>.unmodifiable(data['affected_cycle_keys'] as List);
}

class MembershipAckEvidence {
  MembershipAckEvidence(Map<String, dynamic> json) : wire = _snapshot(json) {
    roleShape(wire, 'room view action scope actor impact');
    roleId(room);
    _scope(scope, view);
    roleCheck(
      membershipActionNames.contains(action) && action != 'recover_leadership',
    );
    roleId(actor['membership_id']);
  }
  factory MembershipAckEvidence.fromPreview(MembershipActionPreview p) =>
      MembershipAckEvidence({
        'room': p.room,
        'view': p.view,
        'action': p.action,
        'scope': p.context.scope,
        'actor': {'membership_id': p.context.data['actor']['membership_id']},
        'impact': p.impact,
      });
  final Map<String, dynamic> wire;
  String get room => wire['room'] as String;
  String get view => wire['view'] as String;
  String get action => wire['action'] as String;
  Map<String, dynamic> get scope => roleMap(wire['scope']);
  Map<String, dynamic> get actor => roleMap(wire['actor']);
  Map<String, dynamic> get impact => roleMap(wire['impact']);
  List<String> get affected =>
      List<String>.from(impact['affected_cycle_keys'] as List);
}
