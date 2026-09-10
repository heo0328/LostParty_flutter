class PartyCreateOccupancyGate {
  const PartyCreateOccupancyGate._();

  static const _staleStatuses = {'disbanded', 'incompleteEnded'};

  /// Transaction 재시도·해산 후 남은 점유를 생성 거절과 구분한다.
  static PartyCreateOccupancyDecision decide({
    required String newRecruitmentId,
    required String playerId,
    required bool newRecruitmentExists,
    required String? newRecruitmentLeaderId,
    required bool assignmentExists,
    required String? assignmentRecruitmentId,
    required String? assignmentCycleKey,
    required bool assignedRecruitmentExists,
    required String? assignedRecruitmentStatus,
    required String? assignedRecruitmentCycleKey,
    required bool assignedRecruitmentContinuesTogether,
    required DateTime? assignedRecruitmentCycleEndsAt,
    required String newCycleKey,
    required DateTime now,
  }) {
    if (newRecruitmentExists) {
      if (newRecruitmentLeaderId == playerId) {
        return PartyCreateOccupancyDecision.alreadyCreated;
      }
      return PartyCreateOccupancyDecision.idConflict;
    }
    if (!assignmentExists) {
      return PartyCreateOccupancyDecision.proceed;
    }
    if (assignmentRecruitmentId == newRecruitmentId) {
      return PartyCreateOccupancyDecision.alreadyCreated;
    }
    if (!assignedRecruitmentExists ||
        _staleStatuses.contains(assignedRecruitmentStatus)) {
      return PartyCreateOccupancyDecision.replaceStaleAssignment;
    }
    final expiredOneShot = assignedRecruitmentStatus == 'active' &&
        !assignedRecruitmentContinuesTogether &&
        assignedRecruitmentCycleKey != null &&
        assignmentCycleKey == assignedRecruitmentCycleKey &&
        assignedRecruitmentCycleKey != newCycleKey &&
        assignedRecruitmentCycleEndsAt != null &&
        !now.toUtc().isBefore(assignedRecruitmentCycleEndsAt.toUtc());
    if (expiredOneShot) {
      return PartyCreateOccupancyDecision.replaceStaleAssignment;
    }
    return PartyCreateOccupancyDecision.participationConflict;
  }
}

enum PartyCreateOccupancyDecision {
  proceed,
  alreadyCreated,
  replaceStaleAssignment,
  idConflict,
  participationConflict,
}
