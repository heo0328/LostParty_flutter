import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/server_registration_api.dart';
import 'cycle_read_repository.dart';
import 'cycle_member_actions.dart' show actionTime;
import 'cycle_schedule.dart' show scheduleStable;
import 'group_character_candidates.dart' show compareCandidateLevels;

const admissionEligibilityPolicy = 'admission-eligibility-2';
const admissionExclusionReasons = {
  'RAID_ITEM_LEVEL_REQUIRED',
  'COMBAT_POWER_REQUIRED',
  'WEEKLY_ALREADY_COMPLETED',
  'WEEKLY_ALREADY_PARTICIPATING',
  'ROOM_FULL',
  'ROOM_COMPOSITION_CONFLICT',
};

Object? _freeze(Object? value) => value is Map
    ? Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k as String, _freeze(v))),
      )
    : value is List
    ? List<Object?>.unmodifiable(value.map(_freeze))
    : value;
Map<String, dynamic> _snapshot(Map<String, dynamic> raw) {
  final encoded = jsonEncode(raw);
  if (utf8.encode(encoded).length > 1024 * 1024) {
    throw const AccountReadException('RESPONSE_TOO_LARGE', status: 413);
  }
  return _freeze(jsonDecode(encoded)) as Map<String, dynamic>;
}

int _int(Object? v, {int min = 1, int max = 2147483647}) {
  roleCheck(v is int && v >= min && v <= max);
  return v as int;
}

String _text(Object? v, {int max = 64}) {
  roleCheck(v is String && v.isNotEmpty && v.length <= max);
  return v as String;
}

String _role(Object? v) {
  roleCheck(v == 'dealer' || v == 'support');
  return v as String;
}

String? _decimal(Object? v, int max) {
  if (v == null) return null;
  roleCheck(
    v is String &&
        v.length <= max &&
        RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(v),
  );
  return v as String;
}

class AdmissionRoleEvaluation {
  AdmissionRoleEvaluation(Map<String, dynamic> raw, String role)
    : wire = _snapshot(raw) {
    roleShape(wire, 'supported allowed reason comparison');
    supported = raidBool(wire['supported']);
    allowed = raidBool(wire['allowed']);
    reason = wire['reason'] as String?;
    if (!supported) {
      roleCheck(
        !allowed &&
            reason == 'ROLE_NOT_SUPPORTED' &&
            wire['comparison'] == null,
      );
      comparison = null;
      return;
    }
    roleCheck(
      allowed ? reason == null : admissionExclusionReasons.contains(reason),
    );
    final p = AdmissionPowerComparison(roleMap(wire['comparison']), role).wire;
    final state = p['state'];
    roleCheck(!allowed || state == 'unrestricted' || state == 'meets');
    roleCheck(
      reason != 'COMBAT_POWER_REQUIRED' ||
          state == 'missing' ||
          state == 'below',
    );
    comparison = p;
  }
  final Map<String, dynamic> wire;
  late final bool supported, allowed;
  late final String? reason;
  late final Map<String, dynamic>? comparison;
}

/// Shared wire validation only; this does not grant admission permission.
class AdmissionPowerComparison {
  AdmissionPowerComparison(Map<String, dynamic> raw, String role)
    : wire = _snapshot(raw) {
    final p = wire;
    roleShape(
      p,
      'selected_role requirement actual state source trust current_summary_version success_summary_version power_revision observed_at success_saved_at success_issues current_issues',
    );
    roleCheck(
      _role(p['selected_role']) == role &&
          p['source'] == 'flutter_analysis' &&
          p['trust'] == 'client_submitted',
    );
    _int(p['current_summary_version']);
    _int(p['power_revision']);
    if (p['success_summary_version'] != null) {
      _int(p['success_summary_version']);
    }
    for (final k in ['observed_at', 'success_saved_at']) {
      if (p[k] != null) actionTime(p[k]);
    }
    for (final k in ['success_issues', 'current_issues']) {
      for (final issue in raidList(p[k])) {
        AnalysisIssue.fromJson(roleMap(issue));
      }
    }
    final requirement = _decimal(p['requirement'], 32),
        actual = _decimal(p['actual'], 32);
    final state = p['state'];
    roleCheck({'unrestricted', 'missing', 'below', 'meets'}.contains(state));
    roleCheck(switch (state) {
      'unrestricted' => requirement == null,
      'missing' => requirement != null && actual == null,
      'below' =>
        requirement != null &&
            actual != null &&
            compareCandidateLevels(actual, requirement) > 0,
      'meets' =>
        requirement != null &&
            actual != null &&
            compareCandidateLevels(actual, requirement) <= 0,
      _ => false,
    });
  }
  final Map<String, dynamic> wire;
}

class AdmissionCandidate {
  AdmissionCandidate(Map<String, dynamic> j) {
    roleShape(
      j,
      'character_id registration_id server_name character_name class_name item_level roles',
    );
    id = roleId(j['character_id']);
    registration = roleId(j['registration_id']);
    server = _text(j['server_name']);
    name = _text(j['character_name']);
    className = _text(j['class_name']);
    level = _decimal(j['item_level'], 64)!;
    final roles = roleMap(j['roles']);
    roleShape(roles, 'dealer support');
    dealer = AdmissionRoleEvaluation(roleMap(roles['dealer']), 'dealer');
    support = AdmissionRoleEvaluation(roleMap(roles['support']), 'support');
    roleCheck(dealer.allowed || support.allowed);
  }
  late final String id, registration, server, name, className, level;
  late final AdmissionRoleEvaluation dealer, support;
  AdmissionRoleEvaluation evaluation(String role) =>
      role == 'dealer' ? dealer : support;
}

class AdmissionCandidateActor {
  AdmissionCandidateActor(Map<String, dynamic> raw) : wire = _snapshot(raw) {
    roleShape(
      wire,
      'membership_id cycle_member_id cycle_member_revision assignments',
    );
    roleId(wire['membership_id']);
    roleId(wire['cycle_member_id']);
    _int(wire['cycle_member_revision']);
    final assignments = raidList(wire['assignments']);
    roleCheck(assignments.isNotEmpty && assignments.length <= 200);
    final ids = <String>{}, rounds = <String>{};
    String? previous;
    for (final raw in assignments) {
      final a = roleMap(raw);
      roleShape(
        a,
        'assignment_id revision item_id round_id character_id selected_role party_no slot_no',
      );
      roleCheck(
        ids.add(roleId(a['assignment_id'])) &&
            rounds.add(roleId(a['round_id'])),
      );
      final item = roleId(a['item_id']);
      roleCheck(previous == null || previous.compareTo(item) < 0);
      previous = item;
      _int(a['revision']);
      roleId(a['character_id']);
      _role(a['selected_role']);
      _int(a['party_no'], max: 2);
      _int(a['slot_no'], max: 4);
    }
  }
  final Map<String, dynamic> wire;
  List<Map<String, dynamic>> get assignments =>
      List.unmodifiable(raidList(wire['assignments']).map(roleMap));
  String get signature => scheduleStable(wire);
}

class AdmissionExclusion {
  AdmissionExclusion(Map<String, dynamic> j) {
    roleShape(j, 'reason detail character_count');
    reason = j['reason'] as String;
    detail = j['detail'] as String?;
    roleCheck(admissionExclusionReasons.contains(reason));
    roleCheck(
      reason == 'COMBAT_POWER_REQUIRED'
          ? {'missing', 'below'}.contains(detail)
          : detail == null,
    );
    count = _int(j['character_count']);
  }
  late final String reason;
  late final String? detail;
  late final int count;
  String get key => '$reason/$detail';
}

class AdmissionCandidatePage {
  AdmissionCandidatePage(
    Map<String, dynamic> raw, {
    required String room,
    required String target,
    required String intent,
  }) : wire = _snapshot(raw) {
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    // Scope semantics reuse the existing parser; RFC3339 offsets are canonicalized only for validation.
    CycleReadScope({
      ...scope,
      'server_now': actionTime(scope['server_now']).toIso8601String(),
      'playable_from': actionTime(scope['playable_from']).toIso8601String(),
    }, target);
    roleId(scope['room_cycle_id']);
    _int(scope['target_revision']);
    _int(scope['target_generation']);
    data = roleMap(wire['data']);
    roleShape(
      data,
      'room_id intent eligibility_policy_version actor evaluated_at catalog_version snapshot_token raw_candidate_count eligible_candidate_count exclusion_summary items next_cursor',
    );
    roleCheck(
      roleId(data['room_id']) == room &&
          data['intent'] == intent &&
          {'apply', 'join', 'change_character'}.contains(intent),
    );
    roleCheck(data['eligibility_policy_version'] == admissionEligibilityPolicy);
    actionTime(data['evaluated_at']);
    _text(data['catalog_version']);
    roleCheck(
      data['snapshot_token'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(data['snapshot_token'] as String),
    );
    rawCount = _int(data['raw_candidate_count'], min: 0);
    eligibleCount = _int(data['eligible_candidate_count'], min: 0);
    roleCheck(eligibleCount <= rawCount);
    actor = data['actor'] == null
        ? null
        : AdmissionCandidateActor(roleMap(data['actor']));
    roleCheck((intent != 'change_character') == (actor == null));
    exclusions = List.unmodifiable(
      raidList(
        data['exclusion_summary'],
      ).map((v) => AdmissionExclusion(roleMap(v))),
    );
    roleCheck(
      exclusions.length <= 7 &&
          exclusions.map((v) => v.key).toSet().length == exclusions.length &&
          exclusions.fold<int>(0, (n, v) => n + v.count) ==
              rawCount - eligibleCount,
    );
    items = List.unmodifiable(
      raidList(data['items']).map((v) => AdmissionCandidate(roleMap(v))),
    );
    roleCheck(items.length <= 100 && items.length <= eligibleCount);
    String? previous;
    for (final item in items) {
      roleCheck(previous == null || previous.compareTo(item.id) < 0);
      previous = item.id;
    }
    cursor = data['next_cursor'] as String?;
    roleCheck(
      cursor == null ||
          cursor!.isNotEmpty && cursor!.length <= 2048 && items.isNotEmpty,
    );
  }
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope, data;
  late final int rawCount, eligibleCount;
  late final String? cursor;
  late final AdmissionCandidateActor? actor;
  late final List<AdmissionCandidate> items;
  late final List<AdmissionExclusion> exclusions;
  String get identity => scheduleStable({
    'scope': {...scope}..remove('server_now'),
    'data': {...data}
      ..remove('evaluated_at')
      ..remove('items')
      ..remove('next_cursor'),
  });
}

abstract interface class AdmissionCandidatesGateway {
  Future<AdmissionCandidatePage> admissionCandidates(
    String room,
    String target,
    String intent, {
    String? cursor,
  });
}

class AdmissionCandidatesReader implements AdmissionCandidatesGateway {
  AdmissionCandidatesReader(this.api);
  final BackendRegistrationApi api;
  @override
  Future<AdmissionCandidatePage> admissionCandidates(
    String room,
    String target,
    String intent, {
    String? cursor,
  }) async {
    roleId(room);
    raidCycleKey(target);
    roleCheck({'apply', 'join', 'change_character'}.contains(intent));
    try {
      final raw = await api.request(
        '/v2/raid-rooms/$room/admission-character-candidates',
        query: {
          'target_cycle_key': target,
          'intent': intent,
          'limit': 100,
          'cursor': ?cursor,
        },
      );
      return AdmissionCandidatePage(
        raw!,
        room: room,
        target: target,
        intent: intent,
      );
    } on FormatException {
      rethrow;
    }
  }
}
