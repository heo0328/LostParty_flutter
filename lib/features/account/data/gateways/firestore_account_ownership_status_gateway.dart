import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/account_ownership_status_gateway.dart';

class FirestoreAccountOwnershipStatusGateway
    implements AccountOwnershipStatusGateway {
  const FirestoreAccountOwnershipStatusGateway({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<Map<String, String>> loadStatuses(
    Iterable<String> gameAccountIds,
  ) async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) return const {};
    final binding = await _firestore
        .collection('authBindings')
        .doc(authUid)
        .get();
    final playerId = binding.data()?['playerId'];
    if (playerId is! String || playerId.isEmpty) return const {};
    final ids = gameAccountIds.toSet().toList(growable: false);
    final snapshots = await Future.wait(
      ids.map(
        (id) => _firestore
            .collection('playerGameAccounts')
            .doc('${playerId}_$id')
            .get(),
      ),
    );
    return {
      for (var index = 0; index < snapshots.length; index++)
        if (snapshots[index].data()?['status'] case final String status)
          ids.elementAt(index): status,
    };
  }
}
