import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/bootstrap/app_startup_result.dart';
import 'package:lost_party/app/bootstrap/lost_party_app_entry.dart';
import 'package:lost_party/features/account_recovery/domain/entities/account_recovery_status.dart';
import 'package:lost_party/features/player/domain/entities/player_session.dart';

void main() {
  final session = PlayerSession(authUid: 'auth-uid', playerId: 'player-1');

  testWidgets('기존 인증 세션은 선택 화면 없이 기존 앱으로 진입한다', (tester) async {
    await tester.pumpWidget(
      LostPartyAppEntry(
        initialize: () async => AppStartupReady(session),
        recover: () async => null,
        startNew: () async => session,
        appBuilder: (_, ready) => MaterialApp(home: Text(ready.playerId)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    expect(find.text('player-1'), findsOneWidget);
    expect(find.text('Google로 기존 계정 복구'), findsNothing);
  });

  testWidgets('인증 세션이 없으면 명시적 선택 전 새 익명 사용자를 만들지 않는다', (tester) async {
    var startNewCalls = 0;
    await tester.pumpWidget(
      LostPartyAppEntry(
        initialize: () async => const AppStartupAuthenticationRequired(),
        recover: () async => null,
        startNew: () async {
          startNewCalls += 1;
          return session;
        },
        appBuilder: (_, ready) => MaterialApp(home: Text(ready.playerId)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    expect(find.text('Google로 기존 계정 복구'), findsOneWidget);
    expect(startNewCalls, 0);

    await tester.tap(find.byKey(const ValueKey('startNewAccountButton')));
    await tester.pumpAndSettle();
    expect(startNewCalls, 0);
    await tester.tap(
      find.byKey(const ValueKey('confirmStartNewAccountButton')),
    );
    await tester.pumpAndSettle();

    expect(startNewCalls, 1);
    expect(find.text('player-1'), findsOneWidget);
  });

  testWidgets('연결되지 않은 Google 계정은 새 사용자로 전환하지 않는다', (tester) async {
    await tester.pumpWidget(
      LostPartyAppEntry(
        initialize: () async => const AppStartupAuthenticationRequired(),
        recover: () async => throw const AccountRecoveryException(
          AccountRecoveryFailureReason.recoveryAccountNotFound,
        ),
        startNew: () async => session,
        appBuilder: (_, ready) => MaterialApp(home: Text(ready.playerId)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recoverExistingAccountButton')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('연결된 기존 LOSTPARTY 사용자가 없습니다'), findsOneWidget);
    expect(find.text('player-1'), findsNothing);
  });
}
