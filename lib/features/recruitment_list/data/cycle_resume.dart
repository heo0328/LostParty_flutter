import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import 'cycle_read_repository.dart';
import 'cycle_schedule.dart';
import 'cycle_management.dart';

Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable({
        for (final e in v.entries) e.key as String: _freeze(e.value),
      })
    : v is List
    ? List<dynamic>.unmodifiable(v.map(_freeze))
    : v;
Map<String, dynamic> _copy(Map<String, dynamic> v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
void _size(Map<String, dynamic> raw, {bool request = false}) {
  if (utf8.encode(jsonEncode(raw)).length > (request ? 32768 : 1024 * 1024)) {
    throw AccountReadException(
      request ? 'REQUEST_TOO_LARGE' : 'RESPONSE_TOO_LARGE',
      status: 413,
    );
  }
}

void _ref(Object? v) =>
    roleCheck(v is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(v));
void _uniqueSorted(List values, String key) {
  final ids = values.map((v) => roleMap(v)[key] as String).toList();
  roleCheck(
    ids.toSet().length == ids.length &&
        jsonEncode(ids) == jsonEncode([...ids]..sort()),
  );
}

void _clock(Object? v) => roleCheck(
  v == null ||
      (v is String && RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][05]$').hasMatch(v)),
);

/// Strict opt-in review. No live schedule is substituted for the proposal basis.
class CycleResumeReview {
  CycleResumeReview(
    Map<String, dynamic> raw,
    Map<String, dynamic> scope,
    String room,
    String target, {
    Map<String, dynamic>? proposal,
  }) : wire = _freeze(_copy(raw)) as Map<String, dynamic> {
    CycleReadScope(scope, target);
    roleCheck(
      roleUtc(scope['playable_from']) == DateTime.parse('${target}T01:00:00Z'),
    );
    roleShape(wire, 'display confirmation');
    display = roleMap(wire['display']);
    roleShape(
      display,
      'version status room_id room_cycle_id target_cycle_key target_generation proposal_id proposal_revision proposal_plan_revision origin settings_revision basis_revision display_revision items groups effect permission',
    );
    roleCheck(
      display['version'] == 1 &&
          {
            'ready',
            'stale',
            'legacy_unverifiable',
          }.contains(display['status']) &&
          display['room_id'] == room &&
          display['target_cycle_key'] == target &&
          roleId(display['room_cycle_id']) == scope['room_cycle_id'] &&
          rolePositive(display['target_generation']) ==
              scope['target_generation'],
    );
    roleId(display['room_id']);
    _ref(display['display_revision']);
    roleCheck(
      {'explicit', 'retained', 'legacy_unknown'}.contains(display['origin']),
    );
    for (final k in [
      'settings_revision',
      'proposal_revision',
      'proposal_plan_revision',
    ]) {
      if (display[k] != null) rolePositive(display[k]);
    }
    if (display['basis_revision'] != null) _ref(display['basis_revision']);
    if (proposal == null) {
      roleCheck(
        [
          'proposal_id',
          'proposal_revision',
          'proposal_plan_revision',
        ].every((k) => display[k] == null),
      );
    } else {
      roleCheck(
        roleId(display['proposal_id']) == proposal['proposal_id'] &&
            display['proposal_revision'] == proposal['revision'] &&
            display['proposal_plan_revision'] ==
                proposal['proposal_plan_revision'],
      );
    }
    final items = raidList(display['items']);
    for (final rawItem in items) {
      final i = roleMap(rawItem);
      roleShape(
        i,
        'item_id source_round_id raid_id difficulty_id catalog_version duration_minutes duration_source',
      );
      roleId(i['item_id']);
      roleId(i['source_round_id']);
      for (final k in ['raid_id', 'difficulty_id', 'catalog_version']) {
        raidText(i[k]);
      }
      if (i['duration_minutes'] != null) rolePositive(i['duration_minutes']);
      roleCheck(i['duration_source'] == null || i['duration_source'] is String);
    }
    _uniqueSorted(items, 'item_id');
    if (proposal != null) {
      final rounds = raidList(proposal['target_round_ids']);
      roleCheck(
        rounds.length == items.length &&
            rounds.toSet().length == rounds.length &&
            items.every((i) => rounds.contains(i['source_round_id'])),
      );
    }
    final groups = raidList(display['groups']);
    for (final rawGroup in groups) {
      final g = roleMap(rawGroup);
      roleShape(
        g,
        'group_ref planning_mode occurrence_mode day_scope required auto_confirm_additional_members alternatives',
      );
      _ref(g['group_ref']);
      roleCheck(
        {'manual', 'coordinated', 'unscheduled'}.contains(g['planning_mode']) &&
            {'one_of', 'each'}.contains(g['occurrence_mode']) &&
            {'selected_weekdays', 'any_current_cycle'}.contains(g['day_scope']),
      );
      raidBool(g['required']);
      final count = g['auto_confirm_additional_members'];
      roleCheck(count == null || (count is int && count >= 1 && count <= 7));
      final alts = raidList(g['alternatives']);
      for (final rawAlt in alts) {
        final a = roleMap(rawAlt);
        roleShape(
          a,
          'alternative_ref weekday starts_local leader_latest_start_local item_ids session_id starts_at ends_at time_state materialization',
        );
        _ref(a['alternative_ref']);
        roleCheck(
          a['weekday'] is int &&
              a['weekday'] >= 1 &&
              a['weekday'] <= 7 &&
              a['session_id'] == null,
        );
        _clock(a['starts_local']);
        _clock(a['leader_latest_start_local']);
        final ids = raidList(a['item_ids']);
        roleCheck(ids.toSet().length == ids.length);
        for (final id in ids) {
          roleId(id);
          roleCheck(items.any((i) => i['item_id'] == id));
        }
        final start = a['starts_at'] == null ? null : roleUtc(a['starts_at']);
        final end = a['ends_at'] == null ? null : roleUtc(a['ends_at']);
        roleCheck(
          a['time_state'] ==
              (end != null
                  ? 'bounded'
                  : start != null
                  ? 'start_only'
                  : 'undetermined'),
        );
        if (end != null) {
          roleCheck(start != null && end.isAfter(start));
        }
        final expectedStart =
            g['planning_mode'] == 'manual' && a['starts_local'] != null
            ? cycleScheduleStart(
                target,
                a['weekday'] as int,
                a['starts_local'] as String,
              )
            : null;
        roleCheck(start == expectedStart);
        if (end != null) {
          final durations = ids
              .map(
                (id) => items.firstWhere(
                  (i) => i['item_id'] == id,
                )['duration_minutes'],
              )
              .toList();
          roleCheck(
            durations.isNotEmpty && durations.every((m) => m is int && m > 0),
          );
          roleCheck(
            end ==
                start!.add(
                  Duration(
                    minutes: durations.cast<int>().fold(0, (a, b) => a + b),
                  ),
                ),
          );
        }
        roleCheck(
          a['materialization'] ==
              (g['planning_mode'] == 'manual'
                  ? (g['occurrence_mode'] == 'each' || alts.length == 1
                        ? 'on_apply'
                        : 'after_group_selection')
                  : g['planning_mode'] == 'coordinated'
                  ? 'after_coordination'
                  : 'not_scheduled'),
        );
      }
      _uniqueSorted(alts, 'alternative_ref');
    }
    _uniqueSorted(groups, 'group_ref');
    effect = roleMap(display['effect']);
    roleShape(
      effect,
      'eligible_count accepted_count required_votes new_round_count new_assignment_count completed_preserved_count superseded_proposal_count creator_accept_on_submit my_immediate_session_count_on_accept',
    );
    for (final k in ['eligible_count', 'accepted_count']) {
      raidNonnegative(effect[k]);
    }
    rolePositive(effect['required_votes']);
    roleCheck(effect['accepted_count'] <= effect['eligible_count']);
    for (final k in [
      'new_round_count',
      'new_assignment_count',
      'completed_preserved_count',
      'superseded_proposal_count',
      'my_immediate_session_count_on_accept',
    ]) {
      if (effect[k] != null) raidNonnegative(effect[k]);
    }
    if (effect['creator_accept_on_submit'] != null) {
      raidBool(effect['creator_accept_on_submit']);
    }
    permission = CyclePermission.fromJson(roleMap(display['permission']));
    if (wire['confirmation'] != null) {
      final v = roleMap(wire['confirmation']);
      roleShape(v, 'context_token issued_at expires_at');
      roleCheck(
        raidText(v['context_token']).length <= 4096 &&
            utf8.encode(v['context_token'] as String).length <= 4096,
      );
      final issued = roleUtc(v['issued_at']),
          expires = roleUtc(v['expires_at']),
          now = roleUtc(scope['server_now']);
      final end = DateTime.parse(
        '${scope['current_cycle_key']}T21:00:00Z',
      ).add(const Duration(days: 6));
      roleCheck(
        !issued.isAfter(now) &&
            expires.isAfter(issued) &&
            expires.difference(issued) <= const Duration(seconds: 120) &&
            !expires.isAfter(end),
      );
      roleCheck(
        display['status'] == 'ready' &&
            permission.allowed &&
            target == scope['current_cycle_key'] &&
            !now.isBefore(roleUtc(scope['playable_from'])),
      );
      if (!expires.isAfter(now)) {
        throw const AccountReadException('COMMAND_CONTEXT_EXPIRED');
      }
    }
    if (display['status'] != 'ready') {
      roleCheck(!permission.allowed && wire['confirmation'] == null);
    }
    if (display['status'] == 'ready') {
      rolePositive(display['settings_revision']);
      _ref(display['basis_revision']);
    }
    if (display['status'] == 'legacy_unverifiable') {
      roleCheck(
        display['basis_revision'] == null &&
            display['settings_revision'] == null,
      );
    }
  }
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> display, effect;
  late final CyclePermission permission;
  bool get canConfirm =>
      display['status'] == 'ready' &&
      permission.allowed &&
      wire['confirmation'] != null;
  String get token {
    if (!canConfirm) {
      throw AccountReadException(
        permission.reason ?? 'PROPOSAL_CONTEXT_CHANGED',
      );
    }
    return roleMap(wire['confirmation'])['context_token'] as String;
  }
}

class CycleResumePlan {
  CycleResumePlan(String room, String target, Map<String, dynamic> raw) {
    _size(raw);
    final normal = _copy(raw);
    final reviews = <String, Map<String, dynamic>>{};
    for (final v in raidList(roleMap(normal['data'])['proposals'])) {
      final p = roleMap(v);
      if (p['kind'] == 'weekly_resume') {
        roleCheck(!reviews.containsKey(roleId(p['proposal_id'])));
        reviews[roleId(p['proposal_id'])] = roleMap(p.remove('resume_review'));
      } else {
        roleCheck(!p.containsKey('resume_review'));
      }
    }
    plan = CycleScheduleView(room, target, 'plan', normal);
    for (final p in raidList(
      plan.data['proposals'],
    ).where((p) => p['kind'] == 'weekly_resume')) {
      final v = roleMap(p);
      entries[v['proposal_id'] as String] = CycleResumeReview(
        reviews[v['proposal_id']]!,
        plan.scope,
        room,
        target,
        proposal: v,
      );
    }
  }
  late final CycleScheduleView plan;
  final entries = <String, CycleResumeReview>{};
}

class CycleResumePreview {
  CycleResumePreview(
    this.plan,
    this.review,
    Map<String, dynamic> body, {
    this.proposalId,
  }) : originalBody = _freeze(_copy(body)) as Map<String, dynamic>,
       signature = scheduleStable({
         'scope': plan.scope,
         'body': body,
         'display': review.display,
       });
  final CycleScheduleView plan;
  final CycleResumeReview review;
  final Map<String, dynamic> originalBody;
  final String signature;
  final String? proposalId;
  String get path => proposalId == null
      ? '/v2/raid-rooms/${plan.room}/weekly-resume-proposals'
      : '/v2/raid-schedule-proposals/$proposalId/responses';
  Map<String, dynamic> body({String? response}) {
    roleCheck(
      proposalId == null
          ? response == null
          : {'accept', 'reject'}.contains(response),
    );
    final result = <String, dynamic>{
      ...originalBody,
      if (proposalId != null) 'response': response,
      'resume_context_token': review.token,
    };
    _size(result, request: true);
    return result;
  }
}

class CycleResumeReader {
  CycleResumeReader(this.api);
  final BackendRegistrationApi api;
  Future<CycleResumePlan> read(String room, String target) async {
    roleId(room);
    raidCycleKey(target);
    final raw = (await api.request(
      '/v2/me/raid-rooms/$room/plan',
      query: {'target_cycle_key': target, 'include_resume_display': 'true'},
    ))!;
    return CycleResumePlan(room, target, raw);
  }

  Future<CycleResumePreview> preview(
    String room,
    String target, {
    String? proposalId,
    List<dynamic>? groups,
  }) async {
    // Capture caller-owned arrays before the first await; null and [] are distinct.
    final frozenGroups = jsonDecode(jsonEncode(groups)) as List<dynamic>?;
    if (proposalId != null) {
      roleId(proposalId);
      final result = await read(room, target);
      final p = result.plan.find('proposals', 'proposal_id', proposalId);
      roleCheck(p['kind'] == 'weekly_resume');
      final mine = roleMap(result.plan.data['my_membership']);
      return CycleResumePreview(result.plan, result.entries[proposalId]!, {
        'expected_cycle_key': result.plan.scope['current_cycle_key'],
        'target_cycle_key': target,
        'expected_target_revision': result.plan.scope['target_revision'],
        'expected_proposal_revision': p['revision'],
        'expected_proposal_plan_revision': p['proposal_plan_revision'],
        'expected_cycle_member_revision': mine['cycle_member_revision'],
      }, proposalId: proposalId);
    }
    final plan = await CycleScheduleReader(api).read(room, target, 'plan');
    final settings = await CycleManagementReader(
      api,
    ).preview(room, target, 'settings');
    roleCheck(scheduleStable(settings.scope) == scheduleStable(plan.scope));
    final mine = roleMap(plan.data['my_membership']);
    final body = <String, dynamic>{
      'expected_cycle_key': plan.scope['current_cycle_key'],
      'target_cycle_key': target,
      'expected_target_revision': plan.scope['target_revision'],
      'expected_room_revision': settings.data['room_revision'],
      'expected_members_revision': plan.data['members_revision'],
      'expected_plan_revision': plan.data['revision'],
      'expected_cycle_member_revision': mine['cycle_member_revision'],
      'expected_leadership_revision': roleMap(
        plan.data['leadership'],
      )['leadership_revision'],
      'schedule_groups': frozenGroups,
    };
    _size(body, request: true);
    final raw = (await api.request(
      '/v2/raid-rooms/$room/weekly-resume-proposals',
      method: 'POST',
      query: {'preview_only': 'true'},
      body: body,
    ))!;
    _size(raw);
    roleShape(raw, 'scope data');
    final scope = roleMap(raw['scope']);
    CycleReadScope(scope, target);
    roleCheck(scheduleStable(scope) == scheduleStable(plan.scope));
    final data = roleMap(raw['data']);
    roleShape(data, 'kind resume_review');
    roleCheck(data['kind'] == 'weekly_resume_preview');
    final review = CycleResumeReview(
      roleMap(data['resume_review']),
      scope,
      room,
      target,
    );
    final source = raidList(
      plan.data['game_items'],
    ).where((i) => i['round_state'] == 'stopped_incomplete').toList();
    final shown = raidList(review.display['items']);
    roleCheck(
      source.length == shown.length &&
          shown.every(
            (i) => source.any(
              (s) =>
                  s['item_id'] == i['item_id'] &&
                  s['round_id'] == i['source_round_id'] &&
                  s['raid_id'] == i['raid_id'] &&
                  s['difficulty_id'] == i['difficulty_id'] &&
                  s['catalog_version'] == i['catalog_version'],
            ),
          ),
    );
    roleCheck(
      review.display['origin'] ==
          (frozenGroups == null ? 'retained' : 'explicit'),
    );
    return CycleResumePreview(plan, review, body);
  }
}
