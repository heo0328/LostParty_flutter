import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/validation/raid_catalog_validator.dart';

void main() {
  const validator = RaidCatalogValidator();

  test('accepts a structurally valid catalog', () {
    expect(validator.validate(_validCatalog()), isEmpty);
  });

  test('rejects duplicate identifiers and invalid numeric ranges', () {
    const invalidDifficulty = RaidDifficultyDefinition(
      difficultyId: 'normal',
      name: '노말',
      displayAlias: '노말',
      displayOrder: 0,
      minItemLevel: 0,
      clearGold: -1,
      boundGold: -1,
      isActive: true,
    );
    final raid = _validRaid(
      partySize: 0,
      gateCount: 0,
      difficulties: const [invalidDifficulty, invalidDifficulty],
    );
    final catalog = _validCatalog(raids: [raid, raid]);

    final codes = validator
        .validate(catalog)
        .map((issue) => issue.code)
        .toSet();

    expect(
      codes,
      containsAll({
        'duplicate_value',
        'invalid_party_size',
        'invalid_gate_count',
        'invalid_display_order',
        'invalid_min_item_level',
        'invalid_clear_gold',
        'invalid_bound_gold',
      }),
    );
  });

  test('accepts a valid recruitment catalog reference', () {
    final issues = validator.validateReference(
      _validCatalog(),
      const RaidCatalogReference(
        catalogVersion: '2026.08.20',
        raidId: 'sample_raid',
        difficultyId: 'normal',
        selectedGates: {1, 2},
      ),
    );

    expect(issues, isEmpty);
  });

  test('allows the same difficulty identifier in different raids', () {
    final catalog = _validCatalog(
      raids: [
        _validRaid(),
        _validRaid(raidId: 'other_raid'),
      ],
    );

    expect(validator.validate(catalog), isEmpty);
  });

  test('rejects stale, unknown, inactive and out-of-range references', () {
    final catalog = _validCatalog(
      raids: [
        _validRaid(
          isActive: false,
          difficulties: const [
            RaidDifficultyDefinition(
              difficultyId: 'normal',
              name: '노말',
              displayAlias: '노말',
              displayOrder: 1,
              minItemLevel: 1700,
              clearGold: 30000,
              boundGold: 0,
              isActive: false,
            ),
          ],
        ),
      ],
    );

    final issues = validator.validateReference(
      catalog,
      const RaidCatalogReference(
        catalogVersion: 'old',
        raidId: 'sample_raid',
        difficultyId: 'normal',
        selectedGates: {0, 3},
      ),
    );
    final codes = issues.map((issue) => issue.code);

    expect(codes, contains('catalog_version_mismatch'));
    expect(codes, contains('inactive_raid'));
    expect(codes, contains('inactive_difficulty'));
    expect(codes.where((code) => code == 'gate_out_of_range'), hasLength(2));
  });

  test('rejects a difficulty that belongs to another raid', () {
    final catalog = _validCatalog(
      raids: [
        _validRaid(),
        _validRaid(
          raidId: 'other_raid',
          difficulties: const [
            RaidDifficultyDefinition(
              difficultyId: 'other_hard',
              name: '하드',
              displayAlias: '하드',
              displayOrder: 1,
              minItemLevel: 1720,
              clearGold: 40000,
              boundGold: 0,
              isActive: true,
            ),
          ],
        ),
      ],
    );

    final issues = validator.validateReference(
      catalog,
      const RaidCatalogReference(
        catalogVersion: '2026.08.20',
        raidId: 'sample_raid',
        difficultyId: 'other_hard',
        selectedGates: {1},
      ),
    );

    expect(issues.map((issue) => issue.code), contains('unknown_difficulty'));
  });
}

RaidCatalog _validCatalog({List<RaidDefinition>? raids}) {
  return RaidCatalog(
    schemaVersion: 1,
    catalogVersion: '2026.08.20',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: raids ?? [_validRaid()],
  );
}

RaidDefinition _validRaid({
  String raidId = 'sample_raid',
  int partySize = 8,
  int gateCount = 2,
  bool isActive = true,
  List<RaidDifficultyDefinition> difficulties = const [
    RaidDifficultyDefinition(
      difficultyId: 'normal',
      name: '노말',
      displayAlias: '노말',
      displayOrder: 1,
      minItemLevel: 1700,
      clearGold: 30000,
      boundGold: 0,
      isActive: true,
    ),
  ],
}) {
  return RaidDefinition(
    raidId: raidId,
    officialName: '샘플 레이드',
    displayName: '샘플',
    aliases: const [],
    partySize: partySize,
    partyCount: 2,
    requiredSupportCount: 2,
    maxDealerCountPerClass: 2,
    gateCount: gateCount,
    isActive: isActive,
    difficulties: difficulties,
  );
}
