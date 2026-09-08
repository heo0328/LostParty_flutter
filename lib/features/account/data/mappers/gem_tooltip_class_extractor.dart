import 'dart:convert';

List<String> extractGemTooltipClassNames(
  Iterable<Object?> tooltipValues,
  Map<String, String> knownClassNames,
) {
  final result = <String>{};
  for (final tooltip in tooltipValues) {
    for (final text in _tooltipStrings(tooltip)) {
      final plainText = _stripMarkup(text);
      for (final match in RegExp(r'\[([^\[\]]+)\]').allMatches(plainText)) {
        final candidate = match.group(1)?.trim();
        if (candidate == null) {
          continue;
        }
        final canonical = knownClassNames[_normalize(candidate)];
        if (canonical != null) {
          result.add(canonical);
        }
      }
    }
  }
  return result.toList(growable: false)..sort();
}

Map<String, String> buildKnownGemClassNames(
  Iterable<({String apiClassName, Iterable<String> aliases})> classes,
) {
  return {
    for (final definition in classes)
      for (final name in [definition.apiClassName, ...definition.aliases])
        _normalize(name): definition.apiClassName,
  };
}

Iterable<String> _tooltipStrings(Object? value) sync* {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map || decoded is List) {
        yield* _tooltipStrings(decoded);
        return;
      }
    } on FormatException {
      // Some API fields contain plain tooltip text rather than encoded JSON.
    }
    yield trimmed;
    return;
  }
  if (value is Map) {
    for (final child in value.values) {
      yield* _tooltipStrings(child);
    }
    return;
  }
  if (value is Iterable) {
    for (final child in value) {
      yield* _tooltipStrings(child);
    }
  }
}

String _stripMarkup(String value) => value
    .replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '')
    .replaceAll('&nbsp;', ' ')
    .trim();

String _normalize(String value) => value.trim().toLowerCase();
