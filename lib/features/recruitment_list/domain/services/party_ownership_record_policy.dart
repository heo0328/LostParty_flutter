import '../../../account/domain/game_account_ownership_snapshot.dart';

/// Classifies a stored record only after its identity and authority are known.
class PartyOwnershipRecordPolicy {
  const PartyOwnershipRecordPolicy._();

  static GameAccountOwnershipCondition classify({
    required GameAccountOwnershipSnapshot ownership,
    required Map<String, dynamic> data,
    required String playerId,
    required String characterId,
    required String raidId,
    required bool isRaidState,
    bool availabilityOnly = false,
    String? claimCycleKey,
  }) {
    if (ownership.condition != GameAccountOwnershipCondition.current ||
        data['playerId'] != playerId ||
        data['characterId'] != characterId ||
        data['raidId'] != raidId) {
      return GameAccountOwnershipCondition.unknown;
    }
    if (isRaidState && !availabilityOnly) {
      final revision = data['revision'];
      final cycle = data['cycleKey'];
      if (revision is! int ||
          revision < 1 ||
          cycle is! String ||
          cycle.isEmpty ||
          !const ['active', 'completed'].contains(data['status'])) {
        return GameAccountOwnershipCondition.unknown;
      }
    } else if (!isRaidState && data['cycleKey'] != claimCycleKey) {
      return GameAccountOwnershipCondition.unknown;
    }
    return ownership.classifyParticipation(data);
  }
}
