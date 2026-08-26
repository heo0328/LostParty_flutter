import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../account/data/local/account_database.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';
import '../../domain/services/party_event_sync_service.dart';

class FirestorePartyEventSyncService implements PartyEventSyncService {
  const FirestorePartyEventSyncService({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    required AccountDatabase database,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _database = database;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final AccountDatabase _database;

  @override
  Future<PartyEventSyncResult> sync() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyEventSyncResult.failure(
        PartyEventSyncFailure.unauthenticated,
      );
    }
    try {
      final binding = await _firestore.collection('authBindings').doc(uid).get();
      final data = binding.data();
      final playerId = data?['playerId'];
      if (data?['status'] != 'active' ||
          playerId is! String ||
          playerId.isEmpty) {
        return const PartyEventSyncResult.failure(
          PartyEventSyncFailure.playerBindingMissing,
        );
      }
      final events = await _firestore
          .collection('players')
          .doc(playerId)
          .collection('events')
          .orderBy('occurredAt')
          .get();
      var count = 0;
      for (final event in events.docs) {
        final value = event.data();
        final status = _historyStatus(value['type']);
        // 알림 전용·미래 type은 완료 히스토리 Projection 대상이 아니다.
        if (status == null) continue;
        final occurredAt = value['occurredAt'];
        if (value['playerId'] != playerId || occurredAt is! Timestamp) {
          return const PartyEventSyncResult.failure(
            PartyEventSyncFailure.invalidData,
          );
        }
        final characterId = value['characterId'];
        final recruitmentId = value['recruitmentId'];
        final raidId = value['raidId'];
        final difficultyId = value['difficultyId'];
        final cycleKey = value['cycleKey'];
        if (characterId is! String ||
            recruitmentId is! String ||
            raidId is! String ||
            difficultyId is! String ||
            cycleKey is! String) {
          return const PartyEventSyncResult.failure(
            PartyEventSyncFailure.invalidData,
          );
        }
        await _database.syncPartyHistoryEvent(
          eventId: event.id,
          playerId: playerId,
          characterId: characterId,
          recruitmentId: recruitmentId,
          raidId: raidId,
          difficultyId: difficultyId,
          cycleKey: cycleKey,
          serverStatus: status,
          occurredAt: occurredAt.toDate().toUtc(),
        );
        count++;
      }
      return PartyEventSyncResult.success(count);
    } on FirebaseException catch (error) {
      return PartyEventSyncResult.failure(switch (error.code) {
        'permission-denied' => PartyEventSyncFailure.permissionDenied,
        'unavailable' || 'deadline-exceeded' =>
          PartyEventSyncFailure.temporarilyUnavailable,
        _ => PartyEventSyncFailure.unknown,
      });
    } catch (_) {
      return const PartyEventSyncResult.failure(PartyEventSyncFailure.unknown);
    }
  }
}

String? _historyStatus(Object? type) {
  final known = PartyEventType.tryParse(type is String ? type : null);
  if (known == null || !known.isRaidHistoryEvent) return null;
  return switch (known) {
    PartyEventType.partyCompleted => 'completed',
    PartyEventType.partyIncompleteEnded => 'incompleteEnded',
    PartyEventType.partyCompletionCancelled => 'completionCancelled',
    _ => null,
  };
}
