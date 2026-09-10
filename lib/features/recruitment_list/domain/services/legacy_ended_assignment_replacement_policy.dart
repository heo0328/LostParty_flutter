class LegacyEndedAssignmentReplacementPolicy {
  const LegacyEndedAssignmentReplacementPolicy();

  bool canReplace({
    required bool assignmentExists,
    required String? assignmentRecruitmentId,
    required String? assignmentCycleKey,
    required String? assignmentRaidId,
    required bool assignedRecruitmentExists,
    required String? assignedRecruitmentStatus,
    required String? assignedRecruitmentCycleStatus,
    required String? assignedRecruitmentCycleKey,
    required bool? assignedRecruitmentContinuesTogether,
    required String newRecruitmentId,
    required String newCycleKey,
    required String newRaidId,
  }) {
    return assignmentExists &&
        assignedRecruitmentExists &&
        assignmentRecruitmentId != null &&
        assignmentRecruitmentId.isNotEmpty &&
        assignmentRecruitmentId != newRecruitmentId &&
        assignmentCycleKey != null &&
        assignmentCycleKey == assignedRecruitmentCycleKey &&
        assignmentCycleKey != newCycleKey &&
        assignmentRaidId == newRaidId &&
        assignedRecruitmentStatus == 'incompleteEnded' &&
        assignedRecruitmentCycleStatus == 'incompleteEnded' &&
        assignedRecruitmentContinuesTogether == false;
  }
}
