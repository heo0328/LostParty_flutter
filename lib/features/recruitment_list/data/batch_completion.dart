import 'dart:convert';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/role_summary.dart';
import 'beta/beta_contract.dart';
import 'beta/cycle_group_policy.dart';
import 'cycle_member_actions.dart' show actionTime;
import 'cycle_read_repository.dart';
import 'cycle_schedule.dart';

enum BatchCompletionKind {
  party,
  personalDeparture;

  String get action => this == party
      ? 'batch_completion'
      : 'batch_personal_completion_departure';
  String get uiAction =>
      this == party ? 'complete_item' : 'personal_completion';
  String get suffix => this == party
      ? 'batch-completions'
      : 'batch-personal-completion-departures';
  String get contextSuffix => this == party
      ? 'batch-completion-context'
      : 'batch-personal-completion-departure-context';
  String get contextSchema =>
      this == party ? 'BatchPartyContext' : 'BatchPersonalContext';
  String get ackSchema => this == party ? 'BatchPartyAck' : 'BatchPersonalAck';
}

BatchCompletionKind batchKind(String action) =>
    BatchCompletionKind.values.singleWhere((k) => k.action == action);

bool isBatchCompletionPath(String path) => BatchCompletionKind.values.any(
  (k) => RegExp('^/v2/raid-rooms/[^/]+/${k.suffix}\$').hasMatch(path),
);

List<String> batchRoundIds(Iterable<String> values) {
  final ids = values.map(roleId).toList();
  roleCheck(
    ids.isNotEmpty && ids.length <= 5 && ids.toSet().length == ids.length,
  );
  return List.unmodifiable(ids..sort());
}

List<String> _ids(Object? raw) {
  final ids = raidList(raw).map(roleId).toList();
  roleCheck(ids.toSet().length == ids.length);
  roleCheck(scheduleStable(ids) == scheduleStable([...ids]..sort()));
  return ids;
}

void _same(Object? a, Object? b) =>
    roleCheck(scheduleStable(a) == scheduleStable(b));
void _setSame(Iterable<String> a, Iterable<String> b) =>
    _same(a.toList()..sort(), b.toList()..sort());

void _history(Map<String, dynamic> h) {
  const BetaContract().validateDefinition('BatchHistory', h);
  final raids = raidList(h['raids']).map(roleMap).toList();
  final ids = raids.map((r) => r['raid_id'] as String).toList();
  roleCheck(ids.toSet().length == ids.length);
  _same(ids, [...ids]..sort());
  roleCheck(
    raids.fold<int>(0, (n, r) => n + (r['assignment_count'] as int)) ==
        h['assignment_count'],
  );
  if (h['assignment_count'] == 0) {
    roleCheck(
      raids.isEmpty &&
          h['digest'] ==
              '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945',
    );
  }
}

Map<String, int> _revisions(Object? raw) {
  final out = <String, int>{};
  final order = <String>[];
  for (final v in raidList(raw)) {
    final r = roleMap(v);
    const BetaContract().validateDefinition('BatchRevision', r);
    final key = '${r['resource']}/${r['id']}';
    roleCheck(!out.containsKey(key));
    out[key] = r['revision'] as int;
    order.add(key);
  }
  _same(order, [...order]..sort());
  return out;
}

abstract interface class CycleBatchCompletionGateway {
  bool get batchCompletionEnabled;
  Future<BatchCompletionPreview> batchCompletion(
    String room,
    String target,
    BatchCompletionKind kind,
    List<String> rounds,
  );
  Future<void> writeBatchCompletion(
    BatchCompletionPreview preview,
    String key,
    Map<String, dynamic> body,
  );
}

/// A server-owned, immutable selection and effect snapshot; never reconstructed
/// from the mutable checkboxes after a command has been saved.
class BatchCompletionPreview {
  BatchCompletionPreview(
    this.room,
    this.target,
    this.kind,
    Iterable<String> selected,
    Map<String, dynamic> raw, {
    Map<String, dynamic>? metadata,
  }) : wire = betaFreeze(raw) as Map<String, dynamic>,
       groupEffects = List.unmodifiable(cycleGroupEffects(metadata)) {
    const BetaContract().validateDefinition(kind.contextSchema, wire);
    scope = roleMap(wire['scope']);
    data = roleMap(wire['data']);
    CycleReadScope(scope, target);
    roleId(room);
    roleCheck(data['room_id'] == room && data['action'] == kind.action);
    rounds = _ids(data['round_ids']);
    _same(rounds, batchRoundIds(selected));
    impact = roleMap(data['impact']);
    _history(roleMap(impact['preserved_completed']));
    permission = CyclePermission.fromJson(roleMap(data['permission']));
    final display = roleMap(data['display']);
    displayRounds = raidList(display['rounds']).map(roleMap).toList();
    assignments = raidList(display['assignments']).map(roleMap).toList();
    final shownIds = assignments
        .map((a) => roleId(a['assignment_id']))
        .toList();
    roleCheck(shownIds.toSet().length == shownIds.length);
    _same(shownIds, [...shownIds]..sort());
    final mapped = displayRounds.map((r) => roleId(r['round_id'])).toList();
    roleCheck(mapped.toSet().length == mapped.length);
    _same(mapped, [...mapped]..sort());
    _setSame(mapped, assignments.map((a) => roleId(a['round_id'])).toSet());
    _setSame(
      rounds,
      assignments
          .where((a) => a['effect'] == 'complete')
          .map((a) => roleId(a['round_id']))
          .toSet(),
    );
    final all = <String>{};
    for (final pair in const [
      ('complete', 'completed_assignment_ids'),
      ('cancel', 'cancelled_assignment_ids'),
      ('preserve_active', 'preserved_active_assignment_ids'),
    ]) {
      final ids = _ids(impact[pair.$2]);
      roleCheck(ids.every(all.add));
      _setSame(
        ids,
        assignments
            .where((a) => a['effect'] == pair.$1)
            .map((a) => roleId(a['assignment_id'])),
      );
    }
    roleCheck(all.length == assignments.length);
    if (kind == BatchCompletionKind.personalDeparture) {
      roleCheck(
        assignments.length <= 5 &&
            assignments.every(
              (a) => a['cycle_member_id'] == data['actor_cycle_member_id'],
            ),
      );
    }
    final before = _revisions(data['revisions']);
    final cycle = scope['room_cycle_id'];
    for (final resource in ['target', 'members', 'plan', 'leadership']) {
      roleCheck(before.containsKey('$resource/$cycle'));
    }
    roleCheck(before['target/$cycle'] == scope['target_revision']);
    roleCheck(
      before['leadership/$cycle'] == data['leadership']['leadership_revision'],
    );
    roleCheck(
      before['cycle_membership/${data['actor_cycle_member_id']}'] ==
          data['actor_cycle_member_revision'],
    );
    final changed = assignments
        .where((a) => a['effect'] != 'preserve_active')
        .toList();
    _setSame(
      before.keys.where((k) => k.startsWith('assignment/')),
      changed.map((a) => 'assignment/${a['assignment_id']}'),
    );
    _setSame(
      before.keys.where((k) => k.startsWith('cycle_membership/')),
      <String>{
        'cycle_membership/${data['actor_cycle_member_id']}',
        ...changed.map((a) => 'cycle_membership/${a['cycle_member_id']}'),
      },
    );
    final dep = data['departure'];
    final closing =
        dep is Map && (dep['effect'] as String).startsWith('close_');
    final roundKeys = before.keys.where((k) => k.startsWith('round/')).toSet();
    if (kind == BatchCompletionKind.personalDeparture && closing) {
      // Closing also changes active rounds with no remaining own assignment.
      // Bind the full set to the plan below; display only maps active effects.
      roleCheck(roundKeys.length <= 5 && roundKeys.isNotEmpty);
      roleCheck(mapped.every((r) => roundKeys.contains('round/$r')));
    } else {
      _setSame(
        roundKeys,
        (kind == BatchCompletionKind.party ? rounds : <String>[]).map(
          (r) => 'round/$r',
        ),
      );
    }
    roleCheck(
      permission.allowed == (data['confirmation'] != null) &&
          permission.allowed == (data['expected_after'] != null),
    );
    if (permission.allowed) {
      roleCheck(
        permission.reason == null && target == scope['current_cycle_key'],
      );
      roleCheck(
        !actionTime(
          scope['server_now'],
        ).isBefore(actionTime(scope['playable_from'])),
      );
      final conf = roleMap(data['confirmation']);
      final issued = actionTime(conf['issued_at']),
          expires = actionTime(conf['expires_at']);
      roleCheck(
        issued == actionTime(scope['server_now']) &&
            expires.isAfter(issued) &&
            expires.difference(issued) <= const Duration(seconds: 120),
      );
      roleCheck(utf8.encode(conf['context_token'] as String).length <= 4096);
      final end = DateTime.parse(
        '${scope['current_cycle_key']}T00:00:00Z',
      ).add(const Duration(days: 7)).subtract(const Duration(hours: 3));
      roleCheck(!expires.isAfter(end));
      if (kind == BatchCompletionKind.party) {
        roleCheck(
          data['leadership']['leader_cycle_member_id'] ==
              data['actor_cycle_member_id'],
        );
      }
      if (dep is Map && dep['effect'] == 'automatic_successor') {
        roleCheck(dep['successor'] != null);
      }
    }
    signature = scheduleStable({
      'scope': scope,
      'data': {
        for (final e in data.entries)
          if (e.key != 'confirmation') e.key: e.value,
      },
      'group_effects': groupEffects,
      'group_policy': metadata?['group_policy'],
    });
  }
  final String room, target;
  final BatchCompletionKind kind;
  final Map<String, dynamic> wire;
  final List<Map<String, dynamic>> groupEffects;
  late final Map<String, dynamic> scope, data, impact;
  late final List<String> rounds;
  late final List<Map<String, dynamic>> displayRounds, assignments;
  late final CyclePermission permission;
  late final String signature;
  String get path => '/v2/raid-rooms/$room/${kind.suffix}';
  void bindPlan(CycleScheduleView plan) {
    if (plan.room != room || plan.target != target) {
      throw const AccountReadException('REVISION_CONFLICT');
    }
    final mine = roleMap(plan.data['my_membership']);
    for (final k in ['room_cycle_id', 'target_generation', 'target_revision']) {
      if (scope[k] != plan.scope[k]) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
    }
    if (data['actor_cycle_member_id'] != mine['cycle_member_id'] ||
        data['actor_cycle_member_revision'] != mine['cycle_member_revision']) {
      throw const AccountReadException('REVISION_CONFLICT');
    }
    final departure = data['departure'];
    if (kind == BatchCompletionKind.personalDeparture &&
        departure != null &&
        (departure['effect'] as String).startsWith('close_')) {
      final expected =
          (plan.data['game_items'] as List)
              .where((item) => item['round_state'] == 'active')
              .map((item) => 'round/${item['round_id']}')
              .toList()
            ..sort();
      final actual = _revisions(
        data['revisions'],
      ).keys.where((k) => k.startsWith('round/')).toList()..sort();
      if (scheduleStable(actual) != scheduleStable(expected)) {
        throw const AccountReadException('REVISION_CONFLICT');
      }
    }
  }

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
      'actor_cycle_member_id': data['actor_cycle_member_id'],
      'expected_cycle_member_revision': data['actor_cycle_member_revision'],
      'round_ids': rounds,
      'context_token': data['confirmation']['context_token'],
    };
  }
}

/// Minimal frozen ACK expectations. No display snapshot or signed token is stored
/// here; the exact token remains only in the original command body.
class BatchCompletionAckEvidence {
  BatchCompletionAckEvidence(Map<String, dynamic> raw)
    : wire = betaFreeze(raw) as Map<String, dynamic> {
    roleShape(
      wire,
      'room target kind scope actor rounds impact departure leadership expected_after revisions confirmation',
    );
    roleId(room);
    raidCycleKey(target);
    CycleReadScope(scope, target);
    _same(rounds, batchRoundIds(rounds));
    roleShape(actor, 'id revision changes');
    roleId(actor['id']);
    rolePositive(actor['revision']);
    roleCheck(actor['changes'] is bool);
    const BetaContract().validateDefinition(
      kind == BatchCompletionKind.party
          ? 'BatchPartyImpact'
          : 'BatchPersonalImpact',
      wire['impact'],
    );
    _history(roleMap(impact['preserved_completed']));
    const BetaContract().validateDefinition(
      'BatchExpectedAfter',
      wire['expected_after'],
    );
    _revisions(wire['revisions']);
    roleShape(roleMap(wire['confirmation']), 'issued_at expires_at');
    actionTime(wire['confirmation']['issued_at']);
    actionTime(wire['confirmation']['expires_at']);
  }
  factory BatchCompletionAckEvidence.fromPreview(BatchCompletionPreview p) =>
      BatchCompletionAckEvidence({
        'room': p.room,
        'target': p.target,
        'kind': p.kind.action,
        'scope': p.scope,
        'actor': {
          'id': p.data['actor_cycle_member_id'],
          'revision': p.data['actor_cycle_member_revision'],
          'changes': p.assignments.any(
            (a) =>
                a['cycle_member_id'] == p.data['actor_cycle_member_id'] &&
                a['effect'] != 'preserve_active',
          ),
        },
        'rounds': p.rounds,
        'impact': p.impact,
        'departure': p.data['departure'],
        'leadership': p.data['leadership'],
        'expected_after': p.data['expected_after'],
        'revisions': p.data['revisions'],
        'confirmation': {
          for (final k in ['issued_at', 'expires_at'])
            k: p.data['confirmation'][k],
        },
      });
  final Map<String, dynamic> wire;
  String get room => wire['room'];
  String get target => wire['target'];
  BatchCompletionKind get kind => batchKind(wire['kind']);
  Map<String, dynamic> get scope => roleMap(wire['scope']);
  Map<String, dynamic> get actor => roleMap(wire['actor']);
  Map<String, dynamic> get impact => roleMap(wire['impact']);
  List<String> get rounds => raidList(wire['rounds']).cast<String>();
  String get path => '/v2/raid-rooms/$room/${kind.suffix}';
  void bindBody(Map<String, dynamic> body) {
    _same(body['round_ids'], rounds);
    roleCheck(
      body['expected_cycle_key'] == scope['current_cycle_key'] &&
          body['target_cycle_key'] == target &&
          body['room_cycle_id'] == scope['room_cycle_id'] &&
          body['target_generation'] == scope['target_generation'] &&
          body['expected_target_revision'] == scope['target_revision'] &&
          body['actor_cycle_member_id'] == actor['id'] &&
          body['expected_cycle_member_revision'] == actor['revision'],
    );
  }

  /// The pinned batch successor ACK retains a nullable predicted effect revision.
  /// Its own policy metadata proves the actual revision; never use a later GET
  /// or rewrite the stored ACK to fill it in.
  void validateGroupEffects(
    List<Map<String, dynamic>> expected,
    Map<String, dynamic> raw,
  ) {
    final actual = cycleGroupEffects(raw);
    roleCheck(actual.length == expected.length);
    for (final effect in expected) {
      roleCheck(
        effect['room_id'] == room &&
            effect['target_cycle_key'] == target &&
            effect['room_cycle_id'] == scope['room_cycle_id'] &&
            effect['generation'] == scope['target_generation'],
      );
      final matches = actual
          .where(
            (v) => const [
              'room_id',
              'target_cycle_key',
              'room_cycle_id',
              'generation',
            ].every((k) => v[k] == effect[k]),
          )
          .toList();
      roleCheck(matches.length == 1);
      final value = matches.single;
      var proven = value;
      final after = roleMap(value['after']);
      if (after['revision'] == null) {
        roleCheck(
          kind == BatchCompletionKind.personalDeparture &&
              wire['departure']?['effect'] == 'automatic_successor',
        );
        final policy = CycleGroupPolicy(roleMap(raw['group_policy']));
        policy.bind(room, target, scope);
        roleCheck(policy.known);
        for (final k in ['scope', 'group_id']) {
          _same(policy.wire[k], after[k]);
        }
        final before = roleMap(value['before']);
        final changed =
            before['scope'] != after['scope'] ||
            before['group_id'] != after['group_id'];
        roleCheck(
          policy.wire['revision'] ==
              rolePositive(before['revision']) + (changed ? 1 : 0),
        );
        proven = {
          ...value,
          'after': {...after, 'revision': policy.wire['revision']},
        };
      }
      CycleGroupEffect(effect).validateAck(proven);
    }
  }

  void validate(Map<String, dynamic> raw, String key) {
    const BetaContract().validateDefinition(kind.ackSchema, raw);
    final s = roleMap(raw['scope']), d = roleMap(raw['data']);
    CycleReadScope(s, target);
    for (final k in [
      'current_cycle_key',
      'target_cycle_key',
      'room_cycle_id',
      'target_generation',
      'policy_version',
      'phase',
      'playable_from',
    ]) {
      if (k == 'playable_from') {
        roleCheck(actionTime(s[k]) == actionTime(scope[k]));
      } else {
        _same(s[k], scope[k]);
      }
    }
    roleCheck(
      d['command_id'] == key &&
          d['action'] == kind.action &&
          d['room_id'] == room &&
          d['actor_cycle_member_id'] == actor['id'] &&
          d['outcome'] == 'applied',
    );
    _same(d['round_ids'], rounds);
    _same(d['impact'], impact);
    _same(d['departure'], wire['departure']);
    _same(d['state'], wire['expected_after']['state']);
    final lead = roleMap(d['leadership']),
        beforeLead = roleMap(wire['leadership']);
    for (final k in ['leader_cycle_member_id', 'leader_membership_id']) {
      _same(lead[k], wire['expected_after'][k]);
    }
    final changedLeader =
        lead['leader_cycle_member_id'] !=
            beforeLead['leader_cycle_member_id'] ||
        lead['leader_membership_id'] != beforeLead['leader_membership_id'];
    roleCheck(
      lead['leadership_revision'] ==
          (beforeLead['leadership_revision'] as int) + (changedLeader ? 1 : 0),
    );
    final before = _revisions(wire['revisions']),
        after = _revisions(d['revisions']);
    _setSame(before.keys, after.keys);
    final cycle = scope['room_cycle_id'];
    roleCheck(
      after['target/$cycle'] == s['target_revision'] &&
          after['leadership/$cycle'] == lead['leadership_revision'],
    );
    for (final e in before.entries) {
      if (e.key.startsWith('leadership/')) continue;
      // A party leader may have no active assignment in the selected rounds.
      if (e.key == 'cycle_membership/${actor['id']}' &&
          kind == BatchCompletionKind.party) {
        roleCheck(
          actor['changes'] == true
              ? after[e.key]! > e.value
              : after[e.key] == e.value,
        );
      } else {
        roleCheck(after[e.key]! > e.value);
      }
    }
    final executed = actionTime(d['executed_at']);
    roleCheck(
      executed == actionTime(s['server_now']) &&
          !executed.isBefore(actionTime(wire['confirmation']['issued_at'])) &&
          executed.isBefore(actionTime(wire['confirmation']['expires_at'])),
    );
  }
}
