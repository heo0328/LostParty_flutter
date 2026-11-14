import 'dart:math' as math;

/// Shared account layout rules. These depend on available space, not device type.
abstract final class AccountResponsiveLayout {
  static const cardGap = 12.0;
  static const pageMaxWidth = 1600.0;
  static const refreshMaxWidth = 640.0;

  static double rosterWidth(
    double availableWidth,
    int count, {
    double textScale = 1,
  }) {
    final layout = cards(
      math.max(0, availableWidth - 32),
      textScale: textScale,
      itemCount: count,
    );
    final grid =
        layout.columns * layout.cardWidth + (layout.columns - 1) * cardGap;
    return math.min(
      availableWidth,
      math.max(320 * math.max(1, textScale), grid + 32),
    );
  }

  static ({int columns, double cardWidth}) cards(
    double availableWidth, {
    double textScale = 1,
    int? itemCount,
  }) {
    final scale = math.max(1.0, textScale);
    // Two readable columns on ordinary phones; accessibility enlargement may
    // still use a single column. Other card users retain their existing sizing.
    final compactMember =
        itemCount != null &&
        availableWidth >= 240 &&
        availableWidth < 392 &&
        scale == 1;
    final minimum = compactMember
        ? (availableWidth - cardGap) / 2
        : 190 * scale;
    final maximum = 280 * scale;
    final capacity = math.max(
      1,
      ((availableWidth + cardGap) / (minimum + cardGap)).floor(),
    );
    final columns = itemCount == null
        ? capacity
        : math.min(capacity, math.max(1, itemCount));
    return (
      columns: columns,
      cardWidth: math.min(
        maximum,
        math.max(0, (availableWidth - cardGap * (columns - 1)) / columns),
      ),
    );
  }
}
