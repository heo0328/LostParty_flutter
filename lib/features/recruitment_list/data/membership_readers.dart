import 'dart:convert';
import 'beta/beta_contract.dart';
import 'beta/beta_read.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import '../domain/policies/party_cycle_policy.dart';
import 'cycle_member_actions.dart' show actionTime;

const membershipReaderProfile = 'membership-actions-1';

String membershipDetailLocation(
  String room,
  String? target, {
  MembershipRecordAnchor? anchor,
}) {
  roleId(room);
  if (target != null) raidCycleKey(target);
  roleCheck(anchor == null || target != null);
  return Uri(
    path: '/recruitments/$room',
    queryParameters: {
      'reader_profile': membershipReaderProfile,
      'target_cycle_key': ?target,
      ...?anchor?.query,
    },
  ).toString();
}

Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable(
        v.map((k, x) => MapEntry(k as String, _freeze(x))),
      )
    : v is List
    ? List<dynamic>.unmodifiable(v.map(_freeze))
    : v;
Map<String, dynamic> _snapshot(Map<String, dynamic> raw) =>
    _freeze(jsonDecode(jsonEncode(raw))) as Map<String, dynamic>;
void _text(Object? value, int max, {bool nullable = false}) => roleCheck(
  nullable && value == null || value is String && value.length <= max,
);
void _revision(Object? v, {bool nullable = false}) {
  if (nullable && v == null) return;
  roleCheck(v is int && v >= 1 && v <= 2147483647);
}

void _id(Object? v, {bool nullable = false}) {
  if (nullable && v == null) return;
  roleId(v);
}

List<Map<String, dynamic>> _rows(Object? v, int max) {
  final rows = raidList(v);
  roleCheck(rows.length <= max);
  return List.unmodifiable(rows.map(roleMap));
}

/// Exact historical identity; never substitute a newly joined membership.
class MembershipRecordAnchor {
  MembershipRecordAnchor(this.membership, this.cycleMember) {
    roleId(membership);
    roleId(cycleMember);
  }
  final String membership, cycleMember;
  Map<String, String> get query => {
    'membership_id': membership,
    'cycle_member_id': cycleMember,
  };
  static MembershipRecordAnchor? fromQuery(Uri uri) {
    for (final key in [
      'target_cycle_key',
      'membership_id',
      'cycle_member_id',
      'reader_profile',
    ]) {
      roleCheck((uri.queryParametersAll[key]?.length ?? 0) <= 1);
    }
    roleCheck(
      uri.queryParameters['reader_profile'] == null ||
          uri.queryParameters['reader_profile'] == membershipReaderProfile,
    );
    final m = uri.queryParameters['membership_id'],
        c = uri.queryParameters['cycle_member_id'];
    if (m == null && c == null) return null;
    roleCheck(
      m != null && c != null && uri.queryParameters['target_cycle_key'] != null,
    );
    raidCycleKey(uri.queryParameters['target_cycle_key']);
    return MembershipRecordAnchor(m!, c!);
  }
}

class MembershipRecordLocator {
  MembershipRecordLocator(Map<String, dynamic> raw) : wire = _snapshot(raw) {
    roleShape(
      wire,
      'membership_id cycle_member_id room_cycle_id target_cycle_key target_generation',
    );
    for (final k in ['membership_id', 'cycle_member_id', 'room_cycle_id']) {
      roleId(wire[k]);
    }
    raidCycleKey(wire['target_cycle_key']);
    _revision(wire['target_generation'], nullable: true);
  }
  final Map<String, dynamic> wire;
  MembershipRecordAnchor get anchor => MembershipRecordAnchor(
    wire['membership_id'] as String,
    wire['cycle_member_id'] as String,
  );
}

class MembershipRecordSnapshot {
  MembershipRecordSnapshot(Map<String, dynamic> raw) : wire = _snapshot(raw) {
    roleShape(wire, 'locator rounds assignments schedule_segments');
    locator = MembershipRecordLocator(roleMap(wire['locator']));
    roleCheck(locator.wire['target_generation'] != null);
    rounds = _rows(wire['rounds'], 5);
    assignments = _rows(wire['assignments'], 40);
    segments = _rows(wire['schedule_segments'], 40);
    final roundIds = <String>{},
        assignmentIds = <String>{},
        segmentIds = <String>{};
    for (final r in rounds) {
      roleShape(
        r,
        'item_id round_id raid_id difficulty_id catalog_version state',
      );
      roleCheck(roundIds.add(roleId(r['round_id'])));
      roleId(r['item_id']);
      for (final k in ['raid_id', 'difficulty_id', 'catalog_version']) {
        _text(r[k], 64);
      }
      roleCheck(
        {
          'active',
          'completed',
          'stopped_incomplete',
          'legacy_ended',
        }.contains(r['state']),
      );
    }
    for (final a in assignments) {
      roleShape(
        a,
        'assignment_id item_id round_id character_id character_name raid_id difficulty_id catalog_version state completion_source completed_at ended_at',
      );
      roleCheck(assignmentIds.add(roleId(a['assignment_id'])));
      roleId(a['character_id']);
      _text(a['character_name'], 64, nullable: true);
      final r = rounds.where((r) => r['round_id'] == a['round_id']).single;
      roleCheck(
        [
          'item_id',
          'raid_id',
          'difficulty_id',
          'catalog_version',
        ].every((k) => a[k] == r[k]),
      );
      roleCheck(
        {
          'active',
          'completed',
          'left',
          'stopped_incomplete',
          'legacy_ended',
        }.contains(a['state']),
      );
      roleCheck(
        a['completion_source'] == null ||
            {'manual', 'party'}.contains(a['completion_source']),
      );
      for (final k in ['completed_at', 'ended_at']) {
        if (a[k] != null) actionTime(a[k]);
      }
    }
    for (final s in segments) {
      roleShape(s, 'segment_id round_id session_id starts_at ends_at state');
      roleCheck(
        segmentIds.add(roleId(s['segment_id'])) &&
            roundIds.contains(s['round_id']),
      );
      roleId(s['session_id']);
      roleCheck({'planned', 'released'}.contains(s['state']));
      for (final k in ['starts_at', 'ends_at']) {
        if (s[k] != null) actionTime(s[k]);
      }
      if (s['starts_at'] != null && s['ends_at'] != null) {
        roleCheck(actionTime(s['ends_at']).isAfter(actionTime(s['starts_at'])));
      }
    }
  }
  final Map<String, dynamic> wire;
  late final MembershipRecordLocator locator;
  late final List<Map<String, dynamic>> rounds, assignments, segments;
}

/// Shared projection for detail, plan and own-list entries. All maps are frozen.
class MembershipProjection {
  MembershipProjection(
    Map<String, dynamic> raw,
    String targetKey, {
    required bool entry,
  }) : wire = _snapshot(raw) {
    roleShape(
      wire,
      entry
          ? 'target viewer recovery permissions content'
          : 'target viewer access recovery permissions content record',
    );
    target = roleMap(wire['target']);
    viewer = roleMap(wire['viewer']);
    recovery = roleMap(wire['recovery']);
    permissions = roleMap(wire['permissions']);
    roleShape(
      target,
      'room_id title room_revision room_state target_cycle_key room_cycle_id target_generation target_revision target_state generation_state leadership',
    );
    roleId(target['room_id']);
    _text(target['title'], 60);
    _revision(target['room_revision']);
    roleCheck(
      target['target_cycle_key'] == targetKey &&
          {'active', 'ended'}.contains(target['room_state']),
    );
    _id(target['room_cycle_id'], nullable: true);
    for (final k in ['target_generation', 'target_revision']) {
      _revision(target[k], nullable: true);
    }
    roleCheck(
      target['target_state'] == null ||
          {
            'open',
            'review_required',
            'closed',
          }.contains(target['target_state']),
    );
    roleCheck(
      target['generation_state'] == null ||
          {
            'open',
            'review_required',
            'cancelled',
            'completed',
            'stopped',
          }.contains(target['generation_state']),
    );
    if (target['leadership'] != null) {
      final l = roleMap(target['leadership']);
      roleShape(
        l,
        'leader_cycle_member_id leader_membership_id leadership_revision',
      );
      _revision(l['leadership_revision']);
      _id(l['leader_cycle_member_id'], nullable: true);
      _id(l['leader_membership_id'], nullable: true);
      roleCheck(
        (l['leader_cycle_member_id'] == null) ==
            (l['leader_membership_id'] == null),
      );
    }
    roleShape(
      viewer,
      'membership_id membership_revision membership_state cycle_member_id cycle_member_revision cycle_member_state joined_order role mode record_locator',
    );
    roleId(viewer['membership_id']);
    _revision(viewer['membership_revision']);
    _id(viewer['cycle_member_id'], nullable: true);
    _revision(viewer['cycle_member_revision'], nullable: true);
    roleCheck(
      (viewer['cycle_member_id'] == null) ==
          (viewer['cycle_member_revision'] == null),
    );
    roleCheck(
      {'active', 'ended'}.contains(viewer['membership_state']) &&
          {'leader', 'member', 'none'}.contains(viewer['role']),
    );
    roleCheck(
      {
        'participating',
        'review_required',
        'cancelled',
        'removed',
        'completed',
        'stopped',
        'not_selected',
      }.contains(viewer['cycle_member_state']),
    );
    roleCheck(
      {
        'participant',
        'retained',
        'recovery',
        'record',
        'relation_only',
      }.contains(mode),
    );
    final order = viewer['joined_order'];
    roleCheck(
      order == null ||
          order is String &&
              order.length <= 20 &&
              RegExp(r'^[1-9][0-9]*$').hasMatch(order),
    );
    if (viewer['record_locator'] != null) {
      locator = MembershipRecordLocator(roleMap(viewer['record_locator']));
      roleCheck(
        locator!.wire['membership_id'] == viewer['membership_id'] &&
            locator!.wire['cycle_member_id'] == viewer['cycle_member_id'] &&
            locator!.wire['target_cycle_key'] == targetKey &&
            locator!.wire['room_cycle_id'] == target['room_cycle_id'] &&
            locator!.wire['target_generation'] == target['target_generation'],
      );
    }
    roleShape(
      recovery,
      'state reason revision remaining_review_reasons menu_access can_request_recovery',
    );
    roleCheck(
      {
        'none',
        'leadership_pending',
        'review_remaining',
        'unverified',
      }.contains(recovery['state']),
    );
    _text(recovery['reason'], 64, nullable: true);
    _revision(recovery['revision'], nullable: true);
    final reasons = raidList(recovery['remaining_review_reasons']);
    roleCheck(reasons.length <= 16);
    for (final r in reasons) {
      _text(r, 64);
    }
    raidBool(recovery['menu_access']);
    _permission(roleMap(recovery['can_request_recovery']));
    roleShape(
      permissions,
      'view_detail view_plan manage_target resume_weekly read_action_menu',
    );
    for (final value in permissions.values) {
      _permission(roleMap(value));
    }
    if (!entry) {
      final access = roleMap(wire['access']);
      roleShape(access, 'state basis read_only evaluated_at');
      roleCheck(
        access['state'] == 'allowed' &&
            {
              'current_membership',
              'historical_membership',
              'target_record',
            }.contains(access['basis']),
      );
      raidBool(access['read_only']);
      roleCheck(!isRecord || access['read_only'] == true);
      actionTime(access['evaluated_at']);
      if (wire['record'] != null) {
        record = MembershipRecordSnapshot(roleMap(wire['record']));
        roleCheck(
          locator != null &&
              record!.locator.wire.keys.every(
                (k) => record!.locator.wire[k] == locator!.wire[k],
              ),
        );
      }
      roleCheck(isRecord == (record != null));
    }
    if (wire['content'] != null) content = roleMap(wire['content']);
    if (isRecord) {
      roleCheck(content == null && locator != null && viewer['role'] == 'none');
    }
    if (isRecord) {
      for (final k in ['manage_target', 'resume_weekly', 'read_action_menu']) {
        roleCheck(!allowed(k));
      }
      roleCheck(recovery['menu_access'] == false);
    }
    if (mode == 'relation_only') {
      roleCheck(
        viewer['cycle_member_id'] == null &&
            locator == null &&
            viewer['role'] == 'none',
      );
    }
  }
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> target, viewer, recovery, permissions;
  MembershipRecordLocator? locator;
  MembershipRecordSnapshot? record;
  Map<String, dynamic>? content;
  String get room => target['room_id'] as String;
  String get mode => viewer['mode'] as String;
  bool get isRecord => mode == 'record';
  bool get readOnly => isRecord || wire['access']?['read_only'] == true;
  bool allowed(String key) => permissions[key]['allowed'] == true;
  bool get canReadMenu =>
      !isRecord &&
      recovery['menu_access'] == true &&
      allowed('read_action_menu');
  (String, String, String?) get identity => (
    target['target_cycle_key'] as String,
    viewer['membership_id'] as String,
    viewer['cycle_member_id'] as String?,
  );
}

void _permission(Map<String, dynamic> p) {
  roleShape(p, 'allowed reason next_change_at');
  raidBool(p['allowed']);
  _text(p['reason'], 64, nullable: true);
  if (p['next_change_at'] != null) actionTime(p['next_change_at']);
  roleCheck(p['allowed'] != true || p['reason'] == null);
}

Map<String, dynamic> _scope(
  Map<String, dynamic> wire,
  String target,
  String kind, {
  bool anchored = false,
}) {
  final s = roleMap(wire['scope']);
  roleShape(
    s,
    'server_now current_cycle_key target_cycle_key policy_version reader_kind',
  );
  final now = actionTime(s['server_now']),
      c = raidCycleKey(s['current_cycle_key']);
  const policy = PartyCyclePolicy();
  raidCycleKey(target);
  roleCheck(
    policy.keyFor(now) == c &&
        s['target_cycle_key'] == target &&
        s['policy_version'] == membershipReaderProfile &&
        s['reader_kind'] == kind,
  );
  if (!anchored) {
    roleCheck(
      target == c || target == policy.keyFor(policy.fromKey(c)!.endsAt),
    );
  }
  return s;
}

class MembershipReadView {
  Map<String, dynamic>? betaData;
  MembershipReadView(
    this.room,
    this.target,
    this.kind,
    Map<String, dynamic> raw, {
    MembershipRecordAnchor? anchor,
  }) : wire = _snapshot(raw) {
    roleShape(wire, 'scope data');
    roleCheck({'detail', 'plan'}.contains(kind));
    roleId(room);
    scope = _scope(wire, target, kind, anchored: anchor != null);
    projection = MembershipProjection(
      roleMap(wire['data']),
      target,
      entry: false,
    );
    roleCheck(projection.room == room);
    roleCheck(
      projection.allowed(kind == 'detail' ? 'view_detail' : 'view_plan'),
    );
    if (anchor != null) {
      roleCheck(
        projection.isRecord &&
            projection.viewer['membership_id'] == anchor.membership &&
            projection.viewer['cycle_member_id'] == anchor.cycleMember,
      );
    }
    final content = projection.content;
    if (content != null) {
      roleShape(content, 'scope data');
      final cs = roleMap(content['scope']), cd = roleMap(content['data']);
      roleCheck(
        cs['target_cycle_key'] == target &&
            cs['current_cycle_key'] == scope['current_cycle_key'],
      );
      for (final k in [
        'room_cycle_id',
        'target_generation',
        'target_revision',
      ]) {
        roleCheck(cs[k] == projection.target[k]);
      }
      if (kind == 'detail') {
        roleCheck(
          cd['room']['room_id'] == room &&
              cd['my_target_role'] == projection.viewer['role'],
        );
      }
      if (kind == 'plan') {
        roleCheck(
          cd['room_id'] == room &&
              cd['my_target_role'] == projection.viewer['role'],
        );
      }
    }
  }
  final String room, target, kind;
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope;
  late final MembershipProjection projection;
}

class MembershipReadPage {
  MembershipReadPage(String target, Map<String, dynamic> raw) {
    final wire = _snapshot(raw);
    roleShape(wire, 'scope data');
    _scope(wire, target, 'memberships');
    final data = roleMap(wire['data']);
    roleShape(data, 'items membership_head next_cursor evaluated_at');
    _revision(data['membership_head']);
    actionTime(data['evaluated_at']);
    items = List.unmodifiable(
      _rows(
        data['items'],
        50,
      ).map((r) => MembershipProjection(r, target, entry: true)),
    );
    roleCheck(items.map((r) => r.identity).toSet().length == items.length);
    final value = data['next_cursor'];
    roleCheck(
      value == null ||
          value is String &&
              value.isNotEmpty &&
              value.length <= 2048 &&
              items.isNotEmpty,
    );
    cursor = value as String?;
  }
  late final List<MembershipProjection> items;
  late final String? cursor;
}

abstract interface class MembershipReadGateway {
  Future<MembershipReadView> detail(
    String room,
    String target, {
    MembershipRecordAnchor? anchor,
    bool includeCoordinationWait = false,
  });
  Future<MembershipReadView> plan(
    String room,
    String target, {
    MembershipRecordAnchor? anchor,
    bool includeCoordinationWait = false,
  });
}

class MembershipReadRepository implements MembershipReadGateway {
  MembershipReadRepository(
    this.api, {
    this.contractMode = RecruitmentContractMode.legacy,
    this.includeGroupState = false,
  });
  final RecruitmentContractMode contractMode;
  final bool includeGroupState;
  final BackendRegistrationApi api;
  Future<MembershipReadView> _read(
    String room,
    String target,
    String kind,
    MembershipRecordAnchor? anchor,
    bool includeCoordinationWait,
  ) async {
    try {
      roleId(room);
      raidCycleKey(target);
      final path = kind == 'detail'
          ? '/v2/raid-rooms/$room/detail'
          : '/v2/me/raid-rooms/$room/plan';
      final result = await readRecruitment(
        api: api,
        mode: contractMode,
        path: path,
        includeGroupState: includeGroupState,
        query: {
          'target_cycle_key': target,
          'reader_profile': membershipReaderProfile,
          if (includeCoordinationWait &&
              anchor == null &&
              contractMode == RecruitmentContractMode.betaWire2)
            'include_coordination_wait': 'true',
          ...?anchor?.query,
        },
        parse: (raw) =>
            MembershipReadView(room, target, kind, raw, anchor: anchor),
      );
      final schedule = result.metadata?['beta_schedule'];
      if (includeCoordinationWait &&
          anchor == null &&
          contractMode == RecruitmentContractMode.betaWire2 &&
          schedule != null) {
        roleCheck(schedule is Map && schedule.containsKey('coordination_wait'));
      }
      return result.value..betaData = betaDisplayData(result.metadata);
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    } on StateError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  @override
  Future<MembershipReadView> detail(
    String room,
    String target, {
    MembershipRecordAnchor? anchor,
    bool includeCoordinationWait = false,
  }) => _read(room, target, 'detail', anchor, includeCoordinationWait);
  @override
  Future<MembershipReadView> plan(
    String room,
    String target, {
    MembershipRecordAnchor? anchor,
    bool includeCoordinationWait = false,
  }) => _read(room, target, 'plan', anchor, includeCoordinationWait);
}
