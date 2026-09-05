import 'dart:math';

/// 계약 §7. 초대코드 값 객체. 문서 ID는 정규화된 코드 자체다.
///
class GroupJoinCode {
  const GroupJoinCode._(this.value);

  /// Crockford 계열에서 혼동 문자 `0O1Il`을 뺀 32자 알파벳(5비트/문자).
  static const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static const length = 6;
  static const legacyLength = 20;

  final String value;

  /// 앞뒤 공백 제거·대문자화 후 알파벳·길이를 검사한다. 실패하면 null.
  static GroupJoinCode? tryParse(String raw) {
    final normalized = normalize(raw);
    if (!_isValidNormalized(normalized)) return null;
    return GroupJoinCode._(normalized);
  }

  /// 입력 정규화. 유효성 검사는 [tryParse]가 한다.
  static String normalize(String raw) => raw.trim().toUpperCase();

  /// 암호학적 난수로 새 코드를 만든다. [random]은 테스트 주입용이다.
  static GroupJoinCode generate({Random? random}) {
    final source = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[source.nextInt(alphabet.length)]);
    }
    return GroupJoinCode._(buffer.toString());
  }

  static bool _isValidNormalized(String value) {
    if (value.length != length && value.length != legacyLength) return false;
    for (final unit in value.codeUnits) {
      final char = String.fromCharCode(unit);
      if (!alphabet.contains(char)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is GroupJoinCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
