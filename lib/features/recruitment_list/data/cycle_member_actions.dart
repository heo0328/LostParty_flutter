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
