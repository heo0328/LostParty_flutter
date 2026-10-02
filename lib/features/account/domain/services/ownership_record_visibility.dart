import '../game_account_ownership_snapshot.dart';

/// False means a proven old relationship; unknown authority is an error.
bool isCurrentOwnershipRecord({
  required String playerId,
  required int revision,
  required Map<String, dynamic>? character,
  required Map<String, dynamic>? account,
}) {
  final owner = character?['ownerPlayerId'];
  final accountId = character?['gameAccountId'];
  if (owner is! String || accountId is! String || revision < 0) {
    throw const FormatException('Unknown record ownership.');
  }
  final authority = GameAccountOwnershipSnapshot.inspect(
    playerId: owner,
    gameAccountId: accountId,
    character: character,
    account: account,
  );
  final condition = authority.classifyParticipation({
    'ownershipRevision': revision,
  });
  if (condition == GameAccountOwnershipCondition.unknown ||
      (condition == GameAccountOwnershipCondition.current &&
          owner != playerId)) {
    throw const FormatException('Inconsistent record ownership.');
  }
  return condition == GameAccountOwnershipCondition.current;
}
