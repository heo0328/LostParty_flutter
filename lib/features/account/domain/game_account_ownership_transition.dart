/// An ownership generation changes only when a different Player takes ownership.
/// Missing generations are legacy zero; malformed data must not be repaired by
/// authenticating a roster, because that could revive an old participation.
class GameAccountOwnershipTransition {
  GameAccountOwnershipTransition._({
    required this.previousOwnerPlayerId,
    required this.previousRevision,
    required this.nextRevision,
  });

  factory GameAccountOwnershipTransition.fromAccount({
    required Map<String, dynamic>? account,
    required String nextOwnerPlayerId,
  }) {
    if (nextOwnerPlayerId.isEmpty) {
      throw const FormatException('Missing new roster owner.');
    }
    if (account == null) {
      return GameAccountOwnershipTransition._(
        previousOwnerPlayerId: null,
        previousRevision: 0,
        nextRevision: 1,
      );
    }
    final owner = account['ownerPlayerId'];
    if (owner is! String || owner.isEmpty) {
      throw const FormatException('Invalid existing roster owner.');
    }
    final revision = _readRevision(account);
    final changed = owner != nextOwnerPlayerId;
    if (changed && revision == _maxRevision) {
      throw const FormatException('Ownership revision exhausted.');
    }
    return GameAccountOwnershipTransition._(
      previousOwnerPlayerId: owner,
      previousRevision: revision,
      nextRevision: changed ? revision + 1 : revision,
    );
  }

  // Also exactly representable in the web client.
  static const _maxRevision = 9007199254740991;
  final String? previousOwnerPlayerId;
  final int previousRevision;
  final int nextRevision;

  void validateExistingCharacter({
    required Map<String, dynamic>? character,
    required String gameAccountId,
  }) {
    if (character == null) return;
    if (previousOwnerPlayerId == null ||
        character['gameAccountId'] != gameAccountId ||
        character['ownerPlayerId'] != previousOwnerPlayerId ||
        _readRevision(character) != previousRevision) {
      throw const FormatException('Character ownership does not match roster.');
    }
  }

  static int _readRevision(Map<String, dynamic> data) {
    final value = data.containsKey('ownershipRevision')
        ? data['ownershipRevision']
        : 0;
    if (value is! int || value < 0 || value > _maxRevision) {
      throw const FormatException('Invalid ownership revision.');
    }
    return value;
  }
}
