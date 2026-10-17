class DisplayNumberFormatter {
  const DisplayNumberFormatter._();

  static String integer(num value) => _groupDigits(value.toInt().toString());

  /// Formats numeric API strings and numbers without changing their source.
  static String whole(Object? value, {String missing = '미확인'}) {
    final number = value is num
        ? value
        : value is String
        ? num.tryParse(value.replaceAll(',', '').trim())
        : null;
    return number == null || !number.isFinite ? missing : integer(number);
  }

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
