import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_cycle_write_plan.dart';

void main() {
  test('완료 Snapshot은 완료 당시 Player 순서와 구성을 고정한다', () {
    final members = <Map<String, Object?>>[{'playerId': 'leader', 'characterId': 'bard'}, {'playerId': 'member', 'characterId': 'sorc'}];
    final plan = PartyCycleWritePlan.completedCycle(recruitmentId: 'party', cycleKey: '2026-08-26', completedByPlayerId: 'member', memberSnapshot: members, serverTimestamp: Object());
    expect(plan['status'], 'completed');
    expect(plan['memberPlayerIds'], ['leader', 'member']);
    expect(plan['completedMemberSnapshot'], members);
    expect(plan['completionRevision'], 1);
  });
  test('반복 파티 전환은 다음 회차와 7일 경계를 저장한다', () {
    final plan = PartyCycleWritePlan.advanceRecruitment(continueTogether: true, nextCycleKey: '2026-09-02', nextStartedAt: DateTime.utc(2026, 9, 1, 21), nextEndsAt: DateTime.utc(2026, 9, 8, 21), revision: 4, hasAvailableSlot: true, serverTimestamp: Object(), timestamp: (date) => date);
    expect(plan['currentCycleKey'], '2026-09-02');
    expect(plan['currentCycleStatus'], 'active');
    expect(plan['revision'], 5);
  });
  test('여러 주 미접속 반복 파티는 목표 현재 회차로 직접 이동한다', () {
    final plan = PartyCycleWritePlan.advanceRecruitment(
      continueTogether: true,
      nextCycleKey: '2026-09-23',
      nextStartedAt: DateTime.utc(2026, 9, 22, 21),
      nextEndsAt: DateTime.utc(2026, 9, 29, 21),
      revision: 4,
      hasAvailableSlot: true,
      serverTimestamp: Object(),
      timestamp: (date) => date,
    );
    expect(plan['currentCycleKey'], '2026-09-23');
    expect(plan['cycleStartedAt'], DateTime.utc(2026, 9, 22, 21));
  });
  test('해산은 멤버와 책임자를 비우고 disbanded로 둔다', () {
    final plan = PartyCycleWritePlan.disbandRecruitment(
      revision: 2,
      serverTimestamp: Object(),
    );
    expect(plan['status'], 'disbanded');
    expect(plan['currentCycleStatus'], 'disbanded');
    expect(plan['memberCount'], 0);
    expect(plan['memberPlayerIds'], isEmpty);
    expect(plan['leaderPlayerId'], isNull);
    expect(plan['revision'], 3);
  });
}
