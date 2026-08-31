import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/character_combat_power_sync_gateway.dart';

class FirestoreCharacterCombatPowerSyncGateway
    implements CharacterCombatPowerSyncGateway {
  const FirestoreCharacterCombatPowerSyncGateway({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> updateCombatPowers(
    Map<String, double> powersByCharacterId,
  ) async {
    if (powersByCharacterId.isEmpty) return;
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) throw StateError('Signed-in user required.');
    // 캐릭터별 작은 Transaction: 계정 수에 따른 읽기/쓰기 한도 초과를 피한다.
    // 일부 실패 시 호출자가 실패를 표시하고 다음 진입에서 재시도한다.
    for (final entry in powersByCharacterId.entries) {
      if (entry.key.isEmpty ||
          entry.key.contains('/') ||
          !entry.value.isFinite ||
          entry.value < 0) {
        throw ArgumentError('Invalid character display power.');
      }
      await _firestore.runTransaction<void>((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(uid),
        );
        final playerId = binding.data()?['playerId'];
        if (binding.data()?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          throw StateError('Active player binding required.');
        }
        final player = await transaction.get(
          _firestore.collection('players').doc(playerId),
        );
        if (player.data()?['status'] != 'active') {
          throw StateError('Active player required.');
        }
        final ref = _firestore.collection('characters').doc(entry.key);
        final character = await transaction.get(ref);
        final data = character.data();
        final accountId = data?['gameAccountId'];
        if (data?['status'] != 'active' ||
            data?['ownerPlayerId'] != playerId ||
            accountId is! String ||
            accountId.isEmpty) {
          throw StateError('Active character ownership required.');
        }
        final ownership = await transaction.get(
          _firestore
              .collection('playerGameAccounts')
              .doc('${playerId}_$accountId'),
        );
        if (ownership.data()?['status'] != 'active') {
          throw StateError('Active account ownership required.');
        }
        if (data?['combatPower'] == entry.value) return;
        transaction.update(ref, {
          'combatPower': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }
}
