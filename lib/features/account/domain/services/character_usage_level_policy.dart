class CharacterUsageLevelPolicy {
  const CharacterUsageLevelPolicy();

  static const double minimumItemLevel = 1700;

  bool isInUsageRange(double? itemLevel) =>
      itemLevel != null && itemLevel >= minimumItemLevel;
}
