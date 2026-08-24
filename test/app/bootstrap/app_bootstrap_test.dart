import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/app_bootstrap.dart';

void main() {
  testWidgets('초기화가 끝날 때까지 앱을 만들지 않는다', (tester) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => initialization.future,
        appBuilder: (_) => const MaterialApp(home: Text('준비된 앱')),
      ),
    );

    expect(find.byKey(const Key('firebase-bootstrap-loading')), findsOneWidget);
    expect(find.text('준비된 앱'), findsNothing);

    initialization.complete();
    await tester.pumpAndSettle();

    expect(find.text('준비된 앱'), findsOneWidget);
  });

  testWidgets('초기화 실패를 표시하고 다시 시도한다', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap(
        initialize: () async {
          attempts += 1;
          if (attempts == 1) throw StateError('초기화 실패');
        },
        appBuilder: (_) => const MaterialApp(home: Text('준비된 앱')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('앱 연결을 준비하지 못했습니다.'), findsOneWidget);
    expect(find.text('준비된 앱'), findsNothing);

    await tester.tap(find.byKey(const Key('firebase-bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('준비된 앱'), findsOneWidget);
  });
}
