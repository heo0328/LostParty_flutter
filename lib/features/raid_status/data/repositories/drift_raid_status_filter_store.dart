import 'dart:convert';

import '../../../account/data/local/account_database.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/repositories/raid_status_filter_store.dart';

class DriftRaidStatusFilterStore implements RaidStatusFilterStore {
  DriftRaidStatusFilterStore(this._database);

  final AccountDatabase _database;

  @override
  Future<RaidStatusFilterSelection> load(String playerId) async {
    final raw = await _database.loadRaidStatusFilterSelection(playerId);
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
    RaidStatusFilterSelection selection,
  ) async {
    await _database.saveRaidStatusFilterSelection(
      playerId: playerId,
      selectionJson: jsonEncode(selection.toJson()),
    );
  }
}

class MemoryRaidStatusFilterStore implements RaidStatusFilterStore {
  MemoryRaidStatusFilterStore([Map<String, RaidStatusFilterSelection>? seed])
    : _values = {...?seed};

  final Map<String, RaidStatusFilterSelection> _values;

  Map<String, RaidStatusFilterSelection> get values =>
      Map.unmodifiable(_values);

  @override
  Future<RaidStatusFilterSelection> load(String playerId) async =>
      _values[playerId] ?? RaidStatusFilterSelection.unrestricted;

  @override
  Future<void> save(
    String playerId,
    RaidStatusFilterSelection selection,
  ) async {
    _values[playerId] = selection;
  }
}
