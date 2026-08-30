import '../entities/group_join_command.dart';

/// 계약 §8.3~8.5. 각 명령은 모든 검증 읽기를 끝낸 뒤 원본과 Projection을 한
/// Transaction에서만 쓴다. 부분 상태를 성공으로 남기지 않는다.
abstract interface class GroupJoinCommandRepository {
  Future<GroupJoinCommandResult> invite(GroupInviteCommand command);

  Future<GroupJoinCommandResult> apply(GroupApplyCommand command);

  Future<GroupJoinCommandResult> acceptInvitation(
    GroupInvitationDecisionCommand command,
  );

  Future<GroupJoinCommandResult> rejectInvitation(
    GroupInvitationDecisionCommand command,
  );

  Future<GroupJoinCommandResult> cancelInvitation(
    GroupInvitationCancelCommand command,
  );
}
