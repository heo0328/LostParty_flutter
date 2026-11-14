import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/presentation/widgets/account_tools_grid.dart';
import 'package:lost_party/features/account/presentation/widgets/account_page_typography.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final width in [320.0, 720.0, 1400.0]) {
      testWidgets('content tools fit width=$width scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: AccountPageTypography(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Builder(
                  builder: (context) => Scaffold(
                    body: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                AccountToolsGrid.preferredWidth(context) + 32,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: _Tools(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final label in AccountToolsGrid.labels) {
          expect(find.text(label), findsOneWidget);
        }
        final style = Theme.of(
          tester.element(find.byType(AccountToolsGrid)),
        ).textTheme;
        expect(style.bodyMedium!.fontSize, 16);
        expect(style.bodySmall!.fontSize, 14);
        final first = tester.getRect(find.byType(FilledButton).first);
        expect(first.height, greaterThanOrEqualTo(48));
        if (width == 1400) {
          final second = tester.getRect(find.byType(FilledButton).at(1));
          expect(second.top, first.top);
          expect(second.left - first.right, closeTo(16, 0.1));
        }
      });
    }
  }
}

class _Tools extends StatelessWidget {
  const _Tools();
  @override
  Widget build(BuildContext context) => AccountToolsGrid(
    onVerify: () {},
    onKey: () {},
    onHistory: () {},
    onRefresh: () {},
  );
}
