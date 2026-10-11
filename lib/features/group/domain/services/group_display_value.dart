/// Shared sanitization for informational snapshots, never IDs or permissions.
abstract final class GroupDisplayValue {
  static String? text(Object? value) {
    if (value is! String) return null;
    final clean = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    if (clean.isEmpty) return null;
    return String.fromCharCodes(clean.runes.take(256));
  }

  static double? number(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return value.toDouble();
  }
}
