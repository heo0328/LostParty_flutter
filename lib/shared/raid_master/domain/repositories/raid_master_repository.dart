import '../entities/raid_base.dart';
import '../entities/raid_variation.dart';

abstract class RaidMasterRepository {
  Future<List<RaidBase>> getRaidBases();

  Future<List<RaidVariation>> getRaidVariations();

  Future<List<RaidVariation>> getRaidVariationsByBaseId(String raidBaseId);

  Future<RaidBase?> getRaidBaseById(String raidBaseId);

  Future<RaidVariation?> getRaidVariationById(String raidId);
}
