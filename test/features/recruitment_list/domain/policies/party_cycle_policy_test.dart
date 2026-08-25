import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_cycle_policy.dart';

void main() {
  const policy = PartyCyclePolicy();
  test('회차 키는 KST 수요일 6시부터 7일간 유효하다', () {
    final cycle = policy.fromKey('2026-08-26')!;
    expect(cycle.startedAt, DateTime.utc(2026, 8, 25, 21));
    expect(cycle.endsAt, DateTime.utc(2026, 9, 1, 21));
    expect(cycle.completionCancelDeadline, DateTime.utc(2026, 9, 1, 13));
  });
  test('수요일이 아닌 회차 키는 거절한다', () {
    expect(policy.fromKey('2026-08-27'), isNull);
  });
  test('KST 수요일 6시 직전과 이후의 회차 키를 구분한다', () {
    expect(policy.keyFor(DateTime.utc(2026, 8, 25, 20, 59)), '2026-08-19');
    expect(policy.keyFor(DateTime.utc(2026, 8, 25, 21)), '2026-08-26');
  });
}
