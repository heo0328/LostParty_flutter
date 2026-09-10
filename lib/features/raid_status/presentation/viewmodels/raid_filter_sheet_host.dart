import 'package:flutter/foundation.dart';

import '../../domain/entities/raid_list_sort_selection.dart';
import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/entities/remaining_slots_filter_selection.dart';
import '../../domain/services/raid_status_filter.dart';

/// 필터 시트·바가 현황/모집 ViewModel에 직접 의존하지 않도록 하는 화면 공통 호스트.
abstract interface class RaidFilterSheetHost implements Listenable {
  RaidStatusFilterSelection get filterSelection;
  RaidStatusFilterCatalogOptions get filterCatalog;
  List<RaidStatusFilterOption> get filterGroups;
  List<RaidStatusFilterMemberOption> get filterVisibleMembers;
  bool get showGroupMemberFilters;

  /// 진행 중 전용. 모집 목록은 false.
  bool get showOwnCharacterFilters;
  List<RaidStatusFilterOption> get ownCharacters;

  RaidListSortSelection get sortSelection;
  String get sortBarLabel;
  RemainingSlotsFilterSelection get remainingSlotsSelection;
  String get remainingSlotsBarLabel;

  String get filterCountLabel;
  String get filterBarLabel;

  /// 필터·정렬·남은 자리 필터가 기본이 아니면 초기화 가능.
  bool get canResetFilters;

  Future<void> setSelection(RaidStatusFilterSelection selection);
  Future<void> resetSelection();
  Future<void> setSortSelection(RaidListSortSelection selection);
  Future<void> toggleMemberCountSort();
  Future<void> setRemainingSlotsSelection(
    RemainingSlotsFilterSelection selection,
  );
  Future<void> toggleOwnCharacter(String characterId);
}
