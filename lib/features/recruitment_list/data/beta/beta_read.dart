import 'coordination_wait.dart';
import '../../../account/domain/server_registration_api.dart';
import '../../../account/domain/role_summary.dart';
import 'beta_contract.dart';
import 'cycle_group_policy.dart';

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
    raw.remove('cycle_groups');
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
    if (result.metadata['group_policy'] != null)
      'group_policy': result.metadata['group_policy'],
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
        if (raw.containsKey('group_policy'))
          'group_policy': CycleGroupPolicy(roleMap(raw['group_policy'])).wire,
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
  final policy = data?['group_policy'];
  if (policy is Map && policy['state'] == 'unavailable') return '그룹 정보 확인 불가';
  if (policy is Map &&
      policy['state'] == 'known' &&
      policy['scope'] == 'public') {
    return null;
  }
  final group = data?['group_state'];
  if (group is! Map) return null;
  final name = group['name'] ?? '연결 그룹';
  return switch (group['state']) {
    'active' => '$name',
    'ended' => '$name · 해산된 그룹',
    _ => '$name · 그룹 상태 확인 불가',
  };
}

/// Page-scoped policies use room, actual cycle and generation together.
Map<String, dynamic> groupListStates(Map<String, dynamic> raw) {
  final states = <String, dynamic>{};
  roleCheck(raw['group_states'] is List && raw['cycle_groups'] is List);
  for (final value in raw['group_states'] as List) {
    final state = roleMap(value);
    BetaContract.definition('GroupLinkState', state);
    final id = roleId(state['group_id']);
    roleCheck(!states.containsKey(id));
    roleCheck(state['state'] != 'unavailable' || state['name'] == null);
    states[id] = state;
  }
  final policies = <String, dynamic>{};
  for (final value in raw['cycle_groups'] as List) {
    final policy = CycleGroupPolicy(roleMap(value));
    roleCheck(!policies.containsKey(policy.identity));
    roleCheck(policy.groupId == null || states.containsKey(policy.groupId));
    policies[policy.identity] = {
      'group_policy': policy.wire,
      'group_state': policy.groupId == null ? null : states[policy.groupId],
    };
  }
  final used = <String>{};
  for (final value in roleMap(raw['data'])['items'] as List) {
    final row = roleMap(value);
    final target = _policyTarget(row);
    final matches = policies.entries
        .where((e) => _matchesPolicy(roleMap(e.value)['group_policy'], target))
        .toList();
    roleCheck(matches.length == 1);
    used.add(matches.single.key);
    // Current card fields must agree, never overwrite historical admission_origin.
    final card = row.containsKey('group_id')
        ? row
        : row['room'] ?? (row['content'] as Map?)?['room'];
    if (card is Map &&
        roleMap(matches.single.value)['group_policy']['state'] == 'known') {
      roleCheck(
        card['group_id'] ==
            roleMap(matches.single.value)['group_policy']['group_id'],
      );
    }
  }
  roleCheck(used.length == policies.length);
  return betaFreeze(policies) as Map<String, dynamic>;
}

Map<String, dynamic> _policyTarget(Map<String, dynamic> row) {
  final t = row['target'] ?? row['room'] ?? row;
  return roleMap(t);
}

bool _matchesPolicy(Map<String, dynamic> policy, Map<String, dynamic> target) =>
    policy['room_id'] == target['room_id'] &&
    policy['target_cycle_key'] == target['target_cycle_key'] &&
    policy['room_cycle_id'] == target['room_cycle_id'] &&
    policy['generation'] == target['target_generation'];

Map<String, dynamic>? listDisplayData(
  Map<String, dynamic>? metadata,
  Map<String, dynamic> item,
  String room,
) {
  final directory = metadata?['room_group_states'];
  Map<String, dynamic>? policy;
  if (directory is Map) {
    final target = _policyTarget(item);
    roleCheck(target['room_id'] == room);
    final matches = directory.values
        .where((v) => _matchesPolicy(roleMap(v)['group_policy'], target))
        .toList();
    roleCheck(matches.length == 1);
    policy = roleMap(matches.single);
  }
  return betaDisplayData({...item, if (policy != null) ...policy});
}
