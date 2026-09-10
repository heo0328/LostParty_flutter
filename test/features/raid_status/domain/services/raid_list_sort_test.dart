import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_list_sort_selection.dart';
import 'package:lost_party/features/raid_status/domain/entities/remaining_slots_filter_selection.dart';
import 'package:lost_party/features/raid_status/domain/services/raid_list_sort.dart';

void main() {
  group('raidListRemainingSlots', () {
    test('음수는 0으로 정규화한다', () {
      expect(
        raidListRemainingSlots(memberCount: 10, maxMemberCount: 8),
        0,
      );
      expect(
        raidListRemainingSlots(memberCount: 3, maxMemberCount: 8),
        5,
      );
    });
  });

  group('applyRemainingSlotsFilter', () {
    test('선택이 비면 전체를 유지한다', () {
      final items = [
        _item('full', 8, max: 8),
        _item('open', 3, max: 8),
      ];
      final filtered = applyRemainingSlotsFilter(
        items: items,
        selection: RemainingSlotsFilterSelection.unrestricted,
        memberCountOf: (item) => item.memberCount,
        maxMemberCountOf: (item) => item.maxMemberCount,
      );
      expect(filtered.map((item) => item.id), ['full', 'open']);
    });

    test('2+3 자리는 OR 일치만 통과한다', () {
      final items = [
        _item('two', 6, max: 8),
        _item('three', 5, max: 8),
        _item('one', 7, max: 8),
        _item('four', 4, max: 8),
      ];
      final filtered = applyRemainingSlotsFilter(
        items: items,
        selection: const RemainingSlotsFilterSelection(slotCounts: {2, 3}),
        memberCountOf: (item) => item.memberCount,
        maxMemberCountOf: (item) => item.maxMemberCount,
      );
      expect(filtered.map((item) => item.id), ['two', 'three']);
    });
  });

  group('applyRaidListSort', () {
    test('기본 정렬은 참가 인원 많은 순이다', () {
      final items = [_item('a', 2), _item('b', 1), _item('c', 3)];
      final sorted = applyRaidListSort(
        items: items,
        selection: RaidListSortSelection.defaults,
        memberCountOf: (item) => item.memberCount,
        maxMemberCountOf: (item) => item.maxMemberCount,
      );
      expect(sorted.map((item) => item.id), ['c', 'a', 'b']);
    });

    test('참가 인원 적은 순은 안정 정렬이다', () {
      final items = [
        _item('a', 2),
        _item('b', 1),
        _item('c', 2),
        _item('d', 3),
      ];
      final sorted = applyRaidListSort(
        items: items,
        selection: const RaidListSortSelection(
          direction: RaidListSortDirection.ascending,
        ),
        memberCountOf: (item) => item.memberCount,
        maxMemberCountOf: (item) => item.maxMemberCount,
      );
      expect(sorted.map((item) => item.id), ['b', 'a', 'c', 'd']);
    });

    test('동률은 원래 인덱스를 유지한다', () {
      final items = [
        _item('first', 4),
        _item('second', 4),
        _item('third', 4),
      ];
      final sorted = applyRaidListSort(
        items: items,
        selection: RaidListSortSelection.defaults,
        memberCountOf: (item) => item.memberCount,
        maxMemberCountOf: (item) => item.maxMemberCount,
      );
      expect(sorted.map((item) => item.id), ['first', 'second', 'third']);
    });
  });

  group('RaidListSortSelection', () {
    test('toggled()는 방향을 뒤집는다', () {
      expect(
        RaidListSortSelection.defaults.toggled(),
        const RaidListSortSelection(
          direction: RaidListSortDirection.ascending,
        ),
      );
      expect(
        const RaidListSortSelection(
          direction: RaidListSortDirection.ascending,
        ).toggled(),
        RaidListSortSelection.defaults,
      );
    });
  });

  test('라벨을 만든다', () {
    expect(
      raidListMemberCountSortLabel(RaidListSortSelection.defaults),
      '참가 인원수',
    );
    expect(
      remainingSlotsFilterBarLabel(RemainingSlotsFilterSelection.unrestricted),
      '남은 자리',
    );
    expect(
      remainingSlotsFilterBarLabel(
        const RemainingSlotsFilterSelection(slotCounts: {2, 3}),
      ),
      '남은 자리 2,3',
    );
  });
}

class _Item {
  const _Item(this.id, this.memberCount, {this.maxMemberCount = 8});

  final String id;
  final int memberCount;
  final int maxMemberCount;
}

_Item _item(String id, int memberCount, {int max = 8}) =>
    _Item(id, memberCount, maxMemberCount: max);
