import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import 'cycle_read_repository.dart';
import 'cycle_schedule.dart' show scheduleStable;

abstract interface class CycleDepartureGateway {
  Future<DeparturePreview> departure(String room, String target, String round);
  Future<void> writeDeparture(
    DeparturePreview preview,
    String key,
    Map<String, dynamic> body,
  );
}

abstract interface class CycleRemovalGateway {
  Future<RemovalPreview> removal(String room, String target, String member);
  Future<void> writeRemoval(
    RemovalPreview preview,
    String mode,
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
int _revision(Object? v) {
  final n = rolePositive(v);
  roleCheck(n <= 2147483647);
  return n;
}

DateTime actionTime(Object? v) {
  roleCheck(v is String);
  final raw = v as String;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|([+-])(\d{2}):(\d{2}))$',
  ).firstMatch(raw);
  roleCheck(match != null);
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match!.group(i)!)];
  final local = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  roleCheck(
    local.year == parts[0] &&
        local.month == parts[1] &&
        local.day == parts[2] &&
        local.hour == parts[3] &&
        local.minute == parts[4] &&
        local.second == parts[5],
  );
  if (match!.group(7) != 'Z') {
    roleCheck(
      int.parse(match.group(9)!) <= 23 && int.parse(match.group(10)!) <= 59,
    );
  }
  return DateTime.parse(raw).toUtc();
}

void _name(Object? v) {
  roleCheck(v == null || v is String);
}

void _lead(Map<String, dynamic> j) {
  roleShape(
    j,
    'leader_cycle_member_id leadership_revision leader_membership_id',
  );
  _revision(j['leadership_revision']);
  for (final k in ['leader_cycle_member_id', 'leader_membership_id']) {
    if (j[k] != null) roleId(j[k]);
  }
  roleCheck(
    (j['leader_cycle_member_id'] == null) ==
        (j['leader_membership_id'] == null),
  );
}

List<String> _ids(Object? v, int max) {
  final items = raidList(v);
  roleCheck(items.length <= max);
  final ids = items.map(roleId).toList();
  roleCheck(ids.toSet().length == ids.length);
  return ids;
}

bool _sameIds(Object? a, Object? b) =>
    scheduleStable(_ids(a, 5)..sort()) == scheduleStable(_ids(b, 5)..sort());

/// A card-bound snapshot. Each option has independent confirmation evidence.
class RemovalPreview {
  RemovalPreview(this.room, this.target, this.member, Map<String, dynamic> raw)
    : wire = _freeze(jsonDecode(jsonEncode(raw))) as Map<String, dynamic> {
    roleId(room);
    roleId(member);
    raidCycleKey(target);
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    CycleReadScope({
      ...scope,
      'server_now': actionTime(scope['server_now']).toIso8601String(),
      'playable_from': actionTime(scope['playable_from']).toIso8601String(),
    }, target);
    data = roleMap(wire['data']);
    roleShape(
      data,
      'action room_id target_membership_id source opposite_relation options',
    );
    roleCheck(data['action'] == 'member_removal' && data['room_id'] == room);
    roleId(data['target_membership_id']);
    source = roleMap(data['source']);
    _target(source);
    roleCheck(source['target_cycle_member_id'] == member);
    for (final k in [
      'target_cycle_key',
      'room_cycle_id',
      'target_generation',
      'target_revision',
    ]) {
      roleCheck(source[k] == scope[k]);
    }
    opposite = roleMap(data['opposite_relation']);
    roleShape(opposite, 'target_cycle_key status target');
    final c = scope['current_cycle_key'] as String;
    final n = DateTime.parse(
      c,
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    roleCheck(opposite['target_cycle_key'] == (target == c ? n : c));
    roleCheck(
      {'none', 'participating', 'review_required'}.contains(opposite['status']),
    );
    if (opposite['target'] != null) {
      final other = roleMap(opposite['target']);
      _target(other);
      roleCheck(
        opposite['status'] == 'participating' &&
            other['target_cycle_key'] == opposite['target_cycle_key'] &&
            other['room_cycle_id'] != source['room_cycle_id'] &&
            other['target_cycle_member_id'] != member,
      );
    }
    options = roleMap(data['options']);
    roleShape(options, 'current_only both');
    for (final mode in ['current_only', 'both']) {
      final o = option(mode);
      roleShape(o, 'permission impact confirmation');
      final p = permission(mode);
      roleCheck(
        p.allowed ? p.reason == null : p.reason != null && p.reason!.isNotEmpty,
      );
      roleCheck(
        p.allowed == (o['impact'] != null) &&
            p.allowed == (o['confirmation'] != null),
      );
      if (!p.allowed) continue;
      final targets = mode == 'both'
          ? [source, roleMap(opposite['target'])]
          : [source];
      if (mode == 'both') roleCheck(opposite['status'] == 'participating');
      final impact = roleMap(o['impact']);
      roleShape(
        impact,
        'mode affected_cycle_keys targets preserves_completed preserves_global_membership',
      );
      roleCheck(
        impact['mode'] == mode &&
            impact['preserves_completed'] == true &&
            impact['preserves_global_membership'] == true,
      );
      final keys = targets.map((t) => t['target_cycle_key']).toList();
      roleCheck(
        scheduleStable(impact['affected_cycle_keys']) == scheduleStable(keys),
      );
      final effects = raidList(impact['targets']);
      roleCheck(effects.length == targets.length);
      for (var i = 0; i < targets.length; i++) {
        final t = targets[i],
            effect = roleMap(effects[i]),
            lead = roleMap(t['leadership']);
        roleCheck(
          lead['leader_cycle_member_id'] == t['actor_cycle_member_id'] &&
              t['target_cycle_member_id'] != t['actor_cycle_member_id'] &&
              lead['leader_membership_id'] != membership,
        );
        roleShape(
          effect,
          'target_cycle_key cycle_member_id cancel_assignment_ids preserved_completed_assignment_ids released_reservation_count',
        );
        roleCheck(
          effect['target_cycle_key'] == t['target_cycle_key'] &&
              effect['cycle_member_id'] == t['target_cycle_member_id'],
        );
        final all = [
          ..._ids(effect['cancel_assignment_ids'], 5),
          ..._ids(effect['preserved_completed_assignment_ids'], 5),
        ];
        roleCheck(all.length <= 5 && all.toSet().length == all.length);
        raidNonnegative(effect['released_reservation_count']);
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
          expires = actionTime(confirmation['expires_at']);
      final end = DateTime.parse(
        '${c}T00:00:00Z',
      ).add(const Duration(days: 7)).subtract(const Duration(hours: 3));
      roleCheck(
        issued == actionTime(scope['server_now']) &&
            expires.isAfter(issued) &&
            expires.difference(issued) <= const Duration(seconds: 120) &&
            !expires.isAfter(end),
      );
    }
  }
  final String room, target, member;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope, data, source, opposite, options;
  String get membership => data['target_membership_id'] as String;
  String get path => '/v2/raid-rooms/$room/member-removals';
  Map<String, dynamic> option(String mode) {
    roleCheck({'current_only', 'both'}.contains(mode));
    return roleMap(options[mode]);
  }

  CyclePermission permission(String mode) {
    final p = roleMap(option(mode)['permission']);
    return CyclePermission.fromJson({
      ...p,
      if (p['next_change_at'] != null)
        'next_change_at': actionTime(p['next_change_at']).toIso8601String(),
    });
  }

  List<String> affected(String mode) => raidList(
    roleMap(option(mode)['impact'])['affected_cycle_keys'],
  ).cast<String>();
  String signature(String mode) => scheduleStable({
    'scope': {
      for (final e in scope.entries)
        if (e.key != 'server_now') e.key: e.value,
    },
    'room_id': room,
    'target_membership_id': membership,
    'source': source,
    if (mode == 'both') 'opposite_relation': opposite,
    'option': {
      for (final e in option(mode).entries)
        if (e.key != 'confirmation') e.key: e.value,
    },
  });
  Map<String, dynamic> body(String mode) {
    final p = permission(mode);
    if (!p.allowed) throw AccountReadException(p.reason ?? 'PERMISSION_DENIED');
    return {
      'expected_cycle_key': scope['current_cycle_key'],
      'target_cycle_key': target,
      'room_cycle_id': source['room_cycle_id'],
      'target_generation': source['target_generation'],
      'expected_target_revision': source['target_revision'],
      'context_token': option(mode)['confirmation']['context_token'],
      'target_membership_id': membership,
      'target_cycle_member_id': member,
      'expected_target_cycle_member_revision':
          source['target_cycle_member_revision'],
      'mode': mode,
    };
  }

  void _target(Map<String, dynamic> t) {
    roleShape(
      t,
      'target_cycle_key room_cycle_id target_generation target_revision actor_cycle_member_id actor_cycle_member_revision target_cycle_member_id target_cycle_member_revision character_id character_name leadership',
    );
    raidCycleKey(t['target_cycle_key']);
    for (final k in [
      'room_cycle_id',
      'actor_cycle_member_id',
      'target_cycle_member_id',
      'character_id',
    ]) {
      roleId(t[k]);
    }
    for (final k in [
      'target_generation',
      'target_revision',
      'actor_cycle_member_revision',
      'target_cycle_member_revision',
    ]) {
      _revision(t[k]);
    }
    _name(t['character_name']);
    _lead(roleMap(t['leadership']));
  }
}

void validateRemovalResult(
  Map<String, dynamic> raw,
  RemovalPreview p,
  String mode,
  String key,
) {
  validateRemovalEvidenceResult(
    raw,
    RemovalAckEvidence.fromPreview(p, mode),
    key,
  );
}

void validateRemovalEvidenceResult(
  Map<String, dynamic> raw,
  RemovalAckEvidence p,
  String key,
) {
  roleShape(raw, 'scope data');
  final scope = roleMap(raw['scope']), d = roleMap(raw['data']);
  CycleReadScope({
    ...scope,
    'server_now': actionTime(scope['server_now']).toIso8601String(),
    'playable_from': actionTime(scope['playable_from']).toIso8601String(),
  }, p.target);
  for (final k in [
    'current_cycle_key',
    'target_cycle_key',
    'playable_from',
    'phase',
    'policy_version',
    'room_cycle_id',
    'target_generation',
  ]) {
    roleCheck(
      k == 'playable_from'
          ? actionTime(scope[k]) == actionTime(p.scope[k])
          : scope[k] == p.scope[k],
    );
  }
  roleCheck(scope['target_revision'] == p.scope['target_revision'] + 1);
  roleShape(
    d,
    'command_id action outcome executed_at room_id subject_membership_id affected_cycle_keys effects',
  );
  roleCheck(
    d['command_id'] == key &&
        d['action'] == 'member_removal' &&
        d['outcome'] == 'applied' &&
        d['room_id'] == p.room &&
        d['subject_membership_id'] == p.membership,
  );
  final executed = actionTime(d['executed_at']),
      conf = roleMap(p.option['confirmation']);
  roleCheck(
    executed == actionTime(scope['server_now']) &&
        !executed.isBefore(actionTime(conf['issued_at'])) &&
        executed.isBefore(actionTime(conf['expires_at'])),
  );
  final impact = roleMap(p.option['impact']);
  roleCheck(
    scheduleStable(d['affected_cycle_keys']) ==
        scheduleStable(impact['affected_cycle_keys']),
  );
  final effects = raidList(d['effects']),
      expected = raidList(impact['targets']);
  roleCheck(effects.length == expected.length);
  for (var i = 0; i < effects.length; i++) {
    final v = roleMap(effects[i]), e = roleMap(expected[i]);
    final t = i == 0 ? p.source : roleMap(p.opposite['target']);
    roleShape(
      v,
      'target_cycle_key room_cycle_id target_generation target_revision cycle_member_id cycle_member_revision state leadership completed_assignment_ids cancelled_assignment_ids preserved_completed_assignment_ids',
    );
    for (final k in [
      'target_cycle_key',
      'room_cycle_id',
      'target_generation',
    ]) {
      roleCheck(v[k] == t[k]);
    }
    roleCheck(
      _revision(v['target_revision']) == t['target_revision'] + 1 &&
          v['cycle_member_id'] == t['target_cycle_member_id'] &&
          _revision(v['cycle_member_revision']) ==
              t['target_cycle_member_revision'] + 1 &&
          v['state'] == 'removed',
    );
    _lead(roleMap(v['leadership']));
    roleCheck(
      scheduleStable(v['leadership']) == scheduleStable(t['leadership']) &&
          _ids(v['completed_assignment_ids'], 1).isEmpty &&
          _sameIds(v['cancelled_assignment_ids'], e['cancel_assignment_ids']) &&
          _sameIds(
            v['preserved_completed_assignment_ids'],
            e['preserved_completed_assignment_ids'],
          ),
    );
  }
}

/// Immutable confirmation evidence; never uses an independently fetched plan
/// to supply the names or effects that the user approves.
class DeparturePreview {
  DeparturePreview(this.room, this.target, this.round, Map<String, dynamic> raw)
    : wire = _freeze(jsonDecode(jsonEncode(raw))) as Map<String, dynamic> {
    roleId(room);
    raidCycleKey(target);
    roleId(round);
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    data = roleMap(wire['data']);
    // Existing scope validation is UTC based. Normalize only this new DTO.
    final normalized = {
      ...scope,
      'server_now': actionTime(scope['server_now']).toIso8601String(),
      'playable_from': actionTime(scope['playable_from']).toIso8601String(),
    };
    CycleReadScope(normalized, target);
    roleId(scope['room_cycle_id']);
    _revision(scope['target_generation']);
    _revision(scope['target_revision']);
    roleShape(
      data,
      'action room_id subject leadership impact display permission confirmation',
    );
    roleCheck(
      data['action'] == 'personal_completion_departure' &&
          data['room_id'] == room,
    );
    subject = roleMap(data['subject']);
    roleShape(
      subject,
      'membership_id cycle_member_id cycle_member_revision character_id round_id assignment_id assignment_revision',
    );
    for (final k in [
      'membership_id',
      'cycle_member_id',
      'character_id',
      'round_id',
      'assignment_id',
    ]) {
      roleId(subject[k]);
    }
    for (final k in ['cycle_member_revision', 'assignment_revision']) {
      _revision(subject[k]);
    }
    roleCheck(subject['round_id'] == round);
    leadership = roleMap(data['leadership']);
    _lead(leadership);
    impact = roleMap(data['impact']);
    roleShape(
      impact,
      'complete_assignment_ids cancel_assignment_ids preserved_completed_assignment_ids released_reservation_count departure_effect successor preserves_other_cycles preserves_global_membership',
    );
    final complete = _ids(impact['complete_assignment_ids'], 1),
        cancel = _ids(impact['cancel_assignment_ids'], 4),
        preserved = _ids(impact['preserved_completed_assignment_ids'], 5);
    roleCheck(
      complete.length == 1 && complete.single == subject['assignment_id'],
    );
    final all = [...complete, ...cancel, ...preserved];
    roleCheck(all.toSet().length == all.length && all.length <= 5);
    raidNonnegative(impact['released_reservation_count']);
    roleCheck(
      impact['preserves_other_cycles'] == true &&
          impact['preserves_global_membership'] == true,
    );
    roleCheck(
      {
        'leave',
        'automatic_successor',
        'close_completed',
        'close_incomplete',
      }.contains(impact['departure_effect']),
    );
    final successor = impact['successor'];
    if (successor != null) {
      final v = roleMap(successor);
      roleShape(
        v,
        'cycle_member_id revision joined_order character_id character_name',
      );
      roleId(v['cycle_member_id']);
      roleId(v['character_id']);
      _revision(v['revision']);
      _name(v['character_name']);
      roleCheck(
        v['cycle_member_id'] != subject['cycle_member_id'] &&
            v['joined_order'] is String &&
            RegExp(r'^[1-9][0-9]*$').hasMatch(v['joined_order']),
      );
    }
    display = roleMap(data['display']);
    roleShape(
      display,
      'character_id character_name assignments display_revision',
    );
    roleCheck(display['character_id'] == subject['character_id']);
    _name(display['character_name']);
    roleCheck(
      display['display_revision'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(display['display_revision']),
    );
    final shown = raidList(display['assignments']);
    roleCheck(shown.length == all.length);
    final seen = <String>{};
    for (final raw in shown) {
      final v = roleMap(raw);
      roleShape(
        v,
        'assignment_id round_id item_id character_id character_name raid_id raid_name difficulty_id difficulty_name catalog_version effect',
      );
      for (final k in [
        'assignment_id',
        'round_id',
        'item_id',
        'character_id',
      ]) {
        roleId(v[k]);
      }
      for (final k in [
        'raid_id',
        'raid_name',
        'difficulty_id',
        'difficulty_name',
        'catalog_version',
      ]) {
        roleCheck(v[k] is String);
      }
      _name(v['character_name']);
      final id = v['assignment_id'] as String;
      roleCheck(
        seen.add(id) &&
            v['character_id'] == subject['character_id'] &&
            all.contains(id),
      );
      roleCheck(
        v['effect'] ==
            (complete.contains(id)
                ? 'complete'
                : cancel.contains(id)
                ? 'cancel'
                : 'preserve_completed'),
      );
      if (id == complete.single) roleCheck(v['round_id'] == round);
    }
    final permissionWire = roleMap(data['permission']);
    permission = CyclePermission.fromJson({
      ...permissionWire,
      if (permissionWire['next_change_at'] != null)
        'next_change_at': actionTime(
          permissionWire['next_change_at'],
        ).toIso8601String(),
    });
    roleCheck(
      permission.allowed
          ? permission.reason == null
          : permission.reason is String && permission.reason!.isNotEmpty,
    );
    confirmation = data['confirmation'] == null
        ? null
        : roleMap(data['confirmation']);
    roleCheck(permission.allowed == (confirmation != null));
    if (permission.allowed) {
      roleCheck(leadership['leader_cycle_member_id'] != null);
      roleCheck(
        (impact['departure_effect'] == 'leave')
            ? leadership['leader_cycle_member_id'] != subject['cycle_member_id']
            : leadership['leader_cycle_member_id'] ==
                  subject['cycle_member_id'],
      );

      roleCheck(
        permission.reason == null && target == scope['current_cycle_key'],
      );
      roleCheck(
        !actionTime(
          scope['server_now'],
        ).isBefore(actionTime(scope['playable_from'])),
      );
      roleCheck(
        actionTime(scope['playable_from']) ==
            DateTime.parse('${target}T01:00:00Z'),
      );
      roleCheck(
        (impact['departure_effect'] == 'automatic_successor') ==
            (successor != null),
      );
      final v = confirmation!;
      roleShape(v, 'context_token issued_at expires_at');
      roleCheck(
        v['context_token'] is String &&
            (v['context_token'] as String).isNotEmpty &&
            utf8.encode(v['context_token']).length <= 4096,
      );
      final now = actionTime(scope['server_now']),
          issued = actionTime(v['issued_at']),
          expires = actionTime(v['expires_at']);
      roleCheck(
        issued == now &&
            expires.isAfter(issued) &&
            expires.difference(issued) <= const Duration(seconds: 120),
      );
      final end = DateTime.parse(
        '${scope['current_cycle_key']}T00:00:00Z',
      ).add(const Duration(days: 7)).subtract(const Duration(hours: 3));
      roleCheck(!expires.isAfter(end));
    }
  }
  final String room, target, round;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope,
      data,
      subject,
      leadership,
      impact,
      display;
  late final Map<String, dynamic>? confirmation;
  late final CyclePermission permission;
  String get path => '/v2/raid-rooms/$room/personal-completion-departures';
  String get signature => scheduleStable({
    'scope': {
      for (final e in scope.entries)
        if (e.key != 'server_now') e.key: e.value,
    },
    'data': {
      for (final e in data.entries)
        if (e.key != 'confirmation') e.key: e.value,
    },
  });
  Map<String, dynamic> body() {
    if (!permission.allowed) {
      throw AccountReadException(permission.reason ?? 'PERMISSION_DENIED');
    }
    return {
      'expected_cycle_key': scope['current_cycle_key'],
      'target_cycle_key': target,
      'room_cycle_id': scope['room_cycle_id'],
      'target_generation': scope['target_generation'],
      'expected_target_revision': scope['target_revision'],
      'actor_cycle_member_id': subject['cycle_member_id'],
      'expected_cycle_member_revision': subject['cycle_member_revision'],
      'round_id': round,
      'context_token': confirmation!['context_token'],
    };
  }
}

/// Validate the original ACK against its frozen evidence, not today's cycle.
void validateDepartureResult(
  Map<String, dynamic> raw,
  DeparturePreview p,
  String key,
) {
  validateDepartureEvidenceResult(
    raw,
    DepartureAckEvidence.fromPreview(p),
    key,
  );
}

void validateDepartureEvidenceResult(
  Map<String, dynamic> raw,
  DepartureAckEvidence p,
  String key,
) {
  roleShape(raw, 'scope data');
  final scope = roleMap(raw['scope']), d = roleMap(raw['data']);
  CycleReadScope({
    ...scope,
    'server_now': actionTime(scope['server_now']).toIso8601String(),
    'playable_from': actionTime(scope['playable_from']).toIso8601String(),
  }, p.target);
  for (final k in [
    'current_cycle_key',
    'target_cycle_key',
    'playable_from',
    'phase',
    'policy_version',
    'room_cycle_id',
    'target_generation',
  ]) {
    roleCheck(
      k == 'playable_from'
          ? actionTime(scope[k]) == actionTime(p.scope[k])
          : scope[k] == p.scope[k],
    );
  }
  roleShape(
    d,
    'command_id action outcome executed_at room_id subject_membership_id affected_cycle_keys effects',
  );
  roleCheck(
    d['command_id'] == key &&
        d['action'] == 'personal_completion_departure' &&
        d['outcome'] == 'applied' &&
        d['room_id'] == p.room &&
        d['subject_membership_id'] == p.subject['membership_id'],
  );
  roleCheck(actionTime(d['executed_at']) == actionTime(scope['server_now']));
  final executed = actionTime(d['executed_at']);
  roleCheck(
    !executed.isBefore(actionTime(p.confirmation!['issued_at'])) &&
        executed.isBefore(actionTime(p.confirmation!['expires_at'])),
  );

  roleCheck(
    scheduleStable(d['affected_cycle_keys']) == scheduleStable([p.target]),
  );
  final effects = raidList(d['effects']);
  roleCheck(effects.length == 1);
  final v = roleMap(effects.single);
  roleShape(
    v,
    'target_cycle_key room_cycle_id target_generation target_revision cycle_member_id cycle_member_revision state leadership completed_assignment_ids cancelled_assignment_ids preserved_completed_assignment_ids',
  );
  for (final k in [
    'target_cycle_key',
    'room_cycle_id',
    'target_generation',
    'target_revision',
  ]) {
    roleCheck(v[k] == scope[k]);
  }
  roleCheck(
    _revision(v['target_revision']) == p.scope['target_revision'] + 1 &&
        v['cycle_member_id'] == p.subject['cycle_member_id'] &&
        _revision(v['cycle_member_revision']) ==
            p.subject['cycle_member_revision'] + 1 &&
        v['state'] == 'cancelled',
  );
  roleCheck(
    _sameIds(
          v['completed_assignment_ids'],
          p.impact['complete_assignment_ids'],
        ) &&
        _sameIds(
          v['cancelled_assignment_ids'],
          p.impact['cancel_assignment_ids'],
        ) &&
        _sameIds(
          v['preserved_completed_assignment_ids'],
          p.impact['preserved_completed_assignment_ids'],
        ),
  );
  final lead = roleMap(v['leadership']);
  _lead(lead);
  final effect = p.impact['departure_effect'];
  if (effect == 'leave') {
    roleCheck(scheduleStable(lead) == scheduleStable(p.leadership));
  } else {
    roleCheck(
      lead['leadership_revision'] == p.leadership['leadership_revision'] + 1,
    );
    roleCheck(
      lead['leader_cycle_member_id'] ==
          (effect == 'automatic_successor'
              ? roleMap(p.impact['successor'])['cycle_member_id']
              : null),
    );
    if (effect == 'automatic_successor') {
      roleCheck(
        lead['leader_membership_id'] != null &&
            lead['leader_membership_id'] != p.subject['membership_id'],
      );
    }
  }
}

class RemovalAckEvidence {
  RemovalAckEvidence(Map<String, dynamic> json)
    : wire = _freeze(json) as Map<String, dynamic> {
    roleShape(
      wire,
      'room target member membership scope source opposite option',
    );
    roleId(room);
    roleId(member);
    roleId(membership);
    raidCycleKey(target);
  }
  factory RemovalAckEvidence.fromPreview(RemovalPreview p, String mode) =>
      RemovalAckEvidence({
        'room': p.room,
        'target': p.target,
        'member': p.member,
        'membership': p.membership,
        'scope': p.scope,
        'source': _removalAckTarget(p.source),
        'opposite': p.opposite['target'] == null
            ? {}
            : {'target': _removalAckTarget(roleMap(p.opposite['target']))},
        'option': {
          'confirmation': {
            'issued_at': p.option(mode)['confirmation']['issued_at'],
            'expires_at': p.option(mode)['confirmation']['expires_at'],
          },
          'impact': {
            'affected_cycle_keys': p.option(
              mode,
            )['impact']['affected_cycle_keys'],
            'targets': [
              for (final t in raidList(p.option(mode)['impact']['targets']))
                {
                  for (final k in [
                    'cancel_assignment_ids',
                    'preserved_completed_assignment_ids',
                  ])
                    k: t[k],
                },
            ],
          },
        },
      });
  final Map<String, dynamic> wire;
  String get room => wire['room'] as String;
  String get target => wire['target'] as String;
  String get member => wire['member'] as String;
  String get membership => wire['membership'] as String;
  Map<String, dynamic> get scope => roleMap(wire['scope']);
  Map<String, dynamic> get source => roleMap(wire['source']);
  Map<String, dynamic> get opposite => roleMap(wire['opposite']);
  Map<String, dynamic> get option => roleMap(wire['option']);
}

class DepartureAckEvidence {
  DepartureAckEvidence(Map<String, dynamic> json)
    : wire = _freeze(json) as Map<String, dynamic> {
    roleShape(wire, 'room target scope subject confirmation impact leadership');
    roleId(room);
    raidCycleKey(target);
  }
  factory DepartureAckEvidence.fromPreview(DeparturePreview p) =>
      DepartureAckEvidence({
        'room': p.room,
        'target': p.target,
        'scope': p.scope,
        'subject': {
          for (final k in [
            'membership_id',
            'cycle_member_id',
            'cycle_member_revision',
          ])
            k: p.subject[k],
        },
        'confirmation': {
          'issued_at': p.confirmation!['issued_at'],
          'expires_at': p.confirmation!['expires_at'],
        },
        'impact': {
          for (final k in [
            'complete_assignment_ids',
            'cancel_assignment_ids',
            'preserved_completed_assignment_ids',
            'departure_effect',
          ])
            k: p.impact[k],
          'successor': p.impact['successor'] == null
              ? null
              : {'cycle_member_id': p.impact['successor']['cycle_member_id']},
        },
        'leadership': p.leadership,
      });
  final Map<String, dynamic> wire;
  String get room => wire['room'] as String;
  String get target => wire['target'] as String;
  Map<String, dynamic> get scope => roleMap(wire['scope']);
  Map<String, dynamic> get subject => roleMap(wire['subject']);
  Map<String, dynamic>? get confirmation => roleMap(wire['confirmation']);
  Map<String, dynamic> get impact => roleMap(wire['impact']);
  Map<String, dynamic> get leadership => roleMap(wire['leadership']);
}

Map<String, dynamic> _removalAckTarget(Map<String, dynamic> t) => {
  for (final k in [
    'target_cycle_key',
    'room_cycle_id',
    'target_generation',
    'target_revision',
    'target_cycle_member_id',
    'target_cycle_member_revision',
    'leadership',
  ])
    k: t[k],
};
