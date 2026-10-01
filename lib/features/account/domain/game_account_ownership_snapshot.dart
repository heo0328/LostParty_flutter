import 'game_account_ownership_transition.dart';

enum GameAccountOwnershipCondition { current, ownershipChanged, unknown }

class GameAccountOwnershipSnapshot {
  const GameAccountOwnershipSnapshot._(this.condition, this.revision);
  const GameAccountOwnershipSnapshot.unknown()
    : this._(GameAccountOwnershipCondition.unknown, null);

  factory GameAccountOwnershipSnapshot.inspect({
    required String playerId,
    required String gameAccountId,
    required Map<String, dynamic>? account,
    required Map<String, dynamic>? character,
  }) {
    if (account == null ||
        character == null ||
        account['status'] != 'active' ||
        character['status'] != 'active') {
      return const GameAccountOwnershipSnapshot.unknown();
    }
    try {
      final owner = account['ownerPlayerId'];
      if (owner is! String) return const GameAccountOwnershipSnapshot.unknown();
      final transition = GameAccountOwnershipTransition.fromAccount(
        account: account,
        nextOwnerPlayerId: owner,
      );
      transition.validateExistingCharacter(
        character: character,
        gameAccountId: gameAccountId,
      );
      return GameAccountOwnershipSnapshot._(
        owner == playerId
            ? GameAccountOwnershipCondition.current
            : GameAccountOwnershipCondition.ownershipChanged,
        transition.previousRevision,
      );
    } on FormatException {
      return const GameAccountOwnershipSnapshot.unknown();
    }
  }

  final GameAccountOwnershipCondition condition;
  final int? revision;

  GameAccountOwnershipCondition classifyParticipation(
    Map<String, dynamic> data,
  ) {
    if (condition != GameAccountOwnershipCondition.current) return condition;
    final previous = data.containsKey('ownershipRevision')
        ? data['ownershipRevision']
        : 0;
    if (previous is! int || previous < 0 || previous > revision!) {
      return GameAccountOwnershipCondition.unknown;
    }
    return previous == revision
        ? GameAccountOwnershipCondition.current
        : GameAccountOwnershipCondition.ownershipChanged;
  }
}
