import '../entities/active_raid_assignment.dart';

enum ParticipationConflictType {
  sameUserInRecruitment,
  sameCharacterAndRaid,
  overlappingSchedule,
  uncertainSchedule,
}

class ParticipationConflict {
  const ParticipationConflict({required this.type, required this.assignment});

  final ParticipationConflictType type;
  final ActiveRaidAssignment assignment;
}

class ParticipationConflictDecision {
  const ParticipationConflictDecision(this.conflicts);

  final List<ParticipationConflict> conflicts;

  bool get canConfirm => conflicts.isEmpty;
  bool get hasBlockingConflict => conflicts.any(
    (conflict) => conflict.type != ParticipationConflictType.uncertainSchedule,
  );
  bool get requiresScheduleResolution => conflicts.any(
    (conflict) => conflict.type == ParticipationConflictType.uncertainSchedule,
  );
}

class ParticipationConflictPolicy {
  const ParticipationConflictPolicy();

  ParticipationConflictDecision evaluate({
    required ActiveRaidAssignment proposed,
    required Iterable<ActiveRaidAssignment> activeAssignments,
  }) {
    final conflicts = <ParticipationConflict>[];
    for (final active in activeAssignments) {
      if (active.userId != proposed.userId) continue;

      if (active.recruitmentId == proposed.recruitmentId) {
        conflicts.add(
          ParticipationConflict(
            type: ParticipationConflictType.sameUserInRecruitment,
            assignment: active,
          ),
        );
        continue;
      }

      if (active.characterId == proposed.characterId &&
          active.raidId == proposed.raidId) {
        conflicts.add(
          ParticipationConflict(
            type: ParticipationConflictType.sameCharacterAndRaid,
            assignment: active,
          ),
        );
      }

      final scheduleConflict = _scheduleConflict(
        active.schedule,
        proposed.schedule,
      );
      if (scheduleConflict != null) {
        conflicts.add(
          ParticipationConflict(type: scheduleConflict, assignment: active),
        );
      }
    }
    return ParticipationConflictDecision(List.unmodifiable(conflicts));
  }

  ParticipationConflictType? _scheduleConflict(
    RaidParticipationSchedule left,
    RaidParticipationSchedule right,
  ) {
    final leftEnd = left.expectedEndAt;
    final rightEnd = right.expectedEndAt;
    if (leftEnd != null && !leftEnd.isAfter(right.startAt)) return null;
    if (rightEnd != null && !rightEnd.isAfter(left.startAt)) return null;
    if (leftEnd == null || rightEnd == null) {
      return ParticipationConflictType.uncertainSchedule;
    }
    final overlaps = left.startAt.isBefore(rightEnd) &&
        right.startAt.isBefore(leftEnd);
    return overlaps ? ParticipationConflictType.overlappingSchedule : null;
  }
}
