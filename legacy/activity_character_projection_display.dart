import '../../../account/domain/entities/activity_character_projection.dart';
import '../entities/group_request_character.dart';

GroupRequestCharacter groupRequestCharacterFromProjection(
  ActivityCharacterProjection projection,
) {
  return GroupRequestCharacter(
    characterId: projection.characterId,
    ownerPlayerId: projection.playerId,
    characterName: projection.characterName,
    serverName: projection.serverName,
    characterClassName: projection.characterClassName,
    itemLevel: projection.itemLevel,
    combatPower: projection.combatPower,
  );
}
