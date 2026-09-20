class PartyOrphanedRaidParticipation {
  const PartyOrphanedRaidParticipation({
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.recruitmentId,
    required this.stateRevision,
    required this.isHistorical,
  });

  final String characterId;
  final String raidId;
  final String cycleKey;
  final String recruitmentId;
  final int stateRevision;
  final bool isHistorical;
}
