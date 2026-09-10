/// 레이드 현황 `진행 중` 필터 선택.
///
/// 공개 조건은 빈 상태를 허용하지 않는다. 일반 공개와 그룹 공개가 모두
/// 선택되면 `전체`와 같다. 레이드·난이도·그룹·그룹원 집합이 비면 해당 차원은
/// 전체 허용이다. 선택한 그룹원의 Character 집합이 비면 그 사용자의 참가만
/// 요구한다.
class RaidStatusFilterSelection {
  const RaidStatusFilterSelection({
    required this.includePublic,
    required this.includeGroup,
    this.raidIds = const {},
    this.difficultyIds = const {},
    this.groupIds = const {},
    this.memberPlayerIds = const {},
    this.characterIdsByPlayer = const {},
    this.ownCharacterIds = const {},
  }) : assert(
         includePublic || includeGroup,
         '공개 조건은 일반 공개와 그룹 공개 중 하나 이상이어야 한다.',
       );

  /// 기본 진입: 전체·일반 공개·그룹 공개가 모두 선택된 상태.
  static const unrestricted = RaidStatusFilterSelection(
    includePublic: true,
    includeGroup: true,
  );

  /// `groupId`가 없는 일반 레이드.
  final bool includePublic;

  /// 현재 Player가 볼 수 있고 `groupId`가 있는 그룹 레이드.
  final bool includeGroup;

  /// 비어 있으면 모든 레이드 허용. 값이 있으면 차원 내부 OR.
  final Set<String> raidIds;

  /// 비어 있으면 모든 난이도 허용. 값이 있으면 차원 내부 OR.
  final Set<String> difficultyIds;

  /// 비어 있으면 그룹 ID 조건을 적용하지 않는다. 값이 있으면 차원 내부 OR.
  final Set<String> groupIds;

  /// 비어 있으면 그룹원 조건을 적용하지 않는다. 값이 있으면 사용자 사이 AND.
  final Set<String> memberPlayerIds;

  /// 선택한 그룹원별 Character. 키가 없거나 집합이 비면 그 사용자의 참가만 요구한다.
  /// 값이 있으면 해당 사용자 내부 OR.
  final Map<String, Set<String>> characterIdsByPlayer;

  /// 진행 중 전용. 현재 사용자의 Character 다중 선택.
  /// 비어 있으면 내 Character 조건을 적용하지 않는다. 값이 있으면 OR.
  final Set<String> ownCharacterIds;

  bool get includeAllPublicScopes => includePublic && includeGroup;

  /// 그룹·그룹원·Character 선택 UI와 판정은 그룹 공개만일 때만 쓴다.
  bool get isGroupPublicOnly => includeGroup && !includePublic;

  bool get isUnrestricted =>
      includeAllPublicScopes &&
      raidIds.isEmpty &&
      difficultyIds.isEmpty &&
      groupIds.isEmpty &&
      memberPlayerIds.isEmpty &&
      characterIdsByPlayer.isEmpty &&
      ownCharacterIds.isEmpty;

  int get selectedCharacterCount => characterIdsByPlayer.values.fold<int>(
    0,
    (count, ids) => count + ids.length,
  );

  RaidStatusFilterSelection copyWith({
    bool? includePublic,
    bool? includeGroup,
    Set<String>? raidIds,
    Set<String>? difficultyIds,
    Set<String>? groupIds,
    Set<String>? memberPlayerIds,
    Map<String, Set<String>>? characterIdsByPlayer,
    Set<String>? ownCharacterIds,
  }) => RaidStatusFilterSelection(
    includePublic: includePublic ?? this.includePublic,
    includeGroup: includeGroup ?? this.includeGroup,
    raidIds: raidIds ?? this.raidIds,
    difficultyIds: difficultyIds ?? this.difficultyIds,
    groupIds: groupIds ?? this.groupIds,
    memberPlayerIds: memberPlayerIds ?? this.memberPlayerIds,
    characterIdsByPlayer: characterIdsByPlayer ?? this.characterIdsByPlayer,
    ownCharacterIds: ownCharacterIds ?? this.ownCharacterIds,
  );

  /// `전체`는 파생 상태다. 선택하면 일반·그룹 공개를 함께 켠다.
  RaidStatusFilterSelection selectAllPublicScopes() =>
      copyWith(includePublic: true, includeGroup: true);

  /// 일반 공개를 끄면 그룹만, 둘 다 꺼지려 하면 전체로 복귀한다.
  RaidStatusFilterSelection togglePublic() {
    if (includePublic) {
      if (!includeGroup) return unrestricted;
      return copyWith(includePublic: false);
    }
    return copyWith(includePublic: true);
  }

  /// 그룹 공개를 끄면 일반만, 둘 다 꺼지려 하면 전체로 복귀한다.
  RaidStatusFilterSelection toggleGroup() {
    if (includeGroup) {
      if (!includePublic) return unrestricted;
      return copyWith(includeGroup: false);
    }
    return copyWith(includeGroup: true);
  }

  RaidStatusFilterSelection toggleRaid(String raidId) {
    final next = {...raidIds};
    if (!next.add(raidId)) {
      next.remove(raidId);
    }
    return copyWith(raidIds: next);
  }

  RaidStatusFilterSelection toggleDifficulty(String difficultyId) {
    final next = {...difficultyIds};
    if (!next.add(difficultyId)) {
      next.remove(difficultyId);
    }
    return copyWith(difficultyIds: next);
  }

  RaidStatusFilterSelection toggleGroupId(String groupId) {
    final next = {...groupIds};
    if (!next.add(groupId)) {
      next.remove(groupId);
    }
    return copyWith(groupIds: next);
  }

  /// 그룹원을 해제하면 그 사용자의 Character 선택도 함께 지운다.
  RaidStatusFilterSelection toggleMember(String playerId) {
    final nextMembers = {...memberPlayerIds};
    final nextCharacters = {
      for (final entry in characterIdsByPlayer.entries)
        entry.key: {...entry.value},
    };
    if (!nextMembers.add(playerId)) {
      nextMembers.remove(playerId);
      nextCharacters.remove(playerId);
    }
    return copyWith(
      memberPlayerIds: nextMembers,
      characterIdsByPlayer: nextCharacters,
    );
  }

  /// Character를 선택하면 부모 그룹원도 선택한다. 칩을 모두 해제해도 그룹원은 남긴다.
  RaidStatusFilterSelection toggleCharacter({
    required String playerId,
    required String characterId,
  }) {
    final nextMembers = {...memberPlayerIds, playerId};
    final nextCharacters = {
      for (final entry in characterIdsByPlayer.entries)
        entry.key: {...entry.value},
    };
    final current = {...?nextCharacters[playerId]};
    if (!current.add(characterId)) {
      current.remove(characterId);
    }
    if (current.isEmpty) {
      nextCharacters.remove(playerId);
    } else {
      nextCharacters[playerId] = current;
    }
    return copyWith(
      memberPlayerIds: nextMembers,
      characterIdsByPlayer: nextCharacters,
    );
  }

  /// 진행 중 전용 내 Character 칩. 그룹원 Character 선택과 독립이다.
  RaidStatusFilterSelection toggleOwnCharacter(String characterId) {
    final next = {...ownCharacterIds};
    if (!next.add(characterId)) {
      next.remove(characterId);
    }
    return copyWith(ownCharacterIds: next);
  }

  /// 전체 또는 일반 공개가 포함되면 숨긴 그룹 관련 선택을 제거한다.
  /// 내 Character 선택은 그룹 공개 여부와 무관하게 유지한다.
  RaidStatusFilterSelection withoutHiddenGroupFilters() {
    if (isGroupPublicOnly) return this;
    if (groupIds.isEmpty &&
        memberPlayerIds.isEmpty &&
        characterIdsByPlayer.isEmpty) {
      return this;
    }
    return copyWith(
      groupIds: const {},
      memberPlayerIds: const {},
      characterIdsByPlayer: const {},
    );
  }

  /// 카탈로그에 없는 레이드·난이도 선택은 제거하고 나머지는 유지한다.
  RaidStatusFilterSelection prune({
    required Set<String> catalogRaidIds,
    required Set<String> catalogDifficultyIds,
  }) {
    final nextRaids = raidIds.intersection(catalogRaidIds);
    final nextDifficulties = difficultyIds.intersection(catalogDifficultyIds);
    if (nextRaids.length == raidIds.length &&
        nextDifficulties.length == difficultyIds.length) {
      return this;
    }
    return copyWith(raidIds: nextRaids, difficultyIds: nextDifficulties);
  }

  /// 가입 그룹·그룹원·Character 후보와 대조한다.
  ///
  /// 저장된 그룹 선택이 하나라도 있었는데 모두 무효면 전체 보기로 초기화한다.
  /// 일부 그룹만 유효하면 그 선택과 남은 그룹원·Character를 유지한다.
  RaidStatusFilterSelection pruneMembership({
    required Set<String> joinedGroupIds,
    required Set<String> candidateMemberPlayerIds,
    Map<String, Set<String>> candidateCharacterIdsByPlayer = const {},
  }) {
    var nextGroupIds = groupIds;
    if (groupIds.isNotEmpty) {
      nextGroupIds = groupIds.intersection(joinedGroupIds);
      if (nextGroupIds.isEmpty) return unrestricted;
    }
    final nextMembers = memberPlayerIds.intersection(candidateMemberPlayerIds);
    final nextCharacters = <String, Set<String>>{};
    for (final playerId in nextMembers) {
      final selected = characterIdsByPlayer[playerId];
      if (selected == null || selected.isEmpty) continue;
      final allowed =
          candidateCharacterIdsByPlayer[playerId] ?? const <String>{};
      final kept = selected.intersection(allowed);
      if (kept.isNotEmpty) {
        nextCharacters[playerId] = kept;
      }
    }
    if (nextGroupIds.length == groupIds.length &&
        nextMembers.length == memberPlayerIds.length &&
        _sameStringSetMap(nextCharacters, characterIdsByPlayer)) {
      return this;
    }
    return copyWith(
      groupIds: nextGroupIds,
      memberPlayerIds: nextMembers,
      characterIdsByPlayer: nextCharacters,
    );
  }

  Map<String, Object?> toJson() {
    final characterJson = <String, List<String>>{};
    final playerIds = characterIdsByPlayer.keys.toList()..sort();
    for (final playerId in playerIds) {
      characterJson[playerId] = (characterIdsByPlayer[playerId]!.toList()
        ..sort());
    }
    return {
      'schemaVersion': 2,
      'includePublic': includePublic,
      'includeGroup': includeGroup,
      'raidIds': (raidIds.toList()..sort()),
      'difficultyIds': (difficultyIds.toList()..sort()),
      'groupIds': (groupIds.toList()..sort()),
      'memberPlayerIds': (memberPlayerIds.toList()..sort()),
      'characterIdsByPlayer': characterJson,
      'ownCharacterIds': (ownCharacterIds.toList()..sort()),
    };
  }

  /// 손상된 저장값은 전체 보기로 초기화한다. D2 JSON은 그룹원 필드 없이 복원한다.
  /// schemaVersion 1은 `ownCharacterIds` 없이 복원한다.
  static RaidStatusFilterSelection fromJson(Object? raw) {
    if (raw is! Map) return unrestricted;
    final includePublic = raw['includePublic'];
    final includeGroup = raw['includeGroup'];
    if (includePublic is! bool || includeGroup is! bool) {
      return unrestricted;
    }
    if (!includePublic && !includeGroup) return unrestricted;
    return RaidStatusFilterSelection(
      includePublic: includePublic,
      includeGroup: includeGroup,
      raidIds: _stringSet(raw['raidIds']),
      difficultyIds: _stringSet(raw['difficultyIds']),
      groupIds: _stringSet(raw['groupIds']),
      memberPlayerIds: _stringSet(raw['memberPlayerIds']),
      characterIdsByPlayer: _stringSetMap(raw['characterIdsByPlayer']),
      ownCharacterIds: _stringSet(raw['ownCharacterIds']),
    ).withoutHiddenGroupFilters();
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return const {};
    return {
      for (final value in raw)
        if (value is String && value.trim().isNotEmpty) value,
    };
  }

  static Map<String, Set<String>> _stringSetMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, Set<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) continue;
      result[key] = _stringSet(entry.value);
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is RaidStatusFilterSelection &&
      includePublic == other.includePublic &&
      includeGroup == other.includeGroup &&
      _sameSet(raidIds, other.raidIds) &&
      _sameSet(difficultyIds, other.difficultyIds) &&
      _sameSet(groupIds, other.groupIds) &&
      _sameSet(memberPlayerIds, other.memberPlayerIds) &&
      _sameStringSetMap(characterIdsByPlayer, other.characterIdsByPlayer) &&
      _sameSet(ownCharacterIds, other.ownCharacterIds);

  @override
  int get hashCode => Object.hash(
    includePublic,
    includeGroup,
    Object.hashAll(raidIds.toList()..sort()),
    Object.hashAll(difficultyIds.toList()..sort()),
    Object.hashAll(groupIds.toList()..sort()),
    Object.hashAll(memberPlayerIds.toList()..sort()),
    Object.hashAll(
      (characterIdsByPlayer.keys.toList()..sort()).expand(
        (playerId) => [
          playerId,
          Object.hashAll(characterIdsByPlayer[playerId]!.toList()..sort()),
        ],
      ),
    ),
    Object.hashAll(ownCharacterIds.toList()..sort()),
  );
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameStringSetMap(
  Map<String, Set<String>> left,
  Map<String, Set<String>> right,
) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null || !_sameSet(entry.value, other)) return false;
  }
  return true;
}
