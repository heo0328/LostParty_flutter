import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

import 'group_member_write_fields.dart';

/// 본인 membership 표시 Snapshot만 갱신한다.
abstract final class GroupMemberSnapshotWritePlan {
  static Map<String, Object?> selfRefresh({
    required String className,
    double? itemLevel,
    double? combatPower,
    PartyGemValidationSnapshot? gemValidation,
    double? storedItemLevel,
    double? storedCombatPower,
    PartyGemValidationSnapshot? storedGemValidation,
    required Object serverTimestamp,
  }) => {
    ...GroupMemberWriteFields.displaySnapshots(
      className: className,
      itemLevel: itemLevel ?? storedItemLevel,
      combatPower: combatPower ?? storedCombatPower,
      gemValidation: gemValidation ?? storedGemValidation,
    ),
    'updatedAt': serverTimestamp,
  };
}
