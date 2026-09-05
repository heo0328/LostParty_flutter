import '../entities/local_game_account.dart';
import '../repositories/activity_characters_repository.dart';

Future<Set<String>?> loadActivityCharacterIds({
  required ActivityCharactersRepository? repository,
  required String? playerId,
}) async {
  if (repository == null || playerId == null || playerId.isEmpty) {
    return null;
  }
  final loaded = await repository.load(playerId: playerId);
  // 빈 선택은 저장 정책에서 허용하지 않는다. 따라서 문서가 하나도 없으면
  // 사용자가 모두 해제한 상태가 아니라 신규/복구 Player의 미초기화 상태다.
  // 기존 인증 Character fallback을 사용해 생성·신청 흐름을 막지 않는다.
  return loaded.characterIds.isEmpty ? null : loaded.characterIds;
}

Iterable<LocalAccountCharacter> charactersMatchingActivity(
  LocalGameAccount account,
  Set<String>? activityCharacterIds, {
  Iterable<LocalAccountCharacter>? fallback,
}) {
  if (activityCharacterIds == null) {
    return fallback ?? account.characters;
  }
  return account.characters.where((character) {
    final serverId = character.serverCharacterId;
    return !character.isRosterMissing &&
        serverId != null &&
        activityCharacterIds.contains(serverId);
  });
}
