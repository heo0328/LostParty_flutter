import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_membership_write_plan.dart';

void main() {
  test('일반 탈퇴는 자리와 역할 카운트를 되돌리고 모집 자리를 연다', () {
    final plan = PartyMembershipWritePlan.removeFromRecruitment(
      memberPlayerIds: const ['leader', 'member'],
      targetPlayerId: 'member',
      memberCount: 2,
      dealerCount: 1,
      supportCount: 1,
      targetRole: 'dealer',
      maxMemberCount: 4,
      revision: 3,
      nextLeaderPlayerId: 'leader',
      nextLeaderCharacterName: '리더캐릭',
      nextLeaderClassName: '바드',
      serverTimestamp: Object(),
    );
    expect(plan['memberPlayerIds'], ['leader']);
    expect(plan['memberCount'], 1);
    expect(plan['dealerCount'], 0);
    expect(plan['leaderPlayerId'], 'leader');
    expect(plan['leaderCharacterNameSnapshot'], '리더캐릭');
    expect(plan['leaderClassNameSnapshot'], '바드');
    expect(plan['hasAvailableSlot'], isTrue);
    expect(plan['revision'], 4);
  });

  test('마지막 책임자 탈퇴는 파티를 종료한다', () {
    final plan = PartyMembershipWritePlan.removeFromRecruitment(
      memberPlayerIds: const ['leader'],
      targetPlayerId: 'leader',
      memberCount: 1,
      dealerCount: 0,
      supportCount: 1,
      targetRole: 'support',
      maxMemberCount: 4,
      revision: 1,
      nextLeaderPlayerId: null,
      nextLeaderCharacterName: null,
      nextLeaderClassName: null,
      serverTimestamp: Object(),
    );
    expect(plan['status'], 'disbanded');
    expect(plan['manualRecruitmentEnabled'], isFalse);
    expect(plan['leaderPlayerId'], isNull);
    expect(plan['leaderCharacterNameSnapshot'], isNull);
    expect(plan['leaderClassNameSnapshot'], isNull);
  });

  test('파티장 표시 Snapshot 갱신 맵을 만든다', () {
    final timestamp = Object();
    final plan = PartyMembershipWritePlan.leaderDisplaySnapshots(
      characterName: '새캐릭',
      className: '기상술사',
      revision: 2,
      serverTimestamp: timestamp,
    );
    expect(plan['leaderCharacterNameSnapshot'], '새캐릭');
    expect(plan['leaderClassNameSnapshot'], '기상술사');
    expect(plan['revision'], 3);
    expect(plan['updatedAt'], same(timestamp));
  });
}
