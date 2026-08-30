import 'group_join_command.dart';
import 'group_join_code.dart';

/// 계약 §7. 그룹장만 실행하는 초대코드 생성. 코드 원문은 결과로만 반환한다.
class GroupJoinCodeCreateCommand {
  const GroupJoinCodeCreateCommand({required this.groupId});

  final String groupId;
}

/// 계약 §7. 정확한 코드 문서 삭제와 `hasActiveJoinCode` true→false를 함께 수행한다.
class GroupJoinCodeRevokeCommand {
  const GroupJoinCodeRevokeCommand({
    required this.groupId,
    required this.code,
  });

  final String groupId;

  /// 정규화 전 원문. Repository가 [GroupJoinCode.tryParse]로 검증한다.
  final String code;
}

/// 계약 §7. `joinCodeVisibleToMembers` 화면 공개 정책만 바꾼다.
class GroupJoinCodeVisibilityCommand {
  const GroupJoinCodeVisibilityCommand({
    required this.groupId,
    required this.visibleToMembers,
  });

  final String groupId;
  final bool visibleToMembers;
}

/// 계약 §8.7. 정확한 코드와 표시용 인증 Character로 즉시 가입한다.
class GroupJoinByCodeCommand {
  const GroupJoinByCodeCommand({
    required this.code,
    required this.characterId,
  });

  final String code;
  final String characterId;
}

/// 초대코드 명령 결과. 생성 성공 시에만 [code]를 담아 한 번 복사할 수 있게 한다.
class GroupJoinCodeCommandResult {
  const GroupJoinCodeCommandResult.success({this.code, this.visibleToMembers})
    : failure = null;

  const GroupJoinCodeCommandResult.failure(this.failure)
    : code = null,
      visibleToMembers = null;

  /// 생성 직후 한 번만 전달하는 정규화 코드. 폐기·가입·표시 변경에는 null이다.
  final GroupJoinCode? code;

  final bool? visibleToMembers;
  final GroupJoinFailure? failure;

  bool get isSuccess => failure == null;
}
