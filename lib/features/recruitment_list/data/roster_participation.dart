import '../../account/domain/role_summary.dart';
import '../../account/domain/member_raid_models.dart';
import 'beta/beta_contract.dart';

Map<String, dynamic> _validated(String name, Map<String, dynamic> raw) {
  const BetaContract(
    mode: RecruitmentContractMode.betaWire2,
  ).validateDefinition(name, raw);
  return betaFreeze(raw) as Map<String, dynamic>;
}

/// Server-owned evidence; a name is never an identity or a recovery command.
class RosterCharacterIssue {
  RosterCharacterIssue(Map<String, dynamic> raw)
    : wire = _validated('RosterCharacterIssue', raw);
  final Map<String, dynamic> wire;
  String get room => wire['room_id'];
  String get target => wire['target_cycle_key'];
  String get cycleMember => wire['cycle_member_id'];
  String get character => wire['character_id'];
  String get name => wire['character_name'] ?? '참가 캐릭터';
  String? get registration => wire['registration_id'];
}

class RosterIssueSummary {
  RosterIssueSummary(Map<String, dynamic> raw)
    : wire = _validated('RosterIssueSummary', raw) {
    final cycles = (wire['cycles'] as List).cast<Map<String, dynamic>>();
    roleCheck(cycles.map((c) => c['target_cycle_key']).toSet().length == 2);
    roleCheck(
      cycles.map((c) => c['target_cycle_key']).toSet().containsAll([
        wire['current_cycle_key'],
        wire['next_cycle_key'],
      ]),
    );
    roleCheck(
      raidCycleKey(wire['next_cycle_key']) ==
          DateTime.parse(
            '${wire['current_cycle_key']}T00:00:00Z',
          ).add(const Duration(days: 7)).toIso8601String().substring(0, 10),
    );
    roleCheck(hasIssues == cycles.any((c) => c['has_issues'] == true));
    for (final c in cycles) {
      roleCheck(c['has_issues'] == ((c['affected_room_count'] as int) > 0));
    }
  }
  final Map<String, dynamic> wire;
  bool get hasIssues => wire['has_issues'];
  Set<String> get affectedCycles => {
    for (final c in wire['cycles'])
      if (c['has_issues'] == true) c['target_cycle_key'] as String,
  };
}

class RosterIssuePage {
  RosterIssuePage(Map<String, dynamic> raw)
    : wire = _validated('RosterIssuePage', raw) {
    items = List.unmodifiable(
      (wire['items'] as List).map((v) => RosterCharacterIssue(roleMap(v))),
    );
  }
  final Map<String, dynamic> wire;
  late final List<RosterCharacterIssue> items;
}

class RosterIssueRoom {
  RosterIssueRoom(Map<String, dynamic> raw)
    : wire = _validated('RosterIssueRoomContext', raw) {
    final summaries = wire['target_summaries'] as List;
    roleCheck(summaries.map((s) => s['target_cycle_key']).toSet().length == 2);
    for (final s in summaries) {
      roleCheck(
        s['state'] == 'not_authorized'
            ? s['has_issues'] == null && s['affected_participant_count'] == null
            : s['has_issues'] is bool && s['affected_participant_count'] is int,
      );
    }
    items = List.unmodifiable(
      ((wire['selected_target_issues'] as List?) ?? []).map(
        (v) => RosterCharacterIssue(roleMap(v)),
      ),
    );
  }
  final Map<String, dynamic> wire;
  late final List<RosterCharacterIssue> items;
  Set<String> get affectedCycles => {
    for (final s in wire['target_summaries'])
      if (s['state'] == 'ready' && s['has_issues'] == true)
        s['target_cycle_key'] as String,
  };
}

class RosterParticipationMember {
  RosterParticipationMember(Map<String, dynamic> raw)
    : wire = _validated('RosterParticipationMember', raw) {
    final ids = <String>{};
    for (final a in [...active, ...preserved]) {
      roleCheck(ids.add(a['assignment_id'] as String));
    }
    final current = wire['current_character'];
    roleCheck(active.isEmpty ? current == null : current != null);
    if (current != null) {
      roleCheck(
        active.every(
          (a) =>
              a['character_id'] == current['character_id'] &&
              a['selected_role'] == current['selected_role'],
        ),
      );
    }
  }
  final Map<String, dynamic> wire;
  List<Map<String, dynamic>> get active =>
      (wire['active_assignments'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get preserved =>
      (wire['preserved_assignments'] as List).cast<Map<String, dynamic>>();
  String get binding => wire['binding_revision'];
  Map<String, dynamic>? get current => wire['current_character'];
  void matchActor(Map<String, dynamic> actor) {
    roleCheck(
      actor['membership_id'] == wire['membership_id'] &&
          actor['cycle_member_id'] == wire['cycle_member_id'] &&
          actor['cycle_member_revision'] == wire['cycle_member_revision'],
    );
    final assignments = (actor['assignments'] as List)
        .cast<Map<String, dynamic>>();
    roleCheck(assignments.length == active.length);
    for (final a in active) {
      roleCheck(assignments.any((v) => a.keys.every((k) => v[k] == a[k])));
    }
  }
}

class RosterParticipationContext {
  RosterParticipationContext(Map<String, dynamic> raw) {
    final change = raw.containsKey('actor');
    wire = _validated(
      change
          ? 'RosterParticipationChangeContext'
          : 'RosterParticipationReadContext',
      raw,
    );
    members = List.unmodifiable(
      (change ? [wire['actor']] : wire['members'] as List).map(
        (v) => RosterParticipationMember(roleMap(v)),
      ),
    );
  }
  late final Map<String, dynamic> wire;
  late final List<RosterParticipationMember> members;
  RosterParticipationMember? forMember(
    String room,
    String target,
    String cycleMember,
  ) => members
      .where(
        (m) =>
            m.wire['room_id'] == room &&
            m.wire['target_cycle_key'] == target &&
            m.wire['cycle_member_id'] == cycleMember,
      )
      .firstOrNull;
}

List<Map<String, dynamic>> remainingAssignmentCas(
  List<Map<String, dynamic>> rows,
  RosterParticipationMember member,
) {
  final result = <Map<String, dynamic>>[];
  for (final active in member.active) {
    final matches = rows
        .where((r) => r['assignment_id'] == active['assignment_id'])
        .toList();
    roleCheck(matches.length == 1);
    // Plan assignments have no placement columns; placement is fenced by binding_revision.
    roleCheck(
      [
        'assignment_id',
        'revision',
        'item_id',
        'round_id',
        'character_id',
        'selected_role',
      ].every((k) => matches.single[k] == active[k]),
    );
    result.add({
      'assignment_id': active['assignment_id'],
      'expected_revision': active['revision'],
    });
  }
  return List.unmodifiable(result);
}

/// Validate cross-field identity before metadata reaches a screen.
void validateRosterEnvelope(Map<String, dynamic> raw) {
  final scope = raw['scope'] as Map?;
  final target = scope?['target_cycle_key'];
  RosterParticipationContext? participation;
  if (raw['participation_context'] != null) {
    participation = RosterParticipationContext(
      roleMap(raw['participation_context']),
    );
    final ids = <String>{};
    for (final m in participation.members) {
      roleCheck(
        ids.add(
          '${m.wire['room_id']}/${m.wire['target_cycle_key']}/${m.wire['cycle_member_id']}',
        ),
      );
      if (target != null) roleCheck(m.wire['target_cycle_key'] == target);
      if (scope?['room_cycle_id'] != null) {
        roleCheck(
          m.wire['room_cycle_id'] == scope!['room_cycle_id'] &&
              m.wire['target_generation'] == scope['target_generation'],
        );
      }
    }
    final actor = (raw['data'] as Map?)?['actor'];
    if (actor != null) participation.members.single.matchActor(roleMap(actor));
  }
  if (raw['character_issue_context'] != null) {
    final context = RosterIssueRoom(roleMap(raw['character_issue_context']));
    final selected = (context.wire['target_summaries'] as List)
        .where((s) => s['target_cycle_key'] == target)
        .firstOrNull;
    if (selected != null) {
      roleCheck(
        selected['state'] == 'ready'
            ? context.wire['selected_target_issues'] != null
            : context.wire['selected_target_issues'] == null,
      );
    }
    for (final issue in context.items) {
      roleCheck(target == null || issue.target == target);
      if (scope?['room_cycle_id'] != null) {
        roleCheck(
          issue.wire['room_cycle_id'] == scope!['room_cycle_id'] &&
              issue.wire['target_generation'] == scope['target_generation'],
        );
      }
      if (participation != null) {
        final member = participation.forMember(
          issue.room,
          issue.target,
          issue.cycleMember,
        );
        roleCheck(member != null);
        final active = member!.active
            .where((a) => a['character_id'] == issue.character)
            .map((a) => a['assignment_id'])
            .toSet();
        roleCheck(active.containsAll(issue.wire['assignment_ids'] as List));
      }
    }
  }
  if (raw['character_issues'] != null) {
    final page = RosterIssuePage(roleMap(raw['character_issues']));
    for (final issue in page.items) {
      roleCheck(target == null || issue.target == target);
    }
  }
}
