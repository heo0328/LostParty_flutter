import '../entities/raid_list_sort_selection.dart';
import '../entities/remaining_slots_filter_selection.dart';

int raidListRemainingSlots({
  required int memberCount,
  required int maxMemberCount,
}) {
  final remaining = maxMemberCount - memberCount;
  return remaining < 0 ? 0 : remaining;
}

List<T> applyRemainingSlotsFilter<T>({
  required List<T> items,
  required RemainingSlotsFilterSelection selection,
  required int Function(T item) memberCountOf,
  required int Function(T item) maxMemberCountOf,
}) {
  if (selection.isUnrestricted) {
    return List<T>.unmodifiable(items);
  }
  return List<T>.unmodifiable([
    for (final item in items)
      if (selection.matches(
        raidListRemainingSlots(
          memberCount: memberCountOf(item),
          maxMemberCount: maxMemberCountOf(item),
        ),
      ))
        item,
  ]);
}

/// 참가 인원 기준 안정 정렬. 동률은 원래 인덱스를 2차 기준으로 유지한다.
List<T> applyRaidListSort<T>({
  required List<T> items,
  required RaidListSortSelection selection,
  required int Function(T item) memberCountOf,
  required int Function(T item) maxMemberCountOf,
}) {
  if (items.length < 2) {
    return List<T>.unmodifiable(items);
  }

  final indexed = [
    for (var index = 0; index < items.length; index++) (index, items[index]),
  ];
  indexed.sort((left, right) {
    final leftValue = memberCountOf(left.$2);
    final rightValue = memberCountOf(right.$2);
    final byValue = selection.direction == RaidListSortDirection.ascending
        ? leftValue.compareTo(rightValue)
        : rightValue.compareTo(leftValue);
    if (byValue != 0) return byValue;
    return left.$1.compareTo(right.$1);
  });
  return List<T>.unmodifiable([for (final entry in indexed) entry.$2]);
}

String raidListMemberCountSortLabel(RaidListSortSelection selection) =>
    selection.isDescending ? '참가 인원수' : '참가 인원수';

String remainingSlotsFilterBarLabel(RemainingSlotsFilterSelection selection) {
  if (selection.isUnrestricted) return '남은 자리';
  final counts = selection.slotCounts.toList()..sort();
  if (counts.length == 1) return '남은 자리 ${counts.single}';
  return '남은 자리 ${counts.join(',')}';
}
