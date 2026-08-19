class CharacterSummary {
  const CharacterSummary({
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    required this.itemLevel,
  });

  final String serverName;
  final String characterName;
  final int characterLevel;
  final String characterClassName;
  final double? itemLevel;
}
