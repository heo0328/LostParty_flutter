class CreateManualWeeklyRaidClaimCommand {
  const CreateManualWeeklyRaidClaimCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.difficultyId,
    required this.cycleKey,
    required this.cycleStartedAt,
    required this.cycleEndsAt,
    this.observation,
    this.forCancellation = false,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String difficultyId;
  final String cycleKey;
  final DateTime cycleStartedAt;
  final DateTime cycleEndsAt;
  final WeeklyRaidCommandObservation? observation;
  final bool forCancellation;
}

class ManualWeeklyRaidClaimImpact {
  const ManualWeeklyRaidClaimImpact({
    this.activeRecruitmentId,
    this.activeRecruitmentTitle,
    this.isRecruitmentLeader = false,
    this.willDisbandRecruitment = false,
    this.nextLeaderCharacterName,
    this.pendingApplicationCount = 0,
    this.orphanedRecruitmentId,
    this.orphanedCycleKey,
    this.orphanedStateRevision,
    this.isHistoricalOrphanedParticipation = false,
    this.observation,
  });

  final String? activeRecruitmentId;
  final String? activeRecruitmentTitle;
  final bool isRecruitmentLeader;
  final bool willDisbandRecruitment;
  final String? nextLeaderCharacterName;
  final int pendingApplicationCount;
  final String? orphanedRecruitmentId;
  final String? orphanedCycleKey;
  final int? orphanedStateRevision;
  final bool isHistoricalOrphanedParticipation;
  final WeeklyRaidCommandObservation? observation;

  bool get hasActiveRecruitment => activeRecruitmentId != null;
  bool get hasOrphanedParticipation => orphanedRecruitmentId != null;
  bool get requiresConfirmation =>
      hasActiveRecruitment || pendingApplicationCount > 0;
}

class CleanupOrphanRaidParticipationCommand {
  const CleanupOrphanRaidParticipationCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.recruitmentId,
    this.expectedStateRevision,
    this.observation,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final String recruitmentId;
  final int? expectedStateRevision;
  final WeeklyRaidCommandObservation? observation;
}

class DeleteManualWeeklyRaidClaimCommand {
  const DeleteManualWeeklyRaidClaimCommand({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    this.observation,
  });

  final String playerId;
  final String characterId;
  final String raidId;
  final String cycleKey;
  final WeeklyRaidCommandObservation? observation;
}

/// Captured before confirmation; exact versions prevent delayed commands from
/// applying to a different ownership or participation lifetime.
class WeeklyRaidCommandObservation {
  WeeklyRaidCommandObservation({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.cycleKey,
    required this.ownershipRevision,
    required Map<String, dynamic>? state,
    required Map<String, dynamic>? claim,
    required Map<String, dynamic>? assignment,
    this.recruitmentRevision,
    Map<String, Map<String, dynamic>> applications = const {},
  }) : stateVersion = _version(state),
       claimVersion = _version(claim),
       assignmentVersion = _version(assignment),
       applicationVersions = Map.unmodifiable(
         applications.map((key, value) => MapEntry(key, _version(value)!)),
       );

  final String playerId, characterId, raidId, cycleKey;
  final int ownershipRevision;
  final int? recruitmentRevision;
  final List<Object?>? stateVersion, claimVersion, assignmentVersion;
  final Map<String, List<Object?>> applicationVersions;
  bool matchesApplication(String path, Map<String, dynamic> data) =>
      applicationVersions.containsKey(path) &&
      _same(applicationVersions[path], _version(data));

  /// Cleanup uses the record's cycle, which may precede the query cycle.
  /// Neither claims nor an already removed pair are deletion targets.
  bool matchesCleanup({
    required String playerId,
    required String characterId,
    required String raidId,
    required int ownershipRevision,
    required Map<String, dynamic>? state,
    required Map<String, dynamic>? assignment,
  }) =>
      this.playerId == playerId &&
      this.characterId == characterId &&
      this.raidId == raidId &&
      this.ownershipRevision == ownershipRevision &&
      ((state == null && assignment == null) ||
          (_same(stateVersion, _version(state)) &&
              _same(assignmentVersion, _version(assignment))));

  bool matches({
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
    required int ownershipRevision,
    required Map<String, dynamic>? state,
    required Map<String, dynamic>? claim,
    required Map<String, dynamic>? assignment,
    bool afterHistoricalDelete = false,
  }) =>
      this.playerId == playerId &&
      this.characterId == characterId &&
      this.raidId == raidId &&
      this.cycleKey == cycleKey &&
      this.ownershipRevision == ownershipRevision &&
      _same(afterHistoricalDelete ? null : stateVersion, _version(state)) &&
      _same(claimVersion, _version(claim)) &&
      _same(assignmentVersion, _version(assignment));

  static List<Object?>? _version(Map<String, dynamic>? data) => data == null
      ? null
      : List<Object?>.unmodifiable([
          for (final key in const [
            'playerId',
            'applicantPlayerId',
            'characterId',
            'raidId',
            'ownershipRevision',
            'revision',
            'cycleKey',
            'status',
            'source',
            'recruitmentId',
            'completedAt',
            'updatedAt',
            'guardSchemaVersion',
            'guardRecruitmentId',
            'guardRoomRevision',
            'guardCycleKey',
            'guardCycleStartedAt',
            'guardCycleEndsAt',
            'guardSlotIndex',
            'guardCheckedAt',
          ])
            data[key],
        ]);
  static bool _same(List<Object?>? a, List<Object?>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
