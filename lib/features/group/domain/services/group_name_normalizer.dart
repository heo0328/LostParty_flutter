import '../entities/group_create_command.dart';

/// 계약 §4.1 검색 Projection 정규화. Unicode NFC, 앞뒤 공백 제거, 영문 소문자화를
/// 그룹명과 대표 캐릭터명에 같은 규칙으로 적용한다. 이 값은 권한 판정이나
/// 식별 키로 사용하지 않는다.
class GroupNameNormalizer {
  const GroupNameNormalizer();

  static const _sBase = 0xAC00;
  static const _lBase = 0x1100;
  static const _vBase = 0x1161;
  static const _tBase = 0x11A7;
  static const _lCount = 19;
  static const _vCount = 21;
  static const _tCount = 28;
  static const _sCount = _lCount * _vCount * _tCount;

  String normalize(String value) => _composeHangul(value).trim().toLowerCase();

  String defaultName(String representativeCharacterName) =>
      '${_composeHangul(representativeCharacterName).trim()}의 그룹';

  /// 직접 입력 그룹명은 trim 후 1~20자이며 줄바꿈·제어문자를 포함하지 않는다.
  bool isValidDisplayName(String value) {
    final trimmed = _composeHangul(value).trim();
    if (trimmed.length < GroupCreateCommand.minNameLength ||
        trimmed.length > GroupCreateCommand.maxNameLength) {
      return false;
    }
    return !trimmed.runes.any(
      (rune) => rune < 0x20 || rune == 0x7f || rune == 0x2028 || rune == 0x2029,
    );
  }

  String displayName(String value) => _composeHangul(value).trim();

  /// IME·플랫폼에 따라 분리된 한글 자모를 표준 NFC 음절로 합성한다.
  /// Dart 코어에는 정규화 API가 없어 계약이 요구하는 한글 조합만 직접 처리한다.
  String _composeHangul(String value) {
    final composed = <int>[];
    for (final rune in value.runes) {
      final last = composed.isEmpty ? null : composed.last;
      if (last != null) {
        if (last >= _lBase &&
            last < _lBase + _lCount &&
            rune >= _vBase &&
            rune < _vBase + _vCount) {
          composed[composed.length - 1] =
              _sBase +
              ((last - _lBase) * _vCount + (rune - _vBase)) * _tCount;
          continue;
        }
        if (last >= _sBase &&
            last < _sBase + _sCount &&
            (last - _sBase) % _tCount == 0 &&
            rune > _tBase &&
            rune < _tBase + _tCount) {
          composed[composed.length - 1] = last + (rune - _tBase);
          continue;
        }
      }
      composed.add(rune);
    }
    return String.fromCharCodes(composed);
  }
}
