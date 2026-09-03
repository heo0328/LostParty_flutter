import '../../domain/entities/class_synergy.dart';
import '../../domain/entities/game_catalog.dart';

/// Owner-supplied data (2026-09-03). No network, UI colors, or live build detection.
/// IDs other than existing bard/true_courage are local catalog keys, not API IDs.
class ClassSynergyCatalog {
  const ClassSynergyCatalog();

  static const version = '2026.09.03.user.v1';

  List<ClassSynergyDefinition> get classes => _classes;

  ClassSynergyDefinition? findClass(String classNameOrId) {
    for (final definition in classes) {
      if (definition.matches(classNameOrId)) return definition;
    }
    return null;
  }

  ClassSynergyResolution resolve({
    required String classNameOrId,
    required GameCatalogRole? role,
    String? branchNameOrId,
  }) {
    final definition = findClass(classNameOrId);
    ClassSynergyResolution result(
      ClassSynergyResolutionStatus status, [
      List<ClassSynergy> effects = const [],
    ]) => ClassSynergyResolution(
      status: status,
      definition: definition,
      synergies: effects,
    );
    if (definition == null) {
      return result(ClassSynergyResolutionStatus.unknownClass);
    }
    if (role == null) return result(ClassSynergyResolutionStatus.roleRequired);
    if (role == GameCatalogRole.support) {
      return result(ClassSynergyResolutionStatus.supportExcluded);
    }
    final common = definition.commonDealerSynergies;
    if (definition.branches.isEmpty) {
      return result(ClassSynergyResolutionStatus.resolved, common);
    }
    if (branchNameOrId == null || branchNameOrId.trim().isEmpty) {
      return result(ClassSynergyResolutionStatus.branchRequired, common);
    }
    for (final branch in definition.branches) {
      if (branch.matches(branchNameOrId)) {
        return result(ClassSynergyResolutionStatus.resolved, [
          ...common,
          ...branch.synergies,
        ]);
      }
    }
    return result(ClassSynergyResolutionStatus.unknownBranch, common);
  }
}

const _classes = <ClassSynergyDefinition>[
  ClassSynergyDefinition(
    classId: 'gunlancer',
    className: '워로드',
    origin: ClassOriginGroup.shushire,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.backHeadDamageIncrease),
      ClassSynergy(SynergyType.damageTakenReduction),
    ],
    branches: [
      ClassSynergyBranch(
        id: 'lone_knight',
        name: '고독한 기사',
        aliases: [],
        synergies: [],
      ),
      ClassSynergyBranch(
        id: 'combat_readiness',
        name: '전투 태세',
        aliases: [],
        synergies: [ClassSynergy(SynergyType.defenseReduction)],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'destroyer',
    className: '디스트로이어',
    origin: ClassOriginGroup.shushire,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.defenseReduction),
      ClassSynergy(
        SynergyType.staggerDamageIncrease,
        adoption: SynergyAdoption.settingDependent,
      ),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'berserker',
    className: '버서커',
    origin: ClassOriginGroup.shushire,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'paladin',
    className: '홀리나이트',
    origin: ClassOriginGroup.shushire,

    supportedRoles: {GameCatalogRole.dealer, GameCatalogRole.support},
    commonDealerSynergies: [],
    branches: [
      ClassSynergyBranch(
        id: 'judgment',
        name: '심판자',
        aliases: [],
        synergies: [ClassSynergy(SynergyType.criticalHitDamageTakenIncrease)],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'valkyrie',
    className: '발키리',
    origin: ClassOriginGroup.shushire,

    supportedRoles: {GameCatalogRole.dealer, GameCatalogRole.support},
    commonDealerSynergies: [],
    branches: [
      ClassSynergyBranch(
        id: 'knight_of_light',
        name: '빛의 기사',
        aliases: [],
        synergies: [ClassSynergy(SynergyType.criticalHitDamageTakenIncrease)],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'slayer',
    className: '슬레이어',
    origin: ClassOriginGroup.shushire,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'bard',
    className: '바드',
    origin: ClassOriginGroup.silin,

    supportedRoles: {GameCatalogRole.dealer, GameCatalogRole.support},
    commonDealerSynergies: [],
    branches: [
      ClassSynergyBranch(
        id: 'true_courage',
        name: '진실된 용맹',
        aliases: ['딜바드'],
        synergies: [
          ClassSynergy(SynergyType.defenseReduction),
          ClassSynergy(SynergyType.attackSpeedIncrease),
          ClassSynergy(SynergyType.enemyAttackPowerReduction),
          ClassSynergy(SynergyType.manaRecoveryRateIncrease),
          ClassSynergy(
            SynergyType.damageTakenReduction,
            adoption: SynergyAdoption.settingDependent,
          ),
        ],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'summoner',
    className: '서머너',
    origin: ClassOriginGroup.silin,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.defenseReduction),
      ClassSynergy(
        SynergyType.manaRecoveryRateIncrease,
        adoption: SynergyAdoption.settingDependent,
      ),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'arcanist',
    className: '아르카나',
    origin: ClassOriginGroup.silin,

    commonDealerSynergies: [ClassSynergy(SynergyType.criticalRateIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'sorceress',
    className: '소서리스',
    origin: ClassOriginGroup.silin,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'sharpshooter',
    className: '호크아이',
    origin: ClassOriginGroup.arthetine,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [
      ClassSynergyBranch(
        id: 'loyal_companion',
        name: '두 번째 동료',
        aliases: [],
        synergies: [
          ClassSynergy(SynergyType.moveSpeedIncrease),
          ClassSynergy(
            SynergyType.enemyAttackPowerReduction,
            adoption: SynergyAdoption.settingDependent,
          ),
        ],
      ),
      ClassSynergyBranch(
        id: 'death_strike',
        name: '죽음의 습격',
        aliases: [],
        synergies: [],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'deadeye',
    className: '데빌헌터',
    origin: ClassOriginGroup.arthetine,
    aliases: ['데몬헌터'],

    commonDealerSynergies: [ClassSynergy(SynergyType.criticalRateIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'gunslinger',
    className: '건슬링어',
    origin: ClassOriginGroup.arthetine,

    commonDealerSynergies: [ClassSynergy(SynergyType.criticalRateIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'artillerist',
    className: '블래스터',
    origin: ClassOriginGroup.arthetine,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.defenseReduction),
      ClassSynergy(SynergyType.staggerDamageIncrease),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'machinist',
    className: '스카우터',
    origin: ClassOriginGroup.arthetine,

    commonDealerSynergies: [ClassSynergy(SynergyType.attackPowerIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'soulfist',
    className: '기공사',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.attackPowerIncrease),
      ClassSynergy(
        SynergyType.damageTakenReduction,
        adoption: SynergyAdoption.settingDependent,
      ),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'scrapper',
    className: '인파이터',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.damageIncrease),
      ClassSynergy(
        SynergyType.staggerDamageIncrease,
        adoption: SynergyAdoption.settingDependent,
      ),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'wardancer',
    className: '배틀마스터',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.criticalRateIncrease),
      ClassSynergy(SynergyType.attackMoveSpeedIncrease),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'glaivier',
    className: '창술사',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.criticalHitDamageTakenIncrease),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'striker',
    className: '스트라이커',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.criticalRateIncrease),
      ClassSynergy(
        SynergyType.attackSpeedIncrease,
        adoption: SynergyAdoption.settingDependent,
      ),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'breaker',
    className: '브레이커',
    origin: ClassOriginGroup.anikka,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'deathblade',
    className: '블레이드',
    origin: ClassOriginGroup.delain,

    commonDealerSynergies: [
      ClassSynergy(SynergyType.backHeadDamageIncrease),
      ClassSynergy(SynergyType.attackMoveSpeedIncrease),
    ],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'shadowhunter',
    className: '데모닉',
    origin: ClassOriginGroup.delain,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'reaper',
    className: '리퍼',
    origin: ClassOriginGroup.delain,

    commonDealerSynergies: [ClassSynergy(SynergyType.defenseReduction)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'souleater',
    className: '소울이터',
    origin: ClassOriginGroup.delain,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'artist',
    className: '도화가',
    origin: ClassOriginGroup.yoz,

    supportedRoles: {GameCatalogRole.dealer, GameCatalogRole.support},
    commonDealerSynergies: [],
    branches: [
      ClassSynergyBranch(
        id: 'recurrence',
        name: '회귀',
        aliases: [],
        synergies: [
          ClassSynergy(SynergyType.defenseReduction),
          ClassSynergy(SynergyType.damageTakenReduction),
          ClassSynergy(
            SynergyType.attackSpeedIncrease,
            adoption: SynergyAdoption.settingDependent,
          ),
        ],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'aeromancer',
    className: '기상술사',
    origin: ClassOriginGroup.yoz,

    commonDealerSynergies: [ClassSynergy(SynergyType.criticalRateIncrease)],
    branches: [
      ClassSynergyBranch(
        id: 'drizzle',
        name: '이슬비',
        aliases: [],
        synergies: [ClassSynergy(SynergyType.enemyAttackPowerReduction)],
      ),
      ClassSynergyBranch(
        id: 'wind_fury',
        name: '질풍노도',
        aliases: [],
        synergies: [ClassSynergy(SynergyType.attackMoveSpeedIncrease)],
      ),
    ],
  ),
  ClassSynergyDefinition(
    classId: 'wildsoul',
    className: '환수사',
    origin: ClassOriginGroup.yoz,

    commonDealerSynergies: [ClassSynergy(SynergyType.defenseReduction)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'guardian_knight',
    className: '가디언나이트',
    origin: ClassOriginGroup.standalone,

    commonDealerSynergies: [ClassSynergy(SynergyType.damageIncrease)],
    branches: [],
  ),
  ClassSynergyDefinition(
    classId: 'dimension_mage',
    className: '차원술사',
    origin: ClassOriginGroup.standalone,

    commonDealerSynergies: [ClassSynergy(SynergyType.defenseReduction)],
    branches: [],
  ),
];
