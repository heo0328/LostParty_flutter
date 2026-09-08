import '../entities/activity_character_projection.dart';
import '../entities/save_activity_characters_command.dart';

abstract interface class ActivityCharactersRepository {
  Future<ActivityCharacters> load({required String playerId});

  Future<ActivityCharacters> save(SaveActivityCharactersCommand command);
}

/// 그룹원이 다른 Player의 활동 Character 최소 목록을 읽는다.
abstract interface class ActivityCharacterProjectionRepository {
  Future<List<ActivityCharacterProjection>> loadProjections({
    required String playerId,
  });
}
