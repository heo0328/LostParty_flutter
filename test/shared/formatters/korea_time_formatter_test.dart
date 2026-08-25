import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/formatters/korea_time_formatter.dart';

void main() {
  test('UTC 시각을 한국 시간 기준 요일과 시각으로 표시한다', () {
    expect(
      KoreaTimeFormatter.dayAndTime(DateTime.utc(2026, 8, 26, 12)),
      '8/26(수) 21:00',
    );
  });

  test('날짜 경계를 넘는 시각도 한국 날짜로 표시한다', () {
    expect(
      KoreaTimeFormatter.dayAndTime(DateTime.utc(2026, 8, 26, 15, 30)),
      '8/27(목) 00:30',
    );
  });

  test('로컬 시각도 UTC로 정규화한 뒤 변환한다', () {
    expect(
      KoreaTimeFormatter.day(DateTime.utc(2026, 8, 26, 12).toLocal()),
      '8/26(수)',
    );
  });
}
