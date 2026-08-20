import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/weekly_raid_reset_policy.dart';

void main() {
  const policy = WeeklyRaidResetPolicy();

  test('수요일 오전 6시 KST 직전에 이전 주차를 사용한다', () {
    final week = policy.weekFor(DateTime.utc(2026, 8, 18, 20, 59, 59));

    expect(week.key, '2026-08-12');
    expect(week.startedAt, DateTime.utc(2026, 8, 11, 21));
  });

  test('수요일 오전 6시 KST부터 새 주차를 사용한다', () {
    final week = policy.weekFor(DateTime.utc(2026, 8, 18, 21));

    expect(week.key, '2026-08-19');
    expect(week.startedAt, DateTime.utc(2026, 8, 18, 21));
  });

  test('입력 DateTime의 로컬 시간대와 무관하게 같은 순간은 같은 주차다', () {
    final utc = policy.weekFor(DateTime.utc(2026, 8, 20));
    final offset = policy.weekFor(DateTime.parse('2026-08-20T09:00:00+09:00'));

    expect(offset.key, utc.key);
    expect(offset.startedAt, utc.startedAt);
  });
}
