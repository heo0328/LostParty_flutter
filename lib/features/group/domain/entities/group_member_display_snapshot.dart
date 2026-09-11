import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

/// 그룹 membership 문서에 저장하는 표시 Snapshot 값.
class GroupMemberDisplaySnapshot {
  const GroupMemberDisplaySnapshot({
    required this.className,
    this.itemLevel,
    this.combatPower,
    this.gemValidation,
  });

  final String className;
  final double? itemLevel;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;

  bool matchesStored({
    String? storedClassName,
    double? storedItemLevel,
    double? storedCombatPower,
    PartyGemValidationSnapshot? storedGemValidation,
  }) {
    return storedClassName == className &&
        (itemLevel == null || storedItemLevel == itemLevel) &&
        (combatPower == null || storedCombatPower == combatPower) &&
        (gemValidation == null ||
            gemValidation!.hasSameValues(storedGemValidation));
  }
}
