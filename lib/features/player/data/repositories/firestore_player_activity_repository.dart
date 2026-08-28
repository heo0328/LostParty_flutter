import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/player_activity_repository.dart';

class FirestorePlayerActivityRepository implements PlayerActivityRepository {
  FirestorePlayerActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> recordAppLaunch({required String playerId}) {
    return _firestore.collection('players').doc(playerId).update({
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }
}
