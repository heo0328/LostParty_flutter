import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../account/data/local/account_database.dart';
import '../../../recruitment_list/data/mappers/party_event_mapper.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';
import '../../domain/services/party_event_sync_service.dart';

class FirestorePartyEventSyncService implements PartyEventSyncService {
  FirestorePartyEventSyncService({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    required AccountDatabase database,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _database = database,
       _mapper = PartyEventMapper(
         toDateTime: (value) => switch (value) {
           Timestamp timestamp => timestamp.toDate().toUtc(),
           DateTime dateTime => dateTime.toUtc(),
           _ => throw const FormatException('Expected Firestore Timestamp.'),
         },
       );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final AccountDatabase _database;
  final PartyEventMapper _mapper;

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
          .collection('partyEvents')
          .where('audiencePlayerIds', arrayContains: playerId)
          .orderBy('occurredAt')
          .get();
      var count = 0;
      for (final event in events.docs) {
        final value = Map<String, Object?>.from(event.data());
        final mapped = _mapper.mapShared(
          value,
          recipientPlayerId: playerId,
          documentId: event.id,
        );
        if (mapped == null) {
          continue;
        }

        final historyStatus = _historyStatus(mapped.knownType);
        if (historyStatus != null) {
          final characterId = mapped.characterId;
          final raidId = mapped.raidId;
          final difficultyId = mapped.difficultyId;
          final cycleKey = mapped.cycleKey;
          if (characterId != null &&
              raidId != null &&
              difficultyId != null &&
              cycleKey != null) {
            await _database.syncPartyHistoryEvent(
              eventId: mapped.eventId,
              playerId: playerId,
              characterId: characterId,
              recruitmentId: mapped.recruitmentId,
              raidId: raidId,
              difficultyId: difficultyId,
              cycleKey: cycleKey,
              serverStatus: historyStatus,
              occurredAt: mapped.occurredAt,
            );
            count++;
          }
        }

        final known = mapped.knownType;
        if (known != null && known.isNotificationCandidate) {
          await _database.syncPartyNotificationReceipt(
            eventId: mapped.eventId,
            playerId: playerId,
            type: mapped.type,
            recruitmentId: mapped.recruitmentId,
            cycleKey: mapped.cycleKey,
            raidId: mapped.raidId,
            difficultyId: mapped.difficultyId,
            characterNameSnapshot: mapped.characterNameSnapshot,
            occurredAt: mapped.occurredAt,
            expiresAt: mapped.expiresAt,
          );
          count++;
        }
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

String? _historyStatus(PartyEventType? type) {
  if (type == null || !type.isRaidHistoryEvent) return null;
  return switch (type) {
    PartyEventType.partyCompleted => 'completed',
    PartyEventType.partyIncompleteEnded => 'incompleteEnded',
    PartyEventType.partyCompletionCancelled => 'completionCancelled',
    _ => null,
  };
}
