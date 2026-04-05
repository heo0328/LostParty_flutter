import '../../domain/entities/raid_base.dart';
import '../../domain/entities/raid_variation.dart';
import '../../domain/repositories/raid_master_repository.dart';
import '../datasources/local_raid_data_source.dart';

class RaidMasterRepositoryImpl implements RaidMasterRepository {
  @override
  Future<List<RaidBase>> getRaidBases() async {
    return LocalRaidDataSource.raidBases;
  }

  @override
  Future<List<RaidVariation>> getRaidVariations() async {
    return LocalRaidDataSource.raidVariations;
  }

  @override
  Future<List<RaidVariation>> getRaidVariationsByBaseId(
    String raidBaseId,
  ) async {
    return LocalRaidDataSource.raidVariations
        .where((e) => e.raidBaseId == raidBaseId)
        .toList();
  }

  @override
  Future<RaidBase?> getRaidBaseById(String raidBaseId) async {
    try {
      return LocalRaidDataSource.raidBases
          .firstWhere((e) => e.raidBaseId == raidBaseId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RaidVariation?> getRaidVariationById(String raidId) async {
    try {
      return LocalRaidDataSource.raidVariations
          .firstWhere((e) => e.raidId == raidId);
    } catch (_) {
      return null;
    }
  }
}