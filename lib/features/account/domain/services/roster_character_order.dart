/// Default order for full-roster reads; personal display-order projections stay separate.
List<T> rosterByItemLevel<T>(
  Iterable<T> characters,
  String? Function(T) itemLevel,
) {
  double level(T character) {
    final value = double.tryParse(
      itemLevel(character)?.replaceAll(',', '') ?? '',
    );
    return value != null && value.isFinite && value >= 0 ? value : -1;
  }

  final indexed = characters.indexed.toList()
    ..sort((a, b) {
      final comparison = level(b.$2).compareTo(level(a.$2));
      return comparison != 0 ? comparison : a.$1.compareTo(b.$1);
    });
  return List.unmodifiable(indexed.map((entry) => entry.$2));
}
