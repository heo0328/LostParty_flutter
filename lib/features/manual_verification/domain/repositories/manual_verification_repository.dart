import '../../../account/domain/entities/game_account_verification.dart';

import '../entities/manual_verification_request.dart';



abstract interface class ManualVerificationRepository {

  Future<ManualVerificationRequest> createRequest({

    required int localAccountId,

    required String localAccountLabel,

    required String proofServerName,

    required String proofCharacterName,

    String? proofClassName,

    String? targetGameAccountId,

    Iterable<String> rosterIdentityKeys = const [],

    String? defenseOfRequestId,

  });



  Future<ManualVerificationRequest> reissueRequest(String requestId);



  Future<void> cancelRequest(String requestId);



  Stream<List<ManualVerificationRequest>> watchMyRequests();



  Stream<List<ManualVerificationRequest>> watchIncomingDisputes();



  Future<GameAccountVerificationResult> loadApprovedResult(String requestId);



  Future<ManualVerificationReviewContext> loadReviewContext(

    ManualVerificationRequest request,

  );



  Future<List<ManualVerificationRequest>> loadPendingQueue();



  Future<void> reviewCancel({

    required String requestId,

    required String reason,

  });



  Future<void> reviewBlock({

    required String requestId,

    required String reason,

  });



  /// Approves a claim request. Opens a dispute when an active owner exists,

  /// otherwise claims ownership immediately.

  Future<GameAccountVerificationResult> reviewApprove(String requestId);



  /// Approves an existing owner's defense request linked to an open dispute.

  Future<void> reviewApproveDefense(String defenseRequestId);

  /// Rejects an owner's defense and immediately transfers ownership to the
  /// requester of the linked dispute without blocking the former owner.
  Future<GameAccountVerificationResult> reviewRejectDefense(
    String defenseRequestId,
  );

  /// Immediately transfers ownership to the requester, skipping the 24-hour
  /// defense window when another player owns the game account.
  Future<GameAccountVerificationResult> reviewForceApprove(String requestId);

  /// Finalizes disputes whose owner-response deadline has passed.

  Future<void> syncExpiredDisputes();



  @Deprecated('Use reviewApprove')

  Future<GameAccountVerificationResult> reviewApproveUnowned(String requestId) =>

      reviewApprove(requestId);

}

