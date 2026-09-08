import 'dart:convert';

import '../../../account/data/local/account_database.dart';
import '../../domain/entities/raid_filter_screen.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
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
}

class MemoryRaidStatusFilterStore implements RaidStatusFilterStore {
  MemoryRaidStatusFilterStore([Map<String, RaidStatusFilterSelection>? seed]) {
    if (seed == null) return;
    for (final entry in seed.entries) {
      _values[_key(entry.key, RaidFilterScreen.activeRaids)] = entry.value;
    }
  }

  final Map<String, RaidStatusFilterSelection> _values = {};

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

  static String _key(String playerId, RaidFilterScreen screen) =>
      '$playerId::${screen.storageKey}';
}
