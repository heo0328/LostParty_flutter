/// 계약: 현재 그룹장이 유효한 일반 멤버에게 권한을 즉시 지정한다.
class GroupLeaderTransferCommand {
  const GroupLeaderTransferCommand({
    required this.groupId,
    required this.targetPlayerId,
    required this.expectedGroupRevision,
  });

  final String groupId;
  final String targetPlayerId;
  final int expectedGroupRevision;
}

/// 계약: 마지막 1인 그룹장의 1차 해산.
class GroupDisbandCommand {
  const GroupDisbandCommand({
    required this.groupId,
    required this.expectedGroupRevision,
  });

  final String groupId;
  final int expectedGroupRevision;
}
