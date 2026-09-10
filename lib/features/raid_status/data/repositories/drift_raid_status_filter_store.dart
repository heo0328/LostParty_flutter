import 'dart:convert';

import '../../../account/data/local/account_database.dart';
import '../../domain/entities/raid_filter_screen.dart';
import '../../domain/entities/raid_list_sort_selection.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/entities/remaining_slots_filter_selection.dart';
import '../../domain/repositories/raid_status_filter_store.dart';

class DriftRaidStatusFilterStore implements RaidStatusFilterStore {
  DriftRaidStatusFilterStore(this._database);

  final AccountDatabase _database;

  @override
  Future<RaidStatusFilterSelection> load(
    String playerId,
    RaidFilterScreen screen,
  ) async {
    final raw = await _database.loadRaidStatusFilterSelection(
      playerId,
      screenKind: screen.storageKey,
    );
    if (raw == null || raw.trim().isEmpty) {
      return RaidStatusFilterSelection.unrestricted;
    }
    try {
      return RaidStatusFilterSelection.fromJson(jsonDecode(raw));
    } catch (_) {
      return RaidStatusFilterSelection.unrestricted;
    }
  }

  @override
  Future<void> save(
    String playerId,
    RaidFilterScreen screen,
    RaidStatusFilterSelection selection,
  ) async {
    await _database.saveRaidStatusFilterSelection(
      playerId: playerId,
      screenKind: screen.storageKey,
      selectionJson: jsonEncode(selection.toJson()),
    );
  }

  @override
  Future<RaidListSortSelection> loadSort(
    String playerId,
    RaidFilterScreen screen,
  ) async {
    final raw = await _database.loadRaidStatusFilterSelection(
      playerId,
      screenKind: _sortStorageKey(screen),
    );
    if (raw == null || raw.trim().isEmpty) {
      return RaidListSortSelection.defaults;
    }
    try {
      return RaidListSortSelection.fromJson(jsonDecode(raw));
    } catch (_) {
      return RaidListSortSelection.defaults;
    }
  }

  @override
  Future<void> saveSort(
    String playerId,
    RaidFilterScreen screen,
    RaidListSortSelection selection,
  ) async {
    await _database.saveRaidStatusFilterSelection(
      playerId: playerId,
      screenKind: _sortStorageKey(screen),
      selectionJson: jsonEncode(selection.toJson()),
    );
  }

  @override
  Future<RemainingSlotsFilterSelection> loadRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
  ) async {
    final raw = await _database.loadRaidStatusFilterSelection(
      playerId,
      screenKind: _remainingSlotsStorageKey(screen),
    );
    if (raw == null || raw.trim().isEmpty) {
      return RemainingSlotsFilterSelection.unrestricted;
    }
    try {
      return RemainingSlotsFilterSelection.fromJson(jsonDecode(raw));
    } catch (_) {
      return RemainingSlotsFilterSelection.unrestricted;
    }
  }

  @override
  Future<void> saveRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
    RemainingSlotsFilterSelection selection,
  ) async {
    await _database.saveRaidStatusFilterSelection(
      playerId: playerId,
      screenKind: _remainingSlotsStorageKey(screen),
      selectionJson: jsonEncode(selection.toJson()),
    );
  }

  static String _sortStorageKey(RaidFilterScreen screen) =>
      '${screen.storageKey}.sort';

  static String _remainingSlotsStorageKey(RaidFilterScreen screen) =>
      '${screen.storageKey}.remainingSlots';
}

class MemoryRaidStatusFilterStore implements RaidStatusFilterStore {
  MemoryRaidStatusFilterStore([Map<String, RaidStatusFilterSelection>? seed]) {
    if (seed == null) return;
    for (final entry in seed.entries) {
      _values[_key(entry.key, RaidFilterScreen.activeRaids)] = entry.value;
    }
  }

  final Map<String, RaidStatusFilterSelection> _values = {};
  final Map<String, RaidListSortSelection> _sortValues = {};
  final Map<String, RemainingSlotsFilterSelection> _remainingSlotsValues = {};

  /// 레이드 현황 화면 선택. 기존 테스트가 playerId만으로 조회한다.
  Map<String, RaidStatusFilterSelection> get values => {
    for (final entry in _values.entries)
      if (entry.key.endsWith('::${RaidFilterScreen.activeRaids.storageKey}'))
        entry.key.substring(
          0,
          entry.key.length -
              '::${RaidFilterScreen.activeRaids.storageKey}'.length,
        ): entry.value,
  };

  @override
  Future<RaidStatusFilterSelection> load(
    String playerId,
    RaidFilterScreen screen,
  ) async =>
      _values[_key(playerId, screen)] ?? RaidStatusFilterSelection.unrestricted;

  @override
  Future<void> save(
    String playerId,
    RaidFilterScreen screen,
    RaidStatusFilterSelection selection,
  ) async {
    _values[_key(playerId, screen)] = selection;
  }

  @override
  Future<RaidListSortSelection> loadSort(
    String playerId,
    RaidFilterScreen screen,
  ) async =>
      _sortValues[_sortKey(playerId, screen)] ?? RaidListSortSelection.defaults;

  @override
  Future<void> saveSort(
    String playerId,
    RaidFilterScreen screen,
    RaidListSortSelection selection,
  ) async {
    _sortValues[_sortKey(playerId, screen)] = selection;
  }

  @override
  Future<RemainingSlotsFilterSelection> loadRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
  ) async =>
      _remainingSlotsValues[_remainingSlotsKey(playerId, screen)] ??
      RemainingSlotsFilterSelection.unrestricted;

  @override
  Future<void> saveRemainingSlotsFilter(
    String playerId,
    RaidFilterScreen screen,
    RemainingSlotsFilterSelection selection,
  ) async {
    _remainingSlotsValues[_remainingSlotsKey(playerId, screen)] = selection;
  }

  static String _key(String playerId, RaidFilterScreen screen) =>
      '$playerId::${screen.storageKey}';

  static String _sortKey(String playerId, RaidFilterScreen screen) =>
      '$playerId::${screen.storageKey}.sort';

  static String _remainingSlotsKey(String playerId, RaidFilterScreen screen) =>
      '$playerId::${screen.storageKey}.remainingSlots';
}
