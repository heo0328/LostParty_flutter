/// 서버 시간은 UTC로 저장하지만 사용자는 항상 한국 시간 기준으로 일정을 읽는다.
class KoreaTimeFormatter {
  const KoreaTimeFormatter._();

  static const _offset = Duration(hours: 9);
  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  /// `8/26(수) 21:00` 형태로 표시한다.
  static String dayAndTime(DateTime instant) {
    final korea = _toKorea(instant);
    return '${korea.month}/${korea.day}(${_weekday(korea)})'
        ' ${_twoDigits(korea.hour)}:${_twoDigits(korea.minute)}';
  }

  /// `8/26(수)` 형태로 표시한다.
  static String day(DateTime instant) {
    final korea = _toKorea(instant);
    return '${korea.month}/${korea.day}(${_weekday(korea)})';
  }

  static DateTime _toKorea(DateTime instant) => instant.toUtc().add(_offset);

  static String _weekday(DateTime korea) => _weekdayNames[korea.weekday - 1];

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
