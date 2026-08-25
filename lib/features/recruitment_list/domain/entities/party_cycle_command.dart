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

enum PartyCycleFailure { unauthenticated, playerBindingMissing, notFound, unauthorized, recruitmentClosed, cycleMismatch, alreadyCompleted, notCompleted, completionCancelExpired, notReadyForAdvance, revisionConflict, permissionDenied, temporarilyUnavailable, invalidRequest, unknown }

class PartyCycleResult {
  const PartyCycleResult.success() : failure = null;
  const PartyCycleResult.failure(this.failure);
  final PartyCycleFailure? failure;
  bool get isSuccess => failure == null;
}
