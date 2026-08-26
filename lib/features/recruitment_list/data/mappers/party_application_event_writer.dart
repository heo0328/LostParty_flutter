import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_event.dart';
import 'party_event_write_plan.dart';

/// 신청 계열 Player Event를 명령 Transaction에 함께 기록한다.
class PartyApplicationEventWriter {
  const PartyApplicationEventWriter._();

  static void write({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required PartyEventType type,
    required String recipientPlayerId,
    required String recruitmentId,
    required int applicationRevision,
    required String actorPlayerId,
    required String characterNameSnapshot,
    required Object serverTimestamp,
    String? classNameSnapshot,
    String? role,
    String? raidId,
    String? difficultyId,
    int? rejectionCount,
    DateTime Function()? now,
  }) {
    assert(
      type == PartyEventType.applicationSubmitted ||
          type == PartyEventType.applicationApproved ||
          type == PartyEventType.applicationRejected ||
          type == PartyEventType.applicationWithdrawn,
      'application event writer requires an application type',
    );
    // 행위자 본인에게는 쓰지 않는다. Rules도 recipient != actor를 요구한다.
    if (recipientPlayerId == actorPlayerId) return;

    final eventId = PartyEventWritePlan.applicationId(
      recruitmentId: recruitmentId,
      applicationPlayerId: type == PartyEventType.applicationSubmitted ||
              type == PartyEventType.applicationWithdrawn
          ? actorPlayerId
          : recipientPlayerId,
      applicationRevision: applicationRevision,
      type: type.wireName,
    );
    final expiresAt = Timestamp.fromDate(
      (now ?? DateTime.now)().toUtc().add(const Duration(days: 28)),
    );
    final ref = firestore
        .collection('players')
        .doc(recipientPlayerId)
        .collection('events')
        .doc(eventId);
    transaction.set(
      ref,
      PartyEventWritePlan.application(
        eventId: eventId,
        type: type,
        recipientPlayerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        applicationRevision: applicationRevision,
        actorPlayerId: actorPlayerId,
        applicantCharacterNameSnapshot: characterNameSnapshot,
        applicantClassNameSnapshot: classNameSnapshot,
        applicantRole: role,
        raidId: raidId,
        difficultyId: difficultyId,
        rejectionCount: rejectionCount,
        serverTimestamp: serverTimestamp,
        expiresAt: expiresAt,
      ),
    );
  }
}
