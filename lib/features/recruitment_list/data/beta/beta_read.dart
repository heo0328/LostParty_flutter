import 'coordination_wait.dart';
import '../../../account/domain/server_registration_api.dart';
import '../../../account/domain/role_summary.dart';
import 'beta_contract.dart';

class BetaDecoded<T> {
  const BetaDecoded(this.value, this.metadata);
  final T value;
  final Map<String, dynamic>? metadata;
}

Future<BetaDecoded<T>> readRecruitment<T>({
  required BackendRegistrationApi api,
  required RecruitmentContractMode mode,
  required String path,
  required T Function(Map<String, dynamic>) parse,
  Map<String, dynamic> query = const {},
  bool includeGroupState = false,
  bool includeGroupList = false,
  String method = 'GET',
  Map<String, dynamic>? body,
}) async {
  final contract = BetaContract(mode: mode);
  final q = contract.query(method, path, {
    ...query,
    if (includeGroupList) 'include_group_state': 'true',
  });
  if (mode == RecruitmentContractMode.betaWire2) {
    contract.validateRequest(method, path, q, body);
  }
  final received = (await api.request(
    path,
    method: method,
    query: includeGroupState
        ? {...q, 'include_group_state': 'true'}
        : q.isEmpty
        ? null
        : q,
    body: body,
  ))!;
  final raw = Map<String, dynamic>.of(received);
  Map<String, dynamic>? groupState;
  if (includeGroupState) {
    roleCheck(
      method == 'GET' &&
          (RegExp(r'^/v2/raid-rooms/[^/]+/detail$').hasMatch(path) ||
              RegExp(r'^/v2/me/raid-rooms/[^/]+/plan$').hasMatch(path)),
    );
    roleCheck(raw.containsKey('group_state'));
    if (raw['group_state'] != null) {
      groupState = roleMap(raw['group_state']);
      roleShape(groupState, 'group_id name state');
      roleId(groupState['group_id']);
      roleCheck(groupState['name'] == null || groupState['name'] is String);
      roleCheck(
        {'active', 'ended', 'unavailable'}.contains(groupState['state']),
      );
    }
    raw.remove('group_state');
  }
  if (includeGroupList && mode == RecruitmentContractMode.betaWire2) {
    contract.validateResponse(method, path, 200, raw);
  }
  final roomGroups = includeGroupList ? groupListStates(raw) : null;
  if (includeGroupList) {
    raw.remove('group_states');
    raw.remove('room_groups');
  }
  if (mode == RecruitmentContractMode.legacy) {
    return BetaDecoded(
      parse(raw),
      !includeGroupState && !includeGroupList
          ? null
          : {
              if (includeGroupList) ...roleMap(raw['data']),
              if (includeGroupState) 'group_state': groupState,
              if (includeGroupList) 'room_group_states': roomGroups,
            },
    );
  }
  final result = BetaResponse.parse(
    method: method,
    path: path,
    status: 200,
    json: raw,
    parseLegacy: parse,
  );
  return BetaDecoded(result.value, {
    ...roleMap(result.metadata['data']),
    if (includeGroupState) 'group_state': groupState,
    if (includeGroupList) 'room_group_states': roomGroups,
  });
}

Map<String, dynamic>? betaDisplayData(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final schedule = raw['beta_schedule'];
  final wait = schedule is Map ? schedule['coordination_wait'] : null;
  if (wait != null) CoordinationWait.fromJson(roleMap(wait));
  return betaFreeze({
        'beta_schedule': schedule is Map
            ? {
                for (final e in schedule.entries)
                  if (e.key != 'coordination_wait') e.key as String: e.value,
              }
            : schedule,
        'coordination_wait': ?wait,
        if (raw.containsKey('group_state')) 'group_state': raw['group_state'],
        if (raw.containsKey('recruitment_identity'))
          'recruitment_identity': raw['recruitment_identity'],
      })
      as Map<String, dynamic>;
}

String? coordinationWaitMessage(Map<String, dynamic>? data) {
  final wait = data?['coordination_wait'];
  return wait == null ? null : CoordinationWait.fromJson(roleMap(wait)).message;
}

String betaScheduleLabel(Map<String, dynamic> data) {
  final s = data['beta_schedule'];
  if (s == null) return '일정 정보 없음';
  return switch (s['coordination_state']) {
    'base_committed' => '직접 지정',
    'coordinating' => '더 이른 시간 조율 중',
    'early_confirmed' => '자동 조율로 확정',
    'base_confirmed' => '기본 시간으로 확정',
    'proposal_confirmed' => '제안 시간으로 확정',
    'deadline_pending' => '출발 시간 확인 중',
    'needs_review' => '일정 확인 필요',
    'ended' => '종료',
    _ => throw const FormatException('Invalid schedule state'),
  };
}

DateTime? betaEffectiveStart(Map<String, dynamic>? data) =>
    data?['beta_schedule'] == null
    ? null
    : roleUtc(data!['beta_schedule']['effective_starts_at']);

String betaDepartureText(Map<String, dynamic> data) {
  final instant = betaEffectiveStart(data);
  final label = betaScheduleLabel(data);
  return instant == null
      ? label
      : '${instant.add(const Duration(hours: 9)).toIso8601String().substring(5, 16).replaceAll('T', ' ')} · $label';
}

String? retainedGroupLabel(Map<String, dynamic>? data) {
  final group = data?['group_state'];
  if (group is! Map) return null;
  final name = group['name'] ?? '연결 그룹';
  return switch (group['state']) {
    'active' => '$name',
    'ended' => '$name · 해산된 그룹',
    _ => '$name · 그룹 상태 확인 불가',
  };
}

/// Page-scoped directory. Admission-origin group IDs are historical and never
/// substitute for the current room connection supplied by room_groups.
Map<String, dynamic> groupListStates(Map<String, dynamic> raw) {
  final states = <String, dynamic>{};
  roleCheck(raw['group_states'] is List && raw['room_groups'] is List);
  for (final value in raw['group_states'] as List) {
    final state = roleMap(value);
    BetaContract.definition('GroupLinkState', state);
    final id = roleId(state['group_id']);
    roleCheck(!states.containsKey(id));
    roleCheck(state['state'] != 'unavailable' || state['name'] == null);
    states[id] = state;
  }
  final rooms = <String, dynamic>{};
  final used = <String>{};
  for (final value in raw['room_groups'] as List) {
    final link = roleMap(value);
    BetaContract.definition('RoomGroupLink', link);
    final room = roleId(link['room_id']);
    roleCheck(!rooms.containsKey(room));
    final group = link['group_id'];
    roleCheck(group == null || states.containsKey(group));
    if (group != null) used.add(group as String);
    rooms[room] = group == null ? null : states[group];
  }
  final page = <String>{};
  for (final value in roleMap(raw['data'])['items'] as List) {
    final row = roleMap(value);
    final room = row['room_id'] ?? roleMap(row['target'])['room_id'];
    page.add(roleId(room));
    // Only actual card payloads carry the current link. Applications retain origin.
    final card = row.containsKey('group_id')
        ? row
        : row['room'] ?? (row['content'] as Map?)?['room'];
    if (card is Map) {
      roleCheck(rooms.containsKey(room));
      roleCheck(card['group_id'] == (rooms[room] as Map?)?['group_id']);
    }
  }
  roleCheck(page.length == rooms.length && page.containsAll(rooms.keys));
  roleCheck(used.length == states.length);
  return betaFreeze(rooms) as Map<String, dynamic>;
}

Map<String, dynamic>? listDisplayData(
  Map<String, dynamic>? metadata,
  Map<String, dynamic> item,
  String room,
) => betaDisplayData({
  ...item,
  if (metadata?.containsKey('room_group_states') == true)
    'group_state': (metadata!['room_group_states'] as Map)[room],
});
