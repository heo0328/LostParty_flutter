import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_event.dart';
import 'party_event_write_plan.dart';

/// 멤버십 계열 Player Event를 명령 Transaction에 함께 기록한다.
class PartyMembershipEventWriter {
  const PartyMembershipEventWriter._();

  static void writeToRecipients({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required PartyEventType type,
    required Iterable<String> recipientPlayerIds,
    required String recruitmentId,
    required int recruitmentRevision,
    required String actorPlayerId,
    required String targetPlayerId,
    required Object serverTimestamp,
    String? characterNameSnapshot,
    String? classNameSnapshot,
    String? role,
    String? previousCharacterNameSnapshot,
    String? targetCharacterNameSnapshot,
    String? raidId,
    String? difficultyId,
    int? partyIndex,
    int? slotIndex,
    String? reason,
    DateTime Function()? now,
  }) {
    for (final recipientPlayerId in recipientPlayerIds) {
      write(
        transaction: transaction,
        firestore: firestore,
        type: type,
        recipientPlayerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        recruitmentRevision: recruitmentRevision,
        actorPlayerId: actorPlayerId,
        targetPlayerId: targetPlayerId,
        characterNameSnapshot: characterNameSnapshot,
        classNameSnapshot: classNameSnapshot,
        role: role,
        previousCharacterNameSnapshot: previousCharacterNameSnapshot,
        targetCharacterNameSnapshot: targetCharacterNameSnapshot,
        raidId: raidId,
        difficultyId: difficultyId,
        partyIndex: partyIndex,
        slotIndex: slotIndex,
        reason: reason,
        serverTimestamp: serverTimestamp,
        now: now,
      );
    }
  }

  static void write({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required PartyEventType type,
    required String recipientPlayerId,
    required String recruitmentId,
    required int recruitmentRevision,
    required String actorPlayerId,
    required String targetPlayerId,
    required Object serverTimestamp,
    String? characterNameSnapshot,
    String? classNameSnapshot,
    String? role,
    String? previousCharacterNameSnapshot,
    String? targetCharacterNameSnapshot,
    String? raidId,
    String? difficultyId,
    int? partyIndex,
    int? slotIndex,
    String? reason,
    DateTime Function()? now,
  }) {
    assert(
      type == PartyEventType.memberJoined ||
          type == PartyEventType.memberLeft ||
          type == PartyEventType.memberKicked ||
          type == PartyEventType.memberCharacterChanged,
      'membership event writer requires a membership type',
    );
    // 행위자 본인에게는 쓰지 않는다. Rules도 recipient != actor를 요구한다.
    if (recipientPlayerId == actorPlayerId) return;

    final eventId = PartyEventWritePlan.membershipId(
      recruitmentId: recruitmentId,
      targetPlayerId: targetPlayerId,
      recruitmentRevision: recruitmentRevision,
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
      PartyEventWritePlan.membership(
        eventId: eventId,
        type: type,
        recipientPlayerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        recruitmentRevision: recruitmentRevision,
        actorPlayerId: actorPlayerId,
        targetPlayerId: targetPlayerId,
        characterNameSnapshot: characterNameSnapshot,
        classNameSnapshot: classNameSnapshot,
        role: role,
        previousCharacterNameSnapshot: previousCharacterNameSnapshot,
        targetCharacterNameSnapshot: targetCharacterNameSnapshot,
        raidId: raidId,
        difficultyId: difficultyId,
        partyIndex: partyIndex,
        slotIndex: slotIndex,
        reason: reason,
        serverTimestamp: serverTimestamp,
        expiresAt: expiresAt,
      ),
    );
  }
}
