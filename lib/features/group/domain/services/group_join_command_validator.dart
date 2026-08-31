import '../entities/group_join_code.dart';
import '../entities/group_join_code_command.dart';
import '../entities/group_join_command.dart';
import '../entities/group_leave_command.dart';

/// Transaction 이전에 확인할 수 있는 형식 오류만 걸러 낸다. 권한·상태 전이는
/// Transaction 읽기와 Rules가 최종 판정한다.
class GroupJoinCommandValidator {
  const GroupJoinCommandValidator();

  GroupJoinFailure? validateInvite(GroupInviteCommand command) =>
      _invalidDocumentId(command.groupId) ||
          _invalidDocumentId(command.targetCharacterId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateApply(GroupApplyCommand command) =>
      _invalidDocumentId(command.groupId) ||
          _invalidDocumentId(command.characterId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateDecision(GroupInvitationDecisionCommand command) =>
      _invalidDocumentId(command.groupId) ||
          _invalidRevision(command.expectedRelationRevision)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateCancel(GroupInvitationCancelCommand command) =>
      _invalidDocumentId(command.groupId) ||
          _invalidDocumentId(command.targetPlayerId) ||
          _invalidRevision(command.expectedRelationRevision)
      ? GroupJoinFailure.invalidRequest
      : null;

  /// 계약 §8.6 승인·거절·금지는 대상 Player와 요청 revision을 함께 확인한다.
  GroupJoinFailure? validateApplicationDecision(
    GroupApplicationDecisionCommand command,
  ) =>
      _invalidDocumentId(command.groupId) ||
          _invalidDocumentId(command.targetPlayerId) ||
          _invalidRevision(command.expectedRelationRevision)
      ? GroupJoinFailure.invalidRequest
      : null;

  /// 금지 해제는 요청 revision을 요구하지 않는다. block 문서만 지운다.
  GroupJoinFailure? validateBlockRelease(GroupBlockReleaseCommand command) =>
      _invalidDocumentId(command.groupId) ||
          _invalidDocumentId(command.targetPlayerId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateJoinCodeCreate(GroupJoinCodeCreateCommand command) =>
      _invalidDocumentId(command.groupId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateJoinCodeRevoke(
    GroupJoinCodeRevokeCommand command,
  ) {
    if (_invalidDocumentId(command.groupId)) {
      return GroupJoinFailure.invalidRequest;
    }
    return GroupJoinCode.tryParse(command.code) == null
        ? GroupJoinFailure.joinCodeInvalid
        : null;
  }

  GroupJoinFailure? validateJoinCodeVisibility(
    GroupJoinCodeVisibilityCommand command,
  ) =>
      _invalidDocumentId(command.groupId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateLeave(GroupLeaveCommand command) =>
      _invalidDocumentId(command.groupId)
      ? GroupJoinFailure.invalidRequest
      : null;

  GroupJoinFailure? validateJoinByCode(GroupJoinByCodeCommand command) {
    if (_invalidDocumentId(command.characterId)) {
      return GroupJoinFailure.invalidRequest;
    }
    return GroupJoinCode.tryParse(command.code) == null
        ? GroupJoinFailure.joinCodeInvalid
        : null;
  }

  /// 초대 검색은 정확한 이름 한 건만 조회한다. 빈 문자열과 제어문자는 거절한다.
  bool isValidCharacterNameQuery(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 40) return false;
    return !trimmed.runes.any((rune) => rune < 0x20 || rune == 0x7f);
  }

  bool _invalidDocumentId(String value) =>
      value.trim().isEmpty || value.contains('/');

  bool _invalidRevision(int value) => value < 1;
}
