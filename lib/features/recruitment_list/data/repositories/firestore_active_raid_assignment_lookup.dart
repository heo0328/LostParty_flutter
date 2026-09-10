import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/active_raid_assignment_repository.dart';
import '../../domain/services/legacy_ended_assignment_replacement_policy.dart';

class FirestoreActiveRaidAssignmentLookup
    implements ActiveRaidAssignmentLookup {
  const FirestoreActiveRaidAssignmentLookup({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

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
        .collection('activeRaidAssignments')
        .doc('${characterId}_$raidId')
        .get();
    if (!document.exists) return false;
    final assignment = document.data();
    if (assignment?['cycleKey'] == cycleKey) return true;
    final recruitmentId = assignment?['recruitmentId'];
    if (recruitmentId is! String || recruitmentId.isEmpty) return true;
    final recruitment = await _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .get();
    final recruitmentData = recruitment.data();
    final canReplace = const LegacyEndedAssignmentReplacementPolicy()
        .canReplace(
          assignmentExists: true,
          assignmentRecruitmentId: recruitmentId,
          assignmentCycleKey: assignment?['cycleKey'] as String?,
          assignmentRaidId: assignment?['raidId'] as String?,
          assignedRecruitmentExists: recruitment.exists,
          assignedRecruitmentStatus: recruitmentData?['status'] as String?,
          assignedRecruitmentCycleStatus:
              recruitmentData?['currentCycleStatus'] as String?,
          assignedRecruitmentCycleKey:
              recruitmentData?['currentCycleKey'] as String?,
          assignedRecruitmentContinuesTogether:
              recruitmentData?['continueTogether'] as bool?,
          newRecruitmentId: 'candidate-check',
          newCycleKey: cycleKey,
          newRaidId: raidId,
        );
    return !canReplace;
  }
}
