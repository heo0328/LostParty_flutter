enum PartyCycleAssignmentAction { create, update, delete, skip, conflict }

class PartyCycleAssignmentWritePlan {
  const PartyCycleAssignmentWritePlan._();

  static PartyCycleAssignmentAction decide({
    required bool continueTogether,
    required bool assignmentExists,
    required String? assignmentRecruitmentId,
    required String? assignmentCycleKey,
    required String recruitmentId,
    required String oldCycleKey,
    required String targetCycleKey,
  }) {
    if (!assignmentExists) {
      return continueTogether
          ? PartyCycleAssignmentAction.create
          : PartyCycleAssignmentAction.skip;
    }
    if (assignmentRecruitmentId != recruitmentId) {
      return continueTogether
          ? PartyCycleAssignmentAction.conflict
          : PartyCycleAssignmentAction.skip;
    }
    if (assignmentCycleKey == targetCycleKey) {
      return continueTogether
          ? PartyCycleAssignmentAction.skip
          : PartyCycleAssignmentAction.conflict;
    }
    if (assignmentCycleKey != oldCycleKey) {
      return PartyCycleAssignmentAction.conflict;
    }
    return continueTogether
        ? PartyCycleAssignmentAction.update
        : PartyCycleAssignmentAction.delete;
  }

  static Map<String, Object?> recurringAssignment({
    required String playerId,
    required String characterId,
    required String raidId,
    required String recruitmentId,
    required String targetCycleKey,
    required String role,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'playerId': playerId,
    'characterId': characterId,
    'raidId': raidId,
    'recruitmentId': recruitmentId,
    'cycleKey': targetCycleKey,
    'role': role,
    'createdAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };
}
