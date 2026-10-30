import 'dart:convert';
import 'beta/beta_interaction_api.dart';
import 'beta/beta_contract.dart';
import 'beta/cycle_group_policy.dart';
import '../domain/policies/recruitment_start_policy.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import '../domain/backend_recruitment.dart';
import 'cycle_read_repository.dart';
import 'cycle_session_display.dart';

const cycleManagementLabels = {
  'continue': '다음 주 참가',
  'decline': '참가하지 않기',
  'open': '다음 주도 함께하기',
  'reopen': '선택 주차 모집 재개',
  'cancel': '선택 주차 탈퇴',
  'transfer': '공대장 위임',
  'settings': '모집 조건 변경',
  'formation': '파티 편성',
  'remove': '참가자 내보내기',
  'common': '공통 정보 변경',
  'leave': '전체 주차 탈퇴',
  'end': '모집 전체 종료',
};

String _stable(Object? v) {
  Object? sort(Object? x) {
    if (x is Map) {
      final keys = x.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sort(x[k])};
    }
    if (x is List) return x.map(sort).toList();
    return x;
  }

  return jsonEncode(sort(v));
}

void _permission(Object? v) {
  final p = CyclePermission.fromJson(roleMap(v));
  if (!p.allowed) throw AccountReadException(p.reason ?? 'PERMISSION_DENIED');
}

void _leadership(Object? value) {
  final j = roleMap(value);
  roleShape(
    j,
    'leader_cycle_member_id leadership_revision leader_membership_id',
  );
  rolePositive(j['leadership_revision']);
  for (final k in ['leader_cycle_member_id', 'leader_membership_id']) {
    if (j[k] != null) roleId(j[k]);
  }
}

void _candidate(Object? value) {
  final j = roleMap(value);
  roleShape(
    j,
    'cycle_member_id revision joined_order character_id character_name permission',
  );
  roleId(j['cycle_member_id']);
  roleId(j['character_id']);
  rolePositive(j['revision']);
  final order = j['joined_order'];
  roleCheck(
    order is String &&
        RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(order) &&
        BigInt.parse(order) <= BigInt.parse('9223372036854775807'),
  );
  roleCheck(j['character_name'] == null || j['character_name'] is String);
  CyclePermission.fromJson(roleMap(j['permission']));
}

class CycleManagementPreview {
  CycleManagementPreview(
    this.room,
    this.target,
    this.action,
    Map<String, dynamic> raw, {
    Map<String, dynamic> query = const {},
    this.betaData,
    Map<String, dynamic>? targetGroup,
  }) : wire = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
       query = Map.unmodifiable(query),
       targetGroup = targetGroup == null
           ? null
           : betaFreeze(targetGroup) as Map<String, dynamic> {
    roleId(room);
    raidCycleKey(target);
    roleCheck(cycleManagementLabels.containsKey(action));
    roleShape(wire, 'scope data');
    roleCheck(
      action != 'common' ||
          (query['target_group_id'] != null) == (this.targetGroup != null),
    );
    if (this.targetGroup != null) {
      BetaContract.definition('TargetGroup', this.targetGroup);
      roleCheck(
        action == 'common' &&
            query['target_group_id'] == this.targetGroup!['group_id'],
      );
    }
    scope = roleMap(wire['scope']);
    data = roleMap(wire['data']);
    roleCheck(
      roleId(
            {'formation', 'remove'}.contains(action)
                ? roleMap(data['room'])['room_id']
                : data['room_id'],
          ) ==
          room,
    );
    if (global) {
      roleShape(scope, 'server_now current_cycle_key policy_version');
      roleUtc(scope['server_now']);
      raidCycleKey(scope['current_cycle_key']);
      roleCheck(scope['policy_version'] == twoCyclePolicy);
      roleShape(
        data,
        'room_id command room_revision persistent_membership_revision context_token issued_at expires_at impact_cycles permission expected_cycle_key authorization_cycle_key current_settings',
      );
      roleCheck(
        data['command'] ==
                (action == 'common' ? 'edit_common_settings' : action) &&
            data['expected_cycle_key'] == scope['current_cycle_key'],
      );
      rolePositive(data['room_revision']);
      rolePositive(data['persistent_membership_revision']);
      final current = DateTime.parse('${scope['current_cycle_key']}T00:00:00Z');
      final allowed = [
        scope['current_cycle_key'],
        current.add(const Duration(days: 7)).toIso8601String().substring(0, 10),
      ];
      final impacts = raidList(data['impact_cycles']);
      roleCheck(impacts.length <= 2);
      affected = impacts.map((v) {
        final i = roleMap(v);
        roleShape(
          i,
          'target_cycle_key room_cycle_id generation target_revision leadership member_count assignment_count reservation_count members_revision plan_revision actor_cycle_member_id actor_cycle_member_revision',
        );
        final t = raidCycleKey(i['target_cycle_key']);
        roleCheck(allowed.contains(t));
        roleId(i['room_cycle_id']);
        _leadership(i['leadership']);
        for (final k in [
          'generation',
          'target_revision',
          'members_revision',
          'plan_revision',
        ]) {
          rolePositive(i[k]);
        }
        for (final k in [
          'member_count',
          'assignment_count',
          'reservation_count',
        ]) {
          roleCheck(i[k] is int && i[k] >= 0);
        }
        if (i['actor_cycle_member_id'] != null) {
          roleId(i['actor_cycle_member_id']);
          rolePositive(i['actor_cycle_member_revision']);
        }
        return t;
      }).toList();
      roleCheck(affected.toSet().length == affected.length);
      final settings = roleMap(data['current_settings']);
      roleShape(
        settings,
        usesCycleGroupPolicy ? 'title' : 'title scope group_id group_revision',
      );
      roleCheck(this.targetGroup == null || settings['group_id'] == null);
      raidText(settings['title']);
      if (!usesCycleGroupPolicy) {
        roleCheck({'public', 'group'}.contains(settings['scope']));
      }
      if (settings['group_id'] != null) {
        roleId(settings['group_id']);
        rolePositive(settings['group_revision']);
      }
      if (data['authorization_cycle_key'] != null) {
        roleCheck(allowed.contains(data['authorization_cycle_key']));
      }
    } else {
      CycleReadScope(scope, target);
      affected = [target];
      if (!{'open', 'reopen'}.contains(action)) {
        roleId(scope['room_cycle_id']);
        rolePositive(scope['target_generation']);
        rolePositive(scope['target_revision']);
      }
      if (continuation || opening) {
        roleShape(
          data,
          opening
              ? 'room_id source selection targets target_session_ids leadership context_token issued_at expires_at opening_effect permission conflicts prospective_room_cycle_id prospective_generation prospective_target_revision item_settings session_display'
              : 'room_id action source selection targets target_session_ids context_token issued_at expires_at permission conflicts session_display',
        );
        roleCheck(scope['phase'] == 'future');
        final src = roleMap(data['source']);
        roleShape(
          src,
          'source_cycle_key membership_id membership_revision assignment_ids source_cycle_member_id source_cycle_member_revision',
        );
        roleCheck(src['source_cycle_key'] == scope['current_cycle_key']);
        roleId(src['membership_id']);
        roleId(src['source_cycle_member_id']);
        rolePositive(src['membership_revision']);
        rolePositive(src['source_cycle_member_revision']);
        final ids = raidList(src['assignment_ids']);
        roleCheck(
          ids.isNotEmpty && ids.length <= 5 && ids.toSet().length == ids.length,
        );
        for (final id in ids) {
          roleId(id);
        }
        if (continuation) {
          roleCheck(
            data['action'] == (action == 'decline' ? 'decline' : 'join'),
          );
        }
        if (opening) {
          roleId(data['prospective_room_cycle_id']);
          rolePositive(data['prospective_generation']);
          rolePositive(data['prospective_target_revision']);
          roleCheck(
            {
              'create_and_join',
              'reopen_and_join',
              'already_open',
            }.contains(data['opening_effect']),
          );
          if (data['leadership'] != null) _leadership(data['leadership']);
          final items = raidList(data['item_settings']);
          roleCheck(items.isNotEmpty && items.length <= 5);
          for (final raw in items) {
            final item = roleMap(raw);
            roleShape(
              item,
              'item_id difficulty_id catalog_version duration_minutes',
            );
            roleId(item['item_id']);
            raidText(item['difficulty_id']);
            raidText(item['catalog_version']);
            final duration = item['duration_minutes'];
            roleCheck(
              duration == null ||
                  (duration is int &&
                      duration >= 10 &&
                      duration <= 1440 &&
                      duration % 5 == 0),
            );
          }
        }
        if (data['selection'] != null) {
          final s = roleMap(data['selection']);
          roleShape(
            s,
            'registration_id character_id selected_role expected_registration_version expected_ownership_revision expected_roster_revision expected_lifecycle_revision expected_role_summary_version expected_limits_revision expected_usage_revision',
          );
          roleId(s['registration_id']);
          roleId(s['character_id']);
          roleCheck({'dealer', 'support'}.contains(s['selected_role']));
          for (final k in s.keys.where((k) => k.startsWith('expected_'))) {
            rolePositive(s[k]);
          }
          if (query['character_id'] != null) {
            roleCheck(
              query['character_id'] == s['character_id'] &&
                  query['selected_role'] == s['selected_role'],
            );
          }
        }
        final targets = raidList(data['targets']);
        roleCheck(targets.length <= 5);
        for (final v in targets) {
          final t = roleMap(v);
          roleShape(
            t,
            'item_id round_id party_no expected_round_revision expected_weekly_revision',
          );
          roleId(t['item_id']);
          roleId(t['round_id']);
          roleCheck(t['party_no'] == 1 || t['party_no'] == 2);
          rolePositive(t['expected_round_revision']);
          rolePositive(t['expected_weekly_revision']);
        }
        final sessions = raidList(data['target_session_ids']);
        roleCheck(sessions.toSet().length == sessions.length);
        for (final id in sessions) {
          roleId(id);
        }
        roleCheck(sessions.isEmpty);
        display = CycleSessionDisplay(data['session_display']);
        final preview = opening && data['opening_effect'] != 'already_open';
        display!.bind(
          scope,
          kind: preview
              ? 'opening_preview'
              : action == 'continue'
              ? 'existing'
              : 'none',
          cycleId: preview ? data['prospective_room_cycle_id'] : null,
          generation: preview ? data['prospective_generation'] : null,
        );
        final conflicts = raidList(data['conflicts']);
        roleCheck(conflicts.length <= 5);
        for (final v in conflicts) {
          final c = roleMap(v);
          roleShape(
            c,
            'room_id target_cycle_key raid_id character_id can_view_detail room_title',
          );
          roleCheck(c['target_cycle_key'] == target);
          roleId(c['character_id']);
          raidText(c['raid_id']);
          raidBool(c['can_view_detail']);
          if (c['room_id'] != null) roleId(c['room_id']);
          roleCheck(c['room_title'] == null || c['room_title'] is String);
          roleCheck(c['can_view_detail'] != true || c['room_id'] != null);
        }
      } else if (action == 'cancel') {
        roleShape(
          data,
          'room_id context_token issued_at expires_at impact permission leadership members_revision mode successor',
        );
        final i = roleMap(data['impact']);
        roleShape(
          i,
          'effect_scope assignment_count reservation_count preserves_other_cycles preserves_global_membership',
        );
        roleCheck(
          i['effect_scope'] == 'target_bundle' &&
              i['preserves_other_cycles'] == true &&
              i['preserves_global_membership'] == true,
        );
        roleCheck(
          i['assignment_count'] is int &&
              i['assignment_count'] >= 0 &&
              i['assignment_count'] <= 5 &&
              i['reservation_count'] is int &&
              i['reservation_count'] >= 0,
        );
        roleCheck(
          {'leave', 'auto_successor', 'close_target'}.contains(data['mode']),
        );
        rolePositive(data['members_revision']);
        _leadership(data['leadership']);
        if (data['successor'] != null) _candidate(data['successor']);
        roleCheck(
          (data['mode'] == 'auto_successor') == (data['successor'] != null),
        );
      } else if (action == 'transfer') {
        roleShape(
          data,
          'room_id leadership members_revision candidates context_token issued_at expires_at permission preserves_other_cycles changes_formation',
        );
        _leadership(data['leadership']);
        rolePositive(data['members_revision']);
        roleCheck(
          data['preserves_other_cycles'] == true &&
              data['changes_formation'] == false,
        );
        final cs = raidList(data['candidates']);
        roleCheck(cs.length <= 8);
        for (final c in cs) {
          _candidate(c);
        }
        roleCheck(
          cs.map((c) => roleMap(c)['cycle_member_id']).toSet().length ==
              cs.length,
        );
      } else if (action == 'settings') {
        roleShape(
          data,
          'room_id revision room_revision experience_level combat_requirement continuation scope group_id admission_mode permissions leadership my_target_role',
        );
        rolePositive(data['revision']);
        rolePositive(data['room_revision']);
        _leadership(data['leadership']);
        roleCheck(data['my_target_role'] == 'leader');
      } else {
        // Explicit management uses the same scoped detail, never a private-plan preload.
        roleShape(
          data,
          'room settings members_revision members my_membership plan_revision permissions access leadership my_target_role formation_slots formation_history unplaced_assignments',
        );
        final card = CycleRoomCard(roleMap(data['room']), target);
        roleCheck(
          card.id == room &&
              card.wire['target_revision'] == scope['target_revision'] &&
              card.wire['room_cycle_id'] == scope['room_cycle_id'] &&
              card.wire['target_generation'] == scope['target_generation'],
        );
        roleCheck(data['my_target_role'] == 'leader');
        rolePositive(data['members_revision']);
        rolePositive(data['plan_revision']);
        _leadership(data['leadership']);
        _permission(roleMap(data['permissions'])['view_detail']);
        for (final raw in raidList(data['members'])) {
          final m = roleMap(raw);
          roleShape(
            m,
            'membership_id revision group_member joined_at character assignments comparison build is_me status status_reason target_role cycle_member_id cycle_member_revision joined_order target_state',
          );
          roleId(m['membership_id']);
          rolePositive(m['revision']);
          raidBool(m['is_me']);
          if (m['cycle_member_id'] != null) {
            roleId(m['cycle_member_id']);
            rolePositive(m['cycle_member_revision']);
          }
        }
      }
    }
    if (contextual) {
      final token = raidText(data['context_token']);
      roleCheck(token.length <= 4096);
      final issued = roleUtc(data['issued_at']),
          expires = roleUtc(data['expires_at']),
          now = roleUtc(scope['server_now']);
      roleCheck(!issued.isAfter(now) && expires.isAfter(issued));
      if (!expires.isAfter(now)) {
        throw const AccountReadException('SELECTION_CONTEXT_CHANGED');
      }
      CyclePermission.fromJson(roleMap(data['permission']));
    }
  }
  final Map<String, dynamic>? betaData, targetGroup;
  final String room, target, action;
  final Map<String, dynamic> wire, query;
  late final Map<String, dynamic> scope, data;
  CycleSessionDisplay? display;
  late final List<String> affected;
  String? removalCandidate(String membership, String cycleMember) {
    if (action != 'remove') return null;
    final matches = raidList(data['members'])
        .map(roleMap)
        .where(
          (m) =>
              m['membership_id'] == membership &&
              m['cycle_member_id'] == cycleMember &&
              m['is_me'] == false &&
              m['target_role'] == 'member' &&
              {'participating', 'review_required'}.contains(m['target_state']),
        );
    return matches.length == 1 ? cycleMember : null;
  }

  bool get usesCycleGroupPolicy => betaData?['policy_source'] != null;
  bool get global => {'common', 'leave', 'end'}.contains(action);
  bool get continuation => {'continue', 'decline'}.contains(action);
  bool get opening => {'open', 'reopen'}.contains(action);
  bool get contextual =>
      global ||
      continuation ||
      opening ||
      {'cancel', 'transfer'}.contains(action);
  String get method =>
      {'settings', 'formation', 'common'}.contains(action) ? 'PUT' : 'POST';
  String get path =>
      '/v2/raid-rooms/$room/${const {'continue': 'continuation-participations', 'decline': 'continuation-declines', 'open': 'recruitment-openings', 'reopen': 'recruitment-openings', 'cancel': 'participation-cancellations', 'transfer': 'leadership-transfers', 'settings': 'settings', 'formation': 'formation', 'remove': 'removals', 'common': 'common-settings', 'leave': 'leave', 'end': 'end'}[action]}';
  Map<String, dynamic> get evidence => opening
      ? {
          ...scope,
          'room_cycle_id': data['prospective_room_cycle_id'],
          'target_generation': data['prospective_generation'],
        }
      : scope;
  String get signature => _stable({
    'scope': {
      for (final e in scope.entries)
        if (e.key != 'server_now') e.key: e.value,
    },
    'beta_schedule_config': betaData?['beta_schedule_config'],
    'target_group': targetGroup,
    'group_policy': betaData?['group_policy'],
    'group_effects': cycleGroupEffects(betaData),
    if (betaData?['group_review'] != null)
      'group_permission': betaData!['group_review']['data']['permission'],
    'data': {
      for (final e in data.entries)
        if (!{'context_token', 'issued_at', 'expires_at'}.contains(e.key))
          e.key: e.key == 'session_display'
              ? display!.wire
              : e.key == 'access'
              ? {
                  for (final a in roleMap(e.value).entries)
                    if (a.key != 'evaluated_at') a.key: a.value,
                }
              : e.value,
    },
  });

  CycleGroupPolicy? get groupPolicy => betaData?['group_policy'] == null
      ? null
      : CycleGroupPolicy(roleMap(betaData!['group_policy']));
  List<Map<String, dynamic>> effectsFor([String? candidate]) {
    if (action == 'transfer') {
      final rows =
          betaData?['policy_source']?['data']?['candidates'] as List? ?? [];
      return cycleGroupEffects(
        rows.where((x) => x['cycle_member_id'] == candidate).toList(),
      );
    }
    return cycleGroupEffects(
      betaData?['group_review'] ?? betaData?['policy_source'],
    );
  }

  Map<String, dynamic> _groupChange(Map<String, dynamic> input) {
    final review = roleMap(betaData!['group_review']);
    final effect = CycleGroupEffect(roleMap(review['group_policy_effect']));
    final policy = groupPolicy!;
    if (input.containsKey('group_id')) {
      roleCheck(input['group_id'] == effect.after['group_id']);
    }
    if (input.containsKey('scope')) {
      roleCheck(input['scope'] == effect.after['scope']);
    }
    policy.bind(room, target, scope);
    roleCheck(
      policy.known &&
          effect.wire['room_id'] == room &&
          effect.wire['target_cycle_key'] == target &&
          effect.wire['room_cycle_id'] == scope['room_cycle_id'] &&
          effect.wire['generation'] == scope['target_generation'] &&
          effect.before['revision'] == policy.wire['revision'] &&
          effect.before['scope'] == policy.wire['scope'] &&
          effect.before['group_id'] == policy.groupId,
    );
    final d = roleMap(review['data']);
    _permission(d['permission']);
    final now = roleUtc(review['scope']['server_now']);
    roleCheck(
      !now.isBefore(roleUtc(d['issued_at'])) &&
          now.isBefore(roleUtc(d['expires_at'])),
    );
    return {
      'context_token': d['context_token'],
      'group_policy': {
        'scope': effect.after['scope'],
        'group_id': effect.after['group_id'],
        'expected_revision': policy.wire['revision'],
      },
    };
  }

  Map<String, dynamic> _openingSchedule(Map<String, dynamic> input) {
    final schedule = BetaScheduleConfig(roleMap(input['beta_schedule']));
    roleCheck(
      _stable(schedule.wire) == _stable(betaData!['beta_schedule_config']),
    );
    roleCheck(
      _stable(query['base_starts_at']) ==
              _stable(schedule.wire['base_starts_at']) &&
          query['early_coordination_enabled'] == schedule.enabled &&
          query['early_additional_members'] == schedule.additionalMembers,
    );
    BetaCreationDraft({target: schedule});
    roleCheck(
      schedule.startsAt.second == 0 &&
          schedule.startsAt.millisecond == 0 &&
          schedule.startsAt.microsecond == 0,
    );
    final local = schedule.startsAt.add(const Duration(hours: 9));
    final durations = raidList(data['item_settings']).map((v) {
      final item = roleMap(v);
      return item['duration_minutes'] ??
          const RecruitmentStartPolicy().defaultMinutes(
            item['difficulty_id'] as String,
          );
    });
    roleCheck(durations.every((v) => v is int));
    final duration = durations.cast<int>().fold(0, (a, b) => a + b);
    if (!const RecruitmentStartPolicy().allows(
      now: roleUtc(scope['server_now']),
      weekday: local.weekday,
      minute: local.hour * 60 + local.minute,
      durationMinutes: duration,
      targetCycleKey: target,
      precision: StartTimePrecision.minute,
    )) {
      throw const AccountReadException('SCHEDULE_BEFORE_FLOOR');
    }
    return schedule.wire;
  }

  Map<String, dynamic> body(Map<String, dynamic> input) {
    if (contextual) _permission(data['permission']);
    final base = <String, dynamic>{
      'expected_cycle_key': scope['current_cycle_key'],
      if (!global) 'target_cycle_key': target,
      if (!global) 'expected_target_revision': scope['target_revision'],
      if (contextual) 'context_token': data['context_token'],
    };
    if (global) {
      base['expected_room_revision'] = data['room_revision'];
      if (action != 'common') {
        return {
          ...base,
          'expected_persistent_membership_revision':
              data['persistent_membership_revision'],
        };
      }
      final s = roleMap(data['current_settings']);
      final entered = input['title'];
      final title = entered is String && entered.trim().isEmpty
          ? s['title']
          : entered;
      roleCheck(
        title is String && title.trim().isNotEmpty && title.trim().length <= 60,
      );
      if (usesCycleGroupPolicy) {
        return {...base, 'title': title.trim()};
      }
      final group = input.containsKey('group_id')
          ? input['group_id']
          : s['group_id'];
      final firstLink = s['group_id'] == null && group != null;
      if (firstLink) {
        roleCheck(targetGroup != null && group == targetGroup!['group_id']);
        _permission(targetGroup!['permission']);
      } else {
        roleCheck(group == s['group_id'] && targetGroup == null);
      }
      final visibility = input['scope'] ?? s['scope'];
      roleCheck({'public', 'group'}.contains(visibility));
      roleCheck(visibility != 'group' || group != null);
      roleCheck(!firstLink || visibility == 'group');
      if (group != null) roleId(group);
      return {
        ...base,
        'title': title.trim(),
        'scope': visibility,
        'group_id': group,
        'expected_group_revision': group == null
            ? null
            : rolePositive(
                firstLink
                    ? targetGroup!['group_revision']
                    : s['group_revision'],
              ),
      };
    }
    if (continuation || opening) {
      if (action == 'decline') return base;
      final selected = raidList(input['sessions'] ?? <String>[]).cast<String>();
      roleCheck(selected.toSet().length == selected.length);
      final sessions = opening
          ? <String>[]
          : display!.selectedIds(
              selected.toSet(),
              roleUtc(scope['server_now']),
            );
      if (opening) roleCheck(selected.isEmpty);
      roleCheck(
        data['selection'] != null && raidList(data['targets']).isNotEmpty,
      );
      return {
        ...base,
        'selection': data['selection'],
        'target_items': data['targets'],
        'target_session_ids': sessions,
        if (opening) 'intent': action,
        if (opening && betaData != null)
          'beta_schedule': _openingSchedule(input),
      };
    }
    if (action == 'cancel') {
      return {
        ...base,
        'expected_leadership_revision': roleMap(
          data['leadership'],
        )['leadership_revision'],
      };
    }
    if (action == 'transfer') {
      final c = raidList(data['candidates'])
          .map(roleMap)
          .where((c) => c['cycle_member_id'] == input['candidate'])
          .single;
      _permission(c['permission']);
      return {
        ...base,
        'expected_leadership_revision': roleMap(
          data['leadership'],
        )['leadership_revision'],
        'candidate_cycle_member_id': c['cycle_member_id'],
        'expected_candidate_revision': c['revision'],
      };
    }
    final leadership = roleMap(data['leadership']);
    base['expected_leadership_revision'] = leadership['leadership_revision'];
    if (action == 'settings') {
      _permission(roleMap(data['permissions'])['edit_settings']);
      final exp = input['experience_level'];
      roleCheck(exp == null || recruitmentExperiences.containsKey(exp));
      final mode = input['admission_mode'];
      roleCheck({'leader_only', 'direct_join'}.contains(mode));
      final combat = roleMap(input['combat_requirement']);
      roleShape(combat, 'input_mode dealer_min support_min');
      roleCheck({'shared', 'per_role'}.contains(combat['input_mode']));
      for (final k in ['dealer_min', 'support_min']) {
        final v = combat[k];
        roleCheck(
          v == null ||
              (v is String &&
                  v.length <= 32 &&
                  RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(v)),
        );
      }
      return {
        ...base,
        'expected_room_revision': data['room_revision'],
        'expected_settings_revision': data['revision'],
        if (betaData?['group_review'] != null) ..._groupChange(input),
        'experience_level': exp,
        'combat_requirement': combat,
        'admission_mode': mode,
      };
    }
    final roomData = roleMap(data['room']),
        members = raidList(data['members']).map(roleMap).toList();
    base.addAll({
      'expected_members_revision': data['members_revision'],
      'expected_plan_revision': data['plan_revision'],
    });
    if (action == 'remove') {
      final removed = members
          .where((m) => m['cycle_member_id'] == input['candidate'])
          .single;
      final mine = roleMap(data['my_membership']);
      roleCheck(
        removed['is_me'] == false && removed['target_role'] == 'member',
      );
      return {
        ...base,
        'expected_room_revision': roomData['revision'],
        'expected_cycle_member_revision': rolePositive(
          mine['cycle_member_revision'],
        ),
        'target_cycle_member_id': roleId(removed['cycle_member_id']),
        'expected_removed_cycle_member_revision': rolePositive(
          removed['cycle_member_revision'],
        ),
      };
    }
    final placements = raidList(input['placements']);
    roleCheck(placements.isNotEmpty && placements.length <= 40);
    final spots = <String>{}, pairs = <String>{};
    for (final raw in placements) {
      final p = roleMap(raw);
      roleShape(
        p,
        'cycle_member_id expected_cycle_member_revision item_id party_no slot_no',
      );
      final member = members
          .where(
            (m) =>
                m['cycle_member_id'] == p['cycle_member_id'] &&
                m['target_state'] == 'participating',
          )
          .single;
      roleCheck(
        member['cycle_member_revision'] == p['expected_cycle_member_revision'],
      );
      final assignment = raidList(member['assignments'])
          .map(roleMap)
          .where((a) => a['item_id'] == p['item_id'] && a['state'] == 'active')
          .single;
      roleId(assignment['assignment_id']);
      final item = raidList(
        roomData['items'],
      ).map(roleMap).where((i) => i['item_id'] == p['item_id']).single;
      final capacity =
          (item['game_party_size'] as int) < (roomData['app_capacity'] as int)
          ? item['game_party_size'] as int
          : roomData['app_capacity'] as int;
      roleCheck(
        p['party_no'] is int &&
            p['party_no'] >= 1 &&
            p['party_no'] <= capacity ~/ 4 &&
            p['slot_no'] is int &&
            p['slot_no'] >= 1 &&
            p['slot_no'] <= 4,
      );
      roleCheck(
        spots.add('${p['item_id']}/${p['party_no']}/${p['slot_no']}') &&
            pairs.add('${p['cycle_member_id']}/${p['item_id']}'),
      );
    }
    roleCheck(
      pairs.length ==
          members
              .where((m) => m['target_state'] == 'participating')
              .fold<int>(
                0,
                (sum, m) =>
                    sum +
                    raidList(
                      m['assignments'],
                    ).where((a) => roleMap(a)['state'] == 'active').length,
              ),
    );
    return {...base, 'placements': placements};
  }
}

class CycleManagementReader {
  CycleManagementReader(this.api);
  final BackendRegistrationApi api;
  Future<CycleManagementPreview> preview(
    String room,
    String target,
    String action, {
    Map<String, dynamic> query = const {},
  }) async {
    roleId(room);
    raidCycleKey(target);
    roleCheck(cycleManagementLabels.containsKey(action));
    roleCheck(
      query.keys.every(
        (k) => {
          'target_group_id',
          'review_group_policy',
          'character_id',
          'selected_role',
          'base_starts_at',
          'early_coordination_enabled',
          'early_additional_members',
        }.contains(k),
      ),
    );
    if (action == 'common') {
      if (api is BetaInteractionApi) roleCheck(query.isEmpty);
      roleCheck(query.keys.every((k) => k == 'target_group_id'));
      if (query.isNotEmpty) roleId(query['target_group_id']);
    } else if (action == 'settings') {
      roleCheck(
        query.keys.every(
          (k) => {'target_group_id', 'review_group_policy'}.contains(k),
        ),
      );
      if (query['target_group_id'] != null) roleId(query['target_group_id']);
    } else {
      roleCheck(!query.containsKey('target_group_id'));
      roleCheck(
        query.isEmpty || {'continue', 'open', 'reopen'}.contains(action),
      );
    }
    if (query.containsKey('character_id')) {
      roleId(query['character_id']);
      roleCheck({'dealer', 'support'}.contains(query['selected_role']));
    }
    final global = {'common', 'leave', 'end'}.contains(action);
    final tail = const {
      'continue': 'continuation-context',
      'decline': 'continuation-context',
      'open': 'opening-context',
      'reopen': 'opening-context',
      'cancel': 'participation-cancellation-context',
      'transfer': 'leadership-transfer-context',
      'settings': 'settings',
      'common': 'common-context',
      'leave': 'common-context',
      'end': 'common-context',
    }[action];
    final path = tail == null
        ? '/v2/raid-rooms/$room/detail'
        : '/v2/me/raid-rooms/$room/$tail';
    final requestQuery = {
      if (!global) 'target_cycle_key': target,
      if (global)
        'command': action == 'common' ? 'edit_common_settings' : action,
      if ({'continue', 'decline'}.contains(action))
        'action': action == 'continue' ? 'join' : 'decline',
      if ({'open', 'reopen'}.contains(action)) 'intent': action,
      if ({'continue', 'decline', 'open', 'reopen'}.contains(action))
        'include_session_display': 'true',
      for (final e in query.entries)
        if (!(action == 'settings' &&
            {'target_group_id', 'review_group_policy'}.contains(e.key)))
          e.key: e.value,
    };
    Map<String, dynamic>? betaData, targetGroup;
    late Map<String, dynamic> raw;
    if (api is BetaInteractionApi) {
      final decoded = await (api as BetaInteractionApi).requestDecoded(
        path,
        query: requestQuery,
      );
      raw = decoded.value;
      targetGroup = decoded.metadata?['target_group'] == null
          ? null
          : roleMap(decoded.metadata!['target_group']);
      betaData =
          betaFreeze({
                'group_policy_version':
                    decoded.metadata?['group_policy_version'],
                'group_policy': decoded.metadata?['group_policy'],
                'policy_source': decoded.metadata,
                'beta_schedule_config':
                    decoded.metadata?['data']?['beta_schedule_config'],
              })
              as Map<String, dynamic>;
    } else {
      raw = Map.of((await api.request(path, query: requestQuery))!);
      if (raw.containsKey('target_group')) {
        targetGroup = roleMap(raw.remove('target_group'));
      }
    }
    if (action == 'settings' && query['review_group_policy'] == true) {
      roleCheck(api is BetaInteractionApi);
      final checked = await (api as BetaInteractionApi).requestDecoded(
        '/v2/raid-rooms/$room/command-context',
        query: {
          'command': 'edit_group_policy',
          'target_cycle_key': target,
          if (query['target_group_id'] != null)
            'target_group_id': query['target_group_id'],
        },
      );
      final review = checked.metadata!;
      final effect = CycleGroupEffect(roleMap(review['group_policy_effect']));
      roleCheck(effect.after['group_id'] == query['target_group_id']);
      betaData = {...?betaData, 'group_review': review};
    }
    try {
      return CycleManagementPreview(
        room,
        target,
        action,
        raw,
        query: query,
        betaData: betaData,
        targetGroup: targetGroup,
      );
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }
}
