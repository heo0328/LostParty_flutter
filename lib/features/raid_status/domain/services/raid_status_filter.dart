import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../entities/raid_status_filter_selection.dart';

/// 진행 중 원본 한 건이 공개 조건·레이드·난이도·그룹·그룹원·Character 선택을
/// 만족하는지 판정한다.
///
/// 차원 사이는 AND다. 레이드·난이도·그룹 ID는 차원 내부 OR, 그룹원은 사용자
/// 사이 AND, 한 사용자의 Character는 OR다.
///
/// 진행 중 목록은 [skipIncompleteCharacterLookup]이 기본 true라서
/// [raidCharacterIdByPlayer]가 아직 없으면 Character 칩을 건너뛴다.
/// 모집 목록은 false로 두어 미확인 방을 일치 결과에 넣지 않는다.
/// [raidMemberPlayerIds]가 null이면 그룹원 조건이 있을 때 일치로 보지 않는다.
bool matchesRaidStatusFilter({
  required RaidStatusFilterSelection selection,
  required String? groupId,
  required String raidId,
  required String difficultyId,
  Set<String>? raidMemberPlayerIds = const {},
  Map<String, String>? raidCharacterIdByPlayer,
  String? currentPlayerId,
  bool skipIncompleteCharacterLookup = true,
}) {
  final isGroupLinked = groupId != null && groupId.trim().isNotEmpty;
  if (isGroupLinked) {
    if (!selection.includeGroup) return false;
  } else if (!selection.includePublic) {
    return false;
  }
  if (selection.raidIds.isNotEmpty && !selection.raidIds.contains(raidId)) {
    return false;
  }
  if (selection.difficultyIds.isNotEmpty &&
      !selection.difficultyIds.contains(difficultyId)) {
    return false;
  }
  if (selection.ownCharacterIds.isNotEmpty) {
    final playerId = currentPlayerId?.trim();
    if (playerId == null || playerId.isEmpty) {
      if (!skipIncompleteCharacterLookup) return false;
    } else if (raidCharacterIdByPlayer == null) {
      if (!skipIncompleteCharacterLookup) return false;
    } else {
      final myCharacterId = raidCharacterIdByPlayer[playerId];
      if (myCharacterId == null) {
        if (!skipIncompleteCharacterLookup) return false;
      } else if (!selection.ownCharacterIds.contains(myCharacterId)) {
        return false;
      }
    }
  }
  if (selection.isGroupPublicOnly &&
      selection.groupIds.isNotEmpty &&
      (groupId == null ||
          groupId.trim().isEmpty ||
          !selection.groupIds.contains(groupId))) {
    return false;
  }
  if (!selection.isGroupPublicOnly) return true;
  final knownMemberIds = raidMemberPlayerIds;
  for (final playerId in selection.memberPlayerIds) {
    if (knownMemberIds == null) return false;
    if (!knownMemberIds.contains(playerId)) return false;
    final selectedCharacters = selection.characterIdsByPlayer[playerId];
    if (selectedCharacters == null || selectedCharacters.isEmpty) {
      continue;
    }
    if (raidCharacterIdByPlayer == null) {
      if (skipIncompleteCharacterLookup) continue;
      return false;
    }
    final characterId = raidCharacterIdByPlayer[playerId];
    if (characterId == null || !selectedCharacters.contains(characterId)) {
      return false;
    }
  }
  return true;
}

/// 필터 창·바에 쓰는 카탈로그 칩. 존재하지 않는 레이드·난이도 조합은 만들지 않는다.
class RaidStatusFilterOption {
  const RaidStatusFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class RaidStatusFilterMemberOption {
  const RaidStatusFilterMemberOption({
    required this.playerId,
    required this.label,
    this.groupIds = const {},
    this.characters = const [],
  });

  final String playerId;
  final String label;
  final Set<String> groupIds;
  final List<RaidStatusFilterOption> characters;
}

class RaidStatusFilterCatalogOptions {
  const RaidStatusFilterCatalogOptions({
    this.raids = const [],
    this.difficulties = const [],
  });

  final List<RaidStatusFilterOption> raids;
  final List<RaidStatusFilterOption> difficulties;

  Set<String> get raidIds => {for (final raid in raids) raid.id};

  Set<String> get difficultyIds => {
    for (final difficulty in difficulties) difficulty.id,
  };

  Map<String, String> get raidNames => {
    for (final raid in raids) raid.id: raid.label,
  };

  Map<String, String> get difficultyNames => {
    for (final difficulty in difficulties) difficulty.id: difficulty.label,
  };
}

RaidStatusFilterCatalogOptions raidStatusFilterCatalogOptions(
  RaidCatalog catalog,
) {
  final raids = <RaidStatusFilterOption>[];
  final difficulties = <String, RaidStatusFilterOption>{};
  final difficultyOrder = <String, int>{};
  for (final raid in catalog.raids) {
    if (!raid.isActive) continue;
    raids.add(RaidStatusFilterOption(id: raid.raidId, label: raid.displayName));
    for (final difficulty in raid.difficulties) {
      if (!difficulty.isActive) continue;
      difficultyOrder.putIfAbsent(
        difficulty.difficultyId,
        () => difficulty.displayOrder,
      );
      difficulties.putIfAbsent(
        difficulty.difficultyId,
        () => RaidStatusFilterOption(
          id: difficulty.difficultyId,
          label: difficulty.name,
        ),
      );
    }
  }
  final difficultyList = difficulties.values.toList()
    ..sort((left, right) {
      final byOrder = (difficultyOrder[left.id] ?? 0).compareTo(
        difficultyOrder[right.id] ?? 0,
      );
      if (byOrder != 0) return byOrder;
      return left.label.compareTo(right.label);
    });
  return RaidStatusFilterCatalogOptions(
    raids: raids,
    difficulties: difficultyList,
  );
}

String raidStatusFilterBarLabel(
  RaidStatusFilterSelection selection, {
  Map<String, String> raidNames = const {},
  Map<String, String> difficultyNames = const {},
  Map<String, String> groupNames = const {},
  Map<String, String> memberNames = const {},
}) {
  if (selection.isUnrestricted) return '레이드 필터: 모든 레이드';
  final parts = <String>[];
  if (!selection.includeAllPublicScopes) {
    if (selection.includePublic) parts.add('일반 공개');
    if (selection.includeGroup) parts.add('그룹 공개');
  }
  if (selection.raidIds.length == 1) {
    final id = selection.raidIds.single;
    parts.add(raidNames[id] ?? id);
  } else if (selection.raidIds.length > 1) {
    parts.add('레이드 ${selection.raidIds.length}개');
  }
  if (selection.difficultyIds.length == 1) {
    final id = selection.difficultyIds.single;
    parts.add(difficultyNames[id] ?? id);
  } else if (selection.difficultyIds.length > 1) {
    parts.add('난이도 ${selection.difficultyIds.length}개');
  }
  if (selection.groupIds.length == 1) {
    final id = selection.groupIds.single;
    parts.add(groupNames[id] ?? id);
  } else if (selection.groupIds.length > 1) {
    parts.add('그룹 ${selection.groupIds.length}개');
  }
  if (selection.memberPlayerIds.length == 1) {
    final id = selection.memberPlayerIds.single;
    parts.add(memberNames[id] ?? id);
  } else if (selection.memberPlayerIds.length > 1) {
    parts.add('그룹원 ${selection.memberPlayerIds.length}명');
  }
  if (selection.selectedCharacterCount == 1) {
    parts.add('캐릭터 1개');
  } else if (selection.selectedCharacterCount > 1) {
    parts.add('캐릭터 ${selection.selectedCharacterCount}개');
  }
  if (selection.ownCharacterIds.length == 1) {
    parts.add('내 캐릭터 1개');
  } else if (selection.ownCharacterIds.length > 1) {
    parts.add('내 캐릭터 ${selection.ownCharacterIds.length}개');
  }
  if (parts.isEmpty) return '레이드 필터: 모든 레이드';
  return '레이드 필터: ${parts.join(' · ')}';
}

String raidStatusFilterCountLabel({
  required int count,
  required bool hasMore,
}) => hasMore ? '현재 $count개' : '$count개';
