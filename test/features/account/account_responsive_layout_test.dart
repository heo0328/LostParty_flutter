import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/account_responsive_layout.dart';

void main() {
  test('member phone layout keeps two columns at default text size', () {
    for (final screen in [320.0, 393.0, 412.0]) {
      final outer = AccountResponsiveLayout.rosterWidth(screen - 32, 10);
      expect(
        AccountResponsiveLayout.cards(outer - 32, itemCount: 10).columns,
        2,
      );
    }
  });
  test(
    'roster bounds follow actual card count and scaled minimum without overflow',
    () {
      for (final width in [288.0, 358.0, 688.0, 868.0, 1408.0, 1568.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final count in [0, 1, 2, 7, 20]) {
            final outer = AccountResponsiveLayout.rosterWidth(
              width,
              count,
              textScale: scale,
            );
            expect(outer, lessThanOrEqualTo(width));
            final layout = AccountResponsiveLayout.cards(
              outer - 32,
              itemCount: count,
              textScale: scale,
            );
            expect(
              layout.cardWidth * layout.columns + (layout.columns - 1) * 12,
              lessThanOrEqualTo(outer - 32 + .001),
            );
            expect(layout.columns, lessThanOrEqualTo(count < 1 ? 1 : count));
          }
        }
      }
      expect(
        AccountResponsiveLayout.rosterWidth(1568, 2),
        lessThan(AccountResponsiveLayout.rosterWidth(1568, 7)),
      );
      expect(
        AccountResponsiveLayout.cards(1568, itemCount: 20).columns,
        greaterThan(4),
      );
    },
  );
  test('cards fit narrow, fold and wide spaces without stretching', () {
    for (final width in [140.0, 334.0, 752.0, 1336.0]) {
      final result = AccountResponsiveLayout.cards(width);
      expect(result.cardWidth, lessThanOrEqualTo(280));
      expect(
        result.cardWidth * result.columns +
            AccountResponsiveLayout.cardGap * (result.columns - 1),
        lessThanOrEqualTo(width),
      );
    }
    expect(AccountResponsiveLayout.cards(1336).columns, greaterThan(4));
  });

  test('comparison columns match available width', () {
    expect(AccountResponsiveLayout.cards(360).columns, 1);
    expect(AccountResponsiveLayout.cards(720).columns, 3);
    expect(AccountResponsiveLayout.cards(600).columns, 3);
    expect(AccountResponsiveLayout.cards(593).columns, 2);
    expect(AccountResponsiveLayout.cards(594).columns, 3);
    expect(AccountResponsiveLayout.cards(1200).columns, 6);
  });

  test('large text reduces columns instead of shrinking the content', () {
    final ordinary = AccountResponsiveLayout.cards(752);
    final enlarged = AccountResponsiveLayout.cards(752, textScale: 2);
    expect(enlarged.columns, lessThan(ordinary.columns));
    expect(enlarged.cardWidth, greaterThan(ordinary.cardWidth));
  });
}
