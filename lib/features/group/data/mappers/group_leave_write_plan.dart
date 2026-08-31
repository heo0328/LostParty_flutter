import '../../domain/entities/group_member.dart';

/// 일반 멤버 탈퇴 Transaction 쓰기 계획. member 삭제·그룹 인원·Player 요약·Projection
/// 삭제는 같은 Transaction에서만 수행한다.
class GroupLeaveWritePlan {
  const GroupLeaveWritePlan({
    required this.groupPatch,
    required this.membershipState,
  });

  factory GroupLeaveWritePlan.regularMember({
    required String groupId,
    required int groupRevision,
    required int groupMemberCount,
    required GroupMembershipState membershipState,
    required Object serverTimestamp,
  }) {
    if (groupMemberCount < 2) {
      throw ArgumentError.value(
        groupMemberCount,
        'groupMemberCount',
        'Regular leave requires at least two members.',
      );
    }
    if (!membershipState.contains(groupId)) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Membership state must contain the group.',
      );
    }
    final remainingIds = membershipState.activeGroupIds
        .where((id) => id != groupId)
        .toList(growable: false);
    return GroupLeaveWritePlan(
      groupPatch: {
        'memberCount': groupMemberCount - 1,
        'revision': groupRevision + 1,
        'lastActivityAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      membershipState: {
        'schemaVersion': 1,
        'playerId': membershipState.playerId,
        'activeGroupIds': remainingIds,
        'activeGroupCount': remainingIds.length,
        'revision': membershipState.revision + 1,
        'updatedAt': serverTimestamp,
      },
    );
  }

  final Map<String, Object?> groupPatch;
  final Map<String, Object?> membershipState;
}
