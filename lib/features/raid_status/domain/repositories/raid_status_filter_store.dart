import '../entities/raid_status_filter_selection.dart';

abstract class RaidStatusFilterStore {
  Future<RaidStatusFilterSelection> load(String playerId);

  Future<void> save(String playerId, RaidStatusFilterSelection selection);
}
