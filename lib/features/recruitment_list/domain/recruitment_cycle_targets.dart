import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';

/// Search dates only; never grants a member command permission.
class RecruitmentCycleTargets {
  const RecruitmentCycleTargets(this.serverNow, this.current, this.next);
  factory RecruitmentCycleTargets.member(MemberCycles value) =>
      RecruitmentCycleTargets(
        value.serverNow,
        (key: value.current.key, endsAt: value.current.endsAt),
        (key: value.next.key, endsAt: value.next.endsAt),
      );
  factory RecruitmentCycleTargets.public(MemberRaidCycle value) {
    final nextKey = DateTime.parse(
      '${value.key}T00:00:00Z',
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    return RecruitmentCycleTargets(
      value.serverTime,
      (key: value.key, endsAt: value.endsAt),
      (key: nextKey, endsAt: value.endsAt.add(const Duration(days: 7))),
    );
  }
  final DateTime serverNow;
  final ({String key, DateTime endsAt}) current, next;
  ({String key, DateTime endsAt})? find(String key) => key == current.key
      ? current
      : key == next.key
      ? next
      : null;
}
