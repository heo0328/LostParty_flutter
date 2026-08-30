import '../entities/group_join_code_command.dart';

/// 계약 §7·§8.7. 초대코드 생성·폐기·표시 정책·즉시 가입 명령.
///
/// 코드 원문은 그룹 문서에 저장하지 않는다. 생성 결과는 [GroupJoinCodeCommandResult.code]
/// 로만 반환하며, 폐기는 클라이언트가 보관한 정확한 코드 문자열을 다시 넘긴다.
abstract interface class GroupJoinCodeCommandRepository {
  Future<GroupJoinCodeCommandResult> createCode(
    GroupJoinCodeCreateCommand command,
  );

  Future<GroupJoinCodeCommandResult> revokeCode(
    GroupJoinCodeRevokeCommand command,
  );

  Future<GroupJoinCodeCommandResult> setVisibility(
    GroupJoinCodeVisibilityCommand command,
  );

  Future<GroupJoinCodeCommandResult> joinByCode(GroupJoinByCodeCommand command);
}
