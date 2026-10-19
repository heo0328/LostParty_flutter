import 'server_account_verification.dart';

/// Strict V2 wire checks. V1 parsing and request digests remain unchanged.
void ownershipRequire(bool condition) {
  if (!condition) throw const FormatException('Invalid ownership contract.');
}

Map<String, dynamic> ownershipObject(Object? value, Set<String> fields) {
  ownershipRequire(value is Map<String, dynamic>);
  final json = value as Map<String, dynamic>;
  ownershipRequire(
    json.length == fields.length && fields.every(json.containsKey),
  );
  return json;
}

int ownershipVersion(Object? value) {
  ownershipRequire(value is int && value >= 1);
  return value as int;
}

String ownershipName(Object? value) {
  ownershipRequire(value is String);
  final name = (value as String).trim();
  ownershipRequire(
    name.isNotEmpty &&
        name.runes.length <= 64 &&
        !RegExp(r'[\x00-\x1f\x7f]').hasMatch(name),
  );
  return name;
}

String ownershipChoice(Object? value, Set<String> choices) {
  ownershipRequire(value is String && choices.contains(value));
  return value as String;
}

String? ownershipNullableChoice(Object? value, Set<String> choices) =>
    value == null ? null : ownershipChoice(value, choices);

String? ownershipNullableId(Object? value) =>
    value == null ? null : verificationUuid(value);

DateTime ownershipTime(Object? value) {
  ownershipRequire(
    value is String &&
        RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
        ).hasMatch(value),
  );
  final time = DateTime.parse(value as String);
  // DateTime.parse normalizes invalid calendar dates; reject that normalization.
  ownershipRequire(
    time.toIso8601String().substring(0, 19) == value.substring(0, 19),
  );
  return time;
}

DateTime? ownershipNullableTime(Object? value) =>
    value == null ? null : ownershipTime(value);

List<String> ownershipStrings(
  Object? value,
  String Function(Object?) decode, {
  int min = 0,
  int? max,
}) {
  ownershipRequire(value is List);
  final items = (value as List).map(decode).toList();
  ownershipRequire(
    items.length >= min &&
        (max == null || items.length <= max) &&
        items.toSet().length == items.length,
  );
  return List.unmodifiable(items);
}

Map<String, dynamic> ownershipFreeze(Map<String, dynamic> json) =>
    Map.unmodifiable(
      json.map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic>
              ? ownershipFreeze(value)
              : value is List
              ? List<Object?>.unmodifiable(value)
              : value,
        ),
      ),
    );

VerificationTarget ownershipTarget(Object? value) {
  final json = ownershipObject(value, {'server_name', 'character_name'});
  return VerificationTarget(
    serverName: ownershipName(json['server_name']),
    characterName: ownershipName(json['character_name']),
  );
}
