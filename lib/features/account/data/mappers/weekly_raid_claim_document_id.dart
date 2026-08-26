import 'dart:convert';

class WeeklyRaidClaimDocumentId {
  const WeeklyRaidClaimDocumentId._();

  static String create({
    required String cycleKey,
    required String characterId,
    required String raidId,
  }) {
    return [cycleKey, characterId, raidId].map(_encode).join('~');
  }

  static String _encode(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be blank');
    }
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }
}
