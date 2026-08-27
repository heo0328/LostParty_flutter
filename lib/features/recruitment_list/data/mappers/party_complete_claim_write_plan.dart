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
        claim['sourceCompletionRevision'] == sourceCompletionRevision;
  }
}
