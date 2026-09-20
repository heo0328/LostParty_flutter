import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/party_application_cleanup_repository.dart';

class FirestorePartyApplicationCleanupRepository
    implements PartyApplicationCleanupRepository {
  const FirestorePartyApplicationCleanupRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<PartyApplicationCleanupResult> deleteOrphan({
    required String recruitmentId,
    required String applicantPlayerId,
  }) async {
    if (recruitmentId.isEmpty || applicantPlayerId.isEmpty) {
      return const PartyApplicationCleanupResult.failure(
        PartyApplicationCleanupFailure.invalidRequest,
      );
    }
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return const PartyApplicationCleanupResult.failure(
        PartyApplicationCleanupFailure.unauthenticated,
      );
    }
    try {
      final binding = await _firestore.collection('authBindings').doc(uid).get();
      final data = binding.data();
      if (data?['status'] != 'active' || data?['playerId'] != applicantPlayerId) {
        return const PartyApplicationCleanupResult.failure(
          PartyApplicationCleanupFailure.playerBindingMissing,
        );
      }
      await _firestore
          .collection('recruitments')
          .doc(recruitmentId)
          .collection('applications')
          .doc(applicantPlayerId)
          .delete();
      return const PartyApplicationCleanupResult.success();
    } on FirebaseException catch (error) {
      return PartyApplicationCleanupResult.failure(switch (error.code) {
        'permission-denied' => PartyApplicationCleanupFailure.notOrphaned,
        'unavailable' || 'deadline-exceeded' || 'aborted' =>
          PartyApplicationCleanupFailure.temporarilyUnavailable,
        _ => PartyApplicationCleanupFailure.unknown,
      });
    }
  }
}
