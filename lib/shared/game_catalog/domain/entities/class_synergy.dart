import 'game_catalog.dart';

/// UI grouping/order supplied by the project owner, not an ownership rule.
enum ClassOriginGroup {
  shushire('슈샤이어'),
  silin('실린'),
  arthetine('아르데타인'),
  anikka('애니츠'),
  delain('데런'),
  yoz('요즈'),
  standalone('단독');

  const ClassOriginGroup(this.label);
  final String label;
}

enum SynergyAdoption { always, settingDependent }

enum SynergyType {
  defenseReduction('방깎', true),
  damageIncrease('피증', true),
  attackPowerIncrease('공증', true),
  criticalRateIncrease('치적', true),
  criticalHitDamageTakenIncrease('치피증', true),
  backHeadDamageIncrease('백헤드 피증', true),
  attackMoveSpeedIncrease('공이속', false),
  attackSpeedIncrease('공속', false),
  moveSpeedIncrease('이속', false),
  manaRecoveryRateIncrease('마회', false),
  enemyAttackPowerReduction('공깎', false),
  damageTakenReduction('받피감', false),
  staggerDamageIncrease('무력화', false);

  const SynergyType(this.label, this.isPrimary);
  final String label;
  final bool isPrimary;
}

class ClassSynergy {
  const ClassSynergy(this.type, {this.adoption = SynergyAdoption.always});

  final SynergyType type;
  final SynergyAdoption adoption;
}

/// Additions to the class's common dealer effects, not an API build detector.
class ClassSynergyBranch {
  const ClassSynergyBranch({
    required this.id,
    required this.name,
    required this.synergies,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<ClassSynergy> synergies;

  bool matches(String value) => [id, name, ...aliases].any(
    (candidate) =>
        normalizeSynergyName(candidate) == normalizeSynergyName(value),
  );
}

class ClassSynergyDefinition {
  const ClassSynergyDefinition({
    required this.classId,
    required this.className,
    required this.origin,
    required this.commonDealerSynergies,
    this.aliases = const [],
    this.supportedRoles = const {GameCatalogRole.dealer},
    this.branches = const [],
  });

  final String classId;
  final String className;
  final ClassOriginGroup origin;
  final List<String> aliases;
  final Set<GameCatalogRole> supportedRoles;
  final List<ClassSynergy> commonDealerSynergies;
  final List<ClassSynergyBranch> branches;

  bool matches(String value) => [classId, className, ...aliases].any(
    (candidate) =>
        normalizeSynergyName(candidate) == normalizeSynergyName(value),
  );
}

enum ClassSynergyResolutionStatus {
  resolved,
  unknownClass,
  roleRequired,
  supportExcluded,
  branchRequired,
  unknownBranch,
}

class ClassSynergyResolution {
  ClassSynergyResolution({
    required this.status,
    required List<ClassSynergy> synergies,
    this.definition,
  }) : synergies = List.unmodifiable(synergies);

  final ClassSynergyResolutionStatus status;
  final ClassSynergyDefinition? definition;

  /// Only common effects are returned when the branch is unknown.
  /// Setting-dependent effects remain possibilities, not equipped-skill facts.
  final List<ClassSynergy> synergies;

  List<ClassSynergy> get primary =>
      List.unmodifiable(synergies.where((effect) => effect.type.isPrimary));

  List<ClassSynergy> get alwaysAdopted => List.unmodifiable(
    synergies.where((effect) => effect.adoption == SynergyAdoption.always),
  );
}

String normalizeSynergyName(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
