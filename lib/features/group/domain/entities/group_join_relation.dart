import 'group_relation.dart';

enum GroupJoinRelationKind { invitation, application }

/// 계약 §6 `groups/{groupId}/joinRelations/{playerId}` 원본.
/// 초대와 신청은 같은 `groupId + playerId` 문서 하나만 사용한다.
class GroupJoinRelation {
  const GroupJoinRelation({
    required this.groupId,
    required this.targetPlayerId,
    required this.kind,
    required this.status,
    required this.requestedByPlayerId,
    required this.characterIdSnapshot,
    required this.characterNameSnapshot,
    required this.serverNameSnapshot,
    required this.characterClassNameSnapshot,
    required this.applicationAttempt,
    required this.revision,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
    this.itemLevelSnapshot,
    this.combatPowerSnapshot,
    this.decidedAt,
  });

  /// `expiresAt == createdAt + 24시간`이다.
  static const requestLifetime = Duration(hours: 24);

  final String groupId;
  final String targetPlayerId;
  final GroupJoinRelationKind kind;
  final GroupRequestStatus status;
  final String requestedByPlayerId;
  final String characterIdSnapshot;
  final String characterNameSnapshot;
  final String serverNameSnapshot;
  final String characterClassNameSnapshot;
  final double? itemLevelSnapshot;
  final double? combatPowerSnapshot;
  final int applicationAttempt;
  final int revision;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? decidedAt;
  final DateTime updatedAt;

  bool get isInvitation => kind == GroupJoinRelationKind.invitation;

  /// 만료된 pending 문서는 유효 요청으로 취급하지 않는다.
  bool isPendingAt(DateTime now) =>
      status == GroupRequestStatus.pending && now.isBefore(expiresAt);

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  GroupRelationKind get projectedRelation =>
      isInvitation ? GroupRelationKind.invited : GroupRelationKind.applied;
}

/// 계약 §6.1 `groups/{groupId}/applicantStats/{playerId}` 누적 신청 횟수.
/// 초대와 초대코드 가입은 이 횟수를 증가시키지 않는다.
class GroupApplicantStats {
  const GroupApplicantStats({
    required this.groupId,
    required this.playerId,
    required this.applicationCount,
    this.lastCharacterNameSnapshot,
    this.lastItemLevelSnapshot,
    this.lastCombatPowerSnapshot,
  });

  const GroupApplicantStats.empty({required this.groupId, required this.playerId})
    : applicationCount = 0,
      lastCharacterNameSnapshot = null,
      lastItemLevelSnapshot = null,
      lastCombatPowerSnapshot = null;

  final String groupId;
  final String playerId;
  final int applicationCount;
  final String? lastCharacterNameSnapshot;
  final double? lastItemLevelSnapshot;
  final double? lastCombatPowerSnapshot;

  int get nextApplicationAttempt => applicationCount + 1;
}
