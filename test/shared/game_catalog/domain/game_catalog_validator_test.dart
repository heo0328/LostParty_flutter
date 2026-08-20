import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/game_catalog/domain/entities/game_catalog.dart';
import 'package:lost_party/shared/game_catalog/domain/validation/game_catalog_validator.dart';

void main() {
  const validator = GameCatalogValidator();

  test('accepts a structurally valid catalog', () {
    expect(validator.validate(_validCatalog()), isEmpty);
  });

  test('rejects duplicate class identifiers and API class names', () {
    final original = _validClass();
    final catalog = GameCatalog(
      schemaVersion: 1,
      catalogVersion: '2026.08.20',
      updatedAt: DateTime.utc(2026, 8, 20),
      classes: [original, original],
    );

    final codes = validator.validate(catalog).map((issue) => issue.code);

    expect(codes.where((code) => code == 'duplicate_value'), hasLength(2));
  });

  test('rejects roles that are not supported by the class', () {
    final definition = _validClass(
      supportedRoles: const {GameCatalogRole.dealer},
      defaultRole: GameCatalogRole.support,
      branchRole: GameCatalogRole.support,
      presetRole: GameCatalogRole.support,
    );

    final codes = validator
        .validate(_validCatalog(classes: [definition]))
        .map((issue) => issue.code)
        .toSet();

    expect(
      codes,
      containsAll({
        'unsupported_default_role',
        'unsupported_branch_role',
        'unsupported_preset_role',
      }),
    );
  });

  test('rejects unknown branch references', () {
    final definition = _validClass(
      skillBranchIds: const ['unknown_branch'],
      presetBranchIds: const ['unknown_branch'],
    );

    final issues = validator.validate(_validCatalog(classes: [definition]));

    expect(
      issues.where((issue) => issue.code == 'unknown_branch_reference'),
      hasLength(2),
    );
  });

  test('rejects an invalid core point range', () {
    final definition = _validClass(
      requiredCores: const [
        ArkGridCoreRequirement(
          coreName: '질서의 해',
          minimumPoint: 17,
          recommendedPoint: 14,
        ),
      ],
    );

    final issues = validator.validate(_validCatalog(classes: [definition]));

    expect(
      issues.map((issue) => issue.code),
      contains('invalid_recommended_point'),
    );
  });

  test('rejects an unknown gem target special skill reference', () {
    final definition = _validClass(gemSkillIds: const ['unknown_skill']);

    final issues = validator.validate(_validCatalog(classes: [definition]));

    expect(
      issues.map((issue) => issue.code),
      contains('unknown_special_skill_reference'),
    );
  });
}

GameCatalog _validCatalog({List<GameClassDefinition>? classes}) {
  return GameCatalog(
    schemaVersion: 1,
    catalogVersion: '2026.08.20',
    updatedAt: DateTime.utc(2026, 8, 20),
    classes: classes ?? [_validClass()],
  );
}

GameClassDefinition _validClass({
  Set<GameCatalogRole> supportedRoles = const {
    GameCatalogRole.dealer,
    GameCatalogRole.support,
  },
  GameCatalogRole defaultRole = GameCatalogRole.support,
  GameCatalogRole branchRole = GameCatalogRole.support,
  GameCatalogRole presetRole = GameCatalogRole.support,
  List<String> skillBranchIds = const ['sample_support'],
  List<String> presetBranchIds = const ['sample_support'],
  List<String> gemSkillIds = const ['sample_identity'],
  List<ArkGridCoreRequirement> requiredCores = const [
    ArkGridCoreRequirement(
      coreName: '질서의 해',
      minimumPoint: 14,
      recommendedPoint: 17,
    ),
  ],
}) {
  return GameClassDefinition(
    classId: 'sample_class',
    apiClassName: '샘플 직업',
    aliases: const [],
    supportedRoles: supportedRoles,
    defaultRole: defaultRole,
    enlightenmentBranches: [
      EnlightenmentBranch(
        branchId: 'sample_support',
        tier1NodeName: '샘플 노드',
        displayName: '샘플 계열',
        aliases: const [],
        inferredRole: branchRole,
        relatedPassiveNodes: const ['샘플 추가 노드'],
      ),
    ],
    specialSkills: [
      ClassSpecialSkill(
        skillId: 'sample_identity',
        name: '샘플 아이덴티티',
        aliases: const [],
        category: ClassSpecialSkillCategory.identity,
        relatedBranchIds: skillBranchIds,
      ),
    ],
    gemSkillTargets: [
      ClassGemSkillTarget(
        targetId: 'sample_gem_target',
        name: '샘플 복합 대상',
        aliases: const [],
        relatedSpecialSkillIds: gemSkillIds,
      ),
    ],
    arkGridPresets: [
      ArkGridPreset(
        presetId: 'sample_preset',
        name: '샘플 조합',
        aliases: const [],
        applicableBranchIds: presetBranchIds,
        inferredRole: presetRole,
        requiredPassiveNodes: const ['샘플 추가 노드'],
        optionalPassiveNodes: const [],
        requiredCores: requiredCores,
        tags: const [],
      ),
    ],
  );
}
