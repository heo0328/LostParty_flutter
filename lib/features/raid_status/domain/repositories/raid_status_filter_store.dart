import '../entities/raid_filter_screen.dart';
import '../entities/raid_status_filter_selection.dart';

abstract class RaidStatusFilterStore {
  Future<RaidStatusFilterSelection> load(
    String playerId,
    RaidFilterScreen screen,
  );

  Future<void> save(
    String playerId,
    RaidFilterScreen screen,
    RaidStatusFilterSelection selection,
  );
}
