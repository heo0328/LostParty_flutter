import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/weekly_raid_claim.dart';
import '../../domain/entities/weekly_raid_claim_command.dart';
import '../../domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../dtos/weekly_raid_claim_dto.dart';
import '../mappers/weekly_raid_claim_mapper.dart';
import '../mappers/weekly_raid_claim_document_id.dart';

class FirestoreWeeklyRaidClaimRepository
    implements WeeklyRaidClaimRepository, WeeklyRaidClaimCommandRepository {
  FirestoreWeeklyRaidClaimRepository({
    required FirebaseFirestore firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _mapper = WeeklyRaidClaimMapper(
         toDateTime: (value) => switch (value) {
           Timestamp timestamp => timestamp.toDate(),
           DateTime dateTime => dateTime,
           _ => throw const FormatException('Expected Firestore Timestamp.'),
         },
       );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
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
            return snapshot.docs
                .map((document) {
                  final claim = _mapper.map(
                    WeeklyRaidClaimDto.fromMap(document.data()),
                    documentId: document.id,
                  );
                  if (claim.playerId != playerId ||
                      claim.cycleKey != cycleKey) {
                    throw const FormatException('Claim path mismatch.');
                  }
                  return claim;
                })
                .toList(growable: false);
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
              'unavailable' ||
              'deadline-exceeded' => WeeklyRaidClaimReadFailureType.unavailable,
              _ => WeeklyRaidClaimReadFailureType.unknown,
            });
          }
          throw const WeeklyRaidClaimReadException(
            WeeklyRaidClaimReadFailureType.unknown,
          );
        });
  }

  @override
  Future<WeeklyRaidClaimCommandResult> createManualClaim(
    CreateManualWeeklyRaidClaimCommand command,
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    final claimId = _claimId(
      cycleKey: command.cycleKey,
      characterId: command.characterId,
      raidId: command.raidId,
    );
    if (claimId == null ||
        command.difficultyId.trim().isEmpty ||
        command.cycleEndsAt.toUtc().difference(
              command.cycleStartedAt.toUtc(),
            ) !=
            const Duration(days: 7)) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      final applications = await _firestore
          .collectionGroup('applications')
          .where('schemaVersion', isEqualTo: 1)
          .where('applicantPlayerId', isEqualTo: command.playerId)
          .where('cycleKey', isEqualTo: command.cycleKey)
          .orderBy('updatedAt', descending: true)
          .get();
      final hasPending = applications.docs.any((document) {
        final data = document.data();
        return data['status'] == 'pending' &&
            data['characterId'] == command.characterId;
      });
      if (hasPending) {
        return const WeeklyRaidClaimCommandResult.failure(
          WeeklyRaidClaimCommandFailure.pendingApplication,
        );
      }
      final claimRef = _claim(command.playerId, claimId);
      final assignmentRef = _firestore
          .collection('players')
          .doc(command.playerId)
          .collection('activeRaidAssignments')
          .doc('${command.characterId}_${command.raidId}');
      return await _firestore.runTransaction((transaction) async {
        final claim = await transaction.get(claimRef);
        final assignment = await transaction.get(assignmentRef);
        if (claim.exists) {
          return const WeeklyRaidClaimCommandResult.success();
        }
        if (assignment.exists) {
          return const WeeklyRaidClaimCommandResult.failure(
            WeeklyRaidClaimCommandFailure.activeAssignment,
          );
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(claimRef, {
          'schemaVersion': 1,
          'playerId': command.playerId,
          'characterId': command.characterId,
          'raidId': command.raidId,
          'difficultyId': command.difficultyId,
          'cycleKey': command.cycleKey,
          'source': 'manual',
          'cycleStartedAt': Timestamp.fromDate(command.cycleStartedAt.toUtc()),
          'cycleEndsAt': Timestamp.fromDate(command.cycleEndsAt.toUtc()),
          'completedAt': now,
          'updatedAt': now,
        });
        return const WeeklyRaidClaimCommandResult.success();
      });
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_commandFailure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  @override
  Future<WeeklyRaidClaimCommandResult> deleteManualClaim(
    DeleteManualWeeklyRaidClaimCommand command,
  ) async {
    if (_firebaseAuth.currentUser == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unauthenticated,
      );
    }
    final claimId = _claimId(
      cycleKey: command.cycleKey,
      characterId: command.characterId,
      raidId: command.raidId,
    );
    if (claimId == null) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.invalidRequest,
      );
    }
    try {
      final claimRef = _claim(command.playerId, claimId);
      await _firestore.runTransaction((transaction) async {
        final claim = await transaction.get(claimRef);
        if (claim.exists) transaction.delete(claimRef);
      });
      return const WeeklyRaidClaimCommandResult.success();
    } on FirebaseException catch (error) {
      return WeeklyRaidClaimCommandResult.failure(_commandFailure(error.code));
    } catch (_) {
      return const WeeklyRaidClaimCommandResult.failure(
        WeeklyRaidClaimCommandFailure.unknown,
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _claim(
    String playerId,
    String claimId,
  ) => _firestore
      .collection('players')
      .doc(playerId)
      .collection('weeklyRaidClaims')
      .doc(claimId);

  String? _claimId({
    required String cycleKey,
    required String characterId,
    required String raidId,
  }) {
    try {
      return WeeklyRaidClaimDocumentId.create(
        cycleKey: cycleKey,
        characterId: characterId,
        raidId: raidId,
      );
    } on ArgumentError {
      return null;
    }
  }

  WeeklyRaidClaimCommandFailure _commandFailure(String code) => switch (code) {
    'permission-denied' => WeeklyRaidClaimCommandFailure.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'failed-precondition' ||
    'aborted' => WeeklyRaidClaimCommandFailure.temporarilyUnavailable,
    _ => WeeklyRaidClaimCommandFailure.unknown,
  };
}
