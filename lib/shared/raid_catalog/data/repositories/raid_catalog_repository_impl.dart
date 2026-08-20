import '../../domain/entities/raid_catalog.dart';
import '../../domain/repositories/raid_catalog_repository.dart';
import '../../domain/validation/raid_catalog_validator.dart';
import '../datasources/asset_raid_catalog_data_source.dart';

class InvalidRaidCatalogException implements Exception {
  const InvalidRaidCatalogException(this.issues);

  final List<RaidCatalogValidationIssue> issues;
}

class RaidCatalogRepositoryImpl implements RaidCatalogRepository {
  const RaidCatalogRepositoryImpl({
    required AssetRaidCatalogDataSource dataSource,
    RaidCatalogValidator validator = const RaidCatalogValidator(),
  }) : _dataSource = dataSource,
       _validator = validator;

  final AssetRaidCatalogDataSource _dataSource;
  final RaidCatalogValidator _validator;

  @override
  Future<RaidCatalog> loadCatalog() async {
    final catalog = await _dataSource.loadCatalog();
    final issues = _validator.validate(catalog);
    if (issues.isNotEmpty) throw InvalidRaidCatalogException(issues);
    return catalog;
  }
}
