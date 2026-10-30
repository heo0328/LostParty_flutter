import '../../../account/domain/member_raid_models.dart';
import '../../../account/domain/role_summary.dart';
import 'beta_contract.dart';

/// Current policy identity includes the actual target and generation, never room alone.
class CycleGroupPolicy {
  CycleGroupPolicy(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Metadata', wire);
    roleId(wire['room_id']);
    raidCycleKey(wire['target_cycle_key']);
    roleId(wire['room_cycle_id']);
    if (wire['generation'] != null) rolePositive(wire['generation']);
    if (known) {
      rolePositive(wire['generation']);
      rolePositive(wire['revision']);
      roleCheck({'public', 'group'}.contains(wire['scope']));
      roleCheck((wire['scope'] == 'group') == (wire['group_id'] != null));
      if (wire['group_id'] != null) roleId(wire['group_id']);
    } else {
      roleCheck(
        wire['scope'] == null &&
            wire['group_id'] == null &&
            wire['revision'] == null,
      );
    }
  }
  final Map<String, dynamic> wire;
  bool get known => wire['state'] == 'known';
  String? get groupId => wire['group_id'] as String?;
  String get identity =>
      '${wire['room_id']}/${wire['target_cycle_key']}/${wire['room_cycle_id']}/${wire['generation']}';
  void bind(String room, String target, [Map<String, dynamic>? scope]) {
    roleCheck(wire['room_id'] == room && wire['target_cycle_key'] == target);
    if (scope?['room_cycle_id'] != null) {
      roleCheck(wire['room_cycle_id'] == scope!['room_cycle_id']);
    }
    if (scope?['target_generation'] != null) {
      roleCheck(wire['generation'] == scope!['target_generation']);
    }
  }
}

class CycleGroupEffect {
  CycleGroupEffect(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('Effect', wire);
    roleId(wire['room_id']);
    raidCycleKey(wire['target_cycle_key']);
    roleId(wire['room_cycle_id']);
    rolePositive(wire['generation']);
    for (final key in ['before', 'after']) {
      final state = roleMap(wire[key]);
      roleCheck((state['scope'] == 'group') == (state['group_id'] != null));
      if (state['group_id'] != null) roleId(state['group_id']);
      if (state['revision'] != null) rolePositive(state['revision']);
    }
  }
  final Map<String, dynamic> wire;
  Map<String, dynamic> get before => roleMap(wire['before']);
  Map<String, dynamic> get after => roleMap(wire['after']);
  String get description => after['scope'] == 'public'
      ? (before['scope'] == 'group'
            ? '전체 공개로 변경 · 그룹 연결 해제'
            : '전체 공개 · 그룹 연결 없음')
      : (before['group_id'] == after['group_id']
            ? '기존 그룹 전용 유지'
            : '선택 그룹 전용으로 변경');
  void validateAck(Map<String, dynamic> actual) {
    final ack = CycleGroupEffect(actual);
    for (final k in [
      'room_id',
      'target_cycle_key',
      'room_cycle_id',
      'generation',
    ]) {
      roleCheck(ack.wire[k] == wire[k]);
    }
    for (final k in ['scope', 'group_id']) {
      roleCheck(ack.before[k] == before[k] && ack.after[k] == after[k]);
    }
    if (before['revision'] != null) {
      roleCheck(ack.before['revision'] == before['revision']);
    }
    rolePositive(ack.after['revision']);
    if (after['revision'] != null) {
      roleCheck(ack.after['revision'] == after['revision']);
    }
  }
}

/// Retain effects separately from the existing strict semantic parsers.
List<Map<String, dynamic>> cycleGroupEffects(Object? value) {
  final result = <Map<String, dynamic>>[];
  void visit(Object? v) {
    if (v is List) {
      for (final x in v) {
        visit(x);
      }
    }
    if (v is Map) {
      if (v.containsKey('before') &&
          v.containsKey('after') &&
          v.containsKey('room_cycle_id')) {
        result.add(CycleGroupEffect(roleMap(v)).wire);
      } else {
        for (final x in v.values) {
          visit(x);
        }
      }
    }
  }

  visit(value);
  return List.unmodifiable(result);
}

Map<String, dynamic> withoutCycleGroupFields(Map<String, dynamic> raw) {
  Object? strip(Object? v) => v is Map
      ? {
          for (final e in v.entries)
            if (!{
              'group_policy_version',
              'group_policy',
              'group_policy_effect',
              'group_policy_effects',
              'cycle_groups',
            }.contains(e.key))
              e.key as String: strip(e.value),
        }
      : v is List
      ? v.map(strip).toList()
      : v;
  return strip(raw) as Map<String, dynamic>;
}
