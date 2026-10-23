import 'member_cycle_models.dart';
import 'member_raid_models.dart';
import 'role_summary.dart';

/// Original v2 manual result, not a recruitment command acknowledgement.
class MemberManualCompletionResult {
  MemberManualCompletionResult(Map<String, dynamic> json, String target) {
    roleShape(json, 'scope data');
    final scope = roleMap(json['scope']);
    roleShape(
      scope,
      'server_now current_cycle_key target_cycle_key playable_from phase target_revision policy_version room_cycle_id target_generation',
    );
    raidCycleKey(target);
    final current = raidCycleKey(scope['current_cycle_key']);
    final start = DateTime.parse(
      '${current}T00:00:00Z',
    ).subtract(const Duration(hours: 3));
    final stamp = roleUtc(scope['server_now']);
    roleCheck(
      current == target &&
          scope['target_cycle_key'] == target &&
          scope['phase'] == 'current' &&
          scope['policy_version'] == twoCyclePolicy &&
          !stamp.isBefore(start) &&
          stamp.isBefore(start.add(const Duration(days: 7))) &&
          roleUtc(scope['playable_from']) ==
              start.add(const Duration(hours: 4)) &&
          !stamp.isBefore(start.add(const Duration(hours: 4))),
    );
    // Character-level manual writes have no room cycle or generation.
    roleCheck(
      scope['room_cycle_id'] == null &&
          scope['target_generation'] == null &&
          scope['target_revision'] == null,
    );
    entry = MemberWeeklyEntry.fromJson(roleMap(json['data']));
    roleCheck(entry.cycleKey == target);
  }
  late final MemberWeeklyEntry entry;
}
