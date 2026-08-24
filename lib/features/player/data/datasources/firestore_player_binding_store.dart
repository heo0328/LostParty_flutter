import 'package:cloud_firestore/cloud_firestore.dart';

import 'player_binding_store.dart';

class FirestorePlayerBindingStore implements PlayerBindingStore {
  FirestorePlayerBindingStore(this._firestore);

  static const schemaVersion = 1;
  static const activeStatus = 'active';

  final FirebaseFirestore _firestore;

  @override
  Future<String> getOrCreateActivePlayerId({required String authUid}) {
    final bindingRef = _firestore.collection('authBindings').doc(authUid);

    return _firestore.runTransaction((transaction) async {
      final binding = await transaction.get(bindingRef);
      if (binding.exists) {
        final playerId = _activePlayerId(binding.data());
        final player = await transaction.get(
          _firestore.collection('players').doc(playerId),
        );
        _requireActivePlayer(player.data());
        return playerId;
      }

      final playerRef = _firestore.collection('players').doc();
      final now = FieldValue.serverTimestamp();
      transaction.set(playerRef, {
        'schemaVersion': schemaVersion,
        'status': activeStatus,
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.set(bindingRef, {
        'schemaVersion': schemaVersion,
        'playerId': playerRef.id,
        'status': activeStatus,
        'linkedAt': now,
        'updatedAt': now,
      });
      return playerRef.id;
    });
  }

  String _activePlayerId(Map<String, dynamic>? data) {
    if (data == null ||
        data['schemaVersion'] != schemaVersion ||
        data['status'] != activeStatus ||
        data['playerId'] is! String ||
        (data['playerId'] as String).trim().isEmpty) {
      throw const FormatException('Invalid active auth binding.');
    }
    return data['playerId'] as String;
  }

  void _requireActivePlayer(Map<String, dynamic>? data) {
    if (data == null ||
        data['schemaVersion'] != schemaVersion ||
        data['status'] != activeStatus) {
      throw const FormatException('Invalid active player.');
    }
  }
}
