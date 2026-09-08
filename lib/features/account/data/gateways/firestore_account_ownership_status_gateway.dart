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
    final ids = gameAccountIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) return const {};
    final binding = await _firestore
        .collection('authBindings')
        .doc(authUid)
        .get(const GetOptions(source: Source.server));
    final bindingData = binding.data();
    final playerId = bindingData?['playerId'];
    if (!binding.exists ||
        bindingData?['status'] != 'active' ||
        playerId is! String ||
        playerId.isEmpty) {
      return {for (final id in ids) id: 'serverMismatch'};
    }
    final player = await _firestore
        .collection('players')
        .doc(playerId)
        .get(const GetOptions(source: Source.server));
    if (!player.exists || player.data()?['status'] != 'active') {
      return {for (final id in ids) id: 'serverMismatch'};
    }
    final snapshots = await Future.wait(
      ids.map((id) async {
        final documents = await Future.wait([
          _firestore
              .collection('playerGameAccounts')
              .doc('${playerId}_$id')
              .get(const GetOptions(source: Source.server)),
          _firestore
              .collection('gameAccounts')
              .doc(id)
              .get(const GetOptions(source: Source.server)),
        ]);
        return (ownership: documents[0], account: documents[1]);
      }),
    );
    return {
      for (var index = 0; index < snapshots.length; index++)
        ids[index]: _statusFor(
          playerId: playerId,
          ownership: snapshots[index].ownership,
          account: snapshots[index].account,
        ),
    };
  }

  String _statusFor({
    required String playerId,
    required DocumentSnapshot<Map<String, dynamic>> ownership,
    required DocumentSnapshot<Map<String, dynamic>> account,
  }) {
    final ownershipStatus = ownership.data()?['status'];
    if (ownershipStatus == 'ownershipLost') return 'ownershipLost';
    final accountData = account.data();
    if (!ownership.exists ||
        ownershipStatus != 'active' ||
        !account.exists ||
        accountData?['status'] != 'active') {
      return 'serverMismatch';
    }
    return accountData?['ownerPlayerId'] == playerId
        ? 'active'
        : 'ownershipLost';
  }
}
