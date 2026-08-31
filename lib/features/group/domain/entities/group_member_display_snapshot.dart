/// 그룹 membership 문서에 저장하는 표시 Snapshot 값.
class GroupMemberDisplaySnapshot {
  const GroupMemberDisplaySnapshot({
    required this.className,
    this.itemLevel,
    this.combatPower,
  });

  final String className;
  final double? itemLevel;
  final double? combatPower;

  bool matchesStored({
    String? storedClassName,
    double? storedItemLevel,
    double? storedCombatPower,
  }) {
    return storedClassName == className &&
        (itemLevel == null || storedItemLevel == itemLevel) &&
        (combatPower == null || storedCombatPower == combatPower);
  }
}
