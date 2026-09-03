import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';
import 'package:lost_party/features/group/domain/repositories/group_character_search_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/raid_status/data/repositories/drift_raid_status_filter_store.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_status_filter_selection.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/active_raid_filter_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  ActiveRaidSummary raid({
    required String id,
    String raidId = 'act4',
    String difficultyId = 'normal',
    String? groupId,
    Set<String> memberPlayerIds = const {},
  }) => ActiveRaidSummary(
    id: id,
    title: id,
    leaderPlayerId: 'player-1',
    metadata: RecruitmentMetadata(
      catalogVersion: 'test',
      raidId: raidId,
      difficultyId: difficultyId,
      raidName: raidId,
      difficultyName: difficultyId,
      difficultyAlias: difficultyId,
      gateCount: 2,
      minItemLevel: 1680,
      minCombatPower: null,
      experienceLevel: null,
      maxPlayHours: null,
    ),
    currentCycleKey: '2026-08-19',
    memberCount: 1,
    maxMemberCount: 8,
    revision: 1,
    updatedAt: DateTime.utc(2026, 8, 20),
    isOwnedByCurrentPlayer: true,
    groupId: groupId,
    memberPlayerIds: memberPlayerIds,
  );

  test('원본과 필터 결과를 나누고 공개 조건을 로컬 적용한다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(id: 'public'),
            raid(id: 'group', groupId: 'group-1', raidId: 'serca'),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.originalItems, hasLength(2));
    expect(viewModel.state.items, hasLength(2));
    expect(viewModel.state.countLabel, '2개');

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.toggleGroup(),
    );
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(store.values['player-1']?.includeGroup, isFalse);
  });

  test('저장된 필터를 복원하고 카탈로그에 없는 선택은 제거한다', () async {
    final store = MemoryRaidStatusFilterStore({
      'player-1': const RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4', 'retired'},
        difficultyIds: {'normal', 'legacy'},
      ),
    });
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(id: 'public'),
            raid(id: 'serca', raidId: 'serca', difficultyId: 'hard'),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: store,
      catalogRepository: _CatalogRepository(),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.selection.raidIds, {'act4'});
    expect(viewModel.state.selection.difficultyIds, {'normal'});
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(viewModel.state.barLabel, '레이드 필터: 4막 · 노말');
  });

  test('칩 변경은 원본 스트림을 다시 구독하지 않는다', () async {
    var starts = 0;
    final controller =
        StreamController<PartyReadSnapshot<ActiveRaidSummary>>.broadcast();
    addTearDown(controller.close);
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () {
        starts += 1;
        return controller.stream;
      },
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
    )..start();
    addTearDown(viewModel.dispose);

    controller.add(
      PartyReadSnapshot(items: [raid(id: 'public')], isFromCache: false),
    );
    await Future<void>.delayed(Duration.zero);
    await viewModel.setSelection(
      const RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'missing'},
      ),
    );

    expect(starts, 1);
    expect(viewModel.state.isEmptyFiltered, isTrue);
    expect(viewModel.state.originalItems, hasLength(1));
  });

  test('현재 Player는 그룹원 후보에서 빼고 사용자 AND로 목록을 좁힌다', () async {
    final groups = _FakeGroupReadRepository(
      groups: [_groupRelation()],
      membersByGroup: {
        'group-1': [
          _groupMember(playerId: 'player-1', name: '나'),
          _groupMember(playerId: 'player-2', name: '친구딜러'),
          _groupMember(playerId: 'player-3', name: '친구서폿'),
        ],
      },
    );
    var memberLoads = 0;
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(
              id: 'both',
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2', 'player-3'},
            ),
            raid(
              id: 'only-two',
              groupId: 'group-1',
              raidId: 'serca',
              memberPlayerIds: {'player-1', 'player-2'},
            ),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
      membersStreamFactory: (id) {
        memberLoads += 1;
        return Stream.value(
          PartyReadSnapshot(
            items: [
              _memberDisplay(playerId: 'player-2', characterId: 'char-21'),
              _memberDisplay(playerId: 'player-3', characterId: 'char-33'),
            ],
            isFromCache: false,
          ),
        );
      },
      groupReadRepository: groups,
      activityCharactersRepository: _FakeActivity({
        'player-2': {'char-21', 'char-24'},
        'player-3': {'char-33'},
      }),
      characterSearchRepository: _FakeSearch({
        'player-2': [
          _searchChar(playerId: 'player-2', id: 'char-21', name: '딜러A'),
          _searchChar(playerId: 'player-2', id: 'char-24', name: '딜러B'),
        ],
        'player-3': [
          _searchChar(playerId: 'player-3', id: 'char-33', name: '서폿A'),
        ],
      }),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.members.map((member) => member.playerId), [
      'player-2',
      'player-3',
    ]);
    expect(
      viewModel.state.members.map((member) => member.label),
      isNot(contains('나')),
    );

    final afterMembers = memberLoads;
    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted
          .togglePublic()
          .toggleMember('player-2')
          .toggleMember('player-3'),
    );
    expect(viewModel.state.items.map((item) => item.id), ['both']);
    expect(memberLoads, afterMembers);
    expect(groups.loadMembersCount, 1);
    expect(
      viewModel.state.members
          .firstWhere((member) => member.playerId == 'player-2')
          .characters
          .map((character) => character.id),
      ['char-21', 'char-24'],
    );
    expect(viewModel.state.showGroupMemberFilters, isTrue);
  });

  test('초기화는 전체 보기로 되돌리고 저장한다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [raid(id: 'public'), raid(id: 'group', groupId: 'group-1')],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.togglePublic(),
    );
    expect(viewModel.state.selection.isUnrestricted, isFalse);
    await viewModel.resetSelection();
    expect(viewModel.state.selection.isUnrestricted, isTrue);
    expect(store.values['player-1']?.isUnrestricted, isTrue);
    expect(viewModel.state.items, hasLength(2));
  });

  test('전체를 선택하면 그룹원 선택을 지우고 그룹원 UI를 숨긴다', () async {
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(
              id: 'both',
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2'},
            ),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
      groupReadRepository: _FakeGroupReadRepository(
        groups: [_groupRelation()],
        membersByGroup: {
          'group-1': [_groupMember(playerId: 'player-2', name: '친구딜러')],
        },
      ),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted
          .togglePublic()
          .toggleMember('player-2'),
    );
    expect(viewModel.state.showGroupMemberFilters, isTrue);
    expect(viewModel.state.selection.memberPlayerIds, {'player-2'});

    await viewModel.setSelection(
      viewModel.state.selection.selectAllPublicScopes(),
    );
    expect(viewModel.state.showGroupMemberFilters, isFalse);
    expect(viewModel.state.selection.memberPlayerIds, isEmpty);
  });

  test('그룹원 Character 후보는 활동 ID만 쓰고 인증 Character 전체로 대체하지 않는다', () async {
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(
              id: 'both',
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2'},
            ),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
      groupReadRepository: _FakeGroupReadRepository(
        groups: [_groupRelation()],
        membersByGroup: {
          'group-1': [_groupMember(playerId: 'player-2', name: '친구딜러')],
        },
      ),
      activityCharactersRepository: _FakeActivity({
        'player-2': {'char-21'},
      }),
      characterSearchRepository: _FakeSearch({
        'player-2': [
          _searchChar(playerId: 'player-2', id: 'char-21', name: '딜러A'),
          _searchChar(playerId: 'player-2', id: 'char-99', name: '인증만'),
        ],
      }),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      viewModel.state.members.single.characters.map(
        (character) => character.id,
      ),
      ['char-21'],
    );
  });

  test('활동 Character가 없으면 그룹원 Character 칩을 비운다', () async {
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(
              id: 'both',
              groupId: 'group-1',
              memberPlayerIds: {'player-1', 'player-2'},
            ),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
      groupReadRepository: _FakeGroupReadRepository(
        groups: [_groupRelation()],
        membersByGroup: {
          'group-1': [_groupMember(playerId: 'player-2', name: '친구딜러')],
        },
      ),
      activityCharactersRepository: _FakeActivity({}),
      characterSearchRepository: _FakeSearch({
        'player-2': [
          _searchChar(playerId: 'player-2', id: 'char-21', name: '딜러A'),
        ],
      }),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.members.single.characters, isEmpty);
  });

  test('저장된 그룹이 모두 무효면 전체 보기로 되돌린다', () async {
    final store = MemoryRaidStatusFilterStore({
      'player-1': const RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        groupIds: {'gone'},
        memberPlayerIds: {'player-2'},
      ),
    });
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(items: [raid(id: 'public')], isFromCache: false),
      ),
      playerId: 'player-1',
      filterStore: store,
      groupReadRepository: _FakeGroupReadRepository(
        groups: [_groupRelation()],
        membersByGroup: {
          'group-1': [_groupMember(playerId: 'player-2', name: '친구딜러')],
        },
      ),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.selection, RaidStatusFilterSelection.unrestricted);
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(store.values['player-1']?.isUnrestricted, isTrue);
  });
}

class _CatalogRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: const [
      RaidDefinition(
        raidId: 'act4',
        officialName: '4막',
        displayName: '4막',
        aliases: [],
        partySize: 8,
        partyCount: 2,
        requiredSupportCount: 2,
        maxDealerCountPerClass: 2,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'normal',
            name: '노말',
            displayAlias: '노말',
            displayOrder: 1,
            minItemLevel: 1680,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1700,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
      RaidDefinition(
        raidId: 'serca',
        officialName: '세르카',
        displayName: '세르카',
        aliases: [],
        partySize: 4,
        partyCount: 1,
        requiredSupportCount: 1,
        maxDealerCountPerClass: 1,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1730,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
    ],
  );
}

GroupRelation _groupRelation({
  String groupId = 'group-1',
  String name = '테스트그룹',
}) => GroupRelation(
  groupId: groupId,
  playerId: 'player-1',
  relation: GroupRelationKind.member,
  groupNameSnapshot: name,
  displayCharacterNameSnapshot: '나',
  sourceRevision: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

GroupMember _groupMember({
  required String playerId,
  required String name,
  String groupId = 'group-1',
}) => GroupMember(
  groupId: groupId,
  playerId: playerId,
  role: GroupMemberRole.member,
  joinedAt: DateTime.utc(2026, 8, 1),
  joinSequence: 1,
  joinedBy: GroupJoinedBy.created,
  displayCharacterIdSnapshot: 'char-$playerId',
  displayCharacterNameSnapshot: name,
  revision: 1,
);

PartyMemberDisplay _memberDisplay({
  required String playerId,
  required String characterId,
}) => PartyMemberDisplay(
  playerId: playerId,
  characterName: characterId,
  className: '블레이드',
  role: PartyRole.dealer,
  partyIndex: 0,
  characterId: characterId,
);

GroupRequestCharacter _searchChar({
  required String playerId,
  required String id,
  required String name,
}) => GroupRequestCharacter(
  characterId: id,
  ownerPlayerId: playerId,
  characterName: name,
  serverName: '루페온',
  characterClassName: '블레이드',
);

class _FakeGroupReadRepository extends Fake implements GroupReadRepository {
  _FakeGroupReadRepository({
    required this.groups,
    required this.membersByGroup,
  });

  final List<GroupRelation> groups;
  final Map<String, List<GroupMember>> membersByGroup;
  var loadMembersCount = 0;

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) =>
      Stream.value(GroupReadSnapshot(items: groups, isFromCache: false));

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async {
    loadMembersCount += 1;
    return membersByGroup[groupId] ?? const [];
  }
}

class _FakeActivity implements ActivityCharactersRepository {
  _FakeActivity(this.idsByPlayer);

  final Map<String, Set<String>> idsByPlayer;

  @override
  Future<ActivityCharacters> load({required String playerId}) async =>
      ActivityCharacters(
        playerId: playerId,
        characterIds: idsByPlayer[playerId] ?? const {},
      );

  @override
  Future<ActivityCharacters> save(SaveActivityCharactersCommand command) {
    throw UnimplementedError();
  }
}

class _FakeSearch extends Fake implements GroupCharacterSearchRepository {
  _FakeSearch(this.charactersByPlayer);

  final Map<String, List<GroupRequestCharacter>> charactersByPlayer;

  @override
  Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(
    String ownerPlayerId, {
    int limit = groupCharacterSearchPageSize,
  }) async => charactersByPlayer[ownerPlayerId] ?? const [];
}
