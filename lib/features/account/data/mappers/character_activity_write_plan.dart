import '../../domain/entities/owned_activity_character.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/policies/activity_characters_policy.dart';

class CharacterActivityWritePlan {
  const CharacterActivityWritePlan({
    required this.playerId,
    required this.activityCharacterIds,
    required this.documentsByCharacterId,
    required this.projectionDocumentsByCharacterId,
    required this.characterIdsToRemove,
  });

  final String playerId;
  final List<String> activityCharacterIds;
  final Map<String, Map<String, Object?>> documentsByCharacterId;
  final Map<String, Map<String, Object?>> projectionDocumentsByCharacterId;
  final List<String> characterIdsToRemove;

  static const schemaVersion = 1;
  static const projectionSchemaVersion = 1;

  factory CharacterActivityWritePlan.fromValidated({
    required String playerId,
    required SaveActivityCharactersCommand command,
    required List<OwnedActivityCharacter> ownedCharacters,
    required Object serverTimestamp,
    ActivityCharactersPolicy policy = const ActivityCharactersPolicy(),
  }) {
    final failure = policy.validate(
      playerId: playerId,
      command: command,
      ownedCharacters: ownedCharacters,
    );
    if (failure != null) {
      throw ActivityCharactersSaveException(failure, _message(failure));
    }

    final byId = {
      for (final character in ownedCharacters) character.characterId: character,
    };
    final activityCharacterIds = _orderedActivityIds(command);
    final ownedIds = command.ownedCharacterIds.toSet();
    final characterIdsToRemove =
        (ownedIds.difference(command.activityCharacterIds).toList()..sort());
    final documentsByCharacterId = <String, Map<String, Object?>>{
      for (final characterId in activityCharacterIds)
        characterId: {
          'schemaVersion': schemaVersion,
          'playerId': playerId,
          'characterId': characterId,
          'gameAccountId': byId[characterId]!.gameAccountId,
          'updatedAt': serverTimestamp,
        },
    };
    final projectionDocumentsByCharacterId = <String, Map<String, Object?>>{
      for (var index = 0; index < activityCharacterIds.length; index++)
        activityCharacterIds[index]: _projectionDocument(
          playerId: playerId,
          character: byId[activityCharacterIds[index]]!,
          displayOrder: index,
          serverTimestamp: serverTimestamp,
        ),
    };

    return CharacterActivityWritePlan(
      playerId: playerId,
      activityCharacterIds: activityCharacterIds,
      documentsByCharacterId: documentsByCharacterId,
      projectionDocumentsByCharacterId: projectionDocumentsByCharacterId,
      characterIdsToRemove: characterIdsToRemove,
    );
  }

  static List<String> _orderedActivityIds(
    SaveActivityCharactersCommand command,
  ) {
    if (command.orderedActivityCharacterIds.isNotEmpty) {
      return List<String>.of(command.orderedActivityCharacterIds);
    }
    return command.activityCharacterIds.toList()..sort();
  }

  static Map<String, Object?> _projectionDocument({
    required String playerId,
    required OwnedActivityCharacter character,
    required int displayOrder,
    required Object serverTimestamp,
  }) {
    return {
      'schemaVersion': projectionSchemaVersion,
      'playerId': playerId,
      'characterId': character.characterId,
      'characterName': character.characterName,
      'serverName': character.serverName,
      'characterClassName': character.characterClassName,
      'itemLevel': character.itemLevel,
      'combatPower': character.combatPower,
      'displayOrder': displayOrder,
      'isRepresentative': character.isAccountRepresentative,
      'updatedAt': serverTimestamp,
    };
  }

  static String _message(ActivityCharactersSaveFailure failure) {
    return switch (failure) {
      ActivityCharactersSaveFailure.unauthenticated =>
        '로그인한 사용자만 활동 캐릭터를 저장할 수 있습니다.',
      ActivityCharactersSaveFailure.emptySelection =>
        '앱에서 사용할 캐릭터를 최소 1명 선택해 주세요.',
      ActivityCharactersSaveFailure.invalidCharacterId =>
        '활동 캐릭터 ID가 올바르지 않습니다.',
      ActivityCharactersSaveFailure.notOwned =>
        '현재 사용자가 소유한 활성 캐릭터만 선택할 수 있습니다.',
      ActivityCharactersSaveFailure.inactiveCharacter =>
        '활성 캐릭터만 앱에서 사용할 수 있습니다.',
      ActivityCharactersSaveFailure.inactiveOwnership =>
        '활성 인증 계정의 캐릭터만 앱에서 사용할 수 있습니다.',
      ActivityCharactersSaveFailure.representativeRequired =>
        '대표 캐릭터는 앱에서 사용할 캐릭터에 포함되어야 합니다.',
      ActivityCharactersSaveFailure.incompleteDisplay =>
        '캐릭터 표시 정보가 부족합니다. 내 계정에서 정보를 새로고침한 뒤 다시 저장해 주세요.',
      ActivityCharactersSaveFailure.permissionDenied =>
        '캐릭터 활동 설정을 저장할 권한이 없습니다. 로그인과 캐릭터 소유 상태를 다시 확인해 주세요.',
      ActivityCharactersSaveFailure.unavailable =>
        '서버에 연결하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
    };
  }
}
