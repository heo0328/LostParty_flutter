import '../entities/active_raid_assignment.dart';
import '../policies/participation_conflict_policy.dart';

class ActiveRaidAssignmentAcquireResult {
  const ActiveRaidAssignmentAcquireResult._({
    required this.isSuccess,
    required this.decision,
    this.assignment,
  });

  const ActiveRaidAssignmentAcquireResult.acquired(
    ActiveRaidAssignment assignment,
  ) : this._(
        isSuccess: true,
        assignment: assignment,
        decision: const ParticipationConflictDecision([]),
      );

  const ActiveRaidAssignmentAcquireResult.rejected(
    ParticipationConflictDecision decision,
  ) : this._(isSuccess: false, decision: decision);

  final bool isSuccess;
  final ActiveRaidAssignment? assignment;
  final ParticipationConflictDecision decision;
}

abstract class ActiveRaidAssignmentRepository {
  Future<List<ActiveRaidAssignment>> getByUser(String userId);

  Future<ActiveRaidAssignmentAcquireResult> acquire(
    ActiveRaidAssignment assignment,
  );

  Future<ActiveRaidAssignmentAcquireResult> replace({
    required ActiveRaidAssignment current,
    required ActiveRaidAssignment replacement,
  });

  Future<bool> release({
    required String userId,
    required String characterId,
    required String raidId,
    required String recruitmentId,
  });
}
