import '../entities/group_join_command.dart';
import '../entities/group_leave_command.dart';
import '../entities/group_member_display_snapshot_refresh_command.dart';

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

  /// 계약 §11a. 일반 멤버 본인 탈퇴만 허용한다.
  Future<GroupJoinCommandResult> leave(GroupLeaveCommand command);

  /// 본인 membership 표시 Snapshot만 갱신한다. 다른 필드는 바꾸지 않는다.
  Future<void> refreshMyDisplaySnapshot(
    GroupMemberDisplaySnapshotRefreshCommand command,
  );
}
