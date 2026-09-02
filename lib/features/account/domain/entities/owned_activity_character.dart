class OwnedActivityCharacter {
  const OwnedActivityCharacter({
    required this.characterId,
    required this.gameAccountId,
    required this.ownerPlayerId,
    required this.status,
    required this.ownershipStatus,
    this.representativeCharacterId,
  });

  final String characterId;
  final String gameAccountId;
  final String ownerPlayerId;
  final String status;
  final String ownershipStatus;
  final String? representativeCharacterId;

  bool get isActiveCharacter => status == 'active';
  bool get isActiveOwnership => ownershipStatus == 'active';
}
