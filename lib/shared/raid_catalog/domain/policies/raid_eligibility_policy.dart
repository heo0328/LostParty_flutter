import '../entities/raid_catalog.dart';

class EligibleRaidOption {
  const EligibleRaidOption({required this.raid, required this.difficulties});

  final RaidDefinition raid;
  final List<RaidDifficultyDefinition> difficulties;

  RaidDifficultyDefinition get highestDifficulty => difficulties.reduce(
    (current, candidate) =>
        candidate.displayOrder > current.displayOrder ? candidate : current,
  );
}

class RaidEligibilityPolicy {
  const RaidEligibilityPolicy();

  bool canEnter({
    required double? itemLevel,
    required RaidDifficultyDefinition difficulty,
  }) =>
      itemLevel != null &&
      difficulty.isActive &&
      itemLevel >= difficulty.requiredItemLevel;

  List<RaidDifficultyDefinition> eligibleDifficulties({
    required RaidDefinition raid,
    required double? itemLevel,
  }) {
    if (!raid.isActive || itemLevel == null) return const [];
    final result =
        raid.difficulties
            .where(
              (difficulty) =>
                  canEnter(itemLevel: itemLevel, difficulty: difficulty),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => left.displayOrder.compareTo(right.displayOrder),
          );
    return List.unmodifiable(result);
  }

  List<EligibleRaidOption> eligibleRaids({
    required RaidCatalog catalog,
    required double? itemLevel,
  }) => List.unmodifiable(
    catalog.raids
        .where((raid) => raid.isActive)
        .map(
          (raid) => EligibleRaidOption(
            raid: raid,
            difficulties: eligibleDifficulties(
              raid: raid,
              itemLevel: itemLevel,
            ),
          ),
        )
        .where((option) => option.difficulties.isNotEmpty),
  );
}
