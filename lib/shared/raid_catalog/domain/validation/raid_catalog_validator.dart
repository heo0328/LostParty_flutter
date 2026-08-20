import '../entities/raid_catalog.dart';

class RaidCatalogValidationIssue {
  const RaidCatalogValidationIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

class RaidCatalogValidator {
  const RaidCatalogValidator();

  List<RaidCatalogValidationIssue> validate(RaidCatalog catalog) {
    final issues = <RaidCatalogValidationIssue>[];
    if (catalog.schemaVersion < 1) {
      _add(issues, 'invalid_schema_version', 'schemaVersion', '1 이상이어야 합니다.');
    }
    _requireText(issues, catalog.catalogVersion, 'catalogVersion');
    if (catalog.raids.isEmpty) {
      _add(issues, 'empty_raids', 'raids', '레이드가 하나 이상 필요합니다.');
    }
    _checkUnique(
      issues,
      values: catalog.raids.map((raid) => raid.raidId),
      path: 'raids.raidId',
    );

    for (var raidIndex = 0; raidIndex < catalog.raids.length; raidIndex++) {
      final raid = catalog.raids[raidIndex];
      final raidPath = 'raids[$raidIndex]';
      _requireText(issues, raid.raidId, '$raidPath.raidId');
      _requireText(issues, raid.name, '$raidPath.name');
      if (raid.partySize < 1) {
        _add(
          issues,
          'invalid_party_size',
          '$raidPath.partySize',
          '1 이상이어야 합니다.',
        );
      }
      if (raid.gateCount < 1) {
        _add(
          issues,
          'invalid_gate_count',
          '$raidPath.gateCount',
          '1 이상이어야 합니다.',
        );
      }
      if (raid.difficulties.isEmpty) {
        _add(
          issues,
          'empty_difficulties',
          '$raidPath.difficulties',
          '난이도가 하나 이상 필요합니다.',
        );
      }
      _checkUnique(
        issues,
        values: raid.difficulties.map((difficulty) => difficulty.difficultyId),
        path: '$raidPath.difficulties.difficultyId',
      );
      _checkUnique(
        issues,
        values: raid.difficulties.map(
          (difficulty) => '${difficulty.displayOrder}',
        ),
        path: '$raidPath.difficulties.displayOrder',
      );

      for (
        var difficultyIndex = 0;
        difficultyIndex < raid.difficulties.length;
        difficultyIndex++
      ) {
        final difficulty = raid.difficulties[difficultyIndex];
        final difficultyPath = '$raidPath.difficulties[$difficultyIndex]';
        _requireText(
          issues,
          difficulty.difficultyId,
          '$difficultyPath.difficultyId',
        );
        _requireText(issues, difficulty.name, '$difficultyPath.name');
        if (difficulty.displayOrder < 1) {
          _add(
            issues,
            'invalid_display_order',
            '$difficultyPath.displayOrder',
            '1 이상이어야 합니다.',
          );
        }
        if (difficulty.minItemLevel < 1) {
          _add(
            issues,
            'invalid_min_item_level',
            '$difficultyPath.minItemLevel',
            '1 이상이어야 합니다.',
          );
        }
        if (difficulty.rewardGold < 0) {
          _add(
            issues,
            'invalid_reward_gold',
            '$difficultyPath.rewardGold',
            '0 이상이어야 합니다.',
          );
        }
      }
    }
    return List.unmodifiable(issues);
  }

  List<RaidCatalogValidationIssue> validateReference(
    RaidCatalog catalog,
    RaidCatalogReference reference,
  ) {
    final issues = <RaidCatalogValidationIssue>[];
    if (reference.catalogVersion != catalog.catalogVersion) {
      _add(
        issues,
        'catalog_version_mismatch',
        'catalogVersion',
        '현재 레이드 카탈로그 버전과 일치해야 합니다.',
      );
    }
    final raid = _findRaid(catalog, reference.raidId);
    if (raid == null) {
      _add(issues, 'unknown_raid', 'raidId', '카탈로그에 존재하는 레이드여야 합니다.');
      return List.unmodifiable(issues);
    }
    if (!raid.isActive) {
      _add(issues, 'inactive_raid', 'raidId', '활성 레이드만 모집할 수 있습니다.');
    }
    final difficulty = _findDifficulty(raid, reference.difficultyId);
    if (difficulty == null) {
      _add(
        issues,
        'unknown_difficulty',
        'difficultyId',
        '선택한 레이드에 존재하는 난이도여야 합니다.',
      );
    } else if (!difficulty.isActive) {
      _add(
        issues,
        'inactive_difficulty',
        'difficultyId',
        '활성 난이도만 모집할 수 있습니다.',
      );
    }
    if (reference.selectedGates.isEmpty) {
      _add(issues, 'empty_gates', 'selectedGates', '관문을 하나 이상 선택해야 합니다.');
    }
    for (final gate in reference.selectedGates) {
      if (gate < 1 || gate > raid.gateCount) {
        _add(
          issues,
          'gate_out_of_range',
          'selectedGates',
          '관문은 1부터 ${raid.gateCount} 사이여야 합니다: $gate',
        );
      }
    }
    return List.unmodifiable(issues);
  }

  RaidDefinition? _findRaid(RaidCatalog catalog, String raidId) {
    for (final raid in catalog.raids) {
      if (raid.raidId == raidId) return raid;
    }
    return null;
  }

  RaidDifficultyDefinition? _findDifficulty(
    RaidDefinition raid,
    String difficultyId,
  ) {
    for (final difficulty in raid.difficulties) {
      if (difficulty.difficultyId == difficultyId) return difficulty;
    }
    return null;
  }

  void _checkUnique(
    List<RaidCatalogValidationIssue> issues, {
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
    List<RaidCatalogValidationIssue> issues,
    String value,
    String path,
  ) {
    if (value.trim().isEmpty) {
      _add(issues, 'blank_value', path, '빈 문자열을 사용할 수 없습니다.');
    }
  }

  void _add(
    List<RaidCatalogValidationIssue> issues,
    String code,
    String path,
    String message,
  ) {
    issues.add(
      RaidCatalogValidationIssue(code: code, path: path, message: message),
    );
  }
}
