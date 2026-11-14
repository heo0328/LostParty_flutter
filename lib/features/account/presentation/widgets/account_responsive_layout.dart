import 'dart:math' as math;

/// Shared account layout rules. These depend on available space, not device type.
abstract final class AccountResponsiveLayout {
  static const cardGap = 12.0;
  static const toolsMaxWidth = 537.0;

  static ({int columns, double cardWidth}) cards(
    double availableWidth, {
    double textScale = 1,
  }) {
    final scale = math.max(1.0, textScale);
    final minimum = 156 * scale;
    final maximum = 208 * scale;
    final preferred = 184 * scale;
    final capacity = math.max(
      1,
      ((availableWidth + cardGap) / (minimum + cardGap)).floor(),
    );
    final columns = ((availableWidth + cardGap) / (preferred + cardGap))
        .round()
        .clamp(1, capacity);
    return (
      columns: columns,
      cardWidth: math.min(
        maximum,
        math.max(0, (availableWidth - cardGap * (columns - 1)) / columns),
      ),
    );
  }
}
