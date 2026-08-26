import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/weekly_raid_claim.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../dtos/weekly_raid_claim_dto.dart';
import '../mappers/weekly_raid_claim_mapper.dart';

class FirestoreWeeklyRaidClaimRepository
    implements WeeklyRaidClaimRepository {
  FirestoreWeeklyRaidClaimRepository({required FirebaseFirestore firestore})
    : _firestore = firestore,
      _mapper = WeeklyRaidClaimMapper(
        toDateTime: (value) => switch (value) {
          Timestamp timestamp => timestamp.toDate(),
          DateTime dateTime => dateTime,
          _ => throw const FormatException('Expected Firestore Timestamp.'),
        },
      );

  final FirebaseFirestore _firestore;
  final WeeklyRaidClaimMapper _mapper;

  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) {
    if (playerId.trim().isEmpty || cycleKey.trim().isEmpty) {
      return Stream.error(
        const WeeklyRaidClaimReadException(
          WeeklyRaidClaimReadFailureType.contract,
        ),
      );
    }
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('weeklyRaidClaims')
        .where('cycleKey', isEqualTo: cycleKey)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((document) {
              final claim = _mapper.map(
                WeeklyRaidClaimDto.fromMap(document.data()),
                documentId: document.id,
              );
              if (claim.playerId != playerId || claim.cycleKey != cycleKey) {
                throw const FormatException('Claim path mismatch.');
              }
              return claim;
            }).toList(growable: false);
          } on WeeklyRaidClaimReadException {
            rethrow;
          } catch (_) {
            throw const WeeklyRaidClaimReadException(
              WeeklyRaidClaimReadFailureType.contract,
            );
          }
        })
        .handleError((Object error) {
          if (error is WeeklyRaidClaimReadException) throw error;
          if (error is FirebaseException) {
            throw WeeklyRaidClaimReadException(switch (error.code) {
              'permission-denied' =>
                WeeklyRaidClaimReadFailureType.permissionDenied,
              'unavailable' || 'deadline-exceeded' =>
                WeeklyRaidClaimReadFailureType.unavailable,
              _ => WeeklyRaidClaimReadFailureType.unknown,
            });
          }
          throw const WeeklyRaidClaimReadException(
            WeeklyRaidClaimReadFailureType.unknown,
          );
        });
  }
}
