import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/weekly_raid_status_projection.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../../domain/repositories/weekly_raid_status_repository.dart';
import '../../domain/services/weekly_raid_status_projector.dart';

class FirestoreWeeklyRaidStatusRepository
    implements WeeklyRaidStatusRepository {
  const FirestoreWeeklyRaidStatusRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<WeeklyRaidStatusProjection>> watchCurrentCycleStatuses({
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

    final player = _firestore.collection('players').doc(playerId);
    final stateQuery = player
        .collection('raidStates')
        .where('cycleKey', isEqualTo: cycleKey);
    final claimQuery = player
        .collection('weeklyRaidClaims')
        .where('cycleKey', isEqualTo: cycleKey);
    final assignmentQuery = player
        .collection('activeRaidAssignments')
        .where('cycleKey', isEqualTo: cycleKey);

    late final StreamController<List<WeeklyRaidStatusProjection>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? stateSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? claimSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignmentSub;
    List<WeeklyRaidStatusRecord>? states;
    List<WeeklyRaidStatusRecord>? claims;
    List<WeeklyRaidStatusRecord>? assignments;

    void emitIfReady() {
      if (controller.isClosed ||
          states == null ||
          claims == null ||
          assignments == null) {
        return;
      }
      controller.add(
        WeeklyRaidStatusProjector.project(
          playerId: playerId,
          cycleKey: cycleKey,
          records: [...states!, ...claims!, ...assignments!],
        ),
      );
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) {
        controller.addError(_readException(error), stackTrace);
      }
    }

    controller = StreamController<List<WeeklyRaidStatusProjection>>(
      onListen: () {
        stateSub = stateQuery.snapshots().listen((snapshot) {
          try {
            states = snapshot.docs
                .map(
                  (document) => _stateRecord(
                    document: document,
                    playerId: playerId,
                    cycleKey: cycleKey,
                  ),
                )
                .toList(growable: false);
            emitIfReady();
          } catch (error, stackTrace) {
            addError(error, stackTrace);
          }
        }, onError: addError);
        claimSub = claimQuery.snapshots().listen((snapshot) {
          try {
            claims = snapshot.docs
                .map(
                  (document) => _legacyRecord(
                    document: document,
                    playerId: playerId,
                    cycleKey: cycleKey,
                    kind: WeeklyRaidStatusRecordKind.legacyClaim,
                  ),
                )
                .toList(growable: false);
            emitIfReady();
          } catch (error, stackTrace) {
            addError(error, stackTrace);
          }
        }, onError: addError);
        assignmentSub = assignmentQuery.snapshots().listen((snapshot) {
          try {
            assignments = snapshot.docs
                .map(
                  (document) => _legacyRecord(
                    document: document,
                    playerId: playerId,
                    cycleKey: cycleKey,
                    kind: WeeklyRaidStatusRecordKind.legacyAssignment,
                  ),
                )
                .toList(growable: false);
            emitIfReady();
          } catch (error, stackTrace) {
            addError(error, stackTrace);
          }
        }, onError: addError);
      },
      onCancel: () async {
        await stateSub?.cancel();
        await claimSub?.cancel();
        await assignmentSub?.cancel();
      },
    );
    return controller.stream;
  }

  WeeklyRaidStatusRecord _stateRecord({
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required String playerId,
    required String cycleKey,
  }) {
    final data = document.data();
    final characterId = data['characterId'];
    final raidId = data['raidId'];
    final status = data['status'];
    _validateCommon(
      documentId: document.id,
      data: data,
      playerId: playerId,
      cycleKey: cycleKey,
      characterId: characterId,
      raidId: raidId,
      cycleInDocumentId: false,
    );
    if (status != 'active' && status != 'completed') {
      throw const FormatException('Unknown raidState status.');
    }
    return WeeklyRaidStatusRecord(
      playerId: playerId,
      characterId: characterId as String,
      raidId: raidId as String,
      cycleKey: cycleKey,
      kind: status == 'active'
          ? WeeklyRaidStatusRecordKind.activeState
          : WeeklyRaidStatusRecordKind.completedState,
      recruitmentId: data['recruitmentId'] as String?,
    );
  }

  WeeklyRaidStatusRecord _legacyRecord({
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required String playerId,
    required String cycleKey,
    required WeeklyRaidStatusRecordKind kind,
  }) {
    final data = document.data();
    final characterId = data['characterId'];
    final raidId = data['raidId'];
    _validateCommon(
      documentId: document.id,
      data: data,
      playerId: playerId,
      cycleKey: cycleKey,
      characterId: characterId,
      raidId: raidId,
      cycleInDocumentId: kind == WeeklyRaidStatusRecordKind.legacyClaim,
    );
    return WeeklyRaidStatusRecord(
      playerId: playerId,
      characterId: characterId as String,
      raidId: raidId as String,
      cycleKey: cycleKey,
      kind: kind,
      recruitmentId: data['recruitmentId'] as String?,
    );
  }

  void _validateCommon({
    required String documentId,
    required Map<String, dynamic> data,
    required String playerId,
    required String cycleKey,
    required Object? characterId,
    required Object? raidId,
    required bool cycleInDocumentId,
  }) {
    if (data['playerId'] != playerId ||
        data['cycleKey'] != cycleKey ||
        characterId is! String ||
        characterId.isEmpty ||
        raidId is! String ||
        raidId.isEmpty) {
      throw const FormatException('Weekly raid status path mismatch.');
    }
    final expectedId = cycleInDocumentId
        ? '${cycleKey}_${characterId}_$raidId'
        : '${characterId}_$raidId';
    if (documentId != expectedId) {
      throw const FormatException('Weekly raid status document mismatch.');
    }
  }

  WeeklyRaidClaimReadException _readException(Object error) {
    if (error is WeeklyRaidClaimReadException) return error;
    if (error is FirebaseException) {
      return WeeklyRaidClaimReadException(switch (error.code) {
        'permission-denied' => WeeklyRaidClaimReadFailureType.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' => WeeklyRaidClaimReadFailureType.unavailable,
        _ => WeeklyRaidClaimReadFailureType.unknown,
      });
    }
    if (error is FormatException || error is TypeError) {
      return const WeeklyRaidClaimReadException(
        WeeklyRaidClaimReadFailureType.contract,
      );
    }
    return const WeeklyRaidClaimReadException(
      WeeklyRaidClaimReadFailureType.unknown,
    );
  }
}
