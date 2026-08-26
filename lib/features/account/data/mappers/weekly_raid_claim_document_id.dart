class WeeklyRaidClaimDocumentId {
  const WeeklyRaidClaimDocumentId._();

  static String create({
    required String cycleKey,
    required String characterId,
    required String raidId,
  }) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cycleKey)) {
      throw ArgumentError.value(cycleKey, 'cycleKey', 'invalid format');
    }
    if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(characterId)) {
      throw ArgumentError.value(characterId, 'characterId', 'invalid id');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(raidId)) {
      throw ArgumentError.value(raidId, 'raidId', 'invalid id');
    }
    return '${cycleKey}_${characterId}_$raidId';
  }
}
