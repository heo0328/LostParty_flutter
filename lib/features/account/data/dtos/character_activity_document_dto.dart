class CharacterActivityDocumentDto {
  const CharacterActivityDocumentDto({
    required this.schemaVersion,
    required this.playerId,
    required this.characterId,
    required this.gameAccountId,
  });

  final int schemaVersion;
  final String playerId;
  final String characterId;
  final String gameAccountId;

  factory CharacterActivityDocumentDto.fromMap(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    final characterId = data['characterId'] as String;
    if (characterId != documentId) {
      throw const FormatException('Character activity path mismatch.');
    }
    return CharacterActivityDocumentDto(
      schemaVersion: _asInt(data['schemaVersion']),
      playerId: data['playerId'] as String,
      characterId: characterId,
      gameAccountId: data['gameAccountId'] as String,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected int, got $value');
  }
}
