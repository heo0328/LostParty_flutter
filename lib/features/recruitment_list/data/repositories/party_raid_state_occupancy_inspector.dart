import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_raid_state_conflict.dart';
import '../../domain/services/party_create_occupancy_gate.dart';
import '../../domain/services/party_ownership_record_policy.dart';
import 'party_character_ownership_reader.dart';

class PartyRaidStateOccupancyInspector {
  const PartyRaidStateOccupancyInspector._();

  static Future<PartyRaidStateOccupancyInspection> inspect({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required String playerId,
    required String characterId,
    required String raidId,
    required String requestedCycleKey,
    required DateTime now,
    GameAccountOwnershipSnapshot? ownership,
  }) async {
    final stateRef = firestore
        .collection('players')
        .doc(playerId)
        .collection('raidStates')
        .doc(
          PartyRaidState.documentIdFor(
            characterId: characterId,
            raidId: raidId,
          ),
        );
    final state = await transaction.get(stateRef);
    final data = state.data();
    if (ownership != null) {
      final claim = await transaction.get(
        firestore
            .collection('players')
            .doc(playerId)
            .collection('weeklyRaidClaims')
            .doc('${requestedCycleKey}_${characterId}_$raidId'),
      );
      final claimData = claim.data();
      if (claimData != null) {
        final condition = PartyOwnershipRecordPolicy.classify(
          ownership: ownership,
          data: claimData,
          playerId: playerId,
          characterId: characterId,
          raidId: raidId,
          isRaidState: false,
          claimCycleKey: requestedCycleKey,
        );
        if (condition == GameAccountOwnershipCondition.unknown) {
          return PartyRaidStateOccupancyInspection.inconsistent(stateRef);
        }
        if (condition == GameAccountOwnershipCondition.current) {
          return PartyRaidStateOccupancyInspection(
            stateRef: stateRef,
            decision: ExistingRaidStateOccupancyDecision.currentCompleted,
          );
        }
      }
    }
    if (data == null) {
      return PartyRaidStateOccupancyInspection.none(stateRef);
    }

    if (ownership != null) {
      final condition = PartyOwnershipRecordPolicy.classify(
        ownership: ownership,
        data: data,
        playerId: playerId,
        characterId: characterId,
        raidId: raidId,
        isRaidState: true,
      );
      if (condition == GameAccountOwnershipCondition.unknown) {
        return PartyRaidStateOccupancyInspection.inconsistent(stateRef);
      }
      if (condition == GameAccountOwnershipCondition.ownershipChanged) {
        // Keep the old document until a validated participation write replaces it.
        return PartyRaidStateOccupancyInspection.none(stateRef);
      }
    }

    final statePlayerId = data['playerId'];
    final stateCharacterId = data['characterId'];
    final stateRaidId = data['raidId'];
    final stateCycleKey = data['cycleKey'];
    final stateStatus = data['status'];
    final stateRevision = data['revision'];
    if (statePlayerId != playerId ||
        stateCharacterId != characterId ||
        stateRaidId != raidId ||
        stateCycleKey is! String ||
        stateCycleKey.isEmpty ||
        stateStatus is! String ||
        stateRevision is! int) {
      return PartyRaidStateOccupancyInspection.inconsistent(stateRef);
    }

    DocumentSnapshot<Map<String, dynamic>>? recruitment;
    String? recruitmentId;
    if (stateStatus == 'active') {
      if (data['source'] != 'party' ||
          data['recruitmentId'] is! String ||
          (data['recruitmentId'] as String).isEmpty) {
        return PartyRaidStateOccupancyInspection.inconsistent(stateRef);
      }
      recruitmentId = data['recruitmentId'] as String;
      recruitment = await transaction.get(
        firestore.collection('recruitments').doc(recruitmentId),
      );
      if (recruitment.exists && recruitment.data()?['raidId'] != raidId) {
        return PartyRaidStateOccupancyInspection.inconsistent(stateRef);
      }
    }

    final decision = PartyCreateOccupancyGate.classifyExistingRaidState(
      requestedCycleKey: requestedCycleKey,
      stateCycleKey: stateCycleKey,
      stateStatus: stateStatus,
      recruitmentExists: recruitment?.exists == true,
      recruitmentStatus: recruitment?.data()?['status'] as String?,
      recruitmentCycleStatus:
          recruitment?.data()?['currentCycleStatus'] as String?,
      recruitmentCycleKey: recruitment?.data()?['currentCycleKey'] as String?,
      recruitmentContinuesTogether:
          recruitment?.data()?['continueTogether'] == true,
      recruitmentCycleEndsAt:
          (recruitment?.data()?['cycleEndsAt'] as Timestamp?)?.toDate(),
      now: now,
    );
    return PartyRaidStateOccupancyInspection(
      stateRef: stateRef,
      decision: decision,
      orphanedParticipation:
          decision == ExistingRaidStateOccupancyDecision.currentOrphanActive ||
              decision ==
                  ExistingRaidStateOccupancyDecision.historicalOrphanActive
          ? PartyOrphanedRaidParticipation(
              characterId: characterId,
              raidId: raidId,
              cycleKey: stateCycleKey,
              recruitmentId: recruitmentId!,
              stateRevision: stateRevision,
              isHistorical:
                  decision ==
                  ExistingRaidStateOccupancyDecision.historicalOrphanActive,
            )
          : null,
    );
  }
}

class PartyRaidStateOccupancyInspection {
  const PartyRaidStateOccupancyInspection({
    required this.stateRef,
    required this.decision,
    this.orphanedParticipation,
  });

  factory PartyRaidStateOccupancyInspection.none(
    DocumentReference<Map<String, dynamic>> stateRef,
  ) => PartyRaidStateOccupancyInspection(stateRef: stateRef, decision: null);

  factory PartyRaidStateOccupancyInspection.inconsistent(
    DocumentReference<Map<String, dynamic>> stateRef,
  ) => PartyRaidStateOccupancyInspection(
    stateRef: stateRef,
    decision: ExistingRaidStateOccupancyDecision.inconsistent,
  );

  final DocumentReference<Map<String, dynamic>> stateRef;
  final ExistingRaidStateOccupancyDecision? decision;
  final PartyOrphanedRaidParticipation? orphanedParticipation;
}
