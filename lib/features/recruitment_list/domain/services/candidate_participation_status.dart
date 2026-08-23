enum CandidateParticipationStatusType {
  pendingSameRaid,
  activeSameRaid,
  overlappingSchedule,
  uncertainSchedule,
  weeklyRaidClear,
}

class CandidateParticipationStatus {
  const CandidateParticipationStatus({required this.type, this.count = 1});

  final CandidateParticipationStatusType type;
  final int count;

  bool get isBlocking =>
      type != CandidateParticipationStatusType.pendingSameRaid;
}
