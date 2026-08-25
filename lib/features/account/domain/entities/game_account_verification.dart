class GameAccountVerificationChallenge {
  const GameAccountVerificationChallenge({
    required this.challengeId,
    required this.characterName,
    required this.requiredUnequippedSlots,
    required this.expiresAt,
  });

  final String challengeId;
  final String characterName;
  final List<String> requiredUnequippedSlots;
  final DateTime expiresAt;
}

class GameAccountVerificationResult {
  const GameAccountVerificationResult({
    required this.status,
    this.serverGameAccountId,
    this.serverCharacters = const [],
    this.slots = const [],
  });

  final String status;
  final String? serverGameAccountId;
  final List<VerifiedServerCharacter> serverCharacters;
  final List<String> slots;
}

class VerifiedServerCharacter {
  const VerifiedServerCharacter({
    required this.serverName,
    required this.characterName,
    required this.serverCharacterId,
  });

  final String serverName;
  final String characterName;
  final String serverCharacterId;
}
