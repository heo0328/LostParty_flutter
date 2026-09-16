import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/active_raid_assignment_repository.dart';
import '../../domain/services/party_create_occupancy_gate.dart';

class FirestoreActiveRaidAssignmentLookup
    implements ActiveRaidAssignmentLookup {
  const FirestoreActiveRaidAssignmentLookup({
    required FirebaseFirestore firestore,
    this.clock = DateTime.now,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final DateTime Function() clock;

  @override
  Future<bool> blocksCandidate({
    required String playerId,
    required String characterId,
    required String raidId,
    required String cycleKey,
  }) async {
    final document = await _firestore
        .collection('players')
        .doc(playerId)
        .collection('raidStates')
        .doc('${characterId}_$raidId')
        .get();
    if (!document.exists) return false;
    final state = document.data();
    if (state?['status'] == 'completed') {
      return state?['cycleKey'] == cycleKey;
    }
    if (state?['status'] != 'active') return true;
    final recruitmentId = state?['recruitmentId'];
    if (recruitmentId is! String || recruitmentId.isEmpty) return true;
    final recruitment = await _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .get();
    final recruitmentData = recruitment.data();
    final decision = PartyCreateOccupancyGate.decide(
      newRecruitmentId: 'candidate-check',
      playerId: playerId,
      newRecruitmentExists: false,
      newRecruitmentLeaderId: null,
      assignmentExists: true,
      assignmentRecruitmentId: recruitmentId,
      assignmentCycleKey: state?['cycleKey'] as String?,
      assignedRecruitmentExists: recruitment.exists,
      assignedRecruitmentStatus: recruitmentData?['status'] as String?,
      assignedRecruitmentCycleKey:
          recruitmentData?['currentCycleKey'] as String?,
      assignedRecruitmentContinuesTogether:
          recruitmentData?['continueTogether'] == true,
      assignedRecruitmentCycleEndsAt:
          (recruitmentData?['cycleEndsAt'] as Timestamp?)?.toDate(),
      newCycleKey: cycleKey,
      now: clock(),
    );
    return decision != PartyCreateOccupancyDecision.proceed &&
        decision != PartyCreateOccupancyDecision.replaceStaleAssignment;
  }
}
