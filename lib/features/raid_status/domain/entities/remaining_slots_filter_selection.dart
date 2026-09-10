/// 남은 자리 수 2차 필터. 상단 레이드 필터 이후 로컬에만 적용한다.
///
/// 선택값이 비면 모든 남은 자리 수를 허용한다. 값이 있으면 1~7 중 OR 일치만 통과한다.
class RemainingSlotsFilterSelection {
  const RemainingSlotsFilterSelection({this.slotCounts = const {}});

  static const unrestricted = RemainingSlotsFilterSelection();

  static const selectableSlotCounts = <int>[1, 2, 3, 4, 5, 6, 7];

  /// 허용할 남은 자리 수. 비어 있으면 전체 허용.
  final Set<int> slotCounts;

  bool get isUnrestricted => slotCounts.isEmpty;

  RemainingSlotsFilterSelection toggle(int slotCount) {
    if (!selectableSlotCounts.contains(slotCount)) return this;
    final next = {...slotCounts};
    if (!next.add(slotCount)) {
      next.remove(slotCount);
    }
    return RemainingSlotsFilterSelection(slotCounts: next);
  }

  RemainingSlotsFilterSelection clear() => unrestricted;

  RemainingSlotsFilterSelection copyWith({Set<int>? slotCounts}) =>
      RemainingSlotsFilterSelection(slotCounts: slotCounts ?? this.slotCounts);

  bool matches(int remainingSlots) {
    if (isUnrestricted) return true;
    return slotCounts.contains(remainingSlots);
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'slotCounts': (slotCounts.toList()..sort()),
  };

  static RemainingSlotsFilterSelection fromJson(Object? raw) {
    if (raw is! Map) return unrestricted;
    final values = raw['slotCounts'];
    if (values is! List) return unrestricted;
    final next = <int>{};
    for (final value in values) {
      final count = value is int
          ? value
          : value is num
          ? value.toInt()
          : null;
      if (count != null && selectableSlotCounts.contains(count)) {
        next.add(count);
      }
    }
    return RemainingSlotsFilterSelection(slotCounts: next);
  }

  @override
  bool operator ==(Object other) =>
      other is RemainingSlotsFilterSelection &&
      other.slotCounts.length == slotCounts.length &&
      other.slotCounts.containsAll(slotCounts);

  @override
  int get hashCode => Object.hashAll(slotCounts.toList()..sort());
}
