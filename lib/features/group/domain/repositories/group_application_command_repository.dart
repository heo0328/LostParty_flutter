import '../entities/group_join_command.dart';

/// 계약 §8.6. 현재 그룹장만 실행하는 신청 처리 명령이다.
///
/// 승인은 초대 수락과 같은 membership 원자 쓰기를, 거절은 관계 전이만,
/// 금지는 관계 전이와 block 생성을 한 Transaction에서 수행한다. 해제는 block
/// 문서만 지우고 이전 관계를 복원하지 않는다.
abstract interface class GroupApplicationCommandRepository {
  Future<GroupJoinCommandResult> approveApplication(
    GroupApplicationDecisionCommand command,
  );

  Future<GroupJoinCommandResult> rejectApplication(
    GroupApplicationDecisionCommand command,
  );

  Future<GroupJoinCommandResult> blockApplicant(
    GroupApplicationDecisionCommand command,
  );

  Future<GroupJoinCommandResult> releaseBlock(GroupBlockReleaseCommand command);
}
