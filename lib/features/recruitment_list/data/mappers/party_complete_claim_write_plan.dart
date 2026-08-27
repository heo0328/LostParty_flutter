enum PartyCompleteClaimWriteAction { create, replace, skip }

class PartyCompleteClaimWritePlan {
  const PartyCompleteClaimWritePlan._();

  static Map<String, Object?> partyOwnerClaim({
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
    required String difficultyId,
    required String sourceRecruitmentId,
    required int sourceCompletionRevision,
    required Object cycleStartedAt,
    required Object cycleEndsAt,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'playerId': playerId,
    'characterId': characterId,
    'raidId': raidId,
    'cycleKey': cycleKey,
    'difficultyId': difficultyId,
    'source': 'partyOwner',
    'sourceRecruitmentId': sourceRecruitmentId,
    'sourceCompletionRevision': sourceCompletionRevision,
    'cycleStartedAt': cycleStartedAt,
    'cycleEndsAt': cycleEndsAt,
    'completedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> restoredAssignment({
    required String playerId,
    required String characterId,
    required String raidId,
    required String recruitmentId,
    required String cycleKey,
    required String role,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'playerId': playerId,
    'characterId': characterId,
    'raidId': raidId,
    'recruitmentId': recruitmentId,
    'cycleKey': cycleKey,
    'role': role,
    'createdAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static bool membershipMatchesSnapshot(
    Map<String, dynamic> membership,
    Map<String, Object?> snapshot,
  ) =>
      membership['characterId'] == snapshot['characterId'] &&
      membership['role'] == snapshot['role'] &&
      membership['partyIndex'] == snapshot['partyIndex'] &&
      membership['slotIndex'] == snapshot['slotIndex'];

  static bool claimMatchesPartyComplete({
    required Map<String, dynamic>? claim,
    required String recruitmentId,
    required int sourceCompletionRevision,
  }) {
    if (claim == null) return false;
    return claim['source'] == 'partyOwner' &&
        claim['sourceRecruitmentId'] == recruitmentId &&
        _revisionOf(claim['sourceCompletionRevision']) ==
            sourceCompletionRevision;
  }

  /// 같은 방의 이전 partyOwner Claim은 재완료 때 덮어쓴다.
  /// 없는 Claim만 만들고, manual/partyMember는 출처를 유지한다.
  static PartyCompleteClaimWriteAction claimWriteAction({
    required Map<String, dynamic>? existing,
    required String recruitmentId,
    required int sourceCompletionRevision,
  }) {
    if (existing == null) return PartyCompleteClaimWriteAction.create;
    final source = existing['source'];
    if (source == 'manual' || source == 'partyMember') {
      return PartyCompleteClaimWriteAction.skip;
    }
    if (source != 'partyOwner' ||
        existing['sourceRecruitmentId'] != recruitmentId) {
      return PartyCompleteClaimWriteAction.skip;
    }
    if (_revisionOf(existing['sourceCompletionRevision']) ==
        sourceCompletionRevision) {
      return PartyCompleteClaimWriteAction.skip;
    }
    return PartyCompleteClaimWriteAction.replace;
  }

  static int? _revisionOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
