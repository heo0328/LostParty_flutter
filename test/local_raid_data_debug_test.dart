import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_master/data/datasources/local_raid_data_source.dart';

void main() {
  group('LocalRaidDataSource', () {
    test('raid bases should have matching raid variations', () {
      expect(LocalRaidDataSource.raidBases, isNotEmpty);
      expect(LocalRaidDataSource.raidVariations, isNotEmpty);

      for (final raidBase in LocalRaidDataSource.raidBases) {
        final variations = LocalRaidDataSource.raidVariations
            .where((variation) => variation.raidBaseId == raidBase.raidBaseId)
            .toList()
          ..sort(
            (a, b) => a.difficultyOrder.compareTo(b.difficultyOrder),
          );

        expect(
          variations.map((variation) => variation.raidId),
          orderedEquals(raidBase.difficultyIds),
        );
        expect(variations.length, raidBase.difficultyIds.length);
        expect(raidBase.partySize, greaterThan(0));
        expect(raidBase.gateCount, greaterThan(0));
      }
    });

    test('raid variations should contain valid progression values', () {
      for (final variation in LocalRaidDataSource.raidVariations) {
        expect(variation.raidId, isNotEmpty);
        expect(variation.raidBaseId, isNotEmpty);
        expect(variation.difficultyOrder, greaterThan(0));
        expect(variation.difficultyLabel, isNotEmpty);
        expect(variation.minItemLevel, greaterThan(0));
        expect(variation.rewardGold, greaterThanOrEqualTo(0));
      }
    });
  });
}
