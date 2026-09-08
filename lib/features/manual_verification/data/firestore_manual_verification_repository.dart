import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../../account/data/dtos/sibling_character_dto.dart';
import '../../account/domain/character_identity_key.dart';
import '../../account/domain/entities/game_account_verification.dart';
import '../domain/entities/manual_verification_request.dart';
import '../domain/manual_verification_account_scope.dart';
import '../domain/manual_verification_code.dart';
import '../domain/repositories/manual_verification_repository.dart';

class FirestoreManualVerificationRepository
    implements ManualVerificationRepository {
  FirestoreManualVerificationRepository({
    required LostArkCharacterRemoteDataSource remoteDataSource,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    DateTime Function()? clock,
    String Function()? codeGenerator,
  }) : _remoteDataSource = remoteDataSource,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _clock = clock ?? DateTime.now,
       _codeGenerator = codeGenerator ?? ManualVerificationCode.generate;

  static const _requestTtl = Duration(hours: 24);
  static const _ownerResponseTtl = Duration(hours: 24);

  final LostArkCharacterRemoteDataSource _remoteDataSource;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final DateTime Function() _clock;
  final String Function() _codeGenerator;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('manualVerificationRequests');

  CollectionReference<Map<String, dynamic>> get _blocks =>
      _firestore.collection('manualVerificationBlocks');

  @override
  Future<ManualVerificationRequest> createRequest({
    required int localAccountId,
    required String localAccountLabel,
    required String proofServerName,
    required String proofCharacterName,
    String? proofClassName,
    String? targetGameAccountId,
    Iterable<String> rosterIdentityKeys = const [],
    String? defenseOfRequestId,
  }) async {
    if (localAccountId <= 0) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    final playerId = await _requirePlayerId();
    final identityKey = characterIdentityKey(
      proofServerName,
      proofCharacterName,
    );
    final rosterKeys = rosterIdentityKeys.toSet();
    if (rosterKeys.isEmpty) {
      rosterKeys.add(identityKey);
    }
    try {
      final linkedDispute = defenseOfRequestId == null
          ? null
          : await _requireDefenseDispute(
              defenseOfRequestId: defenseOfRequestId,
              defenderPlayerId: playerId,
              targetGameAccountId: targetGameAccountId,
            );
      await _assertNotBlocked(playerId, identityKey, targetGameAccountId);
      if (defenseOfRequestId == null) {
        await _assertNotAlreadyOwner(
          playerId: playerId,
          identityKey: identityKey,
          targetGameAccountId: linkedDispute?.targetGameAccountId ??
              targetGameAccountId,
        );
      }
      final existing = await _activePendingForAccount(
        playerId: playerId,
        localAccountId: localAccountId,
        serverGameAccountId: targetGameAccountId,
        rosterIdentityKeys: rosterKeys,
      );
      if (existing != null) {
        throw const ManualVerificationException(
          'alreadyActive',
          '이 계정은 이미 인증이 진행 중입니다. 다른 캐릭터로 중복 요청할 수 없습니다.',
        );
      }
      final resolvedGameAccountId =
          linkedDispute?.targetGameAccountId ?? targetGameAccountId;
      final attempts = await _attemptCounts(
        playerId: playerId,
        localAccountId: localAccountId,
        serverGameAccountId: resolvedGameAccountId,
        rosterIdentityKeys: rosterKeys,
      );
      final now = _clock().toUtc();
      final reference = _requests.doc();
      final payload = _createPayload(
        playerId: playerId,
        identityKey: identityKey,
        localAccountId: localAccountId,
        localAccountLabel: localAccountLabel,
        proofServerName: proofServerName,
        proofCharacterName: proofCharacterName,
        proofClassName: proofClassName,
        targetGameAccountId: resolvedGameAccountId,
        defenseOfRequestId: defenseOfRequestId,
        attemptNumberForTarget: attempts.target + 1,
        totalAttemptNumberForPlayer: attempts.player + 1,
        now: now,
      );
      await reference.set(payload);
      return _mapRequest(reference.id, {
        ...payload,
        'createdAt': now,
        'expiresAt': now.add(_requestTtl),
        'updatedAt': now,
      }, now);
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<ManualVerificationRequest> reissueRequest(String requestId) async {
    final playerId = await _requirePlayerId();
    final snapshot = await _requests.doc(requestId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    if (data['requesterPlayerId'] != playerId) {
      throw const ManualVerificationException('forbidden', '요청 권한이 없습니다.');
    }
    if (data['status'] != 'pendingProof') {
      throw const ManualVerificationException(
        'notPending',
        '진행 중인 요청만 재발급할 수 있습니다.',
      );
    }
    final now = _clock().toUtc();
    final update = {
      'verificationCode': _codeGenerator(),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_requestTtl)),
      'updatedAt': FieldValue.serverTimestamp(),
      'attemptNumberForTarget': (data['attemptNumberForTarget'] as num? ?? 1) + 1,
      'totalAttemptNumberForPlayer':
          (data['totalAttemptNumberForPlayer'] as num? ?? 1) + 1,
    };
    await snapshot.reference.update(update);
    return _mapRequest(requestId, {
      ...data,
      ...update,
      'createdAt': now,
      'expiresAt': now.add(_requestTtl),
      'updatedAt': now,
    }, now);
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    final playerId = await _requirePlayerId();
    final snapshot = await _requests.doc(requestId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    if (data['requesterPlayerId'] != playerId) {
      throw const ManualVerificationException('forbidden', '요청 권한이 없습니다.');
    }
    if (data['status'] != 'pendingProof') {
      throw const ManualVerificationException(
        'notPending',
        '진행 중인 요청만 취소할 수 있습니다.',
      );
    }
    await snapshot.reference.update({
      'status': 'cancelled',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<ManualVerificationRequest>> watchMyRequests() async* {
    final playerId = await _requirePlayerId();
    yield* _requests
        .where('requesterPlayerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => _mapRequest(doc.id, doc.data(), _clock()))
              .toList();
          requests.sort((left, right) => right.createdAt.compareTo(left.createdAt));
          return requests;
        });
  }

  @override
  Stream<List<ManualVerificationRequest>> watchIncomingDisputes() async* {
    final playerId = await _requirePlayerId();
    yield* _requests
        .where('previousOwnerPlayerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) {
          final now = _clock();
          final requests = snapshot.docs
              .map((doc) => _mapRequest(doc.id, doc.data(), now))
              .where((request) => request.isAwaitingOwnerResponse)
              .toList();
          requests.sort(
            (left, right) =>
                (left.ownerResponseDeadlineAt ?? left.createdAt).compareTo(
                  right.ownerResponseDeadlineAt ?? right.createdAt,
                ),
          );
          return requests;
        });
  }

  @override
  Future<GameAccountVerificationResult> loadApprovedResult(
    String requestId,
  ) async {
    final playerId = await _requirePlayerId();
    final snapshot = await _requests.doc(requestId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    if (data['requesterPlayerId'] != playerId) {
      throw const ManualVerificationException('forbidden', '요청 권한이 없습니다.');
    }
    if (data['status'] != 'approved' && data['status'] != 'transferred') {
      throw const ManualVerificationException(
        'notApproved',
        '승인된 요청만 연결할 수 있습니다.',
      );
    }
    final accountId = data['targetGameAccountId'];
    if (accountId is! String || accountId.isEmpty) {
      throw const ManualVerificationException(
        'missingAccount',
        '서버 게임 계정 정보가 없습니다.',
      );
    }
    final characters = await _firestore
        .collection('characters')
        .where('gameAccountId', isEqualTo: accountId)
        .get();
    return GameAccountVerificationResult(
      status: 'verified',
      serverGameAccountId: accountId,
      serverCharacters: characters.docs
          .map(
            (doc) => VerifiedServerCharacter(
              serverName: doc.data()['serverName'] as String? ?? '',
              characterName: doc.data()['characterName'] as String? ?? '',
              serverCharacterId: doc.id,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<ManualVerificationReviewContext> loadReviewContext(
    ManualVerificationRequest request,
  ) async {
    await _requireOperator();
    final block = await _blocks
        .doc('${request.requesterPlayerId}_${request.targetIdentityKey}')
        .get();
    var hasActiveOwner = false;
    String? existingOwnerPlayerId;
    if (request.isAwaitingOwnerResponse) {
      final previousOwner = request.previousOwnerPlayerId;
      final gameAccountId = request.targetGameAccountId;
      if (previousOwner != null &&
          previousOwner.isNotEmpty &&
          gameAccountId != null &&
          gameAccountId.isNotEmpty) {
        hasActiveOwner = true;
        existingOwnerPlayerId = previousOwner;
      }
    } else {
      final owner = await _resolveActiveOwner(
        request.targetIdentityKey,
        targetGameAccountId: request.targetGameAccountId,
      );
      if (owner != null) {
        hasActiveOwner = true;
        existingOwnerPlayerId = owner.playerId;
      }
    }
    List<String> rosterSummaries = const [];
    try {
      final siblings = await _remoteDataSource.fetchSiblings(
        request.proofCharacterName,
      );
      rosterSummaries = siblings
          .map(
            (item) =>
                '${item.serverName} ${item.characterName} · ${item.characterClassName}',
          )
          .toList(growable: false);
    } catch (_) {
      rosterSummaries = const ['최신 원정대를 불러오지 못했습니다.'];
    }
    return ManualVerificationReviewContext(
      hasActiveOwner: hasActiveOwner,
      isBlocked: block.data()?['status'] == 'active',
      rosterSummaries: rosterSummaries,
      existingOwnerPlayerId: existingOwnerPlayerId,
    );
  }

  @override
  Future<List<ManualVerificationRequest>> loadPendingQueue() async {
    await _requireOperator();
    unawaited(syncExpiredDisputes());
    try {
      final snapshot = await _requests
          .where('status', isEqualTo: 'pendingProof')
          .get();
      final now = _clock();
      final requests = snapshot.docs
          .map((doc) => _mapRequest(doc.id, doc.data(), now))
          .where((request) => !request.isExpiredAt(now))
          .toList();
      requests.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return requests;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<void> reviewCancel({
    required String requestId,
    required String reason,
  }) async {
    try {
      final operatorPlayerId = await _requireOperator();
      await _reviewStatus(
        requestId: requestId,
        status: 'cancelled',
        operatorPlayerId: operatorPlayerId,
        reason: reason,
      );
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<void> reviewBlock({
    required String requestId,
    required String reason,
  }) async {
    try {
      final operatorPlayerId = await _requireOperator();
      final snapshot = await _requests.doc(requestId).get();
      final data = snapshot.data();
      _requirePending(data);
      final playerId = data!['requesterPlayerId'] as String;
      final identityKey = data['targetIdentityKey'] as String;
      final targetGameAccountId = data['targetGameAccountId'] as String?;
      final blockId = '${playerId}_$identityKey';
      await _firestore.runTransaction((transaction) async {
        final request = await transaction.get(snapshot.reference);
        _requirePending(request.data());
        transaction.update(snapshot.reference, {
          'status': 'blocked',
          'reviewedByOperatorPlayerId': operatorPlayerId,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewReason': reason.trim(),
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_blocks.doc(blockId), {
          'schemaVersion': 1,
          'playerId': playerId,
          'targetIdentityKey': identityKey,
          if (targetGameAccountId != null && targetGameAccountId.isNotEmpty)
            'targetGameAccountId': targetGameAccountId,
          'status': 'active',
          'reason': reason.trim(),
          'blockedByOperatorPlayerId': operatorPlayerId,
          'blockedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<GameAccountVerificationResult> reviewApprove(String requestId) async {
    try {
      final operatorPlayerId = await _requireOperator();
      final snapshot = await _requests.doc(requestId).get();
      final data = snapshot.data();
      _requirePending(data);
      final now = _clock().toUtc();
      final request = _mapRequest(requestId, data!, now);
      if (request.isExpiredAt(now)) {
        throw const ManualVerificationException('expired', '만료된 요청입니다.');
      }
      if (request.isDefenseRequest) {
        throw const ManualVerificationException(
          'invalidRequest',
          '방어 요청은 방어 승인으로 처리해 주세요.',
        );
      }
      await _assertNotBlocked(
        request.requesterPlayerId,
        request.targetIdentityKey,
        request.targetGameAccountId,
      );
      final siblings = await _remoteDataSource.fetchSiblings(
        request.proofCharacterName,
      );
      if (!siblings.any(
        (item) =>
            item.characterName == request.proofCharacterName &&
            item.serverName == request.proofServerName,
      )) {
        throw const ManualVerificationException(
          'rosterMismatch',
          '최신 원정대에 인증 캐릭터가 없습니다.',
        );
      }
      final owner = await _resolveActiveOwner(
        request.targetIdentityKey,
        targetGameAccountId: request.targetGameAccountId,
      );
      if (owner == null) {
        return _firestore.runTransaction((transaction) async {
          final live = await transaction.get(snapshot.reference);
          _requirePending(live.data());
          return _claimForRequester(
            transaction: transaction,
            requestRef: snapshot.reference,
            requesterPlayerId: request.requesterPlayerId,
            operatorPlayerId: operatorPlayerId,
            siblings: siblings,
          );
        });
      }
      if (owner.playerId == request.requesterPlayerId) {
        throw const ManualVerificationException(
          'alreadyOwner',
          '요청자가 이미 이 게임 계정의 소유자입니다. 분쟁을 열 수 없습니다.',
        );
      }
      await _openDispute(
        requestRef: snapshot.reference,
        requesterPlayerId: request.requesterPlayerId,
        operatorPlayerId: operatorPlayerId,
        previousOwnerPlayerId: owner.playerId,
        targetGameAccountId: owner.gameAccountId,
        proofCharacterName: request.proofCharacterName,
      );
      return GameAccountVerificationResult(
        status: 'awaitingOwnerResponse',
        serverGameAccountId: owner.gameAccountId,
        serverCharacters: const [],
      );
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<GameAccountVerificationResult> reviewForceApprove(String requestId) async {
    final operatorPlayerId = await _requireOperator();
    try {
      final snapshot = await _requests.doc(requestId).get();
      final data = snapshot.data();
      _requireForceEligible(data);
      final now = _clock().toUtc();
      final request = _mapRequest(requestId, data!, now);
      if (request.isDefenseRequest) {
        throw const ManualVerificationException(
          'invalidRequest',
          '방어 요청에는 강제 인증을 사용할 수 없습니다.',
        );
      }
      if (request.isPending && request.isExpiredAt(now)) {
        throw const ManualVerificationException('expired', '만료된 요청입니다.');
      }
      await _assertNotBlocked(
        request.requesterPlayerId,
        request.targetIdentityKey,
        request.targetGameAccountId,
      );
      final siblings = await _remoteDataSource.fetchSiblings(
        request.proofCharacterName,
      );
      if (!siblings.any(
        (item) =>
            item.characterName == request.proofCharacterName &&
            item.serverName == request.proofServerName,
      )) {
        throw const ManualVerificationException(
          'rosterMismatch',
          '최신 원정대에 인증 캐릭터가 없습니다.',
        );
      }
      final owner = await _resolveForceTransferOwner(request);
      if (owner.playerId == request.requesterPlayerId) {
        throw const ManualVerificationException(
          'alreadyOwner',
          '요청자가 이미 이 게임 계정의 소유자입니다.',
        );
      }
      return _firestore.runTransaction((transaction) async {
        final live = await transaction.get(snapshot.reference);
        _requireForceEligible(live.data());
        return _claimForRequester(
          transaction: transaction,
          requestRef: snapshot.reference,
          requesterPlayerId: request.requesterPlayerId,
          operatorPlayerId: operatorPlayerId,
          siblings: siblings,
          resolvedGameAccountId: owner.gameAccountId,
          previousOwnerPlayerId: owner.playerId,
          finalStatus: 'transferred',
          transferReviewReason: 'operatorForced',
        );
      });
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<void> reviewApproveDefense(String defenseRequestId) async {
    final operatorPlayerId = await _requireOperator();
    final defenseSnapshot = await _requests.doc(defenseRequestId).get();
    final defenseData = defenseSnapshot.data();
    _requirePending(defenseData);
    final now = _clock().toUtc();
    final defense = _mapRequest(defenseRequestId, defenseData!, now);
    final disputeId = defense.defenseOfRequestId;
    if (disputeId == null || disputeId.isEmpty) {
      throw const ManualVerificationException(
        'invalidRequest',
        '방어 요청이 아닙니다.',
      );
    }
    if (defense.isExpiredAt(now)) {
      throw const ManualVerificationException('expired', '만료된 요청입니다.');
    }
    final disputeSnapshot = await _requests.doc(disputeId).get();
    final disputeData = disputeSnapshot.data();
    if (!disputeSnapshot.exists || disputeData == null) {
      throw const ManualVerificationException('notFound', '분쟁 요청을 찾을 수 없습니다.');
    }
    final dispute = _mapRequest(disputeId, disputeData, now);
    if (!dispute.isAwaitingOwnerResponse) {
      throw const ManualVerificationException(
        'notPending',
        '이미 처리된 분쟁입니다.',
      );
    }
    if (dispute.isOwnerResponseOverdueAt(now)) {
      throw const ManualVerificationException(
        'deadlinePassed',
        '방어 기한이 지났습니다.',
      );
    }
    final previousOwner = dispute.previousOwnerPlayerId;
    if (previousOwner == null ||
        previousOwner.isEmpty ||
        previousOwner != defense.requesterPlayerId) {
      throw const ManualVerificationException(
        'forbidden',
        '기존 소유자만 방어할 수 있습니다.',
      );
    }
    final siblings = await _remoteDataSource.fetchSiblings(
      defense.proofCharacterName,
    );
    if (!siblings.any(
      (item) =>
          item.characterName == defense.proofCharacterName &&
          item.serverName == defense.proofServerName,
    )) {
      throw const ManualVerificationException(
        'rosterMismatch',
        '최신 원정대에 인증 캐릭터가 없습니다.',
      );
    }
    final gameAccountId = dispute.targetGameAccountId;
    if (gameAccountId == null || gameAccountId.isEmpty) {
      throw const ManualVerificationException(
        'missingAccount',
        '대상 게임 계정 정보가 없습니다.',
      );
    }
    final blockId =
        '${dispute.requesterPlayerId}_$gameAccountId';
    await _firestore.runTransaction((transaction) async {
      final liveDefense = await transaction.get(defenseSnapshot.reference);
      _requirePending(liveDefense.data());
      final liveDispute = await transaction.get(disputeSnapshot.reference);
      final liveDisputeData = liveDispute.data();
      if (liveDisputeData == null ||
          liveDisputeData['status'] != 'awaitingOwnerResponse') {
        throw const ManualVerificationException(
          'notPending',
          '이미 처리된 분쟁입니다.',
        );
      }
      final deadline = liveDisputeData['ownerResponseDeadlineAt'];
      if (deadline is Timestamp && now.isBefore(deadline.toDate().toUtc())) {
        // still within deadline
      } else {
        throw const ManualVerificationException(
          'deadlinePassed',
          '방어 기한이 지났습니다.',
        );
      }
      final nowField = FieldValue.serverTimestamp();
      transaction.update(defenseSnapshot.reference, {
        'status': 'approved',
        'targetGameAccountId': gameAccountId,
        'reviewedByOperatorPlayerId': operatorPlayerId,
        'reviewedAt': nowField,
        'resolvedAt': nowField,
        'updatedAt': nowField,
      });
      transaction.update(disputeSnapshot.reference, {
        'status': 'defended',
        'reviewedByOperatorPlayerId': operatorPlayerId,
        'reviewedAt': nowField,
        'reviewReason': 'ownerDefended',
        'resolvedAt': nowField,
        'updatedAt': nowField,
      });
      transaction.set(_blocks.doc(blockId), {
        'schemaVersion': 1,
        'playerId': dispute.requesterPlayerId,
        'targetGameAccountId': gameAccountId,
        'targetIdentityKey': dispute.targetIdentityKey,
        'status': 'active',
        'reason': '기존 소유자가 방어했습니다.',
        'blockedByOperatorPlayerId': operatorPlayerId,
        'blockedAt': nowField,
      });
    });
  }

  @override
  Future<GameAccountVerificationResult> reviewRejectDefense(
    String defenseRequestId,
  ) async {
    final operatorPlayerId = await _requireOperator();
    try {
      final defenseSnapshot = await _requests.doc(defenseRequestId).get();
      final defenseData = defenseSnapshot.data();
      _requirePending(defenseData);
      final now = _clock().toUtc();
      final defense = _mapRequest(defenseRequestId, defenseData!, now);
      final disputeId = defense.defenseOfRequestId;
      if (disputeId == null || disputeId.isEmpty) {
        throw const ManualVerificationException('invalidRequest', '방어 요청이 아닙니다.');
      }
      final disputeSnapshot = await _requests.doc(disputeId).get();
      final disputeData = disputeSnapshot.data();
      if (!disputeSnapshot.exists || disputeData == null) {
        throw const ManualVerificationException('notFound', '분쟁 요청을 찾을 수 없습니다.');
      }
      final dispute = _mapRequest(disputeId, disputeData, now);
      if (!dispute.isAwaitingOwnerResponse) {
        throw const ManualVerificationException('notPending', '이미 처리된 분쟁입니다.');
      }
      if (dispute.previousOwnerPlayerId != defense.requesterPlayerId) {
        throw const ManualVerificationException('forbidden', '기존 소유자의 방어 요청이 아닙니다.');
      }
      final gameAccountId = dispute.targetGameAccountId;
      final previousOwner = dispute.previousOwnerPlayerId;
      if (gameAccountId == null || previousOwner == null) {
        throw const ManualVerificationException('missingAccount', '분쟁 계정 정보가 없습니다.');
      }
      final siblings = await _remoteDataSource.fetchSiblings(
        dispute.proofCharacterName,
      );
      return _firestore.runTransaction((transaction) async {
        final liveDefense = await transaction.get(defenseSnapshot.reference);
        _requirePending(liveDefense.data());
        final liveDispute = await transaction.get(disputeSnapshot.reference);
        if (liveDispute.data()?['status'] != 'awaitingOwnerResponse') {
          throw const ManualVerificationException('notPending', '이미 처리된 분쟁입니다.');
        }
        final result = await _claimForRequester(
          transaction: transaction,
          requestRef: disputeSnapshot.reference,
          requesterPlayerId: dispute.requesterPlayerId,
          operatorPlayerId: operatorPlayerId,
          siblings: siblings,
          resolvedGameAccountId: gameAccountId,
          previousOwnerPlayerId: previousOwner,
          finalStatus: 'transferred',
          transferReviewReason: 'ownerDefenseFailed',
        );
        final nowField = FieldValue.serverTimestamp();
        transaction.update(defenseSnapshot.reference, {
          'status': 'cancelled',
          'reviewedByOperatorPlayerId': operatorPlayerId,
          'reviewedAt': nowField,
          'reviewReason': 'ownerDefenseFailed',
          'resolvedAt': nowField,
          'updatedAt': nowField,
        });
        return result;
      });
    } on ManualVerificationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<void> syncExpiredDisputes() async {
    try {
      final snapshot = await _requests
          .where('status', isEqualTo: 'awaitingOwnerResponse')
          .get();
      final now = _clock().toUtc();
      for (final doc in snapshot.docs) {
        final request = _mapRequest(doc.id, doc.data(), now);
        if (!request.isOwnerResponseOverdueAt(now)) continue;
        try {
          await _finalizeExpiredDispute(doc.reference, request);
        } on ManualVerificationException catch (error) {
          if (error.code != 'notPending' && error.code != 'deadlinePending') {
            rethrow;
          }
        }
      }
    } on FirebaseException catch (error) {
      throw _mapFirebase(error);
    }
  }

  @override
  Future<GameAccountVerificationResult> reviewApproveUnowned(
    String requestId,
  ) =>
      reviewApprove(requestId);

  Future<GameAccountVerificationResult> _claimForRequester({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> requestRef,
    required String requesterPlayerId,
    required String operatorPlayerId,
    required List<SiblingCharacterDto> siblings,
    String? resolvedGameAccountId,
    String? previousOwnerPlayerId,
    String finalStatus = 'approved',
    String? transferReviewReason,
  }) async {
    final claimRefs = siblings
        .map(
          (item) => _firestore
              .collection('characterIdentityClaims')
              .doc(
                characterIdentityKey(item.serverName, item.characterName),
              ),
        )
        .toList(growable: false);
    final claims = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final ref in claimRefs) {
      claims.add(await transaction.get(ref));
    }
    final accountIds = claims
        .where((snapshot) => snapshot.exists)
        .map((snapshot) => snapshot.data()?['gameAccountId'])
        .whereType<String>()
        .toSet();
    if (accountIds.length > 1) {
      throw const ManualVerificationException(
        'conflict',
        '게임 계정 식별자가 충돌합니다.',
      );
    }
    if (resolvedGameAccountId != null &&
        resolvedGameAccountId.isNotEmpty &&
        accountIds.isNotEmpty &&
        !accountIds.contains(resolvedGameAccountId)) {
      throw const ManualVerificationException(
        'conflict',
        '분쟁 대상 게임 계정과 원정대 식별자가 일치하지 않습니다.',
      );
    }
    final accountRef = resolvedGameAccountId != null &&
            resolvedGameAccountId.isNotEmpty
        ? _firestore.collection('gameAccounts').doc(resolvedGameAccountId)
        : accountIds.isEmpty
        ? _firestore.collection('gameAccounts').doc()
        : _firestore.collection('gameAccounts').doc(accountIds.single);
    final account = await transaction.get(accountRef);
    if ((resolvedGameAccountId != null && resolvedGameAccountId.isNotEmpty) ||
        accountIds.isNotEmpty) {
      if (!account.exists) {
        throw const ManualVerificationException(
          'conflict',
          '게임 계정 문서가 없습니다.',
        );
      }
    }
    String? previousOwner;
    if (account.exists) {
      previousOwner = account.data()?['ownerPlayerId'] as String?;
    }
    if (previousOwner is String && previousOwner.isNotEmpty) {
      if (previousOwnerPlayerId == null || previousOwner != previousOwnerPlayerId) {
        throw const ManualVerificationException(
          'existingOwner',
          '기존 소유자가 있어 이번 단계에서 승인할 수 없습니다.',
        );
      }
    } else if (previousOwnerPlayerId != null && previousOwnerPlayerId.isNotEmpty) {
      throw const ManualVerificationException(
        'ownerChanged',
        '소유 상태가 변경되어 이전을 확정할 수 없습니다.',
      );
    }
    final storedCharacterIds = account.exists
        ? (account.data()?['characterIds'] as List?)
                ?.whereType<String>()
                .toList() ??
            const <String>[]
        : const <String>[];
    final characterRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (var index = 0; index < claims.length; index++) {
      final characterId = claims[index].data()?['characterId'];
      characterRefs.add(
        characterId is String && characterId.isNotEmpty
            ? _firestore.collection('characters').doc(characterId)
            : _firestore.collection('characters').doc(),
      );
    }
    final allCharacterIds = {
      ...storedCharacterIds,
      ...characterRefs.map((ref) => ref.id),
    };
    final storedCharacters = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in allCharacterIds) {
      storedCharacters.add(
        await transaction.get(_firestore.collection('characters').doc(id)),
      );
    }
    final now = FieldValue.serverTimestamp();
    for (final snapshot in storedCharacters) {
      if (snapshot.exists &&
          !characterRefs.any((ref) => ref.id == snapshot.id)) {
        transaction.update(snapshot.reference, {
          'ownerPlayerId': requesterPlayerId,
          'rosterStatus': 'missingFromLatestRoster',
          'updatedAt': now,
        });
      }
    }
    transaction.set(accountRef, {
      'schemaVersion': 1,
      'ownerPlayerId': requesterPlayerId,
      'status': 'active',
      'lookupCharacterName': siblings.first.characterName,
      'characterIds': allCharacterIds.toList(growable: false),
      'createdAt': account.exists
          ? (account.data()?['createdAt'] ?? now)
          : now,
      'updatedAt': now,
    });
    final serverCharacters = <VerifiedServerCharacter>[];
    for (var index = 0; index < siblings.length; index++) {
      final sibling = siblings[index];
      final characterRef = characterRefs[index];
      final storedCharacter = storedCharacters
          .where((item) => item.id == characterRef.id)
          .firstOrNull;
      transaction.set(characterRef, {
        'schemaVersion': 1,
        'ownerPlayerId': requesterPlayerId,
        'gameAccountId': accountRef.id,
        'status': 'active',
        'rosterStatus': 'confirmed',
        'serverName': sibling.serverName,
        'characterName': sibling.characterName,
        'characterClassName': sibling.characterClassName,
        'characterLevel': sibling.characterLevel,
        'itemAvgLevel': sibling.itemAvgLevel,
        'createdAt': storedCharacter?.data()?['createdAt'] ?? now,
        'updatedAt': now,
      });
      transaction.set(claimRefs[index], {
        'schemaVersion': 1,
        'gameAccountId': accountRef.id,
        'characterId': characterRef.id,
        'serverName': sibling.serverName,
        'characterName': sibling.characterName,
        'updatedAt': now,
      });
      serverCharacters.add(
        VerifiedServerCharacter(
          serverName: sibling.serverName,
          characterName: sibling.characterName,
          serverCharacterId: characterRef.id,
        ),
      );
    }
    transaction.set(_firestore
        .collection('playerGameAccounts')
        .doc('${requesterPlayerId}_${accountRef.id}'), {
      'schemaVersion': 1,
      'playerId': requesterPlayerId,
      'gameAccountId': accountRef.id,
      'status': 'active',
      'updatedAt': now,
    }, SetOptions(merge: true));
    if (previousOwner is String &&
        previousOwner.isNotEmpty &&
        previousOwner != requesterPlayerId) {
      transaction.set(
        _firestore
            .collection('playerGameAccounts')
            .doc('${previousOwner}_${accountRef.id}'),
        {
          'schemaVersion': 1,
          'playerId': previousOwner,
          'gameAccountId': accountRef.id,
          'status': 'ownershipLost',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }
    final requestUpdate = <String, Object?>{
      'status': finalStatus,
      'targetGameAccountId': accountRef.id,
      'updatedAt': now,
    };
    if (finalStatus == 'approved') {
      requestUpdate.addAll({
        'reviewedByOperatorPlayerId': operatorPlayerId,
        'reviewedAt': now,
        'resolvedAt': now,
      });
    } else if (finalStatus == 'transferred') {
      final reason = transferReviewReason ?? 'ownerResponseExpired';
      requestUpdate.addAll({
        'reviewReason': reason,
        'resolvedAt': now,
      });
      if ((reason == 'operatorForced' || reason == 'ownerDefenseFailed') &&
          operatorPlayerId.isNotEmpty) {
        requestUpdate.addAll({
          'reviewedByOperatorPlayerId': operatorPlayerId,
          'reviewedAt': now,
        });
      }
    }
    transaction.update(requestRef, requestUpdate);
    return GameAccountVerificationResult(
      status: 'verified',
      serverGameAccountId: accountRef.id,
      serverCharacters: serverCharacters,
    );
  }

  Future<void> _openDispute({
    required DocumentReference<Map<String, dynamic>> requestRef,
    required String requesterPlayerId,
    required String operatorPlayerId,
    required String previousOwnerPlayerId,
    required String targetGameAccountId,
    required String proofCharacterName,
  }) async {
    final deadline = Timestamp.fromDate(
      _clock().toUtc().add(_ownerResponseTtl),
    );
    final nowField = FieldValue.serverTimestamp();
    await requestRef.update({
      'status': 'awaitingOwnerResponse',
      'targetGameAccountId': targetGameAccountId,
      'previousOwnerPlayerId': previousOwnerPlayerId,
      'disputeOpenedAt': nowField,
      'ownerResponseDeadlineAt': deadline,
      'reviewedByOperatorPlayerId': operatorPlayerId,
      'reviewedAt': nowField,
      'updatedAt': nowField,
    });
    try {
      await _writeDisputeOpenedEvent(
        requestId: requestRef.id,
        recipientPlayerId: previousOwnerPlayerId,
        requesterPlayerId: requesterPlayerId,
        targetGameAccountId: targetGameAccountId,
        ownerResponseDeadlineAt: deadline,
        proofCharacterName: proofCharacterName,
      );
    } on FirebaseException {
      // 분쟁 상태 전이는 성공했으므로 알림 이벤트 실패만 무시한다.
    }
  }

  Future<void> _finalizeExpiredDispute(
    DocumentReference<Map<String, dynamic>> requestRef,
    ManualVerificationRequest request,
  ) async {
    if (!request.isOwnerResponseOverdueAt(_clock().toUtc())) {
      throw const ManualVerificationException(
        'deadlinePending',
        '방어 기한이 아직 지나지 않았습니다.',
      );
    }
    final siblings = await _remoteDataSource.fetchSiblings(
      request.proofCharacterName,
    );
    await _firestore.runTransaction((transaction) async {
      final live = await transaction.get(requestRef);
      final data = live.data();
      if (data == null || data['status'] != 'awaitingOwnerResponse') {
        throw const ManualVerificationException('notPending', '이미 처리된 분쟁입니다.');
      }
      final deadline = data['ownerResponseDeadlineAt'];
      if (deadline is! Timestamp ||
          _clock().toUtc().isBefore(deadline.toDate().toUtc())) {
        throw const ManualVerificationException(
          'deadlinePending',
          '방어 기한이 아직 지나지 않았습니다.',
        );
      }
      final previousOwner = data['previousOwnerPlayerId'];
      if (previousOwner is! String || previousOwner.isEmpty) {
        throw const ManualVerificationException(
          'invalidRequest',
          '분쟁 소유자 정보가 없습니다.',
        );
      }
      await _claimForRequester(
        transaction: transaction,
        requestRef: requestRef,
        requesterPlayerId: request.requesterPlayerId,
        operatorPlayerId: request.reviewedByOperatorPlayerId ?? '',
        siblings: siblings,
        resolvedGameAccountId: request.targetGameAccountId,
        previousOwnerPlayerId: previousOwner,
        finalStatus: 'transferred',
      );
    });
  }

  Future<void> _writeDisputeOpenedEvent({
    required String requestId,
    required String recipientPlayerId,
    required String requesterPlayerId,
    required String targetGameAccountId,
    required Timestamp ownerResponseDeadlineAt,
    required String proofCharacterName,
  }) async {
    final eventId = 'mvd_$requestId';
    final expiresAt = Timestamp.fromDate(
      _clock().toUtc().add(const Duration(days: 28)),
    );
    await _firestore
        .collection('players')
        .doc(recipientPlayerId)
        .collection('events')
        .doc(eventId)
        .set({
      'schemaVersion': 1,
      'eventId': eventId,
      'type': 'manualVerificationDisputeOpened',
      'playerId': recipientPlayerId,
      'requestId': requestId,
      'requesterPlayerId': requesterPlayerId,
      'targetGameAccountId': targetGameAccountId,
      'proofCharacterNameSnapshot': proofCharacterName,
      'ownerResponseDeadlineAt': ownerResponseDeadlineAt,
      'occurredAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });
  }

  Future<({String playerId, String gameAccountId})?> _resolveActiveOwner(
    String identityKey, {
    String? targetGameAccountId,
  }) async {
    final claim = await _firestore
        .collection('characterIdentityClaims')
        .doc(identityKey)
        .get();
    final claimAccountId = claim.data()?['gameAccountId'];
    final accountId = claimAccountId is String && claimAccountId.isNotEmpty
        ? claimAccountId
        : targetGameAccountId;
    if (accountId is! String || accountId.isEmpty) return null;
    final account = await _firestore.collection('gameAccounts').doc(accountId).get();
    final owner = account.data()?['ownerPlayerId'];
    if (owner is String &&
        owner.isNotEmpty &&
        account.data()?['status'] == 'active') {
      return (playerId: owner, gameAccountId: accountId);
    }
    return null;
  }

  Future<({String playerId, String gameAccountId})> _resolveForceTransferOwner(
    ManualVerificationRequest request,
  ) async {
    if (request.isAwaitingOwnerResponse) {
      final previousOwner = request.previousOwnerPlayerId;
      final gameAccountId = request.targetGameAccountId;
      if (previousOwner == null ||
          previousOwner.isEmpty ||
          gameAccountId == null ||
          gameAccountId.isEmpty) {
        throw const ManualVerificationException(
          'invalidRequest',
          '분쟁 소유자 정보가 없습니다.',
        );
      }
      return (playerId: previousOwner, gameAccountId: gameAccountId);
    }
    final owner = await _resolveActiveOwner(
      request.targetIdentityKey,
      targetGameAccountId: request.targetGameAccountId,
    );
    if (owner == null) {
      throw const ManualVerificationException(
        'noOwner',
        '기존 소유자가 없습니다. 일반 승인을 사용해 주세요.',
      );
    }
    return owner;
  }

  Future<ManualVerificationRequest> _requireDefenseDispute({
    required String defenseOfRequestId,
    required String defenderPlayerId,
    String? targetGameAccountId,
  }) async {
    final snapshot = await _requests.doc(defenseOfRequestId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ManualVerificationException('notFound', '분쟁 요청을 찾을 수 없습니다.');
    }
    final dispute = _mapRequest(defenseOfRequestId, data, _clock());
    if (!dispute.isAwaitingOwnerResponse) {
      throw const ManualVerificationException(
        'notPending',
        '방어할 수 있는 분쟁이 아닙니다.',
      );
    }
    if (dispute.isOwnerResponseOverdueAt(_clock().toUtc())) {
      throw const ManualVerificationException(
        'deadlinePassed',
        '방어 기한이 지났습니다.',
      );
    }
    final previousOwner = dispute.previousOwnerPlayerId;
    if (previousOwner == null ||
        previousOwner.isEmpty ||
        previousOwner != defenderPlayerId) {
      throw const ManualVerificationException(
        'forbidden',
        '기존 소유자만 방어 요청을 만들 수 있습니다.',
      );
    }
    final accountId = dispute.targetGameAccountId;
    if (accountId == null || accountId.isEmpty) {
      throw const ManualVerificationException(
        'missingAccount',
        '대상 게임 계정 정보가 없습니다.',
      );
    }
    if (targetGameAccountId != null &&
        targetGameAccountId.isNotEmpty &&
        targetGameAccountId != accountId) {
      throw const ManualVerificationException(
        'invalidRequest',
        '분쟁 대상 계정과 일치하지 않습니다.',
      );
    }
    return dispute;
  }

  Future<void> _reviewStatus({
    required String requestId,
    required String status,
    required String operatorPlayerId,
    required String reason,
  }) async {
    final snapshot = await _requests.doc(requestId).get();
    _requirePending(snapshot.data());
    await snapshot.reference.update({
      'status': status,
      'reviewedByOperatorPlayerId': operatorPlayerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewReason': reason.trim(),
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _requirePending(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    if (data['status'] != 'pendingProof') {
      throw const ManualVerificationException(
        'notPending',
        '대기 중인 요청만 처리할 수 있습니다.',
      );
    }
  }

  void _requireForceEligible(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ManualVerificationException('notFound', '요청을 찾을 수 없습니다.');
    }
    final status = data['status'];
    if (status != 'pendingProof' && status != 'awaitingOwnerResponse') {
      throw const ManualVerificationException(
        'notPending',
        '강제 인증할 수 있는 요청이 아닙니다.',
      );
    }
  }

  Future<void> _assertNotBlocked(
    String playerId,
    String identityKey,
    String? targetGameAccountId,
  ) async {
    final keys = <String>{
      '${playerId}_$identityKey',
      if (targetGameAccountId != null && targetGameAccountId.isNotEmpty)
        '${playerId}_$targetGameAccountId',
    };
    for (final blockId in keys) {
      try {
        final snapshot = await _blocks.doc(blockId).get();
        if (snapshot.data()?['status'] == 'active') {
          throw const ManualVerificationException(
            'blocked',
            '이 계정에 대한 수동 인증이 금지되어 있습니다.',
          );
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          rethrow;
        }
      }
    }
  }

  Future<void> _assertNotAlreadyOwner({
    required String playerId,
    required String identityKey,
    String? targetGameAccountId,
  }) async {
    if (targetGameAccountId != null && targetGameAccountId.isNotEmpty) {
      final account = await _firestore
          .collection('gameAccounts')
          .doc(targetGameAccountId)
          .get();
      final owner = account.data()?['ownerPlayerId'];
      if (owner == playerId && account.data()?['status'] == 'active') {
        throw const ManualVerificationException(
          'alreadyOwner',
          '이미 인증한 게임 계정입니다. 수동 인증을 다시 요청할 수 없습니다.',
        );
      }
      return;
    }
    final owner = await _resolveActiveOwner(
      identityKey,
      targetGameAccountId: targetGameAccountId,
    );
    if (owner != null && owner.playerId == playerId) {
      throw const ManualVerificationException(
        'alreadyOwner',
        '이미 인증한 게임 계정입니다. 수동 인증을 다시 요청할 수 없습니다.',
      );
    }
  }

  Future<ManualVerificationRequest?> _activePendingForAccount({
    required String playerId,
    required int localAccountId,
    required String? serverGameAccountId,
    required Set<String> rosterIdentityKeys,
  }) async {
    final snapshot = await _requests
        .where('requesterPlayerId', isEqualTo: playerId)
        .get();
    final now = _clock();
    for (final doc in snapshot.docs) {
      final request = _mapRequest(doc.id, doc.data(), now);
      if (!request.isPending || request.isExpiredAt(now)) continue;
      if (isSameManualVerificationAccount(
        request: request,
        localAccountId: localAccountId,
        serverGameAccountId: serverGameAccountId,
        rosterIdentityKeys: rosterIdentityKeys,
      )) {
        return request;
      }
    }
    return null;
  }

  Future<({int target, int player})> _attemptCounts({
    required String playerId,
    required int localAccountId,
    required String? serverGameAccountId,
    required Set<String> rosterIdentityKeys,
  }) async {
    final playerDocs = await _requests
        .where('requesterPlayerId', isEqualTo: playerId)
        .get();
    var target = 0;
    for (final doc in playerDocs.docs) {
      final request = _mapRequest(doc.id, doc.data(), _clock());
      if (isSameManualVerificationAccount(
        request: request,
        localAccountId: localAccountId,
        serverGameAccountId: serverGameAccountId,
        rosterIdentityKeys: rosterIdentityKeys,
      )) {
        target++;
      }
    }
    return (target: target, player: playerDocs.docs.length);
  }

  Map<String, Object?> _createPayload({
    required String playerId,
    required String identityKey,
    required int localAccountId,
    required String localAccountLabel,
    required String proofServerName,
    required String proofCharacterName,
    required String? proofClassName,
    required String? targetGameAccountId,
    String? defenseOfRequestId,
    required int attemptNumberForTarget,
    required int totalAttemptNumberForPlayer,
    required DateTime now,
  }) {
    return {
      'schemaVersion': 1,
      'requesterPlayerId': playerId,
      'targetIdentityKey': identityKey,
      'localAccountId': localAccountId,
      if (targetGameAccountId != null && targetGameAccountId.isNotEmpty)
        'targetGameAccountId': targetGameAccountId,
      if (defenseOfRequestId != null && defenseOfRequestId.isNotEmpty)
        'defenseOfRequestId': defenseOfRequestId,
      'localAccountLabelSnapshot': localAccountLabel,
      'proofServerName': proofServerName.trim(),
      'proofCharacterName': proofCharacterName.trim(),
      if (proofClassName != null && proofClassName.isNotEmpty)
        'proofClassName': proofClassName,
      'verificationCode': _codeGenerator(),
      'status': 'pendingProof',
      'attemptNumberForTarget': attemptNumberForTarget,
      'totalAttemptNumberForPlayer': totalAttemptNumberForPlayer,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_requestTtl)),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ManualVerificationRequest _mapRequest(
    String id,
    Map<String, dynamic> data,
    DateTime fallbackNow,
  ) {
    DateTime readTime(Object? value) {
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is DateTime) return value.toUtc();
      return fallbackNow.toUtc();
    }

    final status = switch (data['status']) {
      'approved' => ManualVerificationStatus.approved,
      'cancelled' => ManualVerificationStatus.cancelled,
      'blocked' => ManualVerificationStatus.blocked,
      'awaitingOwnerResponse' => ManualVerificationStatus.awaitingOwnerResponse,
      'defended' => ManualVerificationStatus.defended,
      'transferred' => ManualVerificationStatus.transferred,
      'expired' => ManualVerificationStatus.expired,
      _ => ManualVerificationStatus.pendingProof,
    };
    return ManualVerificationRequest(
      id: id,
      requesterPlayerId: data['requesterPlayerId'] as String? ?? '',
      targetIdentityKey: data['targetIdentityKey'] as String? ?? '',
      localAccountId: (data['localAccountId'] as num?)?.toInt(),
      targetGameAccountId: data['targetGameAccountId'] as String?,
      localAccountLabelSnapshot:
          data['localAccountLabelSnapshot'] as String? ?? '',
      proofServerName: data['proofServerName'] as String? ?? '',
      proofCharacterName: data['proofCharacterName'] as String? ?? '',
      proofClassName: data['proofClassName'] as String?,
      verificationCode: data['verificationCode'] as String? ?? '',
      status: status,
      attemptNumberForTarget: (data['attemptNumberForTarget'] as num?)?.toInt() ?? 1,
      totalAttemptNumberForPlayer:
          (data['totalAttemptNumberForPlayer'] as num?)?.toInt() ?? 1,
      createdAt: readTime(data['createdAt']),
      expiresAt: readTime(data['expiresAt']),
      reviewedByOperatorPlayerId:
          data['reviewedByOperatorPlayerId'] as String?,
      reviewReason: data['reviewReason'] as String?,
      serverGameAccountId: data['targetGameAccountId'] as String?,
      previousOwnerPlayerId: data['previousOwnerPlayerId'] as String?,
      disputeOpenedAt: data['disputeOpenedAt'] == null
          ? null
          : readTime(data['disputeOpenedAt']),
      ownerResponseDeadlineAt: data['ownerResponseDeadlineAt'] == null
          ? null
          : readTime(data['ownerResponseDeadlineAt']),
      defenseOfRequestId: data['defenseOfRequestId'] as String?,
    );
  }

  Future<String> _requirePlayerId() async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) {
      throw const ManualVerificationException(
        'unauthenticated',
        '로그인이 필요합니다.',
      );
    }
    final binding = await _firestore.collection('authBindings').doc(authUid).get();
    final bindingData = binding.data();
    if (!binding.exists || bindingData?['status'] != 'active') {
      throw const ManualVerificationException(
        'unauthenticated',
        'authBindings가 active가 아닙니다. 앱을 다시 시작해 주세요.',
      );
    }
    final playerId = bindingData?['playerId'];
    if (playerId is! String || playerId.isEmpty) {
      throw const ManualVerificationException(
        'unauthenticated',
        '플레이어 정보를 확인할 수 없습니다.',
      );
    }
    return playerId;
  }

  ManualVerificationException _mapFirebase(FirebaseException error) {
    if (error.code == 'permission-denied') {
      final detail = error.message?.trim();
      return ManualVerificationException(
        'permission-denied',
        detail != null && detail.isNotEmpty
            ? '[permission-denied] $detail'
            : '[permission-denied] Missing or insufficient permissions.',
      );
    }
    if (error.code == 'failed-precondition') {
      return const ManualVerificationException(
        'index',
        '목록 인덱스를 준비 중입니다. 잠시 후 다시 시도해 주세요.',
      );
    }
    return const ManualVerificationException(
      'unavailable',
      '요청을 처리하지 못했습니다. 네트워크를 확인해 주세요.',
    );
  }

  Future<String> _requireOperator() async {
    final playerId = await _requirePlayerId();
    final assignment = await _firestore
        .collection('operatorAssignments')
        .doc(playerId)
        .get();
    if (assignment.data()?['status'] != 'active') {
      throw const ManualVerificationException(
        'forbidden',
        '운영자 지정(operatorAssignments)이 active가 아닙니다.',
      );
    }
    final player = await _firestore.collection('players').doc(playerId).get();
    if (!player.exists || player.data()?['status'] != 'active') {
      throw const ManualVerificationException(
        'forbidden',
        '운영자 Player 문서가 없거나 status가 active가 아닙니다.',
      );
    }
    return playerId;
  }
}
