import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/formatters/display_number_formatter.dart';

void main() {
  test('groups integer digits with commas', () {
    expect(DisplayNumberFormatter.integer(250000), '250,000');
    expect(DisplayNumberFormatter.integer(-1234567), '-1,234,567');
  });

  test('groups fixed-point values while preserving decimal places', () {
    expect(DisplayNumberFormatter.fixed(338229.42), '338,229.42');
    expect(DisplayNumberFormatter.fixed(1700), '1,700.00');
  });
}
