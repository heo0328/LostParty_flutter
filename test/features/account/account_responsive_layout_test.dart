import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/account_responsive_layout.dart';

void main() {
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
