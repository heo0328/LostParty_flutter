/// 레이드 목록 참가 인원 로컬 정렬. 화면별로 독립 저장한다.
///
/// 기본은 참가 인원 많은 순(내림차순)이다. 화살표 터치로 오름/내림만 전환한다.
enum RaidListSortDirection {
  ascending,
  descending,
}

class RaidListSortSelection {
  const RaidListSortSelection({required this.direction});

  /// 참가 인원 많은 순.
  static const defaults = RaidListSortSelection(
    direction: RaidListSortDirection.descending,
  );

  final RaidListSortDirection direction;

  bool get isDefault => direction == RaidListSortDirection.descending;

  bool get isDescending => direction == RaidListSortDirection.descending;

  RaidListSortSelection toggled() => RaidListSortSelection(
    direction: isDescending
        ? RaidListSortDirection.ascending
        : RaidListSortDirection.descending,
  );

  RaidListSortSelection copyWith({RaidListSortDirection? direction}) =>
      RaidListSortSelection(direction: direction ?? this.direction);

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'criterion': 'memberCount',
    'direction': direction.name,
  };

  /// schemaVersion 1의 `none`/`remainingSlots`는 기본(많은 순)으로 복원한다.
  static RaidListSortSelection fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final criterionName = raw['criterion'];
    final directionName = raw['direction'];
    if (criterionName is String &&
        criterionName != 'memberCount' &&
        criterionName != 'none') {
      return defaults;
    }
    if (criterionName == 'none') return defaults;
    final direction = RaidListSortDirection.values
        .where((value) => value.name == directionName)
        .firstOrNull;
    if (direction == null) return defaults;
    return RaidListSortSelection(direction: direction);
  }

  @override
  bool operator ==(Object other) =>
      other is RaidListSortSelection && other.direction == direction;

  @override
  int get hashCode => direction.hashCode;
}
