import '../../domain/entities/owned_activity_character.dart';
import '../../domain/entities/save_activity_characters_command.dart';
import '../../domain/policies/activity_characters_policy.dart';

class CharacterActivityWritePlan {
  const CharacterActivityWritePlan({
    required this.playerId,
    required this.activityCharacterIds,
    required this.documentsByCharacterId,
    required this.characterIdsToRemove,
  });

  final String playerId;
  final List<String> activityCharacterIds;
  final Map<String, Map<String, Object?>> documentsByCharacterId;
  final List<String> characterIdsToRemove;

  static const schemaVersion = 1;

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
    final activityCharacterIds = (command.activityCharacterIds.toList()
      ..sort());
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

    return CharacterActivityWritePlan(
      playerId: playerId,
      activityCharacterIds: activityCharacterIds,
      documentsByCharacterId: documentsByCharacterId,
      characterIdsToRemove: characterIdsToRemove,
    );
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
        '현재 Player가 active 소유한 캐릭터만 선택할 수 있습니다.',
      ActivityCharactersSaveFailure.inactiveCharacter =>
        '활성 캐릭터만 앱에서 사용할 수 있습니다.',
      ActivityCharactersSaveFailure.inactiveOwnership =>
        '활성 인증 계정의 캐릭터만 앱에서 사용할 수 있습니다.',
      ActivityCharactersSaveFailure.representativeRequired =>
        '대표 캐릭터는 앱에서 사용할 캐릭터에 포함되어야 합니다.',
    };
  }
}
