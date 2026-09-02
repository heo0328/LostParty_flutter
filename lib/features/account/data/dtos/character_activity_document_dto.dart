class CharacterActivityDocumentDto {
  const CharacterActivityDocumentDto({
    required this.schemaVersion,
    required this.playerId,
    required this.activityCharacterIds,
    required this.gameAccountIds,
  });

  final int schemaVersion;
  final String playerId;
  final List<String> activityCharacterIds;
  final List<String> gameAccountIds;

  factory CharacterActivityDocumentDto.fromMap(Map<String, dynamic> data) {
    return CharacterActivityDocumentDto(
      schemaVersion: _asInt(data['schemaVersion']),
      playerId: data['playerId'] as String,
      activityCharacterIds: _asStringList(data['activityCharacterIds']),
      gameAccountIds: _asStringList(data['gameAccountIds']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected int, got $value');
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) {
      throw FormatException('Expected list, got $value');
    }
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item,
    ];
  }
}
