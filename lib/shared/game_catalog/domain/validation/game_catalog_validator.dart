import '../entities/game_catalog.dart';

class GameCatalogValidationIssue {
  const GameCatalogValidationIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

class GameCatalogValidator {
  const GameCatalogValidator();

  List<GameCatalogValidationIssue> validate(GameCatalog catalog) {
    final issues = <GameCatalogValidationIssue>[];
    if (catalog.schemaVersion < 1) {
      _add(issues, 'invalid_schema_version', 'schemaVersion', '1 이상이어야 합니다.');
    }
    _requireText(issues, catalog.catalogVersion, 'catalogVersion');
    if (catalog.classes.isEmpty) {
      _add(issues, 'empty_classes', 'classes', '직업이 하나 이상 필요합니다.');
    }

    _checkUnique(
      issues,
      values: catalog.classes.map((value) => value.classId),
      path: 'classes.classId',
    );
    _checkUnique(
      issues,
      values: catalog.classes.map((value) => value.apiClassName),
      path: 'classes.apiClassName',
    );

    for (var index = 0; index < catalog.classes.length; index++) {
      _validateClass(issues, catalog.classes[index], 'classes[$index]');
    }
    return List.unmodifiable(issues);
  }

  void _validateClass(
    List<GameCatalogValidationIssue> issues,
    GameClassDefinition definition,
    String path,
  ) {
    _requireText(issues, definition.classId, '$path.classId');
    _requireText(issues, definition.apiClassName, '$path.apiClassName');
    _checkTextList(issues, definition.aliases, '$path.aliases');
    if (definition.supportedRoles.isEmpty) {
      _add(
        issues,
        'empty_supported_roles',
        '$path.supportedRoles',
        '역할이 하나 이상 필요합니다.',
      );
    } else if (!definition.supportedRoles.contains(definition.defaultRole)) {
      _add(
        issues,
        'unsupported_default_role',
        '$path.defaultRole',
        '기본 역할은 지원 역할에 포함되어야 합니다.',
      );
    }

    final branchIds = definition.enlightenmentBranches
        .map((value) => value.branchId)
        .toSet();
    _checkUnique(
      issues,
      values: definition.enlightenmentBranches.map((value) => value.branchId),
      path: '$path.enlightenmentBranches.branchId',
    );
    for (
      var index = 0;
      index < definition.enlightenmentBranches.length;
      index++
    ) {
      final branch = definition.enlightenmentBranches[index];
      final branchPath = '$path.enlightenmentBranches[$index]';
      _requireText(issues, branch.branchId, '$branchPath.branchId');
      _requireText(issues, branch.tier1NodeName, '$branchPath.tier1NodeName');
      _requireText(issues, branch.displayName, '$branchPath.displayName');
      _checkTextList(issues, branch.aliases, '$branchPath.aliases');
      _checkTextList(
        issues,
        branch.relatedPassiveNodes,
        '$branchPath.relatedPassiveNodes',
      );
      if (!definition.supportedRoles.contains(branch.inferredRole)) {
        _add(
          issues,
          'unsupported_branch_role',
          '$branchPath.inferredRole',
          '계열 역할은 직업의 지원 역할에 포함되어야 합니다.',
        );
      }
    }

    _checkUnique(
      issues,
      values: definition.specialSkills.map((value) => value.skillId),
      path: '$path.specialSkills.skillId',
    );
    for (var index = 0; index < definition.specialSkills.length; index++) {
      final skill = definition.specialSkills[index];
      final skillPath = '$path.specialSkills[$index]';
      _requireText(issues, skill.skillId, '$skillPath.skillId');
      _requireText(issues, skill.name, '$skillPath.name');
      _checkTextList(issues, skill.aliases, '$skillPath.aliases');
      _validateBranchReferences(
        issues,
        skill.relatedBranchIds,
        branchIds,
        '$skillPath.relatedBranchIds',
      );
    }

    final specialSkillIds = definition.specialSkills
        .map((value) => value.skillId)
        .toSet();
    _checkUnique(
      issues,
      values: definition.gemSkillTargets.map((value) => value.targetId),
      path: '$path.gemSkillTargets.targetId',
    );
    for (var index = 0; index < definition.gemSkillTargets.length; index++) {
      final target = definition.gemSkillTargets[index];
      final targetPath = '$path.gemSkillTargets[$index]';
      _requireText(issues, target.targetId, '$targetPath.targetId');
      _requireText(issues, target.name, '$targetPath.name');
      _checkTextList(issues, target.aliases, '$targetPath.aliases');
      _checkTextList(
        issues,
        target.relatedSpecialSkillIds,
        '$targetPath.relatedSpecialSkillIds',
      );
      if (target.relatedSpecialSkillIds.isEmpty) {
        _add(
          issues,
          'empty_gem_target_skills',
          '$targetPath.relatedSpecialSkillIds',
          '관련 특수 스킬이 하나 이상 필요합니다.',
        );
      }
      for (
        var skillIndex = 0;
        skillIndex < target.relatedSpecialSkillIds.length;
        skillIndex++
      ) {
        if (!specialSkillIds.contains(
          target.relatedSpecialSkillIds[skillIndex],
        )) {
          _add(
            issues,
            'unknown_special_skill_reference',
            '$targetPath.relatedSpecialSkillIds[$skillIndex]',
            '같은 직업에 정의된 특수 스킬 ID를 참조해야 합니다.',
          );
        }
      }
    }

    _checkUnique(
      issues,
      values: definition.arkGridPresets.map((value) => value.presetId),
      path: '$path.arkGridPresets.presetId',
    );
    for (var index = 0; index < definition.arkGridPresets.length; index++) {
      final preset = definition.arkGridPresets[index];
      final presetPath = '$path.arkGridPresets[$index]';
      _requireText(issues, preset.presetId, '$presetPath.presetId');
      _requireText(issues, preset.name, '$presetPath.name');
      _checkTextList(issues, preset.aliases, '$presetPath.aliases');
      _checkTextList(
        issues,
        preset.requiredPassiveNodes,
        '$presetPath.requiredPassiveNodes',
      );
      _checkTextList(
        issues,
        preset.optionalPassiveNodes,
        '$presetPath.optionalPassiveNodes',
      );
      _checkTextList(issues, preset.tags, '$presetPath.tags');
      _validateBranchReferences(
        issues,
        preset.applicableBranchIds,
        branchIds,
        '$presetPath.applicableBranchIds',
      );
      if (preset.applicableBranchIds.isEmpty) {
        _add(
          issues,
          'empty_preset_branches',
          '$presetPath.applicableBranchIds',
          '조합에 적용 가능한 계열이 하나 이상 필요합니다.',
        );
      }
      if (!definition.supportedRoles.contains(preset.inferredRole)) {
        _add(
          issues,
          'unsupported_preset_role',
          '$presetPath.inferredRole',
          '조합 역할은 직업의 지원 역할에 포함되어야 합니다.',
        );
      }
      _validateCoreRequirements(
        issues,
        preset.requiredCores,
        '$presetPath.requiredCores',
      );
    }
  }

  void _validateCoreRequirements(
    List<GameCatalogValidationIssue> issues,
    List<ArkGridCoreRequirement> cores,
    String path,
  ) {
    _checkUnique(
      issues,
      values: cores.map((value) => value.coreName),
      path: '$path.coreName',
    );
    for (var index = 0; index < cores.length; index++) {
      final core = cores[index];
      final corePath = '$path[$index]';
      _requireText(issues, core.coreName, '$corePath.coreName');
      if (core.minimumPoint < 0) {
        _add(
          issues,
          'invalid_minimum_point',
          '$corePath.minimumPoint',
          '0 이상이어야 합니다.',
        );
      }
      final recommended = core.recommendedPoint;
      if (recommended != null && recommended < core.minimumPoint) {
        _add(
          issues,
          'invalid_recommended_point',
          '$corePath.recommendedPoint',
          '권장 포인트는 최소 포인트 이상이어야 합니다.',
        );
      }
    }
  }

  void _validateBranchReferences(
    List<GameCatalogValidationIssue> issues,
    List<String> references,
    Set<String> branchIds,
    String path,
  ) {
    _checkTextList(issues, references, path);
    for (var index = 0; index < references.length; index++) {
      if (!branchIds.contains(references[index])) {
        _add(
          issues,
          'unknown_branch_reference',
          '$path[$index]',
          '같은 직업에 정의된 계열 ID를 참조해야 합니다.',
        );
      }
    }
  }

  void _checkTextList(
    List<GameCatalogValidationIssue> issues,
    List<String> values,
    String path,
  ) {
    _checkUnique(issues, values: values, path: path);
    for (var index = 0; index < values.length; index++) {
      _requireText(issues, values[index], '$path[$index]');
    }
  }

  void _checkUnique(
    List<GameCatalogValidationIssue> issues, {
    required Iterable<String> values,
    required String path,
  }) {
    final seen = <String>{};
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty && !seen.add(normalized)) {
        _add(issues, 'duplicate_value', path, '중복 값을 사용할 수 없습니다: $value');
      }
    }
  }

  void _requireText(
    List<GameCatalogValidationIssue> issues,
    String value,
    String path,
  ) {
    if (value.trim().isEmpty) {
      _add(issues, 'blank_value', path, '빈 문자열을 사용할 수 없습니다.');
    }
  }

  void _add(
    List<GameCatalogValidationIssue> issues,
    String code,
    String path,
    String message,
  ) {
    issues.add(
      GameCatalogValidationIssue(code: code, path: path, message: message),
    );
  }
}
