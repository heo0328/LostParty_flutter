class PartyCompleteCycleCommand {
  const PartyCompleteCycleCommand({required this.recruitmentId, required this.cycleKey, required this.expectedRecruitmentRevision});
  final String recruitmentId;
  final String cycleKey;
  final int expectedRecruitmentRevision;
}

class PartyCancelCompletionCommand {
  const PartyCancelCompletionCommand({required this.recruitmentId, required this.cycleKey, required this.expectedRecruitmentRevision, required this.expectedCompletionRevision});
  final String recruitmentId;
  final String cycleKey;
  final int expectedRecruitmentRevision;
  final int expectedCompletionRevision;
}

class PartySetRecurrenceCommand {
  const PartySetRecurrenceCommand({required this.recruitmentId, required this.continueTogether, required this.expectedRecruitmentRevision});
  final String recruitmentId;
  final bool continueTogether;
  final int expectedRecruitmentRevision;
}

class PartyAdvanceCycleCommand {
  const PartyAdvanceCycleCommand({required this.recruitmentId, required this.expectedCycleKey, required this.nextCycleKey, required this.expectedRecruitmentRevision});
  final String recruitmentId;
  final String expectedCycleKey;
  final String nextCycleKey;
  final int expectedRecruitmentRevision;
}

class PartyDisbandCommand {
  const PartyDisbandCommand({
    required this.recruitmentId,
    required this.expectedRecruitmentRevision,
  });

  final String recruitmentId;
  final int expectedRecruitmentRevision;
}

/// completed/해산 대기 orphan 본인 점유 정리. Claim은 만들지 않는다.
class PartyPurgeStaleAssignmentCommand {
  const PartyPurgeStaleAssignmentCommand({
    required this.recruitmentId,
    required this.characterId,
    required this.raidId,
  });

  final String recruitmentId;
  final String characterId;
  final String raidId;
}

enum PartyCycleFailure { unauthenticated, playerBindingMissing, notFound, unauthorized, recruitmentClosed, cycleMismatch, alreadyCompleted, notCompleted, completionCancelExpired, notReadyForAdvance, revisionConflict, permissionDenied, temporarilyUnavailable, invalidRequest, unknown }

class PartyCycleResult {
  const PartyCycleResult.success() : failure = null;
  const PartyCycleResult.failure(this.failure);
  final PartyCycleFailure? failure;
  bool get isSuccess => failure == null;
}
