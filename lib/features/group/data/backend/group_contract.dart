import 'dart:convert';
import 'group_wire_schema.g.dart';

/// Pinned group contract. Validates before a request or any permission is used.
class GroupContract {
  static final Map<String, dynamic> wire = jsonDecode(groupWireSchemaJson);
  static Map<String, dynamic> operation(String method, String path) {
    for (final raw in wire['operations'] as List) {
      final op = Map<String, dynamic>.from(raw as Map);
      final parts = (op['path'] as String).split('/');
      final actual = path.split('/');
      if (op['method'] != method || parts.length != actual.length) continue;
      if (!List.generate(
        parts.length,
        (i) => parts[i].startsWith('{')
            ? RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(actual[i])
            : parts[i] == actual[i],
      ).every((v) => v)) {
        continue;
      }
      return op;
    }
    throw const FormatException('Unknown group operation');
  }

  static void request(
    String method,
    String path,
    Map<String, dynamic> query,
    Object? body,
  ) {
    final op = operation(method, path);
    final params = op['query'] as List;
    if (query.keys.any((k) => !params.any((p) => p['name'] == k))) {
      throw const FormatException('Unknown group query');
    }
    for (final p in params) {
      if (p['required'] == true && !query.containsKey(p['name'])) {
        throw const FormatException('Missing group query');
      }
      if (query.containsKey(p['name'])) validate(p['schema'], query[p['name']]);
    }
    validate(op['request'], body);
  }

  static void response(String method, String path, int status, Object? body) {
    final schemas = operation(method, path)['responses'] as Map;
    if (!schemas.containsKey('$status')) {
      throw const FormatException('Unexpected group status');
    }
    validate(schemas['$status'], body);
  }

  static void validate(dynamic schema, dynamic value) {
    if (schema is! Map) throw const FormatException('Missing schema');
    if (schema.containsKey(r'$ref')) {
      return validate(
        wire['schemas'][(schema[r'$ref'] as String).split('/').last],
        value,
      );
    }
    if (schema['anyOf'] case final List options) {
      for (final option in options) {
        try {
          validate(option, value);
          return;
        } on FormatException {
          continue;
        }
      }
      throw const FormatException('Invalid group union');
    }
    if (schema.containsKey('const') && value != schema['const']) {
      throw const FormatException('Invalid constant');
    }
    if (schema['enum'] case final List values) {
      if (!values.contains(value)) throw const FormatException('Invalid enum');
    }
    switch (schema['type']) {
      case 'null':
        if (value != null) throw const FormatException('Expected null');
      case 'object':
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Expected object');
        }
        final props = schema['properties'] as Map? ?? {};
        for (final k in schema['required'] as List? ?? []) {
          if (!value.containsKey(k)) {
            throw const FormatException('Missing group field');
          }
        }
        if (schema['additionalProperties'] == false &&
            value.keys.any((k) => !props.containsKey(k))) {
          throw const FormatException('Unknown group field');
        }
        for (final k in value.keys) {
          if (props.containsKey(k)) validate(props[k], value[k]);
        }
      case 'array':
        if (value is! List) throw const FormatException('Expected list');
        if (schema['maxItems'] is num && value.length > schema['maxItems']) {
          throw const FormatException('Too many items');
        }
        for (final v in value) {
          validate(schema['items'], v);
        }
      case 'integer':
        if (value is! int) throw const FormatException('Expected integer');
        if (schema['minimum'] is num && value < schema['minimum'] ||
            schema['maximum'] is num && value > schema['maximum']) {
          throw const FormatException('Number out of range');
        }
      case 'boolean':
        if (value is! bool) throw const FormatException('Expected boolean');
      case 'string':
        if (value is! String) throw const FormatException('Expected string');
        if (schema['minLength'] is num && value.length < schema['minLength'] ||
            schema['maxLength'] is num && value.length > schema['maxLength']) {
          throw const FormatException('String out of range');
        }
        if (schema['pattern'] is String &&
            !RegExp(schema['pattern']).hasMatch(value)) {
          throw const FormatException('Invalid string');
        }
        if (schema['format'] == 'uuid' &&
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(value)) {
          throw const FormatException('Invalid UUID');
        }
        if (schema['format'] == 'date-time' &&
            DateTime.tryParse(value) == null) {
          throw const FormatException('Invalid date');
        }
    }
  }
}
