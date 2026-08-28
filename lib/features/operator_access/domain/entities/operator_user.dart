class OperatorUserSummary {
  const OperatorUserSummary({
    required this.playerId,
    required this.status,
    required this.createdAt,
    required this.lastSeenAt,
    required this.hasVerifiedGameAccount,
    this.representativeCharacterName,
  });

  final String playerId;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final bool hasVerifiedGameAccount;
  final String? representativeCharacterName;

  String get displayId {
    final compact = playerId.replaceAll('-', '').toUpperCase();
    final suffix = compact.length <= 6
        ? compact
        : compact.substring(compact.length - 6);
    return 'LP-$suffix';
  }
}

class OperatorGameAccountSummary {
  const OperatorGameAccountSummary({
    required this.gameAccountId,
    required this.status,
    required this.ownershipStatus,
    required this.lookupCharacterName,
    required this.characters,
    this.representativeCharacterId,
  });

  final String gameAccountId;
  final String status;
  final String ownershipStatus;
  final String? lookupCharacterName;
  final List<OperatorCharacterSummary> characters;
  final String? representativeCharacterId;

  OperatorCharacterSummary? get representativeCharacter {
    final id = representativeCharacterId;
    if (id == null) return null;
    return characters
        .where((character) => character.characterId == id)
        .firstOrNull;
  }
}

class OperatorCharacterSummary {
  const OperatorCharacterSummary({
    required this.characterId,
    required this.characterName,
    required this.serverName,
    required this.className,
    required this.status,
  });

  final String characterId;
  final String characterName;
  final String serverName;
  final String className;
  final String status;
}

class OperatorUserDetail {
  const OperatorUserDetail({required this.user, required this.gameAccounts});

  final OperatorUserSummary user;
  final List<OperatorGameAccountSummary> gameAccounts;
}
