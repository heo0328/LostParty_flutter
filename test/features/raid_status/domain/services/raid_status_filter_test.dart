import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_status_filter_selection.dart';
import 'package:lost_party/features/raid_status/domain/services/raid_status_filter.dart';

void main() {
  group('RaidStatusFilterSelection', () {
    test('기본값은 전체·일반 공개·그룹 공개가 모두 선택된 상태다', () {
      const selection = RaidStatusFilterSelection.unrestricted;
      expect(selection.includePublic, isTrue);
      expect(selection.includeGroup, isTrue);
      expect(selection.includeAllPublicScopes, isTrue);
      expect(selection.isUnrestricted, isTrue);
    });

    test('한 하위 공개 조건을 해제하면 전체 체크가 해제된다', () {
      final selection = RaidStatusFilterSelection.unrestricted.togglePublic();
      expect(selection.includePublic, isFalse);
      expect(selection.includeGroup, isTrue);
      expect(selection.includeAllPublicScopes, isFalse);
    });

    test('일반과 그룹 공개를 모두 해제하려 하면 전체로 복귀한다', () {
      final onlyGroup = RaidStatusFilterSelection.unrestricted.togglePublic();
      expect(onlyGroup.toggleGroup(), RaidStatusFilterSelection.unrestricted);
      final onlyPublic = RaidStatusFilterSelection.unrestricted.toggleGroup();
      expect(onlyPublic.togglePublic(), RaidStatusFilterSelection.unrestricted);
    });

    test('전체를 선택하면 일반과 그룹 공개를 함께 선택한다', () {
      final selection = RaidStatusFilterSelection.unrestricted
          .togglePublic()
          .selectAllPublicScopes();
      expect(selection.includePublic, isTrue);
      expect(selection.includeGroup, isTrue);
    });

    test('손상된 JSON은 전체 보기로 초기화한다', () {
      expect(RaidStatusFilterSelection.fromJson(null).isUnrestricted, isTrue);
      expect(RaidStatusFilterSelection.fromJson('bad').isUnrestricted, isTrue);
      expect(
        RaidStatusFilterSelection.fromJson({
          'includePublic': false,
          'includeGroup': false,
        }).isUnrestricted,
        isTrue,
      );
    });

    test('카탈로그에 없는 선택은 제거하고 나머지는 유지한다', () {
      final pruned =
          const RaidStatusFilterSelection(
            includePublic: true,
            includeGroup: false,
            raidIds: {'act4', 'gone'},
            difficultyIds: {'normal', 'legacy'},
          ).prune(
            catalogRaidIds: {'act4'},
            catalogDifficultyIds: {'normal', 'hard'},
          );
      expect(pruned.raidIds, {'act4'});
      expect(pruned.difficultyIds, {'normal'});
      expect(pruned.includePublic, isTrue);
      expect(pruned.includeGroup, isFalse);
    });

    test('D2 JSON은 그룹원 필드 없이 복원한다', () {
      final selection = RaidStatusFilterSelection.fromJson({
        'schemaVersion': 1,
        'includePublic': true,
        'includeGroup': false,
        'raidIds': ['act4'],
        'difficultyIds': ['normal'],
      });
      expect(selection.includeGroup, isFalse);
      expect(selection.raidIds, {'act4'});
      expect(selection.groupIds, isEmpty);
      expect(selection.memberPlayerIds, isEmpty);
      expect(selection.isUnrestricted, isFalse);
    });

    test('그룹원 Character 선택은 부모 사용자를 함께 고르고 칩을 모두 해제해도 그룹원은 남긴다', () {
      final selected = RaidStatusFilterSelection.unrestricted.toggleCharacter(
        playerId: 'player-2',
        characterId: 'char-21',
      );
      expect(selected.memberPlayerIds, {'player-2'});
      expect(selected.characterIdsByPlayer['player-2'], {'char-21'});
      final cleared = selected.toggleCharacter(
        playerId: 'player-2',
        characterId: 'char-21',
      );
      expect(cleared.memberPlayerIds, {'player-2'});
      expect(cleared.characterIdsByPlayer, isEmpty);
    });

    test('그룹원을 해제하면 Character 선택도 지운다', () {
      final selected = RaidStatusFilterSelection.unrestricted
          .toggleCharacter(playerId: 'player-2', characterId: 'char-21')
          .toggleMember('player-2');
      expect(selected.memberPlayerIds, isEmpty);
      expect(selected.characterIdsByPlayer, isEmpty);
    });

    test('저장된 그룹 선택이 모두 무효면 전체 보기로 초기화한다', () {
      const stored = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4'},
        groupIds: {'gone-1', 'gone-2'},
        memberPlayerIds: {'player-2'},
      );
      expect(
        stored.pruneMembership(
          joinedGroupIds: {'group-1'},
          candidateMemberPlayerIds: {'player-2'},
        ),
        RaidStatusFilterSelection.unrestricted,
      );
    });

    test('일부 그룹만 유효하면 그 선택과 남은 그룹원을 유지한다', () {
      const stored = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        groupIds: {'group-1', 'gone'},
        memberPlayerIds: {'player-2', 'player-gone'},
        characterIdsByPlayer: {
          'player-2': {'char-21', 'retired'},
          'player-gone': {'char-x'},
        },
      );
      final pruned = stored.pruneMembership(
        joinedGroupIds: {'group-1'},
        candidateMemberPlayerIds: {'player-2'},
        candidateCharacterIdsByPlayer: {
          'player-2': {'char-21', 'char-24'},
        },
      );
      expect(pruned.groupIds, {'group-1'});
      expect(pruned.memberPlayerIds, {'player-2'});
      expect(pruned.characterIdsByPlayer['player-2'], {'char-21'});
    });

    test('전체 또는 일반 공개가 포함되면 그룹 관련 선택을 제거한다', () {
      const stored = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4'},
        groupIds: {'group-1'},
        memberPlayerIds: {'player-2'},
        characterIdsByPlayer: {
          'player-2': {'char-21'},
        },
      );
      final cleared = stored.withoutHiddenGroupFilters();
      expect(cleared.raidIds, {'act4'});
      expect(cleared.groupIds, isEmpty);
      expect(cleared.memberPlayerIds, isEmpty);
      expect(cleared.characterIdsByPlayer, isEmpty);
      expect(
        RaidStatusFilterSelection.fromJson({
          'includePublic': true,
          'includeGroup': true,
          'groupIds': ['group-1'],
          'memberPlayerIds': ['player-2'],
        }).groupIds,
        isEmpty,
      );
    });

    test('그룹 공개만일 때는 그룹 관련 선택을 유지한다', () {
      const stored = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        groupIds: {'group-1'},
        memberPlayerIds: {'player-2'},
      );
      expect(stored.withoutHiddenGroupFilters(), stored);
    });
  });

  group('matchesRaidStatusFilter', () {
    const publicRaid = _Target(
      groupId: null,
      raidId: 'act4',
      difficultyId: 'normal',
    );
    const groupRaid = _Target(
      groupId: 'group-1',
      raidId: 'serca',
      difficultyId: 'hard',
    );
    const publicGroupLinked = _Target(
      groupId: 'group-1',
      raidId: 'act4',
      difficultyId: 'hard',
    );

    test('기본 전체 선택은 일반과 그룹 연결 레이드를 모두 허용한다', () {
      expect(_matches(publicRaid), isTrue);
      expect(_matches(groupRaid), isTrue);
      expect(_matches(publicGroupLinked), isTrue);
    });

    test('일반 공개는 groupId가 없는 레이드만 허용한다', () {
      final selection = RaidStatusFilterSelection.unrestricted.toggleGroup();
      expect(_matches(publicRaid, selection: selection), isTrue);
      expect(_matches(groupRaid, selection: selection), isFalse);
      expect(_matches(publicGroupLinked, selection: selection), isFalse);
    });

    test('그룹 공개는 visibility와 무관하게 groupId 기준으로 허용한다', () {
      final selection = RaidStatusFilterSelection.unrestricted.togglePublic();
      expect(_matches(publicRaid, selection: selection), isFalse);
      expect(_matches(groupRaid, selection: selection), isTrue);
      expect(_matches(publicGroupLinked, selection: selection), isTrue);
    });

    test('레이드와 난이도는 차원 내부 OR, 차원 사이 AND다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4', 'serca'},
        difficultyIds: {'hard'},
      );
      expect(_matches(publicRaid, selection: selection), isFalse);
      expect(_matches(groupRaid, selection: selection), isTrue);
      expect(_matches(publicGroupLinked, selection: selection), isTrue);
      expect(
        _matches(
          const _Target(raidId: 'belgardin', difficultyId: 'hard'),
          selection: selection,
        ),
        isFalse,
      );
    });

    test('해당 차원 선택이 없으면 전체를 허용한다', () {
      const raidOnly = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4'},
      );
      expect(_matches(publicRaid, selection: raidOnly), isTrue);
      expect(_matches(groupRaid, selection: raidOnly), isFalse);
    });

    test('그룹 ID는 그룹 공개만일 때만 적용되고 차원 내부 OR다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        groupIds: {'group-1'},
      );
      expect(_matches(publicRaid, selection: selection), isFalse);
      expect(_matches(groupRaid, selection: selection), isTrue);
      expect(
        _matches(
          const _Target(
            groupId: 'group-2',
            raidId: 'act4',
            difficultyId: 'normal',
          ),
          selection: selection,
        ),
        isFalse,
      );
    });

    test('전체가 포함되면 그룹 ID 선택을 판정에 쓰지 않는다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        groupIds: {'group-1'},
      );
      expect(_matches(publicRaid, selection: selection), isTrue);
      expect(_matches(groupRaid, selection: selection), isTrue);
    });

    test('그룹원은 사용자 사이 AND, Character는 사용자 내부 OR다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        memberPlayerIds: {'player-2', 'player-3'},
        characterIdsByPlayer: {
          'player-2': {'char-21', 'char-24'},
          'player-3': {'char-33', 'char-35'},
        },
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-2', 'player-3'},
          characterIdByPlayer: {'player-2': 'char-21', 'player-3': 'char-33'},
        ),
        isTrue,
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-2'},
          characterIdByPlayer: {'player-2': 'char-21', 'player-3': 'char-33'},
        ),
        isFalse,
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-2', 'player-3'},
          characterIdByPlayer: {'player-2': 'char-99', 'player-3': 'char-33'},
        ),
        isFalse,
      );
    });

    test('그룹원만 고르고 Character 칩이 없으면 참가 사실만 요구한다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        memberPlayerIds: {'player-2'},
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-2'},
          characterIdByPlayer: {'player-2': 'inactive-char'},
        ),
        isTrue,
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-9'},
        ),
        isFalse,
      );
    });

    test('Character 칩이 있어도 membership이 아직 없으면 Character 조건을 건너뛴다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        memberPlayerIds: {'player-2'},
        characterIdsByPlayer: {
          'player-2': {'char-21'},
        },
      );
      expect(
        _matches(
          groupRaid,
          selection: selection,
          memberPlayerIds: {'player-2'},
        ),
        isTrue,
      );
      expect(
        matchesRaidStatusFilter(
          selection: selection,
          groupId: groupRaid.groupId,
          raidId: groupRaid.raidId,
          difficultyId: groupRaid.difficultyId,
          raidMemberPlayerIds: {'player-2'},
          skipIncompleteCharacterLookup: false,
        ),
        isFalse,
      );
    });

    test('그룹원 ID가 없으면 그룹원 조건을 일치로 보지 않는다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: false,
        includeGroup: true,
        memberPlayerIds: {'player-2'},
      );
      expect(
        matchesRaidStatusFilter(
          selection: selection,
          groupId: groupRaid.groupId,
          raidId: groupRaid.raidId,
          difficultyId: groupRaid.difficultyId,
          raidMemberPlayerIds: null,
        ),
        isFalse,
      );
    });

    test('내 Character는 현재 사용자 membership Character ID로 OR 판정한다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        ownCharacterIds: {'char-me'},
      );
      expect(
        matchesRaidStatusFilter(
          selection: selection,
          groupId: publicRaid.groupId,
          raidId: publicRaid.raidId,
          difficultyId: publicRaid.difficultyId,
          raidCharacterIdByPlayer: {'player-1': 'char-me'},
          currentPlayerId: 'player-1',
        ),
        isTrue,
      );
      expect(
        matchesRaidStatusFilter(
          selection: selection,
          groupId: publicRaid.groupId,
          raidId: publicRaid.raidId,
          difficultyId: publicRaid.difficultyId,
          raidCharacterIdByPlayer: {'player-1': 'other'},
          currentPlayerId: 'player-1',
        ),
        isFalse,
      );
    });

    test('내 Character 선택이 없으면 기존처럼 모두 허용한다', () {
      expect(
        matchesRaidStatusFilter(
          selection: RaidStatusFilterSelection.unrestricted,
          groupId: publicRaid.groupId,
          raidId: publicRaid.raidId,
          difficultyId: publicRaid.difficultyId,
          currentPlayerId: 'player-1',
        ),
        isTrue,
      );
    });
  });

  group('RaidStatusFilterSelection ownCharacterIds', () {
    test('토글과 JSON schema v2를 왕복한다', () {
      final selected = RaidStatusFilterSelection.unrestricted
          .toggleOwnCharacter('char-1')
          .toggleOwnCharacter('char-2');
      expect(selected.ownCharacterIds, {'char-1', 'char-2'});
      expect(selected.isUnrestricted, isFalse);
      final json = selected.toJson();
      expect(json['schemaVersion'], 2);
      expect(json['ownCharacterIds'], ['char-1', 'char-2']);
      expect(RaidStatusFilterSelection.fromJson(json), selected);
    });

    test('그룹 공개 해제와 무관하게 내 Character 선택을 유지한다', () {
      final selected = RaidStatusFilterSelection.unrestricted
          .toggleOwnCharacter('char-1')
          .togglePublic();
      expect(selected.ownCharacterIds, {'char-1'});
      expect(selected.withoutHiddenGroupFilters().ownCharacterIds, {'char-1'});
    });
  });

  test('결과 개수는 다음 페이지가 있으면 현재 N개, 없으면 N개다', () {
    expect(raidStatusFilterCountLabel(count: 3, hasMore: true), '현재 3개');
    expect(raidStatusFilterCountLabel(count: 3, hasMore: false), '3개');
  });
}

class _Target {
  const _Target({
    this.groupId,
    required this.raidId,
    required this.difficultyId,
  });

  final String? groupId;
  final String raidId;
  final String difficultyId;
}

bool _matches(
  _Target target, {
  RaidStatusFilterSelection selection = RaidStatusFilterSelection.unrestricted,
  Set<String> memberPlayerIds = const {},
  Map<String, String>? characterIdByPlayer,
}) => matchesRaidStatusFilter(
  selection: selection,
  groupId: target.groupId,
  raidId: target.raidId,
  difficultyId: target.difficultyId,
  raidMemberPlayerIds: memberPlayerIds,
  raidCharacterIdByPlayer: characterIdByPlayer,
);
