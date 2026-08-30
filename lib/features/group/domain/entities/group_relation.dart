enum GroupRelationKind { member, invited, applied }

enum GroupRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  expired,
  blocked,
}

/// `players/{playerId}/groupRelations/{groupId}` 역방향 Projection.
/// 원본 그룹·membership 없이 단독으로 만들거나 바꾸지 않는다.
class GroupRelation {
  const GroupRelation({
    required this.groupId,
    required this.playerId,
    required this.relation,
    required this.groupNameSnapshot,
    required this.displayCharacterNameSnapshot,
    required this.sourceRevision,
    required this.createdAt,
    required this.updatedAt,
    this.requestStatus,
    this.expiresAt,
  });

  final String groupId;
  final String playerId;
  final GroupRelationKind relation;
  final GroupRequestStatus? requestStatus;
  final String groupNameSnapshot;
  final String displayCharacterNameSnapshot;
  final DateTime? expiresAt;
  final int sourceRevision;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMember => relation == GroupRelationKind.member;

  bool isExpiredAt(DateTime now) {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !now.isBefore(expiresAt);
  }
}
