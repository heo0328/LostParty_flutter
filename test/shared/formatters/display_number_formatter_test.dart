import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/formatters/display_number_formatter.dart';

void main() {
  test('groups integer digits with commas', () {
    expect(DisplayNumberFormatter.integer(250000), '250,000');
    expect(DisplayNumberFormatter.integer(-1234567), '-1,234,567');
  });

  test(
    'whole display handles wire values without rounding or mutating them',
    () {
      const raw = '1,769.99';
      expect(DisplayNumberFormatter.whole(raw), '1,769');
      expect(raw, '1,769.99');
      expect(DisplayNumberFormatter.whole(4344.99), '4,344');
      expect(DisplayNumberFormatter.whole(0), '0');
      expect(DisplayNumberFormatter.whole(null), '미확인');
      expect(DisplayNumberFormatter.whole('invalid'), '미확인');
      expect(DisplayNumberFormatter.whole(double.nan), '미확인');
      expect(DisplayNumberFormatter.whole(null, missing: '-'), '-');
    },
  );

  test('groups fixed-point values while preserving decimal places', () {
    expect(DisplayNumberFormatter.fixed(338229.42), '338,229.42');
    expect(DisplayNumberFormatter.fixed(1700), '1,700.00');
  });
}
