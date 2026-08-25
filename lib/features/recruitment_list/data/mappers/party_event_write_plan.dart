class PartyEventWritePlan {
  const PartyEventWritePlan._();

  static String id({required String recruitmentId, required String cycleKey, required int eventRevision, required String type}) => '${recruitmentId}_${cycleKey}_${eventRevision}_$type';

  static Map<String, Object?> cycle({required String eventId, required String type, required String playerId, required String recruitmentId, required String cycleKey, required String raidId, required String difficultyId, required int eventRevision, required Map<String, Object?> memberSnapshot, required Object serverTimestamp, required Object expiresAt}) => {
    'schemaVersion': 1, 'eventId': eventId, 'type': type,
    'playerId': playerId, 'recruitmentId': recruitmentId,
    'cycleKey': cycleKey, 'raidId': raidId, 'difficultyId': difficultyId,
    'eventRevision': eventRevision, 'characterId': memberSnapshot['characterId'],
    'characterNameSnapshot': memberSnapshot['characterNameSnapshot'],
    'classNameSnapshot': memberSnapshot['classNameSnapshot'],
    'role': memberSnapshot['role'], 'partyIndex': memberSnapshot['partyIndex'],
    'occurredAt': serverTimestamp, 'expiresAt': expiresAt,
  };
}
