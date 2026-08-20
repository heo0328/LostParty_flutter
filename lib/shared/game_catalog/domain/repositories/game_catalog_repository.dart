import '../entities/game_catalog.dart';

abstract interface class GameCatalogRepository {
  Future<GameCatalog> loadCatalog();
}
