import '../../../account/domain/entities/weekly_raid_claim_command.dart';

class PartyOrphanedRaidParticipation {
  const PartyOrphanedRaidParticipation({
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.recruitmentId,
    required this.stateRevision,
    required this.isHistorical,
    this.observation,
  });

  final String characterId;
  final String raidId;
  final String cycleKey;
  final String recruitmentId;
  final int stateRevision;
  final bool isHistorical;
  final WeeklyRaidCommandObservation? observation;
}
