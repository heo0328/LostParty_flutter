import '../../domain/entities/group_member.dart';

/// 그룹장 즉시 지정 이전과 1차 해산의 Transaction 쓰기 계획.
class GroupLeaderTransferWritePlan {
  const GroupLeaderTransferWritePlan({
    required this.groupPatch,
    required this.outgoingLeaderPatch,
    required this.incomingLeaderPatch,
  });

  factory GroupLeaderTransferWritePlan.fromMembers({
    required String incomingLeaderPlayerId,
    required String incomingLeaderDisplayName,
    required int groupRevision,
    required int outgoingLeaderRevision,
    required int incomingLeaderRevision,
    required Object serverTimestamp,
  }) => GroupLeaderTransferWritePlan(
    groupPatch: {
      'leaderPlayerId': incomingLeaderPlayerId,
      'leaderDisplayCharacterNameSnapshot': incomingLeaderDisplayName,
      'revision': groupRevision + 1,
      'lastActivityAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    },
    outgoingLeaderPatch: {
      'role': GroupMemberRole.member.name,
      'revision': outgoingLeaderRevision + 1,
      'updatedAt': serverTimestamp,
    },
    incomingLeaderPatch: {
      'role': GroupMemberRole.leader.name,
      'revision': incomingLeaderRevision + 1,
      'updatedAt': serverTimestamp,
    },
  );

  final Map<String, Object?> groupPatch;
  final Map<String, Object?> outgoingLeaderPatch;
  final Map<String, Object?> incomingLeaderPatch;
}

class GroupDisbandWritePlan {
  const GroupDisbandWritePlan({
    required this.groupPatch,
    required this.membershipState,
  });

  factory GroupDisbandWritePlan.soloLeader({
    required String groupId,
    required int groupRevision,
    required GroupMembershipState membershipState,
    required Object serverTimestamp,
  }) {
    if (membershipState.playerId.isEmpty) {
      throw ArgumentError.value(
        membershipState.playerId,
        'playerId',
        'Disband requires the caller membership state.',
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
    return GroupDisbandWritePlan(
      groupPatch: {
        'status': 'softDeleted',
        'memberCount': 0,
        'deletedAt': serverTimestamp,
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
