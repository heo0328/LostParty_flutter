import '../entities/group_member_display_snapshot.dart';

/// 본인 membership 문서의 표시 Snapshot만 서버에 반영한다.
class GroupMemberDisplaySnapshotRefreshCommand {
  const GroupMemberDisplaySnapshotRefreshCommand({
    required this.groupId,
    required this.snapshot,
  });

  final String groupId;
  final GroupMemberDisplaySnapshot snapshot;
}
