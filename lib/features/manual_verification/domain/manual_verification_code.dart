import 'dart:math';

class ManualVerificationCode {
  const ManualVerificationCode._();

  static const prefix = 'LP-';
  static const length = 6;
  static const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  static final _pattern = RegExp(r'^LP-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$');

  static String generate([Random? random]) {
    final source = random ?? Random.secure();
    final body = List.generate(
      length,
      (_) => alphabet[source.nextInt(alphabet.length)],
    ).join();
    return '$prefix$body';
  }

  static bool isValid(String value) => _pattern.hasMatch(value.trim().toUpperCase());

  static String normalize(String value) => value.trim().toUpperCase();
}
