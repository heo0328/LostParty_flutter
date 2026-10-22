import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';

/// A read-only context projection. Preview refs never identify real sessions.
class CycleSessionDisplay {
  CycleSessionDisplay(Object? value) {
    final j = roleMap(value);
    roleShape(
      j,
      'kind selection_mode target_cycle_key room_cycle_id target_generation plan_revision display_revision sessions previews',
    );
    raidCycleKey(j['target_cycle_key']);
    roleId(j['room_cycle_id']);
    _version(j['target_generation']);
    _ref(j['display_revision']);
    final kind = j['kind'];
    roleCheck({'existing', 'opening_preview', 'none'}.contains(kind));
    roleCheck(
      j['selection_mode'] ==
          const {
            'existing': 'select_session_ids',
            'opening_preview': 'opening_implicit_enrolment',
            'none': 'no_session_selection',
          }[kind],
    );
    if (kind == 'opening_preview') {
      roleCheck(j['plan_revision'] == null);
    } else {
      _version(j['plan_revision']);
    }
    final actual = raidList(j['sessions']), groups = raidList(j['previews']);
    roleCheck(actual.length <= 64);
    roleCheck(kind == 'existing' ? groups.isEmpty : actual.isEmpty);
    if (kind == 'none') roleCheck(groups.isEmpty);
    String? previous;
    for (final raw in actual) {
      final s = roleMap(raw);
      roleShape(
        s,
        'session_id revision schedule_revision state required starts_at ends_at join_deadline permission',
      );
      final id = roleId(s['session_id']);
      roleCheck(
        id == id.toLowerCase() &&
            (previous == null || previous.compareTo(id) < 0),
      );
      previous = id;
      _version(s['revision']);
      _version(s['schedule_revision']);
      raidBool(s['required']);
      roleCheck({'confirmed', 'unconfirmed'}.contains(s['state']));
      final start = _time(s['starts_at']), end = _time(s['ends_at']);
      roleCheck((start == null) == (end == null));
      if (s['state'] == 'confirmed') roleCheck(start != null);
      if (start != null && end != null) roleCheck(start.isBefore(end));
      _time(s['join_deadline']);
      CyclePermission.fromJson(roleMap(s['permission']));
    }
    previous = null;
    for (final raw in groups) {
      final g = roleMap(raw);
      roleShape(
        g,
        'preview_group_ref source_group_revision planning_mode occurrence_mode day_scope required alternatives',
      );
      final ref = _ref(g['preview_group_ref']);
      roleCheck(previous == null || previous.compareTo(ref) < 0);
      previous = ref;
      _version(g['source_group_revision']);
      raidBool(g['required']);
      roleCheck(
        {'manual', 'coordinated', 'unscheduled'}.contains(g['planning_mode']),
      );
      roleCheck({'one_of', 'each'}.contains(g['occurrence_mode']));
      roleCheck(
        {'selected_weekdays', 'any_current_cycle'}.contains(g['day_scope']),
      );
      final alternatives = raidList(g['alternatives']);
      String? last;
      for (final raw in alternatives) {
        final a = roleMap(raw);
        roleShape(
          a,
          'preview_ref session_id state weekday starts_at ends_at time_state materialization',
        );
        final ref = _ref(a['preview_ref']);
        roleCheck(last == null || last.compareTo(ref) < 0);
        last = ref;
        roleCheck(a['session_id'] == null && a['state'] == 'preview');
        roleCheck(
          a['weekday'] is int &&
              (a['weekday'] as int) >= 1 &&
              (a['weekday'] as int) <= 7,
        );
        final start = _time(a['starts_at']), end = _time(a['ends_at']);
        switch (a['time_state']) {
          case 'bounded':
            roleCheck(start != null && end != null && start.isBefore(end));
          case 'start_only':
            roleCheck(start != null && end == null);
          case 'undetermined':
            roleCheck(start == null && end == null);
          default:
            roleCheck(false);
        }
        final manual = g['planning_mode'] == 'manual';
        final materialization = manual
            ? (g['occurrence_mode'] == 'each' || alternatives.length == 1
                  ? 'on_open'
                  : 'after_group_selection')
            : (g['planning_mode'] == 'coordinated'
                  ? 'after_coordination'
                  : 'not_scheduled');
        roleCheck(a['materialization'] == materialization);
        if (!manual) roleCheck(a['time_state'] == 'undetermined');
      }
    }
    wire = _freeze(j) as Map<String, dynamic>;
    sessions = List.unmodifiable(raidList(wire['sessions']).map(roleMap));
    previews = List.unmodifiable(raidList(wire['previews']).map(roleMap));
  }

  late final Map<String, dynamic> wire;
  late final List<Map<String, dynamic>> sessions, previews;
  String get kind => wire['kind'] as String;
  bool get selectable => kind == 'existing';

  void bind(
    Map<String, dynamic> scope, {
    required String kind,
    Object? cycleId,
    Object? generation,
    Object? planRevision,
  }) {
    roleCheck(
      this.kind == kind &&
          wire['target_cycle_key'] == scope['target_cycle_key'],
    );
    roleCheck(wire['room_cycle_id'] == (cycleId ?? scope['room_cycle_id']));
    roleCheck(
      wire['target_generation'] == (generation ?? scope['target_generation']),
    );
    if (planRevision != null) roleCheck(wire['plan_revision'] == planRevision);
  }

  void matchChoices(List<Map<String, dynamic>> choices) {
    roleCheck(choices.length == sessions.length);
    final byId = {for (final s in sessions) s['session_id']: s};
    for (final c in choices) {
      final s = byId[c['session_id']];
      roleCheck(s != null);
      for (final k in ['required', 'join_deadline']) {
        roleCheck(s![k] == c[k]);
      }
      final a = roleMap(s!['permission']), b = roleMap(c['permission']);
      roleCheck(a.length == b.length && a.keys.every((k) => a[k] == b[k]));
    }
  }

  bool selectionReady(Set<String> chosen) =>
      selectable &&
      sessions
          .where((s) => s['required'] == true)
          .every((s) => chosen.contains(s['session_id'])) &&
      sessions
          .where((s) => chosen.contains(s['session_id']))
          .every((s) => roleMap(s['permission'])['allowed'] == true);

  List<String> selectedIds(Set<String> chosen, DateTime now) {
    roleCheck(selectable);
    final allowed = sessions
        .where((s) => roleMap(s['permission'])['allowed'] == true)
        .map((s) => s['session_id'])
        .toSet();
    roleCheck(allowed.containsAll(chosen));
    if (!selectionReady(chosen)) {
      throw const AccountReadException('SESSION_SELECTION_REQUIRED');
    }
    for (final s in sessions.where((s) => chosen.contains(s['session_id']))) {
      final deadline = _time(s['join_deadline']);
      if (deadline != null && !deadline.isAfter(now)) {
        throw const AccountReadException('RECRUITMENT_CLOSED');
      }
    }
    return chosen.toList()..sort();
  }
}

Object? _freeze(Object? v) {
  if (v is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      v.map((k, v) => MapEntry(k, _freeze(v))),
    );
  }
  if (v is List) return List<Object?>.unmodifiable(v.map(_freeze));
  return v;
}

void _version(Object? v) => roleCheck(rolePositive(v) <= 2147483647);
String _ref(Object? v) {
  roleCheck(v is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(v));
  return v as String;
}

DateTime? _time(Object? v) => v == null ? null : roleUtc(v);
