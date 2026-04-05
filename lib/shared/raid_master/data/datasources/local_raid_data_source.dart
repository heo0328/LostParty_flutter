import '../../domain/entities/raid_base.dart';
import '../../domain/entities/raid_variation.dart';

class LocalRaidDataSource {
  static final List<RaidBase> raidBases = [
    RaidBase(
      raidBaseId: 'echidna',
      name: '에키드나',
      partySize: 8,
      gateCount: 2,
      difficultyIds: [
        'echidna_normal',
        'echidna_hard',
      ],
    ),
    RaidBase(
      raidBaseId: 'cathedral',
      name: '지평의 성당',
      partySize: 8,
      gateCount: 2,
      difficultyIds: [
        'cathedral_stage_1',
        'cathedral_stage_2',
        'cathedral_stage_3',
      ],
    ),
  ];

  static final List<RaidVariation> raidVariations = [
    // 에키드나
    RaidVariation(
      raidId: 'echidna_normal',
      raidBaseId: 'echidna',
      difficultyType: 'normal',
      difficultyLabel: '노말',
      minItemLevel: 1620,
      rewardGold: 10000,
    ),
    RaidVariation(
      raidId: 'echidna_hard',
      raidBaseId: 'echidna',
      difficultyType: 'hard',
      difficultyLabel: '하드',
      minItemLevel: 1630,
      rewardGold: 18500,
    ),

    // 지평의 성당
    RaidVariation(
      raidId: 'cathedral_stage_1',
      raidBaseId: 'cathedral',
      difficultyType: 'stage_1',
      difficultyLabel: '1단계',
      minItemLevel: 1700,
      rewardGold: 30000,
    ),
    RaidVariation(
      raidId: 'cathedral_stage_2',
      raidBaseId: 'cathedral',
      difficultyType: 'stage_2',
      difficultyLabel: '2단계',
      minItemLevel: 1720,
      rewardGold: 35000,
    ),
    RaidVariation(
      raidId: 'cathedral_stage_3',
      raidBaseId: 'cathedral',
      difficultyType: 'stage_3',
      difficultyLabel: '3단계',
      minItemLevel: 1750,
      rewardGold: 40000,
    ),
  ];
}