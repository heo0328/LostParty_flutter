/// Player별 필터 저장을 화면 단위로 나눈다. 모집 목록과 레이드 현황이 서로 덮어쓰지 않는다.
enum RaidFilterScreen {
  activeRaids,
  recruitmentList;

  String get storageKey => name;
}
