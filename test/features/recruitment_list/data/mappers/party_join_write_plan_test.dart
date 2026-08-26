import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_join_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  test('가입 저장 계획은 모집·멤버십·확정 점유를 함께 갱신한다', () {
    final timestamp = Object();
    final plan = PartyJoinWritePlan.create(
      recruitmentId: 'raid-1', playerId: 'player-2', characterId: 'character-2',
      characterName: '테스트', className: '바드', itemLevel: 1700,
      combatPower: 100000, role: PartyRole.support, partyIndex: 1, slotIndex: 0,
      joinedBy: 'leader', raidId: 'serca', cycleKey: '2026-W34',
      memberCount: 7, memberPlayerIds: const ['leader'], maxMemberCount: 8,
      dealerCount: 6, supportCount: 1, revision: 4,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentUpdate['memberPlayerIds'], ['leader', 'player-2']);
    expect(plan.recruitmentUpdate['memberCount'], 8);
    expect(plan.recruitmentUpdate['supportCount'], 2);
    expect(plan.recruitmentUpdate['hasAvailableSlot'], isFalse);
    expect(plan.recruitmentUpdate['revision'], 5);
    expect(plan.membership['partyIndex'], 1);
    expect(plan.membership['slotIndex'], 0);
    expect(plan.membership['joinedBy'], 'leader');
    expect(plan.assignment['recruitmentId'], 'raid-1');
  });
}
