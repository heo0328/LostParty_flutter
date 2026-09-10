/// 레이드 주차 경계를 계산하는 단일 설정이다.
///
/// 운영 기본값은 KST 수요일 06:00이며, 테스트 조립부에서는 다른 경계를
/// 주입해 시간 경계 시나리오를 빠르게 검증할 수 있다.
class RaidCycleSchedule {
  const RaidCycleSchedule({
    this.utcOffset = const Duration(hours: 9),
    this.resetWeekday = DateTime.wednesday,
    this.resetHour = 6,
    this.resetMinute = 0,
    this.cycleLength = const Duration(days: 7),
  }) : assert(resetWeekday >= DateTime.monday),
       assert(resetWeekday <= DateTime.sunday),
       assert(resetHour >= 0),
       assert(resetHour <= 23),
       assert(resetMinute >= 0),
       assert(resetMinute <= 59);

  final Duration utcOffset;
  final int resetWeekday;
  final int resetHour;
  final int resetMinute;
  final Duration cycleLength;
}
