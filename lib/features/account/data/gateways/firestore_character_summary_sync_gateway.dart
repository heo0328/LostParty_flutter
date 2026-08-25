import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/character_summary_sync_gateway.dart';

class FirestoreCharacterSummarySyncGateway
    implements CharacterSummarySyncGateway {
  const FirestoreCharacterSummarySyncGateway({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> updateSummaries(List<CharacterSummaryServerPatch> patches) async {
    if (patches.isEmpty) return;

    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null || authUid.isEmpty) {
      throw StateError('Signed-in Auth user is required.');
    }

    final binding = await _firestore.collection('authBindings').doc(authUid).get();
    final playerId = binding.data()?['playerId'];
    if (playerId is! String || playerId.isEmpty) {
      throw StateError('Player binding is required.');
    }

    await _firestore.runTransaction((transaction) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final patch in patches) {
        snapshots.add(
          await transaction.get(
            _firestore.collection('characters').doc(patch.serverCharacterId),
          ),
        );
      }

      final now = FieldValue.serverTimestamp();
      for (var index = 0; index < patches.length; index++) {
        final patch = patches[index];
        final snapshot = snapshots[index];
        if (!snapshot.exists) {
          throw StateError('Character ${patch.serverCharacterId} was not found.');
        }
        final data = snapshot.data();
        if (data?['ownerPlayerId'] != playerId) {
          throw StateError('Character ownership mismatch.');
        }
        if (data?['status'] != 'active') {
          throw StateError('Character is not active.');
        }

        final existingFetchedAt = data?['lastSummaryFetchedAt'];
        if (existingFetchedAt is Timestamp &&
            existingFetchedAt.toDate().isAfter(patch.fetchedAt)) {
          continue;
        }

        transaction.update(snapshot.reference, {
          'characterName': patch.characterName,
          'characterLevel': patch.characterLevel,
          'itemAvgLevel': patch.itemAvgLevel,
          'lastSummaryFetchedAt': Timestamp.fromDate(patch.fetchedAt.toUtc()),
          'updatedAt': now,
        });
      }
    });
  }
}
