import '../../account/data/backend_account_read_api.dart';
import 'beta/beta_contract.dart';
import 'beta/beta_read.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import 'membership_readers.dart';

class CycleReadScope {
  CycleReadScope(Map<String, dynamic> j, String target) {
    roleShape(
      j,
      'server_now current_cycle_key target_cycle_key playable_from phase target_revision policy_version room_cycle_id target_generation',
    );
    final now = roleUtc(j['server_now']);
    roleUtc(j['playable_from']);
    final current = raidCycleKey(j['current_cycle_key']);
    final start = DateTime.parse(
      '${current}T06:00:00Z',
    ).subtract(const Duration(hours: 9));
    final next = DateTime.parse(
      '${current}T00:00:00Z',
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    roleCheck(
      !now.isBefore(start) &&
          now.isBefore(start.add(const Duration(days: 7))) &&
          (target == current || target == next) &&
          j['phase'] == (target == current ? 'current' : 'future'),
    );
    roleCheck(
      raidCycleKey(j['target_cycle_key']) == target &&
          j['policy_version'] == twoCyclePolicy &&
          {'current', 'future'}.contains(j['phase']),
    );
    for (final k in ['target_revision', 'target_generation']) {
      if (j[k] != null) rolePositive(j[k]);
    }
    if (j['room_cycle_id'] != null) roleId(j['room_cycle_id']);
  }
}

class CycleRoomCard {
  Map<String, dynamic>? betaData;
  CycleRoomCard(Map<String, dynamic> j, String target)
    : wire = Map.unmodifiable(j) {
    roleShape(
      j,
      'room_id revision title scope group_id admission_mode experience_level app_capacity app_member_count state items game_items leader_display created_at phase restricted schedule_summary combat_requirement continuation_enabled permissions leadership my_target_role target_cycle_key target_state target_revision room_cycle_id target_generation',
    );
    id = roleId(j['room_id']);
    title = raidText(j['title']);
    roleCheck(raidCycleKey(j['target_cycle_key']) == target);
    roleId(j['room_cycle_id']);
    rolePositive(j['target_generation']);
    rolePositive(j['target_revision']);
    rolePositive(j['revision']);
    roleCheck(
      {'public', 'group'}.contains(j['scope']) &&
          {'leader_only', 'direct_join'}.contains(j['admission_mode']) &&
          {'active', 'ended'}.contains(j['state']) &&
          {'current', 'future', 'ended'}.contains(j['phase']) &&
          {'leader', 'member', 'none'}.contains(j['my_target_role']),
    );
    if (j['group_id'] != null) roleId(j['group_id']);
    roleUtc(j['created_at']);
    raidBool(j['restricted']);
    raidBool(j['continuation_enabled']);
    final leadership = roleMap(j['leadership']);
    roleShape(
      leadership,
      'leader_cycle_member_id leadership_revision leader_membership_id',
    );
    rolePositive(leadership['leadership_revision']);
    for (final key in ['leader_cycle_member_id', 'leader_membership_id']) {
      if (leadership[key] != null) roleId(leadership[key]);
    }
    capacity = rolePositive(j['app_capacity']);
    count = raidNonnegative(j['app_member_count']);
    roleCheck({4, 8}.contains(capacity) && count <= capacity);
    final p = roleMap(j['permissions']);
    roleShape(p, 'view_detail view_plan');
    canView = CyclePermission.fromJson(roleMap(p['view_detail'])).allowed;
    CyclePermission.fromJson(roleMap(p['view_plan']));
    items = raidList(j['items'])
        .map((v) {
          final item = roleMap(v);
          roleShape(
            item,
            'item_id raid_id difficulty_id game_party_size round_id',
          );
          roleId(item['item_id']);
          roleId(item['round_id']);
          raidIdentifier(item['raid_id']);
          raidIdentifier(item['difficulty_id']);
          return Map<String, dynamic>.unmodifiable(item);
        })
        .toList(growable: false);
    final schedule = roleMap(j['schedule_summary']);
    starts = raidList(
      schedule['confirmed_starts_at'],
    ).map(roleUtc).toList(growable: false);
  }
  final Map<String, dynamic> wire;
  late final String id, title;
  late final int capacity, count;
  late final bool canView;
  late final List<Map<String, dynamic>> items;
  late final List<DateTime> starts;
}

class CycleOwnRow {
  Map<String, dynamic>? betaData;
  CycleOwnRow.profile(this.profile, String target) {
    final p = profile!;
    id = p.viewer['membership_id'] as String;
    roomId = p.room;
    state = p.viewer['membership_state'] == 'ended' ? 'ended' : 'current';
    participationState = p.viewer['cycle_member_state'] as String;
    historyOnly = p.isRecord;
    recoveryOnly = p.mode == 'recovery';
    canView = p.allowed('view_detail');
    if (p.content != null) {
      final legacy = CycleOwnRow(p.content!, target, false);
      roleCheck(
        legacy.id == id &&
            legacy.roomId == roomId &&
            p.content!['cycle_member_id'] == p.viewer['cycle_member_id'] &&
            p.content!['target_generation'] == p.target['target_generation'],
      );
      card = legacy.card;
    }
  }
  CycleOwnRow(Map<String, dynamic> j, String target, bool application) {
    if (application) {
      applicationData = Map.unmodifiable(j);
      roleShape(
        j,
        'application_id room_id revision state created_at expires_at ended_at character_id selected_role display admission_origin target_cycle_key target_generation',
      );
      id = roleId(j['application_id']);
      roomId = roleId(j['room_id']);
      roleId(j['character_id']);
      rolePositive(j['target_generation']);
      roleCheck(
        {
          'pending',
          'accepted',
          'rejected',
          'withdrawn',
          'expired',
          'cancelled',
        }.contains(j['state']),
      );
      canView = true;
    } else {
      roleShape(
        j,
        'membership_id revision room_id state joined_at ended_at assignments room recovery_only history_only permissions target_role cycle_member_id cycle_member_revision joined_order target_participation_state target_cycle_key room_cycle_id target_generation target_revision',
      );
      id = roleId(j['membership_id']);
      roomId = roleId(j['room_id']);
      participationState = raidText(j['target_participation_state']);
      recoveryOnly = raidBool(j['recovery_only']);
      historyOnly = raidBool(j['history_only']);
      roleCheck({'current', 'ended'}.contains(j['state']));
      roleCheck({'leader', 'member', 'none'}.contains(j['target_role']));
      final permissions = roleMap(j['permissions']);
      roleShape(permissions, 'view_plan');
      final plan = CyclePermission.fromJson(roleMap(permissions['view_plan']));
      roleCheck(
        {
          'participating',
          'completed',
          'stopped',
          'cancelled',
          'legacy_intent',
          'not_selected',
          'review_required',
        }.contains(participationState),
      );
      if (j['room'] != null) card = CycleRoomCard(roleMap(j['room']), target);
      if (card != null) {
        roleCheck(
          card!.id == roomId &&
              card!.wire['target_generation'] == j['target_generation'],
        );
        for (final k in ['room_cycle_id', 'target_revision']) {
          if (j[k] != null) roleCheck(card!.wire[k] == j[k]);
        }
      }
      canView = card?.canView == true;
      if (recoveryOnly) {
        roleCheck(
          card == null &&
              j['target_generation'] == null &&
              j['joined_order'] == null &&
              j['target_role'] == 'none' &&
              participationState == 'review_required' &&
              raidList(j['assignments']).isEmpty &&
              j['room_cycle_id'] != null &&
              j['target_revision'] != null &&
              j['cycle_member_id'] != null &&
              j['cycle_member_revision'] != null &&
              !plan.allowed &&
              plan.reason == 'ROOM_REVIEW_REQUIRED',
        );
      }
      for (final k in ['cycle_member_id', 'room_cycle_id']) {
        if (j[k] != null) roleId(j[k]);
      }
      for (final k in [
        'cycle_member_revision',
        'target_generation',
        'target_revision',
      ]) {
        if (j[k] != null) rolePositive(j[k]);
      }
      if (j['joined_order'] != null) {
        final order = raidText(j['joined_order']);
        roleCheck(
          RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(order) &&
              BigInt.parse(order) <= BigInt.parse('9223372036854775807'),
        );
      }
    }
    roleCheck(raidCycleKey(j['target_cycle_key']) == target);
    rolePositive(j['revision']);
    state = raidText(j['state']);
  }
  late final String id, roomId, state;
  Map<String, dynamic>? applicationData;
  MembershipProjection? profile;
  Object get identity => profile?.identity ?? id;
  String? get title => profile?.target['title'] as String? ?? card?.title;
  String? participationState;
  bool recoveryOnly = false, historyOnly = false;
  CycleRoomCard? card;
  late final bool canView;
  bool get isActiveParticipation => profile != null
      ? !profile!.isRecord &&
            profile!.viewer['membership_state'] == 'active' &&
            {'participating', 'review_required'}.contains(participationState) &&
            {
              'open',
              'review_required',
            }.contains(profile!.target['target_state'])
      : state == 'current' &&
            !historyOnly &&
            (participationState == 'participating' ||
                participationState == 'review_required') &&
            (recoveryOnly ||
                (card != null &&
                    card!.wire['state'] == 'active' &&
                    {
                      'open',
                      'review_required',
                    }.contains(card!.wire['target_state'])));
  bool get isEndedParticipation =>
      state == 'ended' ||
      historyOnly ||
      card?.wire['state'] == 'ended' ||
      {
        'completed',
        'stopped',
        'cancelled',
        'removed',
      }.contains(participationState);
}

class CycleOwnPage {
  CycleOwnPage.profile(String target, Map<String, dynamic> raw) {
    final page = MembershipReadPage(target, raw);
    rows = List.unmodifiable(
      page.items.map((p) => CycleOwnRow.profile(p, target)),
    );
    cursor = page.cursor;
  }
  CycleOwnPage(Map<String, dynamic> j, String target, bool application) {
    roleShape(j, 'scope data');
    CycleReadScope(roleMap(j['scope']), target);
    final d = roleMap(j['data']);
    roleShape(
      d,
      application
          ? 'items applications_revision next_cursor evaluated_at'
          : 'items membership_head next_cursor evaluated_at',
    );
    rolePositive(d[application ? 'applications_revision' : 'membership_head']);
    roleUtc(d['evaluated_at']);
    rows = raidList(d['items'])
        .map((v) => CycleOwnRow(roleMap(v), target, application))
        .toList(growable: false);
    roleCheck(
      rows.length <= 20 && rows.map((r) => r.id).toSet().length == rows.length,
    );
    cursor = d['next_cursor'] as String?;
    roleCheck(
      cursor == null ||
          (cursor!.isNotEmpty && cursor!.length <= 2048 && rows.isNotEmpty),
    );
  }
  late final List<CycleOwnRow> rows;
  late final String? cursor;
}

class CycleReadRepository {
  CycleReadRepository(
    this.api, {
    this.membershipProfile = false,
    this.contractMode = RecruitmentContractMode.legacy,
  });
  final RecruitmentContractMode contractMode;
  final DioBackendAccountReadApi api;
  final bool membershipProfile;
  Future<T> _read<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<CycleOwnPage> own(
    String target, {
    bool applications = false,
    bool history = false,
    String? cursor,
  }) => _read(() async {
    raidCycleKey(target);
    final result = await readRecruitment(
      api: api,
      mode: contractMode,
      path: applications
          ? '/v2/me/raid-room-applications'
          : '/v2/me/raid-room-memberships',
      query: {
        'target_cycle_key': target,
        'state': applications
            ? 'pending'
            : history
            ? 'ended'
            : 'current',
        'limit': 20,
        'cursor': ?cursor,
        if (membershipProfile && !applications)
          'reader_profile': membershipReaderProfile,
      },
      parse: (j) => membershipProfile && !applications
          ? CycleOwnPage.profile(target, j)
          : CycleOwnPage(j, target, applications),
    );
    if (result.metadata != null) {
      final items = result.metadata!['items'] as List;
      for (var i = 0; i < result.value.rows.length; i++) {
        final row = result.value.rows[i];
        row.betaData = betaDisplayData(roleMap(items[i]));
        row.card?.betaData = row.betaData;
      }
    }
    return result.value;
  });
  Future<CycleRoomCard> room(String id, String target) => _read(() async {
    roleId(id);
    raidCycleKey(target);
    final result = await readRecruitment(
      api: api,
      mode: contractMode,
      path: '/v2/raid-rooms/$id',
      query: {'target_cycle_key': target},
      parse: (j) => j,
    );
    final j = result.value;
    roleShape(j, 'scope data');
    CycleReadScope(roleMap(j['scope']), target);
    final value = CycleRoomCard(roleMap(j['data']), target);
    final scope = roleMap(j['scope']);
    roleCheck(
      value.id == id &&
          value.wire['room_cycle_id'] == scope['room_cycle_id'] &&
          value.wire['target_revision'] == scope['target_revision'] &&
          value.wire['target_generation'] == scope['target_generation'],
    );
    return value..betaData = betaDisplayData(result.metadata);
  });
}
