/// 그룹원이 읽을 수 있는 활동 Character 최소 표시값.
///
/// 소유권·인증 내부 필드(`gameAccountId`, `ownerPlayerId`, `status`)는 포함하지
/// 않는다. 문서 경로는 `players/{playerId}/activityCharacterProjections/{characterId}`다.
class ActivityCharacterProjection {
  const ActivityCharacterProjection({
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

  final String playerId;
  final String characterId;
  final String characterName;
  final String serverName;
  final String characterClassName;
  final int displayOrder;
  final bool isRepresentative;
  final double? itemLevel;
  final double? combatPower;
}
