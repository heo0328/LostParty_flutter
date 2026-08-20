import '../../domain/entities/game_catalog.dart';
import '../../domain/repositories/game_catalog_repository.dart';
import '../../domain/validation/game_catalog_validator.dart';
import '../datasources/asset_game_catalog_data_source.dart';

class InvalidGameCatalogException implements Exception {
  const InvalidGameCatalogException(this.issues);

  final List<GameCatalogValidationIssue> issues;
}

class GameCatalogRepositoryImpl implements GameCatalogRepository {
  const GameCatalogRepositoryImpl({
    required AssetGameCatalogDataSource dataSource,
    GameCatalogValidator validator = const GameCatalogValidator(),
  }) : _dataSource = dataSource,
       _validator = validator;

  final AssetGameCatalogDataSource _dataSource;
  final GameCatalogValidator _validator;

  @override
  Future<GameCatalog> loadCatalog() async {
    final catalog = await _dataSource.loadCatalog();
    final issues = _validator.validate(catalog);
    if (issues.isNotEmpty) {
      throw InvalidGameCatalogException(issues);
    }
    return catalog;
  }
}
