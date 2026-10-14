import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/app_bootstrap.dart';

void main() {
  const session = 'player-1';

  testWidgets('초기화가 끝날 때까지 앱을 만들지 않는다', (tester) async {
    final initialization = Completer<String>();

    await tester.pumpWidget(
      AppBootstrap<String>(
        initialize: () => initialization.future,
        appBuilder: (_, ready) => MaterialApp(home: Text('준비된 앱 $ready')),
      ),
    );

    expect(find.byKey(const Key('app-bootstrap-loading')), findsOneWidget);
    expect(find.text('준비된 앱 player-1'), findsNothing);

    initialization.complete(session);
    await tester.pumpAndSettle();

    expect(find.text('준비된 앱 player-1'), findsOneWidget);
  });

  testWidgets('초기화 실패를 표시하고 다시 시도한다', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap<String>(
        initialize: () async {
          attempts += 1;
          if (attempts == 1) throw StateError('초기화 실패');
          return session;
        },
        appBuilder: (_, ready) => MaterialApp(home: Text('준비된 앱 $ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('앱 연결을 준비하지 못했습니다.'), findsOneWidget);
    expect(find.text('준비된 앱 player-1'), findsNothing);

    await tester.tap(find.byKey(const Key('app-bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('준비된 앱 player-1'), findsOneWidget);
  });

  testWidgets('초기화가 빨라도 최소 진입 화면 시간을 보장한다', (tester) async {
    await tester.pumpWidget(
      AppBootstrap<String>(
        initialize: () async => session,
        minimumLoadingDuration: const Duration(milliseconds: 2200),
        loadingBuilder: (_) =>
            const MaterialApp(home: SizedBox(key: Key('branded-entry-screen'))),
        appBuilder: (_, ready) => MaterialApp(home: Text('준비된 앱 $ready')),
      ),
    );

    await tester.pump();
    expect(find.byKey(const Key('branded-entry-screen')), findsOneWidget);
    expect(find.text('준비된 앱 player-1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2199));
    expect(find.byKey(const Key('branded-entry-screen')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('준비된 앱 player-1'), findsOneWidget);
  });
}
