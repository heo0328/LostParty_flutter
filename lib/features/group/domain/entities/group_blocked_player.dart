/// 계약 §6.2 금지 사유. 신청 거절과 함께 금지하면 [applicationRejected]이고
/// 이미 끝난 신청을 뒤늦게 금지하면 [manual]이다.
enum GroupBlockReason { applicationRejected, manual }

/// `groups/{groupId}/blockedPlayers/{playerId}` 원본.
///
/// 금지 주체는 Player다. 본·부계정과 Character 변경은 금지를 우회하지 못한다.
/// 현재 그룹장만 읽고 만들고 지운다.
class GroupBlockedPlayer {
  const GroupBlockedPlayer({
    required this.groupId,
    required this.playerId,
    required this.blockedByPlayerId,
    required this.reason,
    required this.characterNameSnapshot,
    required this.applicationCountSnapshot,
    required this.createdAt,
    this.itemLevelSnapshot,
    this.combatPowerSnapshot,
  });

  final String groupId;
  final String playerId;
  final String blockedByPlayerId;
  final GroupBlockReason reason;
  final String characterNameSnapshot;
  final int applicationCountSnapshot;
  final double? itemLevelSnapshot;
  final double? combatPowerSnapshot;
  final DateTime createdAt;
}
