import '../../account/domain/account_read_session.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import '../domain/policies/party_cycle_policy.dart';

/// Server owns the active C/N room set; no count is inferred from paged cards.
class RaidRoomUsage {
  RaidRoomUsage.fromJson(Map<String, dynamic> raw) {
    roleShape(
      raw,
      'policy_version evaluated_at limits_revision usage_revision limit_source updated_at limits usage issues',
    );
    roleCheck(raw['policy_version'] == 'member-room-limits-v1');
    evaluatedAt = roleUtc(raw['evaluated_at']);
    rolePositive(raw['limits_revision']);
    rolePositive(raw['usage_revision']);
    roleCheck({'default', 'account'}.contains(raw['limit_source']));
    if (raw['updated_at'] != null) roleUtc(raw['updated_at']);
    final limits = roleMap(raw['limits']), usage = roleMap(raw['usage']);
    roleShape(limits, 'group_capacity joined_groups raid_rooms');
    roleShape(usage, 'joined_groups raid_rooms');
    for (final value in limits.values) {
      roleCheck(value is int && value >= 0);
    }
    for (final key in ['joined_groups', 'raid_rooms']) {
      final metric = roleMap(usage[key]);
      roleShape(metric, 'used remaining state can_increase');
      final count = metric['used'], cap = limits[key] as int;
      if (metric['state'] == 'unavailable') {
        roleCheck(
          count == null &&
              metric['remaining'] == null &&
              metric['can_increase'] == null,
        );
      } else {
        roleCheck(count is int && count >= 0);
        final n = count as int;
        roleCheck(
          metric['remaining'] == (cap > n ? cap - n : 0) &&
              metric['can_increase'] == (n < cap) &&
              metric['state'] ==
                  (n > cap
                      ? 'exceeded'
                      : n == cap
                      ? 'at_limit'
                      : 'within'),
        );
      }
    }
    roleCheck(raw['issues'] is List);
    for (final item in raw['issues'] as List) {
      final issue = roleMap(item);
      roleShape(issue, 'code dimension used limit');
      roleCheck(
        {
              'MEMBER_GROUP_LIMIT_EXCEEDED': 'joined_groups',
              'MEMBER_RAID_LIMIT_EXCEEDED': 'raid_rooms',
            }[issue['code']] ==
            issue['dimension'],
      );
      final metric = roleMap(usage[issue['dimension']]);
      roleCheck(
        metric['state'] == 'exceeded' &&
            issue['used'] == metric['used'] &&
            issue['limit'] == limits[issue['dimension']],
      );
    }
    used = usage['raid_rooms']['used'] as int?;
    limit = limits['raid_rooms'] as int;
    currentCycle = const PartyCyclePolicy().keyFor(evaluatedAt);
  }
  late final DateTime evaluatedAt;
  late final String currentCycle;
  late final int? used;
  late final int limit;
  String get label => used == null ? '—/—' : '$used/$limit';
}

class RaidRoomUsageRepository {
  const RaidRoomUsageRepository(this.api);
  final BackendRegistrationApi api;
  Future<RaidRoomUsage> read() async {
    try {
      final raw = await api.request('/v1/me/usage-limits');
      return RaidRoomUsage.fromJson(roleMap(raw));
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }
}
