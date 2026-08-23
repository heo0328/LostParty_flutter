import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';

void main() {
  const policy = RaidEligibilityPolicy();

  test('아이템 레벨을 충족하는 활성 레이드와 난이도만 반환한다', () {
    final options = policy.eligibleRaids(catalog: _catalog, itemLevel: 1680);

    expect(options.map((option) => option.raid.raidId), ['raid-a']);
    expect(options.single.difficulties.map((item) => item.difficultyId), [
      'normal',
      'hard',
    ]);
  });

  test('입장 가능한 난이도 중 displayOrder가 가장 높은 항목을 선택한다', () {
    final option = policy
        .eligibleRaids(catalog: _catalog, itemLevel: 1700)
        .singleWhere((option) => option.raid.raidId == 'raid-a');

    expect(option.highestDifficulty.difficultyId, 'nightmare');
  });

  test('아이템 레벨이 없으면 선택 가능한 레이드가 없다', () {
    expect(policy.eligibleRaids(catalog: _catalog, itemLevel: null), isEmpty);
  });
}

final _catalog = RaidCatalog(
  schemaVersion: 1,
  catalogVersion: 'test',
  updatedAt: DateTime.utc(2026),
  raids: [
    RaidDefinition(
      raidId: 'raid-a',
      officialName: 'A',
      displayName: 'A',
      aliases: [],
      partySize: 8,
      partyCount: 2,
      requiredSupportCount: 2,
      maxDealerCountPerClass: 2,
      gateCount: 3,
      isActive: true,
      difficulties: [
        RaidDifficultyDefinition(
          difficultyId: 'nightmare',
          name: '나이트메어',
          displayAlias: '나메',
          displayOrder: 30,
          minItemLevel: 1700,
          clearGold: 0,
          boundGold: 0,
          isActive: true,
        ),
        RaidDifficultyDefinition(
          difficultyId: 'normal',
          name: '노말',
          displayAlias: '노말',
          displayOrder: 10,
          minItemLevel: 1660,
          clearGold: 0,
          boundGold: 0,
          isActive: true,
        ),
        RaidDifficultyDefinition(
          difficultyId: 'hard',
          name: '하드',
          displayAlias: '하드',
          displayOrder: 20,
          minItemLevel: 1680,
          clearGold: 0,
          boundGold: 0,
          isActive: true,
        ),
      ],
    ),
    RaidDefinition(
      raidId: 'raid-b',
      officialName: 'B',
      displayName: 'B',
      aliases: [],
      partySize: 4,
      partyCount: 1,
      requiredSupportCount: 1,
      maxDealerCountPerClass: 1,
      gateCount: 2,
      isActive: true,
      difficulties: [
        RaidDifficultyDefinition(
          difficultyId: 'normal',
          name: '노말',
          displayAlias: '노말',
          displayOrder: 10,
          minItemLevel: 1710,
          clearGold: 0,
          boundGold: 0,
          isActive: true,
        ),
      ],
    ),
  ],
);
