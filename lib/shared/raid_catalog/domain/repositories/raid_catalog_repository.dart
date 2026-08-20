import '../entities/raid_catalog.dart';

abstract class RaidCatalogRepository {
  Future<RaidCatalog> loadCatalog();
}
