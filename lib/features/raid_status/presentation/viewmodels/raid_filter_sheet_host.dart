import 'package:flutter/foundation.dart';

import '../../domain/entities/raid_status_filter_selection.dart';
import '../../domain/services/raid_status_filter.dart';

/// 필터 시트·바가 현황/모집 ViewModel에 직접 의존하지 않도록 하는 화면 공통 호스트.
abstract interface class RaidFilterSheetHost implements Listenable {
  RaidStatusFilterSelection get filterSelection;
  RaidStatusFilterCatalogOptions get filterCatalog;
  List<RaidStatusFilterOption> get filterGroups;
  List<RaidStatusFilterMemberOption> get filterVisibleMembers;
  bool get showGroupMemberFilters;
  String get filterCountLabel;
  String get filterBarLabel;

  Future<void> setSelection(RaidStatusFilterSelection selection);
  Future<void> resetSelection();
}
