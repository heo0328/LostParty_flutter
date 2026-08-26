import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_event.dart';
import 'party_event_write_plan.dart';

/// 해산·종료 계열 Player Event를 명령 Transaction에 함께 기록한다.
class PartyLifecycleEventWriter {
  const PartyLifecycleEventWriter._();

  static void writeToRecipients({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required PartyEventType type,
    required Iterable<String> recipientPlayerIds,
    required String recruitmentId,
    required String cycleKey,
    required int recruitmentRevision,
    required String actorPlayerId,
    required Object serverTimestamp,
    String? raidId,
    String? difficultyId,
    Map<String, String?> characterNameByPlayerId = const {},
    String? endReason,
    DateTime Function()? now,
  }) {
    for (final recipientPlayerId in recipientPlayerIds) {
      write(
        transaction: transaction,
        firestore: firestore,
        type: type,
        recipientPlayerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        cycleKey: cycleKey,
        recruitmentRevision: recruitmentRevision,
        actorPlayerId: actorPlayerId,
        characterNameSnapshot: characterNameByPlayerId[recipientPlayerId],
        raidId: raidId,
        difficultyId: difficultyId,
        endReason: endReason,
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
    required String cycleKey,
    required int recruitmentRevision,
    required String actorPlayerId,
    required Object serverTimestamp,
    String? characterNameSnapshot,
    String? raidId,
    String? difficultyId,
    String? endReason,
    DateTime Function()? now,
  }) {
    assert(
      type == PartyEventType.partyDisbanded || type == PartyEventType.partyEnded,
      'lifecycle event writer requires partyDisbanded or partyEnded',
    );
    if (recipientPlayerId == actorPlayerId) return;

    final eventId = PartyEventWritePlan.lifecycleId(
      recruitmentId: recruitmentId,
      cycleKey: cycleKey,
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
      PartyEventWritePlan.lifecycle(
        eventId: eventId,
        type: type,
        recipientPlayerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        cycleKey: cycleKey,
        recruitmentRevision: recruitmentRevision,
        actorPlayerId: actorPlayerId,
        raidId: raidId,
        difficultyId: difficultyId,
        characterNameSnapshot: characterNameSnapshot,
        endReason: endReason,
        serverTimestamp: serverTimestamp,
        expiresAt: expiresAt,
      ),
    );
  }
}
