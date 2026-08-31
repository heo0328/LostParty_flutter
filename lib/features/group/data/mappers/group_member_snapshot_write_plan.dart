import 'group_member_write_fields.dart';

/// 본인 membership 표시 Snapshot만 갱신한다.
abstract final class GroupMemberSnapshotWritePlan {
  static Map<String, Object?> selfRefresh({
    required String className,
    double? itemLevel,
    double? combatPower,
    required Object serverTimestamp,
  }) => {
    ...GroupMemberWriteFields.displaySnapshots(
      className: className,
      itemLevel: itemLevel,
      combatPower: combatPower,
    ),
    'updatedAt': serverTimestamp,
  };
}
