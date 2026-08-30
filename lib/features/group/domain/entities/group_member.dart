enum GroupMemberRole { leader, member }

enum GroupJoinedBy { created, invitation, application, joinCode }

/// membership 주체는 항상 Player다. Character Snapshot은 표시값이다.
class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.playerId,
    required this.role,
    required this.joinedAt,
    required this.joinSequence,
    required this.joinedBy,
    required this.displayCharacterIdSnapshot,
    required this.displayCharacterNameSnapshot,
    required this.revision,
  });

  /// 계약 §8.4 그룹 정원.
  static const maxMemberCount = 50;

  final String groupId;
  final String playerId;
  final GroupMemberRole role;
  final DateTime joinedAt;
  final int joinSequence;
  final GroupJoinedBy joinedBy;
  final String displayCharacterIdSnapshot;
  final String displayCharacterNameSnapshot;
  final int revision;

  bool get isLeader => role == GroupMemberRole.leader;
}

/// `players/{playerId}/groupMembershipState/current` 요약. 문서가 없으면 빈 상태다.
class GroupMembershipState {
  const GroupMembershipState({
    required this.playerId,
    required this.activeGroupIds,
    required this.revision,
  });

  const GroupMembershipState.empty(this.playerId)
    : activeGroupIds = const [],
      revision = 0;

  static const maxActiveGroupCount = 50;

  final String playerId;
  final List<String> activeGroupIds;
  final int revision;

  int get activeGroupCount => activeGroupIds.length;

  bool get isAtLimit => activeGroupCount >= maxActiveGroupCount;

  bool contains(String groupId) => activeGroupIds.contains(groupId);
}
