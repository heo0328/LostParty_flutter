class CharacterSummaryServerPatch {
  const CharacterSummaryServerPatch({
    required this.serverCharacterId,
    required this.characterName,
    required this.characterLevel,
    required this.itemAvgLevel,
    required this.fetchedAt,
  });

  final String serverCharacterId;
  final String characterName;
  final int characterLevel;
  final String itemAvgLevel;
  final DateTime fetchedAt;
}

abstract interface class CharacterSummarySyncGateway {
  Future<void> updateSummaries(List<CharacterSummaryServerPatch> patches);
}
