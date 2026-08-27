import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../entities/character_weekly_raid_display_preference.dart';

class WeeklyRaidDisplayCandidate {
  const WeeklyRaidDisplayCandidate({
    required this.raid,
    required this.difficulty,
    required this.gold,
  });

  final RaidDefinition raid;
  final RaidDifficultyDefinition difficulty;
  final int gold;

  String get raidId => raid.raidId;
  String get label => raid.displayName;
  String get difficultyId => difficulty.difficultyId;
  int get minItemLevel => difficulty.minItemLevel;
}

/// 입장 가능 후보·기본 추천·사용자 설정을 카드 표시 목록으로 투영한다.
class WeeklyRaidDisplayProjector {
  const WeeklyRaidDisplayProjector._();

  static const int defaultDisplayCount = 3;
  static const int maxDisplayCount = 5;

  static List<WeeklyRaidDisplayCandidate> eligibleCandidates({
    required RaidCatalog catalog,
    required double itemLevel,
  }) {
    final eligible = <WeeklyRaidDisplayCandidate>[];
    for (final raid in catalog.raids.where((raid) => raid.isActive)) {
      final difficulties = raid.difficulties.where(
        (difficulty) =>
            difficulty.isActive && difficulty.minItemLevel <= itemLevel,
      );
      if (difficulties.isEmpty) continue;
      final selected = difficulties.reduce((left, right) {
        final leftGold = left.clearGold + left.boundGold;
        final rightGold = right.clearGold + right.boundGold;
        if (leftGold != rightGold) return leftGold > rightGold ? left : right;
        return left.displayOrder > right.displayOrder ? left : right;
      });
      eligible.add(
        WeeklyRaidDisplayCandidate(
          raid: raid,
          difficulty: selected,
          gold: selected.clearGold + selected.boundGold,
        ),
      );
    }
    eligible.sort(_byGoldThenName);
    return List.unmodifiable(eligible);
  }

  static List<WeeklyRaidDisplayCandidate> resolve({
    required List<WeeklyRaidDisplayCandidate> eligible,
    CharacterWeeklyRaidDisplayPreference? preference,
  }) {
    if (preference == null) {
      return List.unmodifiable(
        _sortByEntryLevel(
          eligible.take(defaultDisplayCount).toList(growable: false),
        ),
      );
    }
    if (preference.displayCount == 0) return const [];
    final byId = {
      for (final candidate in eligible) candidate.raidId: candidate,
    };
    final selected = <WeeklyRaidDisplayCandidate>[];
    for (final raidId in preference.raidIds) {
      final candidate = byId[raidId];
      if (candidate != null) selected.add(candidate);
    }
    return List.unmodifiable(selected);
  }

  /// 골드 추천 상위 [requestedCount]개를 고른 뒤 입장 레벨 내림차순으로 정렬한다.
  /// 입장 가능 수가 더 적으면 그만큼만 반환한다.
  static List<WeeklyRaidDisplayCandidate> selectionForCount({
    required List<WeeklyRaidDisplayCandidate> eligible,
    required int requestedCount,
  }) {
    if (requestedCount <= 0 || eligible.isEmpty) return const [];
    final capped = requestedCount > maxDisplayCount
        ? maxDisplayCount
        : requestedCount;
    final takeCount = capped < eligible.length ? capped : eligible.length;
    return List.unmodifiable(
      _sortByEntryLevel(eligible.take(takeCount).toList(growable: false)),
    );
  }

  static int _byGoldThenName(
    WeeklyRaidDisplayCandidate left,
    WeeklyRaidDisplayCandidate right,
  ) {
    final gold = right.gold.compareTo(left.gold);
    if (gold != 0) return gold;
    return left.label.compareTo(right.label);
  }

  static List<WeeklyRaidDisplayCandidate> _sortByEntryLevel(
    List<WeeklyRaidDisplayCandidate> candidates,
  ) {
    final sorted = [...candidates]
      ..sort((left, right) {
        final level = right.minItemLevel.compareTo(left.minItemLevel);
        if (level != 0) return level;
        final gold = right.gold.compareTo(left.gold);
        if (gold != 0) return gold;
        return left.label.compareTo(right.label);
      });
    return sorted;
  }
}
