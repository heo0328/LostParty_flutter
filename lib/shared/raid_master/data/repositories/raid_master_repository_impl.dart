import '../../domain/entities/raid_base.dart';
import '../../domain/entities/raid_variation.dart';
import '../../domain/repositories/raid_master_repository.dart';
import '../../../raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import '../../../raid_catalog/data/repositories/raid_catalog_repository_impl.dart';
import '../../../raid_catalog/domain/entities/raid_catalog.dart';
import '../../../raid_catalog/domain/repositories/raid_catalog_repository.dart';

class RaidMasterRepositoryImpl implements RaidMasterRepository {
  RaidMasterRepositoryImpl({RaidCatalogRepository? catalogRepository})
    : _catalogRepository =
          catalogRepository ??
          RaidCatalogRepositoryImpl(dataSource: AssetRaidCatalogDataSource());

  final RaidCatalogRepository _catalogRepository;

  @override
  Future<List<RaidBase>> getRaidBases() async {
    final catalog = await _catalogRepository.loadCatalog();
    return catalog.raids.where((raid) => raid.isActive).map(_mapBase).toList();
  }

  @override
  Future<List<RaidVariation>> getRaidVariations() async {
    final catalog = await _catalogRepository.loadCatalog();
    return catalog.raids
        .where((raid) => raid.isActive)
        .expand(_mapVariations)
        .toList();
  }

  @override
  Future<List<RaidVariation>> getRaidVariationsByBaseId(
    String raidBaseId,
  ) async {
    final catalog = await _catalogRepository.loadCatalog();
    for (final raid in catalog.raids) {
      if (raid.raidId == raidBaseId && raid.isActive) {
        return _mapVariations(raid).toList();
      }
    }
    return const [];
  }

  @override
  Future<RaidBase?> getRaidBaseById(String raidBaseId) async {
    final catalog = await _catalogRepository.loadCatalog();
    for (final raid in catalog.raids) {
      if (raid.raidId == raidBaseId && raid.isActive) return _mapBase(raid);
    }
    return null;
  }

  @override
  Future<RaidVariation?> getRaidVariationById(String raidId) async {
    final variations = await getRaidVariations();
    for (final variation in variations) {
      if (variation.raidId == raidId) return variation;
    }
    return null;
  }

  RaidBase _mapBase(RaidDefinition raid) => RaidBase(
    raidBaseId: raid.raidId,
    name: raid.displayName,
    partySize: raid.partySize,
    gateCount: raid.gateCount,
    difficultyIds: raid.difficulties
        .where((difficulty) => difficulty.isActive)
        .map((difficulty) => _variationId(raid.raidId, difficulty.difficultyId))
        .toList(),
  );

  Iterable<RaidVariation> _mapVariations(RaidDefinition raid) => raid
      .difficulties
      .where((difficulty) => difficulty.isActive)
      .map(
        (difficulty) => RaidVariation(
          raidId: _variationId(raid.raidId, difficulty.difficultyId),
          raidBaseId: raid.raidId,
          difficultyOrder: difficulty.displayOrder,
          difficultyLabel: difficulty.name,
          minItemLevel: difficulty.minItemLevel,
          rewardGold: difficulty.clearGold + difficulty.boundGold,
        ),
      );

  String _variationId(String raidId, String difficultyId) =>
      '${raidId}_$difficultyId';
}
