import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../recruitment_list/data/mappers/party_event_mapper.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';
import '../../domain/repositories/party_event_read_repository.dart';

class FirestorePartyEventReadRepository implements PartyEventReadRepository {
  FirestorePartyEventReadRepository({required FirebaseFirestore firestore})
    : _firestore = firestore,
      _mapper = PartyEventMapper(
        toDateTime: (value) => switch (value) {
          Timestamp timestamp => timestamp.toDate().toUtc(),
          DateTime dateTime => dateTime.toUtc(),
          _ => throw const FormatException('Expected Firestore Timestamp.'),
        },
      );

  final FirebaseFirestore _firestore;
  final PartyEventMapper _mapper;

  @override
  Future<List<PartyEvent>> loadRecentEvents({
    required String playerId,
    int limit = 20,
  }) async {
    if (playerId.isEmpty) {
      throw const PartyEventReadException(PartyEventReadFailureType.contract);
    }
    if (limit <= 0) {
      throw const PartyEventReadException(PartyEventReadFailureType.contract);
    }
    try {
      final snapshot = await _firestore
          .collection('partyEvents')
          .where('audiencePlayerIds', arrayContains: playerId)
          .orderBy('occurredAt', descending: true)
          .limit(limit)
          .get();
      final events = <PartyEvent>[];
      for (final doc in snapshot.docs) {
        final mapped = _mapper.mapShared(
          Map<String, Object?>.from(doc.data()),
          recipientPlayerId: playerId,
          documentId: doc.id,
        );
        if (mapped == null) {
          throw const PartyEventReadException(
            PartyEventReadFailureType.contract,
          );
        }
        events.add(mapped);
      }
      return events;
    } on PartyEventReadException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PartyEventReadException(switch (error.code) {
        'permission-denied' => PartyEventReadFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' =>
          PartyEventReadFailureType.unavailable,
        _ => PartyEventReadFailureType.unknown,
      });
    } catch (_) {
      throw const PartyEventReadException(PartyEventReadFailureType.unknown);
    }
  }
}
