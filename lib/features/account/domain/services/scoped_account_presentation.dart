import '../role_summary.dart';
import '../scoped_cache_models.dart';

/// The caller supplies restored or explicitly pending preferences for every row.
/// No name-based merge or implicit defaults for an unqueried character.
class ScopedPresentationItem {
  const ScopedPresentationItem(
    this.ref,
    this.character,
    this.preferences, {
    this.itemLevel,
  });
  final ScopedCharacterRef ref;
  final CacheCharacterObservation character;
  final PreferenceValues preferences;
  final double? itemLevel;
}

List<ScopedPresentationItem> projectScopedAccountPresentation({
  required List<ScopedPresentationItem> items,
  required StorageScope scope,
  required String accountId,
  required String? representativeId,
  required int visibleCount,
}) {
  cacheRequire(visibleCount >= 1 && visibleCount <= 200);
  final ids = <String>{};
  for (final item in items) {
    cacheRequire(
      item.ref.scope == scope &&
          item.ref.accountId == accountId &&
          item.character.accountId == accountId &&
          item.ref.characterId == item.character.characterId &&
          ids.add(item.ref.characterId),
      'IDENTITY_CONFLICT',
    );
    cacheRequire(
      item.itemLevel == null ||
          (item.itemLevel!.isFinite && item.itemLevel! >= 0),
    );
  }
  int nullable<T extends Comparable<T>>(T? a, T? b) => a == null
      ? (b == null ? 0 : 1)
      : b == null
      ? -1
      : a.compareTo(b);
  final visible = items.where((i) => i.preferences.visible).toList();
  visible.sort((a, b) {
    final representative =
        (b.ref.characterId == representativeId ? 1 : 0) -
        (a.ref.characterId == representativeId ? 1 : 0);
    if (representative != 0) return representative;
    final rank = nullable<num>(
      a.preferences.displayOrder,
      b.preferences.displayOrder,
    );
    if (rank != 0) return rank;
    final power = a.itemLevel == null
        ? (b.itemLevel == null ? 0 : 1)
        : b.itemLevel == null
        ? -1
        : b.itemLevel!.compareTo(a.itemLevel!);
    if (power != 0) return power;
    final name = a.character.characterName.compareTo(b.character.characterName);
    return name != 0 ? name : a.ref.characterId.compareTo(b.ref.characterId);
  });
  return List.unmodifiable(visible.take(visibleCount));
}
