/// 레이드 현황 `진행 중` 기본 필터 선택.
///
/// 공개 조건은 빈 상태를 허용하지 않는다. 일반 공개와 그룹 공개가 모두
/// 선택되면 `전체`와 같다. 레이드·난이도 집합이 비면 해당 차원은 전체 허용이다.
class RaidStatusFilterSelection {
  const RaidStatusFilterSelection({
    required this.includePublic,
    required this.includeGroup,
    this.raidIds = const {},
    this.difficultyIds = const {},
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

  bool get includeAllPublicScopes => includePublic && includeGroup;

  bool get isUnrestricted =>
      includeAllPublicScopes && raidIds.isEmpty && difficultyIds.isEmpty;

  RaidStatusFilterSelection copyWith({
    bool? includePublic,
    bool? includeGroup,
    Set<String>? raidIds,
    Set<String>? difficultyIds,
  }) => RaidStatusFilterSelection(
    includePublic: includePublic ?? this.includePublic,
    includeGroup: includeGroup ?? this.includeGroup,
    raidIds: raidIds ?? this.raidIds,
    difficultyIds: difficultyIds ?? this.difficultyIds,
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

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'includePublic': includePublic,
    'includeGroup': includeGroup,
    'raidIds': (raidIds.toList()..sort()),
    'difficultyIds': (difficultyIds.toList()..sort()),
  };

  /// 손상된 저장값은 전체 보기로 초기화한다.
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
    );
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return const {};
    return {
      for (final value in raw)
        if (value is String && value.trim().isNotEmpty) value,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RaidStatusFilterSelection &&
      includePublic == other.includePublic &&
      includeGroup == other.includeGroup &&
      _sameSet(raidIds, other.raidIds) &&
      _sameSet(difficultyIds, other.difficultyIds);

  @override
  int get hashCode => Object.hash(
    includePublic,
    includeGroup,
    Object.hashAll(raidIds.toList()..sort()),
    Object.hashAll(difficultyIds.toList()..sort()),
  );
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
