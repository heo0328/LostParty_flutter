import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_weekly_raid_display_preference.dart';
import 'package:lost_party/features/account/domain/services/weekly_raid_display_projector.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';

void main() {
  test(
    'display aliases preserve canonical IDs, original name and combined alias',
    () {
      const nightmare = RaidDifficultyDefinition(
        difficultyId: 'nightmare',
        name: '나이트메어',
        displayAlias: '나르카',
        displayOrder: 3,
        minItemLevel: 1740,
        clearGold: 1,
        boundGold: 0,
        isActive: true,
      );
      expect(nightmare.displayName, '나메');
      expect(nightmare.name, '나이트메어');
      expect(nightmare.displayAlias, '나르카');
      const stage = RaidDifficultyDefinition(
        difficultyId: 'stage2',
        name: '2단계',
        displayAlias: '지평2단',
        displayOrder: 2,
        minItemLevel: 1720,
        clearGold: 0,
        boundGold: 1,
        isActive: true,
      );
      expect(stage.displayName, '2단');
      final raid = _raid(
        raidId: 'horizon_cathedral',
        displayName: '지평의 성당',
        difficulties: [stage],
      );
      expect(raid.displayName, '지평의 성당');
      expect(raid.aliases, contains('지평'));
      expect(raid.aliases, isNot(contains('성당')));
      expect(raid.officialName, '지평의 성당');
      expect(raid.raidId, 'horizon_cathedral');
    },
  );
  test(
    'explicit selection supports more than five and never fills missing IDs',
    () {
      final ids = List.generate(8, (i) => 'raid_$i');
      final pref = CharacterWeeklyRaidDisplayPreference(
        characterId: 1,
        displayCount: ids.length,
        raidIds: ids,
      );
      expect(pref.isValid, isTrue);
      final candidates = [
        for (var i = 0; i < 7; i++)
          WeeklyRaidDisplayCandidate(
            raid: _raid(
              raidId: ids[i],
              displayName: ids[i],
              difficulties: [_difficulty(minItemLevel: 1700, clearGold: 1)],
            ),
            difficulty: _difficulty(minItemLevel: 1700, clearGold: 1),
            gold: 1,
          ),
      ];
      expect(
        WeeklyRaidDisplayProjector.resolve(
          eligible: candidates,
          preference: pref,
        ),
        hasLength(7),
      );
      expect(pref.raidIds, hasLength(8));
    },
  );

  group('WeeklyRaidDisplayProjector', () {
    final catalog = RaidCatalog(
      schemaVersion: 1,
      catalogVersion: 'test',
      updatedAt: DateTime.utc(2026),
      raids: [
        _raid(
          raidId: 'gold_low',
          displayName: '골드높음입장낮음',
          difficulties: [_difficulty(minItemLevel: 1700, clearGold: 90000)],
        ),
        _raid(
          raidId: 'mid',
          displayName: '중간',
          difficulties: [_difficulty(minItemLevel: 1720, clearGold: 50000)],
        ),
        _raid(
          raidId: 'high',
          displayName: '높은입장',
          difficulties: [_difficulty(minItemLevel: 1740, clearGold: 40000)],
        ),
        _raid(
          raidId: 'extra',
          displayName: '추가',
          difficulties: [_difficulty(minItemLevel: 1710, clearGold: 30000)],
        ),
        _raid(
          raidId: 'fifth',
          displayName: '다섯째',
          difficulties: [_difficulty(minItemLevel: 1690, clearGold: 20000)],
        ),
        _raid(
          raidId: 'too_hard',
          displayName: '입장불가',
          difficulties: [_difficulty(minItemLevel: 1800, clearGold: 999999)],
        ),
      ],
    );

    test('eligibleCandidates keeps one difficulty per raid by max gold', () {
      final eligible = WeeklyRaidDisplayProjector.eligibleCandidates(
        catalog: catalog,
        itemLevel: 1760,
      );

      expect(eligible.map((c) => c.raidId), [
        'gold_low',
        'mid',
        'high',
        'extra',
        'fifth',
      ]);
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

      expect(resolved.map((c) => c.raidId), ['fifth', 'high', 'extra', 'mid']);
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
