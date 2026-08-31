import 'group_relation.dart';

/// 계약 §8.3 직접 초대. 초대 대상은 검색한 Character의 `ownerPlayerId`로 확정하므로
/// 명령은 Character ID만 전달한다.
class GroupInviteCommand {
  const GroupInviteCommand({
    required this.groupId,
    required this.targetCharacterId,
  });

  final String groupId;
  final String targetCharacterId;
}

/// 계약 §8.5 가입 신청. 신청에 사용한 active 인증 Character를 전달한다.
class GroupApplyCommand {
  const GroupApplyCommand({required this.groupId, required this.characterId});

  final String groupId;
  final String characterId;
}

/// 계약 §8.4 초대 수락·거절. 대상 Player 본인만 실행하므로 대상 ID를 받지 않는다.
class GroupInvitationDecisionCommand {
  const GroupInvitationDecisionCommand({
    required this.groupId,
    required this.expectedRelationRevision,
  });

  final String groupId;
  final int expectedRelationRevision;
}

/// 계약 §8.4 초대 취소. 발신자는 자기 초대만, 그룹장은 모든 초대를 취소한다.
class GroupInvitationCancelCommand {
  const GroupInvitationCancelCommand({
    required this.groupId,
    required this.targetPlayerId,
    required this.expectedRelationRevision,
  });

  final String groupId;
  final String targetPlayerId;
  final int expectedRelationRevision;
}

/// 계약 §8.6 신청 승인·거절·금지. 현재 그룹장만 실행하며 대상 Player를 지정한다.
class GroupApplicationDecisionCommand {
  const GroupApplicationDecisionCommand({
    required this.groupId,
    required this.targetPlayerId,
    required this.expectedRelationRevision,
  });

  final String groupId;
  final String targetPlayerId;
  final int expectedRelationRevision;
}

/// 계약 §6.2 금지 해제. block 문서만 지우며 이전 relation을 복원하지 않는다.
class GroupBlockReleaseCommand {
  const GroupBlockReleaseCommand({
    required this.groupId,
    required this.targetPlayerId,
  });

  final String groupId;
  final String targetPlayerId;
}

enum GroupJoinFailure {
  unauthenticated,
  playerBindingMissing,
  invalidRequest,
  invalidCharacter,
  ownershipLost,
  groupNotFound,
  groupClosed,
  notGroupMember,
  notGroupLeader,
  alreadyMember,
  blocked,
  requestAlreadyPending,
  requestNotFound,
  requestNotPending,
  requestExpired,
  revisionConflict,
  groupCapacityFull,
  activeGroupLimitReached,
  /// 계약 §7. 그룹에 이미 활성 코드가 있어 새 코드를 만들 수 없다.
  joinCodeActive,
  /// 활성 코드가 없거나 폐기 대상 코드 문서가 없다.
  joinCodeMissing,
  /// 입력 형식이 아니거나 정규화 후에도 문서 ID로 쓸 수 없다.
  joinCodeInvalid,
  /// 그룹장은 이전·해산 없이 탈퇴할 수 없다.
  leaderCannotLeave,
  permissionDenied,
  temporarilyUnavailable,
  unknown,
}

/// 성공 결과는 명령 이후 관계의 최종 상태를 반환한다. 이미 최종 상태였던 재시도는
/// 역방향 변경 없이 현재 상태를 그대로 반환한다.
class GroupJoinCommandResult {
  const GroupJoinCommandResult.success(this.status) : failure = null;

  /// 금지 해제처럼 요청 상태를 바꾸지 않는 명령의 성공 결과다.
  const GroupJoinCommandResult.completed() : status = null, failure = null;

  const GroupJoinCommandResult.failure(this.failure) : status = null;

  final GroupRequestStatus? status;
  final GroupJoinFailure? failure;

  bool get isSuccess => failure == null;
}
