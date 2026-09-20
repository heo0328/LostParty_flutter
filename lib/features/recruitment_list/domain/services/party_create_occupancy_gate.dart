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
    final expiredOneShot =
        assignedRecruitmentStatus == 'active' &&
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

  /// 같은 Character·raidId 고정 경로를 점유한 `raidState`의 수명을 판정한다.
  ///
  /// 현재 화면 주차와 다르다는 이유만으로 고아로 보지 않는다. 활성 상태는
  /// 연결 모집이 실제로 없거나 종료됐거나, 1회성 모집의 수명이 끝난 경우에만
  /// 정리 대상으로 분류한다. 반복 모집은 지난 주차 문서를 가리켜도 참가 충돌로
  /// 남겨 후속 주차 승계가 먼저 처리되게 한다.
  static ExistingRaidStateOccupancyDecision classifyExistingRaidState({
    required String requestedCycleKey,
    required String stateCycleKey,
    required String stateStatus,
    required bool recruitmentExists,
    required String? recruitmentStatus,
    required String? recruitmentCycleStatus,
    required String? recruitmentCycleKey,
    required bool recruitmentContinuesTogether,
    required DateTime? recruitmentCycleEndsAt,
    required DateTime now,
  }) {
    final isHistorical = stateCycleKey != requestedCycleKey;
    if (stateStatus == 'completed') {
      return isHistorical
          ? ExistingRaidStateOccupancyDecision.historicalCompleted
          : ExistingRaidStateOccupancyDecision.currentCompleted;
    }
    if (stateStatus != 'active') {
      return ExistingRaidStateOccupancyDecision.inconsistent;
    }

    final isClosed =
        _staleStatuses.contains(recruitmentStatus) ||
        recruitmentStatus == 'completed' ||
        recruitmentCycleStatus == 'completed';
    final isExpiredOneShot =
        recruitmentStatus == 'active' &&
        !recruitmentContinuesTogether &&
        recruitmentCycleKey == stateCycleKey &&
        recruitmentCycleEndsAt != null &&
        !now.toUtc().isBefore(recruitmentCycleEndsAt.toUtc());
    if (!recruitmentExists || isClosed || isExpiredOneShot) {
      return isHistorical
          ? ExistingRaidStateOccupancyDecision.historicalOrphanActive
          : ExistingRaidStateOccupancyDecision.currentOrphanActive;
    }
    return isHistorical
        ? ExistingRaidStateOccupancyDecision.participationConflict
        : ExistingRaidStateOccupancyDecision.currentActive;
  }
}

enum PartyCreateOccupancyDecision {
  proceed,
  alreadyCreated,
  replaceStaleAssignment,
  idConflict,
  participationConflict,
}

enum ExistingRaidStateOccupancyDecision {
  currentActive,
  currentCompleted,
  currentOrphanActive,
  historicalOrphanActive,
  historicalCompleted,
  participationConflict,
  inconsistent,
}
