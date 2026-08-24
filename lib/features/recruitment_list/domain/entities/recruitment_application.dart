import 'party_recruitment.dart';

enum RecruitmentApplicationStatus {
  pending,
  approved,
  rejected,
  withdrawn,
  superseded,
}

enum ApplicationVoteDecision { approve, reject }

class ApplicationVote {
  const ApplicationVote({required this.voterUserId, required this.decision});

  final String voterUserId;
  final ApplicationVoteDecision decision;
}

class RecruitmentApplication {
  const RecruitmentApplication({
    required this.applicantUserId,
    required this.characterId,
    required this.className,
    required this.requestedRole,
    this.itemLevel,
    this.combatPower,
    this.status = RecruitmentApplicationStatus.pending,
    this.votes = const {},
  });

  final String applicantUserId;
  final String characterId;
  final String className;
  final PartyRole requestedRole;
  final double? itemLevel;
  final double? combatPower;
  final RecruitmentApplicationStatus status;
  final Map<String, ApplicationVote> votes;

  int get approvalCount => votes.values
      .where((vote) => vote.decision == ApplicationVoteDecision.approve)
      .length;

  int get rejectionCount => votes.values
      .where((vote) => vote.decision == ApplicationVoteDecision.reject)
      .length;

  RecruitmentApplication copyWith({
    RecruitmentApplicationStatus? status,
    Map<String, ApplicationVote>? votes,
  }) => RecruitmentApplication(
    applicantUserId: applicantUserId,
    characterId: characterId,
    className: className,
    requestedRole: requestedRole,
    itemLevel: itemLevel,
    combatPower: combatPower,
    status: status ?? this.status,
    votes: votes ?? this.votes,
  );
}

class RecruitmentPartyMember {
  const RecruitmentPartyMember({
    required this.userId,
    required this.characterId,
    required this.className,
    required this.role,
    required this.partyIndex,
    this.itemLevel,
    this.combatPower,
  });

  final String userId;
  final String characterId;
  final String className;
  final PartyRole role;
  final int partyIndex;
  final double? itemLevel;
  final double? combatPower;

  RecruitmentPartyMember copyWith({
    String? characterId,
    String? className,
    PartyRole? role,
    int? partyIndex,
    double? itemLevel,
    double? combatPower,
  }) => RecruitmentPartyMember(
    userId: userId,
    characterId: characterId ?? this.characterId,
    className: className ?? this.className,
    role: role ?? this.role,
    partyIndex: partyIndex ?? this.partyIndex,
    itemLevel: itemLevel ?? this.itemLevel,
    combatPower: combatPower ?? this.combatPower,
  );
}
