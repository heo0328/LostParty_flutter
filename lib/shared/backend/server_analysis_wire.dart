import 'dart:convert';
import 'server_analysis_schema.g.dart';

/// Closed validation of the published analysis projection; semantic fences live
/// in its DTOs. This does not negotiate or accept an older wire shape.
class ServerAnalysisWire {
  static final Map<String, dynamic> definitions = jsonDecode(
    serverAnalysisSchemaJson,
  );
  static void check(bool value) {
    if (!value) throw const FormatException('Invalid server analysis response');
  }

  static void definition(String name, Object? value) =>
      validate(definitions[name], value);
  static void validate(dynamic s, dynamic v) {
    check(s is Map);
    if (s[r'$ref'] is String) {
      definition((s[r'$ref'] as String).split('/').last, v);
      return;
    }
    if (s['anyOf'] is List) {
      var valid = false;
      for (final option in s['anyOf']) {
        try {
          validate(option, v);
          valid = true;
          break;
        } on FormatException {
          continue;
        }
      }
      check(valid);
    }
    if (s.containsKey('const')) check(v == s['const']);
    if (s['enum'] is List) check(s['enum'].contains(v));
    switch (s['type']) {
      case 'object':
        check(v is Map<String, dynamic>);
      case 'array':
        check(v is List);
      case 'string':
        check(v is String);
      case 'integer':
        check(v is int);
      case 'boolean':
        check(v is bool);
      case 'null':
        check(v == null);
    }
    if (v is Map<String, dynamic>) {
      final properties = s['properties'] as Map? ?? {};
      check((s['required'] as List? ?? []).every(v.containsKey));
      if (s['additionalProperties'] == false) {
        check(v.keys.every(properties.containsKey));
      }
      for (final e in v.entries) {
        if (properties.containsKey(e.key)) validate(properties[e.key], e.value);
      }
    }
    if (v is List) {
      check(
        v.length >= (s['minItems'] ?? 0) &&
            v.length <= (s['maxItems'] ?? 100000),
      );
      if (s['items'] != null) {
        for (final item in v) {
          validate(s['items'], item);
        }
      }
    }
    if (v is int) {
      check(
        (s['minimum'] == null || v >= s['minimum']) &&
            (s['maximum'] == null || v <= s['maximum']),
      );
    }
    if (v is String) {
      check(
        v.runes.length >= (s['minLength'] ?? 0) &&
            v.runes.length <= (s['maxLength'] ?? 1000000),
      );
      if (s['pattern'] is String) check(RegExp(s['pattern']).hasMatch(v));
      if (s['format'] == 'uuid') {
        check(
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(v),
        );
      }
      if (s['format'] == 'date-time') {
        check(
          RegExp(r'(Z|\+00:00)$').hasMatch(v) && DateTime.tryParse(v) != null,
        );
      }
    }
  }
}
