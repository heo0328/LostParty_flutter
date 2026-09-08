class ActivityCharacterProjectionDto {
  const ActivityCharacterProjectionDto({
    required this.schemaVersion,
    required this.playerId,
    required this.characterId,
    required this.characterName,
    required this.serverName,
    required this.characterClassName,
    required this.displayOrder,
    required this.isRepresentative,
    this.itemLevel,
    this.combatPower,
  });

  final int schemaVersion;
  final String playerId;
  final String characterId;
  final String characterName;
  final String serverName;
  final String characterClassName;
  final int displayOrder;
  final bool isRepresentative;
  final double? itemLevel;
  final double? combatPower;

  factory ActivityCharacterProjectionDto.fromMap(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    final characterId = data['characterId'] as String;
    if (characterId != documentId) {
      throw const FormatException(
        'Activity character projection path mismatch.',
      );
    }
    return ActivityCharacterProjectionDto(
      schemaVersion: _asInt(data['schemaVersion']),
      playerId: data['playerId'] as String,
      characterId: characterId,
      characterName: data['characterName'] as String,
      serverName: data['serverName'] as String,
      characterClassName: data['characterClassName'] as String,
      displayOrder: _asInt(data['displayOrder']),
      isRepresentative: data['isRepresentative'] as bool,
      itemLevel: _asOptionalDouble(data['itemLevel']),
      combatPower: _asOptionalDouble(data['combatPower']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected int, got $value');
  }

  static double? _asOptionalDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw FormatException('Expected number, got $value');
  }
}
