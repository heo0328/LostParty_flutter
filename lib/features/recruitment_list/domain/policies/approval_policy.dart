enum ApprovalMode { leaderOnly, anyMember, quorum }

enum ApprovalRejectionMode { anyAuthorizedMember }

class ApprovalPolicy {
  const ApprovalPolicy._({
    required this.mode,
    required this.requiredApprovals,
    required this.leaderVoteRequired,
    required this.rejectionMode,
  });

  const ApprovalPolicy.leaderOnly()
    : this._(
        mode: ApprovalMode.leaderOnly,
        requiredApprovals: 1,
        leaderVoteRequired: true,
        rejectionMode: ApprovalRejectionMode.anyAuthorizedMember,
      );

  const ApprovalPolicy.anyMember()
    : this._(
        mode: ApprovalMode.anyMember,
        requiredApprovals: 1,
        leaderVoteRequired: false,
        rejectionMode: ApprovalRejectionMode.anyAuthorizedMember,
      );

  factory ApprovalPolicy.quorum({
    required int requiredApprovals,
    bool leaderVoteRequired = false,
  }) {
    if (requiredApprovals < 2) {
      throw ArgumentError.value(
        requiredApprovals,
        'requiredApprovals',
        '정족수 승인은 2명 이상의 동의가 필요합니다.',
      );
    }
    return ApprovalPolicy._(
      mode: ApprovalMode.quorum,
      requiredApprovals: requiredApprovals,
      leaderVoteRequired: leaderVoteRequired,
      rejectionMode: ApprovalRejectionMode.anyAuthorizedMember,
    );
  }

  final ApprovalMode mode;
  final int requiredApprovals;
  final bool leaderVoteRequired;
  final ApprovalRejectionMode rejectionMode;
}
