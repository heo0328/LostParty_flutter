import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_leave_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';

void main() {
  const membershipState = GroupMembershipState(
    playerId: 'player-2',
    activeGroupIds: ['group-1', 'group-2'],
    revision: 4,
  );

  test('일반 멤버 탈퇴는 인원·요약·활동 시각을 함께 갱신한다', () {
    final plan = GroupLeaveWritePlan.regularMember(
      groupId: 'group-1',
      groupRevision: 9,
      groupMemberCount: 3,
      membershipState: membershipState,
      serverTimestamp: 'server-ts',
    );

    expect(plan.groupPatch, {
      'memberCount': 2,
      'revision': 10,
      'lastActivityAt': 'server-ts',
      'updatedAt': 'server-ts',
    });
    expect(plan.membershipState['playerId'], 'player-2');
    expect(plan.membershipState['activeGroupIds'], ['group-2']);
    expect(plan.membershipState['activeGroupCount'], 1);
    expect(plan.membershipState['revision'], 5);
    expect(plan.membershipState['updatedAt'], 'server-ts');
  });

  test('요약에 없는 그룹은 탈퇴 계획을 만들지 않는다', () {
    expect(
      () => GroupLeaveWritePlan.regularMember(
        groupId: 'group-9',
        groupRevision: 1,
        groupMemberCount: 2,
        membershipState: membershipState,
        serverTimestamp: Object(),
      ),
      throwsArgumentError,
    );
  });

  test('마지막 멤버 탈퇴는 일반 멤버 경로에서 허용하지 않는다', () {
    expect(
      () => GroupLeaveWritePlan.regularMember(
        groupId: 'group-1',
        groupRevision: 1,
        groupMemberCount: 1,
        membershipState: membershipState,
        serverTimestamp: Object(),
      ),
      throwsArgumentError,
    );
  });
}
