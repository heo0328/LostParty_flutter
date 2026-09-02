import '../entities/save_activity_characters_command.dart';

abstract interface class ActivityCharactersRepository {
  Future<ActivityCharacters> load({required String playerId});

  Future<ActivityCharacters> save(SaveActivityCharactersCommand command);
}
