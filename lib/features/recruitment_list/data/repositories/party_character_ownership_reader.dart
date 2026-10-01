import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../account/domain/game_account_ownership_snapshot.dart';
export '../../../account/domain/game_account_ownership_snapshot.dart';

class PartyCharacterOwnershipReader {
  const PartyCharacterOwnershipReader._();

  static Future<GameAccountOwnershipSnapshot> read({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required String playerId,
    required Map<String, dynamic>? character,
  }) async {
    final gameAccountId = character?['gameAccountId'];
    if (gameAccountId is! String || gameAccountId.isEmpty) {
      return const GameAccountOwnershipSnapshot.unknown();
    }
    final account = await transaction.get(
      firestore.collection('gameAccounts').doc(gameAccountId),
    );
    return GameAccountOwnershipSnapshot.inspect(
      playerId: playerId,
      gameAccountId: gameAccountId,
      account: account.data(),
      character: character,
    );
  }
}
