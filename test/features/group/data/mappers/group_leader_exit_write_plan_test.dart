import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_leader_exit_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';

void main() {
  test('이전 계획은 그룹장과 두 membership 역할만 교체한다', () {
    final plan = GroupLeaderTransferWritePlan.fromMembers(
      incomingLeaderPlayerId: 'player-2',
      incomingLeaderDisplayName: '후임캐릭터',
      groupRevision: 4,
      outgoingLeaderRevision: 2,
      incomingLeaderRevision: 1,
      serverTimestamp: 'server-ts',
    );

    expect(plan.groupPatch['leaderPlayerId'], 'player-2');
    expect(plan.groupPatch['leaderDisplayCharacterNameSnapshot'], '후임캐릭터');
    expect(plan.groupPatch['revision'], 5);
    expect(plan.outgoingLeaderPatch['role'], GroupMemberRole.member.name);
    expect(plan.outgoingLeaderPatch['revision'], 3);
    expect(plan.incomingLeaderPatch['role'], GroupMemberRole.leader.name);
    expect(plan.incomingLeaderPatch['revision'], 2);
  });

  test('1차 해산은 soft delete와 요약 그룹 제거를 함께 만든다', () {
    final plan = GroupDisbandWritePlan.soloLeader(
      groupId: 'group-1',
      groupRevision: 8,
      membershipState: const GroupMembershipState(
        playerId: 'player-1',
        activeGroupIds: ['group-1', 'group-2'],
        revision: 3,
      ),
      serverTimestamp: 'server-ts',
    );

    expect(plan.groupPatch['status'], 'softDeleted');
    expect(plan.groupPatch['memberCount'], 0);
    expect(plan.groupPatch['revision'], 9);
    expect(plan.membershipState['activeGroupIds'], ['group-2']);
    expect(plan.membershipState['activeGroupCount'], 1);
  });
}
