import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_cycle_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/raid_cycle_schedule.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_cycle_runtime.dart';

void main() {
  test('경계를 넘으면 한 번만 새 회차를 알리고 같은 회차 재확인은 무시한다', () {
    var now = DateTime.utc(2026, 9, 27, 1, 59);
    final runtime = PartyCycleRuntime(
      policy: const PartyCyclePolicy(
        schedule: RaidCycleSchedule(
          utcOffset: Duration.zero,
          resetWeekday: DateTime.sunday,
          resetHour: 2,
        ),
      ),
      now: () => now,
      observeLifecycle: false,
      scheduleBoundaryRefresh: false,
    );
    addTearDown(runtime.dispose);
    var notifications = 0;
    runtime.addListener(() => notifications++);

    expect(runtime.current.key, '2026-09-20');
    now = DateTime.utc(2026, 9, 27, 2, 0);
    runtime.refresh();
    expect(runtime.current.key, '2026-09-27');
    expect(notifications, 1);

    now = DateTime.utc(2026, 9, 27, 2, 30);
    expect(runtime.refreshAndGetKey(), '2026-09-27');
    expect(notifications, 1);
  });

  test('운영 기본 경계는 KST 수요일 06시다', () {
    const policy = PartyCyclePolicy();

    expect(policy.keyFor(DateTime.utc(2026, 9, 22, 20, 59)), '2026-09-16');
    expect(policy.keyFor(DateTime.utc(2026, 9, 22, 21, 0)), '2026-09-23');
  });
}
