import '../entities/recruitment_application.dart';
import '../entities/party_recruitment.dart';
import '../policies/approval_policy.dart';
import '../policies/party_composition_policy.dart';

enum RecruitmentCommandFailure {
  none,
  recruitmentClosed,
  invalidApplication,
  duplicateApplication,
  alreadyMember,
  applicationNotFound,
  applicationNotPending,
  unauthorized,
  duplicateVote,
  compositionRejected,
  weeklyRaidAlreadyCleared,
  participationConflict,
  pendingApplicationsRequireConfirmation,
}

class RecruitmentCommandResult {
  const RecruitmentCommandResult._({
    required this.isSuccess,
    required this.state,
    required this.failure,
    this.compositionFailure = PartyCompositionFailure.none,
  });

  const RecruitmentCommandResult.success(RecruitmentState state)
    : this._(
        isSuccess: true,
        state: state,
        failure: RecruitmentCommandFailure.none,
      );

  const RecruitmentCommandResult.failure(
    RecruitmentState state,
    RecruitmentCommandFailure failure, {
    PartyCompositionFailure compositionFailure = PartyCompositionFailure.none,
  }) : this._(
         isSuccess: false,
         state: state,
         failure: failure,
         compositionFailure: compositionFailure,
       );

  final bool isSuccess;
  final RecruitmentState state;
  final RecruitmentCommandFailure failure;
  final PartyCompositionFailure compositionFailure;
}

class RecruitmentState {
  RecruitmentState({
    required this.leaderUserId,
    required this.approvalPolicy,
    required this.compositionPolicy,
    required List<RecruitmentPartyMember> members,
    Map<String, RecruitmentApplication> applications = const {},
    this.isRecruiting = true,
  }) : members = List.unmodifiable(members),
       applications = Map.unmodifiable(applications) {
    if (!this.members.any((member) => member.userId == leaderUserId)) {
      throw ArgumentError('파티장은 현재 파티원에 포함되어야 합니다.');
    }
    if (this.members.map((member) => member.userId).toSet().length !=
        this.members.length) {
      throw ArgumentError('파티원 사용자 ID는 중복될 수 없습니다.');
    }
  }

  final String leaderUserId;
  final ApprovalPolicy approvalPolicy;
  final PartyCompositionPolicy compositionPolicy;
  final List<RecruitmentPartyMember> members;
  final Map<String, RecruitmentApplication> applications;
  final bool isRecruiting;

  int get dealerCount =>
      members.where((member) => member.role == PartyRole.dealer).length;
  int get supportCount => members.length - dealerCount;

  RecruitmentState copyWith({
    PartyCompositionPolicy? compositionPolicy,
    List<RecruitmentPartyMember>? members,
    Map<String, RecruitmentApplication>? applications,
    bool? isRecruiting,
  }) => RecruitmentState(
    leaderUserId: leaderUserId,
    approvalPolicy: approvalPolicy,
    compositionPolicy: compositionPolicy ?? this.compositionPolicy,
    members: members ?? this.members,
    applications: applications ?? this.applications,
    isRecruiting: isRecruiting ?? this.isRecruiting,
  );
}

class RecruitmentStateMachine {
  const RecruitmentStateMachine();

  RecruitmentCommandResult apply({
    required RecruitmentState state,
    required RecruitmentApplication application,
  }) {
    if (!state.isRecruiting) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.recruitmentClosed,
      );
    }
    if (application.status != RecruitmentApplicationStatus.pending ||
        application.votes.isNotEmpty) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.invalidApplication,
      );
    }
    if (state.members.any(
      (member) => member.userId == application.applicantUserId,
    )) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.alreadyMember,
      );
    }
    final existingApplication = state.applications[application.applicantUserId];
    if (existingApplication != null &&
        (existingApplication.status == RecruitmentApplicationStatus.pending ||
            existingApplication.status ==
                RecruitmentApplicationStatus.approved)) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.duplicateApplication,
      );
    }

    final composition = _arrangeWithApplicant(state, application);
    if (!composition.canJoin) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.compositionRejected,
        compositionFailure: composition.failure,
      );
    }

    if (state.approvalPolicy.mode == ApprovalMode.directJoin) {
      return _approveApplication(
        state,
        application.copyWith(status: RecruitmentApplicationStatus.approved),
      );
    }

    return RecruitmentCommandResult.success(
      state.copyWith(
        applications: {
          ...state.applications,
          application.applicantUserId: application,
        },
      ),
    );
  }

  RecruitmentCommandResult withdraw({
    required RecruitmentState state,
    required String applicantUserId,
    required String actorUserId,
  }) {
    final application = state.applications[applicantUserId];
    final failure = _applicationFailure(application);
    if (failure != null) {
      return RecruitmentCommandResult.failure(state, failure);
    }
    if (actorUserId != applicantUserId) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.unauthorized,
      );
    }

    return RecruitmentCommandResult.success(
      _replaceApplication(
        state,
        application!.copyWith(status: RecruitmentApplicationStatus.withdrawn),
      ),
    );
  }

  RecruitmentCommandResult changeCharacter({
    required RecruitmentState state,
    required String actorUserId,
    required String characterId,
    required String className,
    PartyRole? role,
    double? itemLevel,
  }) {
    final memberIndex = state.members.indexWhere(
      (member) => member.userId == actorUserId,
    );
    if (memberIndex < 0) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.unauthorized,
      );
    }
    final current = state.members[memberIndex];
    final proposedRole = role ?? current.role;
    if (current.characterId == characterId && current.role == proposedRole) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.invalidApplication,
      );
    }
    final proposedMembers = [
      for (final member in state.members)
        member.userId == actorUserId
            ? member.copyWith(
                characterId: characterId,
                className: className,
                role: proposedRole,
                itemLevel: itemLevel,
              )
            : member,
    ];
    final composition = state.compositionPolicy.arrange(
      proposedMembers
          .map(
            (member) => PartyCompositionMember(
              id: member.userId,
              className: member.className,
              role: member.role,
            ),
          )
          .toList(growable: false),
    );
    if (!composition.canJoin) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.compositionRejected,
        compositionFailure: composition.failure,
      );
    }
    return RecruitmentCommandResult.success(
      state.copyWith(
        members: proposedMembers
            .map(
              (member) => member.copyWith(
                partyIndex: composition.assignments[member.userId],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  RecruitmentCommandResult vote({
    required RecruitmentState state,
    required String applicantUserId,
    required String voterUserId,
    required ApplicationVoteDecision decision,
  }) {
    final application = state.applications[applicantUserId];
    final failure = _applicationFailure(application);
    if (failure != null) {
      return RecruitmentCommandResult.failure(state, failure);
    }
    if (!_canVote(state, voterUserId)) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.unauthorized,
      );
    }
    if (application!.votes.containsKey(voterUserId)) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.duplicateVote,
      );
    }

    final votedApplication = application.copyWith(
      votes: Map.unmodifiable({
        ...application.votes,
        voterUserId: ApplicationVote(
          voterUserId: voterUserId,
          decision: decision,
        ),
      }),
    );
    if (decision == ApplicationVoteDecision.reject) {
      return RecruitmentCommandResult.success(
        _replaceApplication(
          state,
          votedApplication.copyWith(
            status: RecruitmentApplicationStatus.rejected,
          ),
        ),
      );
    }
    if (!_hasRequiredApprovals(state, votedApplication)) {
      return RecruitmentCommandResult.success(
        _replaceApplication(state, votedApplication),
      );
    }

    return _approveApplication(state, votedApplication);
  }

  RecruitmentCommandResult _approveApplication(
    RecruitmentState state,
    RecruitmentApplication application,
  ) {
    final composition = _arrangeWithApplicant(state, application);
    if (!composition.canJoin) {
      return RecruitmentCommandResult.failure(
        state,
        RecruitmentCommandFailure.compositionRejected,
        compositionFailure: composition.failure,
      );
    }

    final members =
        [
              ...state.members,
              RecruitmentPartyMember(
                userId: application.applicantUserId,
                characterId: application.characterId,
                className: application.className,
                role: application.requestedRole,
                itemLevel: application.itemLevel,
                partyIndex:
                    composition.assignments[application.applicantUserId]!,
              ),
            ]
            .map(
              (member) => member.copyWith(
                partyIndex: composition.assignments[member.userId],
              ),
            )
            .toList(growable: false);
    final approvedApplication = application.copyWith(
      status: RecruitmentApplicationStatus.approved,
    );
    final nextState = _replaceApplication(
      state.copyWith(
        members: members,
        isRecruiting:
            members.length < state.compositionPolicy.rules.totalMembers,
      ),
      approvedApplication,
    );
    return RecruitmentCommandResult.success(nextState);
  }

  RecruitmentCommandFailure? _applicationFailure(
    RecruitmentApplication? application,
  ) {
    if (application == null) {
      return RecruitmentCommandFailure.applicationNotFound;
    }
    if (application.status != RecruitmentApplicationStatus.pending) {
      return RecruitmentCommandFailure.applicationNotPending;
    }
    return null;
  }

  bool _canVote(RecruitmentState state, String voterUserId) {
    final isMember = state.members.any(
      (member) => member.userId == voterUserId,
    );
    if (!isMember) return false;
    return switch (state.approvalPolicy.mode) {
      ApprovalMode.leaderOnly => voterUserId == state.leaderUserId,
      ApprovalMode.directJoin => false,
      ApprovalMode.anyMember || ApprovalMode.quorum => true,
    };
  }

  bool _hasRequiredApprovals(
    RecruitmentState state,
    RecruitmentApplication application,
  ) {
    final currentMemberIds = state.members
        .map((member) => member.userId)
        .toSet();
    final currentApprovalCount = application.votes.values
        .where(
          (vote) =>
              currentMemberIds.contains(vote.voterUserId) &&
              vote.decision == ApplicationVoteDecision.approve,
        )
        .length;
    if (currentApprovalCount < state.approvalPolicy.requiredApprovals) {
      return false;
    }
    return !state.approvalPolicy.leaderVoteRequired ||
        application.votes[state.leaderUserId]?.decision ==
            ApplicationVoteDecision.approve;
  }

  PartyCompositionDecision _arrangeWithApplicant(
    RecruitmentState state,
    RecruitmentApplication application,
  ) => state.compositionPolicy.arrange([
    ...state.members.map(
      (member) => PartyCompositionMember(
        id: member.userId,
        className: member.className,
        role: member.role,
      ),
    ),
    PartyCompositionMember(
      id: application.applicantUserId,
      className: application.className,
      role: application.requestedRole,
    ),
  ]);

  RecruitmentState _replaceApplication(
    RecruitmentState state,
    RecruitmentApplication application,
  ) => state.copyWith(
    applications: {
      ...state.applications,
      application.applicantUserId: application,
    },
  );
}
