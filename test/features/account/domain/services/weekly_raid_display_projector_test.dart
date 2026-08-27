import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_weekly_raid_display_preference.dart';
import 'package:lost_party/features/account/domain/services/weekly_raid_display_projector.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';

void main() {
  group('WeeklyRaidDisplayProjector', () {
    final catalog = RaidCatalog(
      schemaVersion: 1,
      catalogVersion: 'test',
      updatedAt: DateTime.utc(2026),
      raids: [
        _raid(
          raidId: 'gold_low',
          displayName: '골드높음입장낮음',
          difficulties: [
            _difficulty(minItemLevel: 1700, clearGold: 90000),
          ],
        ),
        _raid(
          raidId: 'mid',
          displayName: '중간',
          difficulties: [
            _difficulty(minItemLevel: 1720, clearGold: 50000),
          ],
        ),
        _raid(
          raidId: 'high',
          displayName: '높은입장',
          difficulties: [
            _difficulty(minItemLevel: 1740, clearGold: 40000),
          ],
        ),
        _raid(
          raidId: 'extra',
          displayName: '추가',
          difficulties: [
            _difficulty(minItemLevel: 1710, clearGold: 30000),
          ],
        ),
        _raid(
          raidId: 'fifth',
          displayName: '다섯째',
          difficulties: [
            _difficulty(minItemLevel: 1690, clearGold: 20000),
          ],
        ),
        _raid(
          raidId: 'too_hard',
          displayName: '입장불가',
          difficulties: [
            _difficulty(minItemLevel: 1800, clearGold: 999999),
          ],
        ),
      ],
    );

    test('eligibleCandidates keeps one difficulty per raid by max gold', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );

      expect(
        eligible.map((c) => c.raidId),
        ['gold_low', 'mid', 'high', 'extra', 'fifth'],
      );
      expect(eligible.every((c) => c.minItemLevel <= 1760), isTrue);
    });

    test('resolve defaults to top gold three sorted by entry level desc', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );
      final resolved = WeeklyRaidDisplayProjector.resolve(
        eligible: eligible,
        preference: null,
      );

      expect(resolved.map((c) => c.raidId), ['high', 'mid', 'gold_low']);
    });

    test('resolve respects saved preference order and count', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );
      final resolved = WeeklyRaidDisplayProjector.resolve(
        eligible: eligible,
        preference: const CharacterWeeklyRaidDisplayPreference(
          characterId: 1,
          displayCount: 4,
          raidIds: ['fifth', 'high', 'extra', 'mid'],
        ),
      );

      expect(resolved.map((c) => c.raidId), [
        'fifth',
        'high',
        'extra',
        'mid',
      ]);
    });

    test('resolve returns empty list for displayCount 0', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );
      final resolved = WeeklyRaidDisplayProjector.resolve(
        eligible: eligible,
        preference: const CharacterWeeklyRaidDisplayPreference(
          characterId: 1,
          displayCount: 0,
          raidIds: [],
        ),
      );

      expect(resolved, isEmpty);
    });

    test('selectionForCount clamps to eligible and sorts by entry level', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );
      final selected = WeeklyRaidDisplayProjector.selectionForCount(
        eligible: eligible,
        requestedCount: 5,
      );

      expect(selected.map((c) => c.raidId), [
        'high',
        'mid',
        'extra',
        'gold_low',
        'fifth',
      ]);

      final lowLevelEligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1705,
      );
      final clamped = WeeklyRaidDisplayProjector.selectionForCount(
        eligible: lowLevelEligible,
        requestedCount: 5,
      );
      expect(clamped.map((c) => c.raidId), ['gold_low', 'fifth']);
    });
  });
}

RaidDifficultyDefinition _difficulty({
  required int minItemLevel,
  required int clearGold,
}) => RaidDifficultyDefinition(
  difficultyId: 'normal',
  name: '노말',
  displayAlias: '노말',
  displayOrder: 1,
  minItemLevel: minItemLevel,
  clearGold: clearGold,
  boundGold: 0,
  isActive: true,
);

RaidDefinition _raid({
  required String raidId,
  required String displayName,
  required List<RaidDifficultyDefinition> difficulties,
}) => RaidDefinition(
  raidId: raidId,
  officialName: displayName,
  displayName: displayName,
  aliases: const [],
  partySize: 4,
  partyCount: 1,
  requiredSupportCount: 1,
  maxDealerCountPerClass: 1,
  gateCount: 2,
  isActive: true,
  difficulties: difficulties,
);
