enum ManualVerificationStatus {
  pendingProof,
  approved,
  cancelled,
  blocked,
  awaitingOwnerResponse,
  defended,
  transferred,
  expired,
}

class ManualVerificationRequest {
  const ManualVerificationRequest({
    required this.id,
    required this.requesterPlayerId,
    required this.targetIdentityKey,
    required this.localAccountLabelSnapshot,
    required this.proofServerName,
    required this.proofCharacterName,
    required this.verificationCode,
    required this.status,
    required this.attemptNumberForTarget,
    required this.totalAttemptNumberForPlayer,
    required this.createdAt,
    required this.expiresAt,
    this.localAccountId,
    this.targetGameAccountId,
    this.proofClassName,
    this.reviewedByOperatorPlayerId,
    this.reviewReason,
    this.serverGameAccountId,
    this.previousOwnerPlayerId,
    this.disputeOpenedAt,
    this.ownerResponseDeadlineAt,
    this.defenseOfRequestId,
  });

  final String id;
  final String requesterPlayerId;
  final String targetIdentityKey;
  final int? localAccountId;
  final String? targetGameAccountId;
  final String localAccountLabelSnapshot;
  final String proofServerName;
  final String proofCharacterName;
  final String? proofClassName;
  final String verificationCode;
  final ManualVerificationStatus status;
  final int attemptNumberForTarget;
  final int totalAttemptNumberForPlayer;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? reviewedByOperatorPlayerId;
  final String? reviewReason;
  final String? serverGameAccountId;
  final String? previousOwnerPlayerId;
  final DateTime? disputeOpenedAt;
  final DateTime? ownerResponseDeadlineAt;
  final String? defenseOfRequestId;

  bool get isPending => status == ManualVerificationStatus.pendingProof;

  bool get isDefenseRequest =>
      defenseOfRequestId != null && defenseOfRequestId!.isNotEmpty;

  bool get isAwaitingOwnerResponse =>
      status == ManualVerificationStatus.awaitingOwnerResponse;

  bool isExpiredAt(DateTime now) =>
      isPending && !now.toUtc().isBefore(expiresAt.toUtc());

  bool isOwnerResponseOverdueAt(DateTime now) {
    final deadline = ownerResponseDeadlineAt;
    if (!isAwaitingOwnerResponse || deadline == null) return false;
    return !now.toUtc().isBefore(deadline.toUtc());
  }
}

class ManualVerificationException implements Exception {
  const ManualVerificationException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

class ManualVerificationReviewContext {
  const ManualVerificationReviewContext({
    required this.hasActiveOwner,
    required this.isBlocked,
    required this.rosterSummaries,
    this.existingOwnerPlayerId,
  });

  final bool hasActiveOwner;
  final bool isBlocked;
  final List<String> rosterSummaries;
  final String? existingOwnerPlayerId;
}
