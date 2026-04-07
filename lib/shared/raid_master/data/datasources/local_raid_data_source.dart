import '../../domain/entities/raid_base.dart';
import '../../domain/entities/raid_variation.dart';

class LocalRaidDataSource {
  static final List<RaidBase> raidBases = [
    RaidBase(
      raidBaseId: 'armorche',
      name: '4막:아르모체',
      partySize: 8,
      gateCount: 2,
      difficultyIds: [
        'armorche_normal',
        'armorche_hard',
      ],
    ),
    RaidBase(
      raidBaseId: 'kazeroth',
      name: '종막:카제로스',
      partySize: 8,
      gateCount: 2,
      difficultyIds: [
        'kazeroth_normal',
        'kazeroth_hard',
      ],
    ),
    RaidBase(
      raidBaseId: 'serca',
      name: '세르카',
      partySize: 4,
      gateCount: 2,
      difficultyIds: [
        'serca_normal',
        'serca_hard',
        'serca_nightmare',
      ],
    ),
    RaidBase(
      raidBaseId: 'cathedral',
      name: '지평의 성당',
      partySize: 4,
      gateCount: 2,
      difficultyIds: [
        'cathedral_stage_1',
        'cathedral_stage_2',
        'cathedral_stage_3',
      ],
    ),
  ];

  static final List<RaidVariation> raidVariations = [
    // 아르모체
    RaidVariation(
      raidId: 'armorche_normal',
      raidBaseId: 'armorche',
      difficultyOrder: 1,
      difficultyLabel: '노말',
      minItemLevel: 1700,
      rewardGold: 33000,
    ),
    RaidVariation(
      raidId: 'armorche_hard',
      raidBaseId: 'armorche',
      difficultyOrder: 2,
      difficultyLabel: '하드',
      minItemLevel: 1720,
      rewardGold: 42000,
    ),
    // 카제로스
    RaidVariation(
      raidId: 'kazeroth_normal',
      raidBaseId: 'kazeroth',
      difficultyOrder: 1,
      difficultyLabel: '노말',
      minItemLevel: 1710,
      rewardGold: 40000,
    ),
    RaidVariation(
      raidId: 'kazeroth_hard',
      raidBaseId: 'kazeroth',
      difficultyOrder: 2,
      difficultyLabel: '하드',
      minItemLevel: 1730,
      rewardGold: 52000,
    ),
    // 세르카
    RaidVariation(
      raidId: 'serca_normal',
      raidBaseId: 'serca',
      difficultyOrder: 1,
      difficultyLabel: '노말',
      minItemLevel: 1710,
      rewardGold: 35000,
    ),
    RaidVariation(
      raidId: 'serca_hard',
      raidBaseId: 'serca',
      difficultyOrder: 2,
      difficultyLabel: '하드',
      minItemLevel: 1730,
      rewardGold: 44000,
    ),
    RaidVariation(
      raidId: 'serca_nightmare',
      raidBaseId: 'serca',
      difficultyOrder: 3,
      difficultyLabel: '나이트메어',
      minItemLevel: 1740,
      rewardGold: 54000,
    ),
    // 지평의 성당
    RaidVariation(
      raidId: 'cathedral_stage_1',
      raidBaseId: 'cathedral',
      difficultyOrder: 1,
      difficultyLabel: '1단계',
      minItemLevel: 1700,
      rewardGold: 30000,
    ),
    RaidVariation(
      raidId: 'cathedral_stage_2',
      raidBaseId: 'cathedral',
      difficultyOrder: 2,
      difficultyLabel: '2단계',
      minItemLevel: 1720,
      rewardGold: 40000,
    ),
    RaidVariation(
      raidId: 'cathedral_stage_3',
      raidBaseId: 'cathedral',
      difficultyOrder: 3,
      difficultyLabel: '3단계',
      minItemLevel: 1750,
      rewardGold: 50000,
    ),
  ];
}