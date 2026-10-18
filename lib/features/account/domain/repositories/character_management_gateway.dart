import 'package:flutter/foundation.dart';

import '../entities/local_game_account.dart';

/// Existing management UI projection. Integer IDs exist only in this editor;
/// implementations retain the canonical UUID mapping and never persist them.
class CharacterManagementSnapshot {
  const CharacterManagementSnapshot({
    required this.account,
    required this.selectedIds,
    required this.usableIds,
    required this.hasNiceGroup,
    this.initialSelectionRequired = false,
  });
  final LocalGameAccount account;
  final Set<int> selectedIds, usableIds;
  final bool hasNiceGroup;
  final bool initialSelectionRequired;
}

abstract class CharacterManagementGateway implements Listenable {
  bool get current;
  bool get pending;
  bool get busy;
  Future<CharacterManagementSnapshot> load();
  Future<CharacterManagementSnapshot> save({
    required List<int> selectedIds,
    required int representativeId,
    required int displayLimit,
    bool saveDisplayOrder = true,
  });
}
