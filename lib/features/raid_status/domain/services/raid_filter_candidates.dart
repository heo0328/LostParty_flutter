import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/entities/group_relation.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../group/domain/services/activity_display_characters.dart';
import '../entities/raid_status_filter_selection.dart';
import 'raid_status_filter.dart';

class RaidFilterCandidateSnapshot {
  const RaidFilterCandidateSnapshot({
    this.joinedGroupIds = const {},
    this.groups = const [],
    this.members = const [],
  });

  final Set<String> joinedGroupIds;
  final List<RaidStatusFilterOption> groups;
  final List<RaidStatusFilterMemberOption> members;
}

/// 가입 그룹·정상 멤버·활동 Character 표시 문서를 필터 칩 후보로 만든다. 본인은 제외한다.
Future<RaidFilterCandidateSnapshot> loadRaidFilterCandidates({
  required GroupReadRepository repository,
  required String playerId,
  required List<GroupRelation> relations,
  ActivityCharactersRepository? activityCharactersRepository,
  GroupCharacterSearchRepository? characterSearchRepository,
  required bool Function() isStale,
}) async {
  final joined = [
    for (final relation in relations)
      if (relation.isMember) relation,
  ];
  final groups = [
    for (final relation in joined)
      RaidStatusFilterOption(
        id: relation.groupId,
        label: relation.groupNameSnapshot,
      ),
  ];
  final memberByPlayer = <String, String>{};
  final memberGroupIds = <String, Set<String>>{};
  for (final relation in joined) {
    try {
      final members = await repository.loadGroupMembers(relation.groupId);
      if (isStale()) {
        return const RaidFilterCandidateSnapshot();
      }
      for (final member in members) {
        if (member.playerId == playerId) continue;
        memberByPlayer.putIfAbsent(
          member.playerId,
          () => member.displayCharacterNameSnapshot,
        );
        memberGroupIds
            .putIfAbsent(member.playerId, () => {})
            .add(relation.groupId);
      }
    } catch (_) {
      continue;
    }
  }

  final charactersByPlayer = <String, List<RaidStatusFilterOption>>{};
  final search = characterSearchRepository;
  if (search != null) {
    for (final memberPlayerId in memberByPlayer.keys) {
      try {
        final loaded = await loadActivityDisplayCharacters(
          searchRepository: search,
          ownerPlayerId: memberPlayerId,
          activityRepository: activityCharactersRepository,
        );
        if (isStale()) {
          return const RaidFilterCandidateSnapshot();
        }
        charactersByPlayer[memberPlayerId] = [
          for (final character in loaded)
            RaidStatusFilterOption(
              id: character.characterId,
              label: character.characterName,
            ),
        ];
      } catch (_) {
        if (isStale()) {
          return const RaidFilterCandidateSnapshot();
        }
        charactersByPlayer[memberPlayerId] = const [];
      }
    }
  }

  if (isStale()) {
    return const RaidFilterCandidateSnapshot();
  }
  final members = [
    for (final entry in memberByPlayer.entries)
      RaidStatusFilterMemberOption(
        playerId: entry.key,
        label: entry.value,
        groupIds: memberGroupIds[entry.key] ?? const {},
        characters: charactersByPlayer[entry.key] ?? const [],
      ),
  ]..sort((left, right) => left.label.compareTo(right.label));
  return RaidFilterCandidateSnapshot(
    joinedGroupIds: {for (final group in groups) group.id},
    groups: groups,
    members: members,
  );
}

RaidStatusFilterSelection pruneRaidFilterSelection({
  required RaidStatusFilterSelection selection,
  required RaidStatusFilterCatalogOptions catalog,
  required bool groupsLoaded,
  required Set<String> joinedGroupIds,
  required List<RaidStatusFilterMemberOption> members,
}) {
  var next = selection;
  if (catalog.raids.isNotEmpty || catalog.difficulties.isNotEmpty) {
    next = next.prune(
      catalogRaidIds: catalog.raidIds,
      catalogDifficultyIds: catalog.difficultyIds,
    );
  }
  if (groupsLoaded) {
    next = next.pruneMembership(
      joinedGroupIds: joinedGroupIds,
      candidateMemberPlayerIds: {for (final member in members) member.playerId},
      candidateCharacterIdsByPlayer: {
        for (final member in members)
          member.playerId: {
            for (final character in member.characters) character.id,
          },
      },
    );
  }
  return next.withoutHiddenGroupFilters();
}
