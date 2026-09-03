class OwnedActivityCharacter {
  const OwnedActivityCharacter({
    required this.characterId,
    required this.gameAccountId,
    required this.ownerPlayerId,
    required this.status,
    required this.ownershipStatus,
    this.representativeCharacterId,
    this.characterName = '',
    this.serverName = '',
    this.characterClassName = '',
    this.itemLevel,
    this.combatPower,
  });

  final String characterId;
  final String gameAccountId;
  final String ownerPlayerId;
  final String status;
  final String ownershipStatus;
  final String? representativeCharacterId;
  final String characterName;
  final String serverName;
  final String characterClassName;
  final double? itemLevel;
  final double? combatPower;

  bool get isActiveCharacter => status == 'active';
  bool get isActiveOwnership => ownershipStatus == 'active';
  bool get hasDisplayFields =>
      characterName.isNotEmpty &&
      serverName.isNotEmpty &&
      characterClassName.isNotEmpty;

  bool get isAccountRepresentative =>
      representativeCharacterId != null &&
      representativeCharacterId!.isNotEmpty &&
      representativeCharacterId == characterId;
}
