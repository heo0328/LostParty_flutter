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
      expect(_matches(publicRaid, selection), isTrue);
      expect(_matches(groupRaid, selection), isFalse);
      expect(_matches(publicGroupLinked, selection), isFalse);
    });

    test('그룹 공개는 visibility와 무관하게 groupId 기준으로 허용한다', () {
      final selection = RaidStatusFilterSelection.unrestricted.togglePublic();
      expect(_matches(publicRaid, selection), isFalse);
      expect(_matches(groupRaid, selection), isTrue);
      expect(_matches(publicGroupLinked, selection), isTrue);
    });

    test('레이드와 난이도는 차원 내부 OR, 차원 사이 AND다', () {
      const selection = RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4', 'serca'},
        difficultyIds: {'hard'},
      );
      expect(_matches(publicRaid, selection), isFalse);
      expect(_matches(groupRaid, selection), isTrue);
      expect(_matches(publicGroupLinked, selection), isTrue);
      expect(
        _matches(
          const _Target(raidId: 'belgardin', difficultyId: 'hard'),
          selection,
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
      expect(_matches(publicRaid, raidOnly), isTrue);
      expect(_matches(groupRaid, raidOnly), isFalse);
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
  _Target target, [
  RaidStatusFilterSelection selection = RaidStatusFilterSelection.unrestricted,
]) => matchesRaidStatusFilter(
  selection: selection,
  groupId: target.groupId,
  raidId: target.raidId,
  difficultyId: target.difficultyId,
);
