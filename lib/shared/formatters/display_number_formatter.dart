class DisplayNumberFormatter {
  const DisplayNumberFormatter._();

  static String integer(num value) => _groupDigits(value.toInt().toString());

  static String fixed(num value, {int decimalPlaces = 2}) {
    final fixedValue = value.toStringAsFixed(decimalPlaces);
    final parts = fixedValue.split('.');
    final whole = _groupDigits(parts.first);
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  static String _groupDigits(String value) {
    final isNegative = value.startsWith('-');
    final digits = isNegative ? value.substring(1) : value;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return isNegative ? '-$buffer' : buffer.toString();
  }
}
