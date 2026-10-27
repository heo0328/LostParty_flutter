import 'member_raid_models.dart';
import 'role_summary.dart';

const twoCyclePolicy = 'two-cycle-contract-4';

class CyclePermission {
  CyclePermission.fromJson(Map<String, dynamic> j) {
    roleShape(j, 'allowed reason next_change_at');
    allowed = raidBool(j['allowed']);
    reason = j['reason'] as String?;
    nextChange = j['next_change_at'] == null
        ? null
        : roleUtc(j['next_change_at']);
  }
  late final bool allowed;
  late final String? reason;
  late final DateTime? nextChange;
}

class MemberCycleMeta {
  MemberCycleMeta.fromJson(Map<String, dynamic> j) {
    roleShape(j, 'cycle_key starts_at ends_at playable_from permissions');
    key = raidCycleKey(j['cycle_key']);
    startsAt = roleUtc(j['starts_at']);
    endsAt = roleUtc(j['ends_at']);
    playableFrom = roleUtc(j['playable_from']);
    roleCheck(
      startsAt ==
              DateTime.parse(
                '${key}T06:00:00Z',
              ).subtract(const Duration(hours: 9)) &&
          endsAt.difference(startsAt) == const Duration(days: 7) &&
          playableFrom == startsAt.add(const Duration(hours: 4)),
    );
    final p = roleMap(j['permissions']);
    roleShape(p, 'read create admit complete');
    permissions = {
      for (final k in p.keys) k: CyclePermission.fromJson(roleMap(p[k])),
    };
  }
  late final String key;
  late final DateTime startsAt, endsAt, playableFrom;
  late final Map<String, CyclePermission> permissions;
}

class MemberCycles {
  MemberCycles.fromJson(Map<String, dynamic> j) {
    roleShape(j, 'server_now current next policy_version');
    roleCheck(j['policy_version'] == twoCyclePolicy);
    serverNow = roleUtc(j['server_now']);
    current = MemberCycleMeta.fromJson(roleMap(j['current']));
    next = MemberCycleMeta.fromJson(roleMap(j['next']));
    roleCheck(
      !serverNow.isBefore(current.startsAt) &&
          serverNow.isBefore(current.endsAt) &&
          next.startsAt == current.endsAt,
    );
  }
  late final DateTime serverNow;
  late final MemberCycleMeta current, next;
  List<MemberCycleMeta> get values => [current, next];
  MemberCycleMeta? find(String key) =>
      values.where((v) => v.key == key).firstOrNull;
  MemberRaidCycle get legacyCurrent => MemberRaidCycle.fromJson({
    'server_time': serverNow.toIso8601String(),
    'cycle_key': current.key,
    'starts_at': current.startsAt.toIso8601String(),
    'ends_at': current.endsAt.toIso8601String(),
    'timezone': 'Asia/Seoul',
  });
}

/// Read DTO only; does not create a completion command or infer reservations.
class MemberCycleSummary {
  MemberCycleSummary.fromJson(Map<String, dynamic> j) {
    roleShape(
      j,
      'server_now current_cycle_key target_cycle_keys catalog_version entries',
    );
    serverNow = roleUtc(j['server_now']);
    currentKey = raidCycleKey(j['current_cycle_key']);
    targets = raidList(j['target_cycle_keys']).map(raidCycleKey).toSet();
    roleCheck(
      targets.isNotEmpty &&
          targets.length <= 2 &&
          targets.length == raidList(j['target_cycle_keys']).length,
    );
    catalogVersion = raidText(j['catalog_version']);
    entries = raidList(j['entries'])
        .map((v) => MemberWeeklyEntry.fromSummary(roleMap(v)))
        .toList(growable: false);
    roleCheck(entries.length <= 500);
  }
  late final DateTime serverNow;
  late final String currentKey, catalogVersion;
  late final Set<String> targets;
  late final List<MemberWeeklyEntry> entries;
}
