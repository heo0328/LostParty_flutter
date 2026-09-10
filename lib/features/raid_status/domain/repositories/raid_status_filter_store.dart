import '../entities/raid_filter_screen.dart';
import '../entities/raid_list_sort_selection.dart';
import '../entities/raid_status_filter_selection.dart';
import '../entities/remaining_slots_filter_selection.dart';

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

  Future<RaidListSortSelection> loadSort(
    String playerId,
    RaidFilterScreen screen,
  );

  Future<void> saveSort(
    String playerId,
    RaidFilterScreen screen,
    RaidListSortSelection selection,
  );

  Future<RemainingSlotsFilterSelection> loadRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
  );

  Future<void> saveRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
    RemainingSlotsFilterSelection selection,
  );
}
