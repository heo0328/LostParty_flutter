class SaveActivityCharactersCommand {
  const SaveActivityCharactersCommand({
    required this.activityCharacterIds,
    required this.ownedCharacterIds,
    this.orderedActivityCharacterIds = const [],
  });

  /// 저장할 활동 Character의 최종 전체 집합.
  final Set<String> activityCharacterIds;

  /// 이번 저장에서 소유권을 검증할 인증 Character 전체.
  /// 본·부계정 서버 Character ID를 빠짐없이 넣는다.
  final Set<String> ownedCharacterIds;

  /// 활동 Character 표시 순서. 비어 있으면 ID 정렬을 사용한다.
  /// 값이 있으면 [activityCharacterIds]와 같은 집합이어야 한다.
  final List<String> orderedActivityCharacterIds;
}

class ActivityCharacters {
  const ActivityCharacters({
    required this.playerId,
    required this.characterIds,
  });

  final String playerId;
  final Set<String> characterIds;

  bool get isEmpty => characterIds.isEmpty;
}

enum ActivityCharactersSaveFailure {
  unauthenticated,
  emptySelection,
  invalidCharacterId,
  notOwned,
  inactiveCharacter,
  inactiveOwnership,
  representativeRequired,
  incompleteDisplay,
  permissionDenied,
  unavailable,
}

class ActivityCharactersSaveException implements Exception {
  const ActivityCharactersSaveException(this.failure, this.message);

  final ActivityCharactersSaveFailure failure;
  final String message;

  @override
  String toString() => message;
}
