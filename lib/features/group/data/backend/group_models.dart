import 'dart:convert';

Map<String, dynamic> groupMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> groupItems(
  Map<String, dynamic> value, [
  String key = 'items',
]) => (value[key] as List).map(groupMap).toList(growable: false);
String groupName(Object? display) => display is Map
    ? (display['character_name'] as String? ?? '표시 정보 없음')
    : '표시 정보 없음';
bool groupAllowed(Map<String, dynamic>? permissions, String action) =>
    permissions?[action] is Map && permissions![action]['allowed'] == true;

/// Immutable validated server snapshot, without legacy Player identities.
class GroupDetailSnapshot {
  GroupDetailSnapshot(Map<String, dynamic> value) : raw = jsonEncode(value);
  final String raw;
  Map<String, dynamic> get wire => groupMap(jsonDecode(raw));
  Map<String, dynamic> get group => groupMap(wire['group']);
  Map<String, dynamic> get membership => groupMap(wire['my_membership']);
  String get id => group['group_id'] as String;
  String get name => group['name'] as String;
  bool get leader => membership['role'] == 'leader';
  Map<String, dynamic> get actorCas => {
    'expected_group_revision': group['revision'],
    'expected_members_revision': wire['members_revision'],
    'expected_membership_id': membership['membership_id'],
    'expected_membership_revision': membership['revision'],
  };
}

class GroupCharacterChoice {
  const GroupCharacterChoice(this.label, this.selection);
  final String label;
  final Map<String, dynamic> selection;
  String get id => selection['character_id'] as String;
}

String groupSpecText(Object? value) {
  if (value is! Map) return '스펙 정보 없음';
  final labels = <String>['Lv. ${value['item_level'] ?? '미확인'}'];
  for (final role in ['dealer', 'support']) {
    final data = value[role] as Map;
    final analysis = data['analysis'] as Map?;
    final issues = (analysis?['issues'] as List? ?? [])
        .where((v) => v['severity'] == 'error')
        .map((v) => v['code'])
        .toSet();
    final errors = <String>[];
    if (issues.any(
      {'GEM_SLOT_COUNT', 'FOREIGN_CLASS_GEM', 'UNMATCHED_SKILL_GEM'}.contains,
    )) {
      errors.add('보석 오류');
    }
    if (issues.any({'ARK_GRID_MINIMUM', 'ARK_GRID_CONDITION'}.contains)) {
      errors.add('아크그리드 오류');
    }
    final state = analysis?['integrity_status'];
    if (state == 'error' && errors.isEmpty) errors.add('분석 오류');
    if (state == 'review') errors.add('분석 확인 필요');
    if (data['combat_power'] == null && analysis == null) continue;
    labels.add(
      '${role == 'dealer' ? '딜러' : '서포터'} ${data['combat_power'] ?? '미확인'}${errors.isEmpty ? '' : ' · ${errors.join(' · ')}'}${data['combat_power'] != null && state != 'clean' ? ' (마지막 성공 수치)' : ''}',
    );
  }
  if (value['state'] == 'unavailable') labels.add('현재 스펙 확인 불가');
  return labels.join('\n');
}
