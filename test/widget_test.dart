import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/domain/entities/game_account_verification.dart';
import 'package:lost_party/features/account/domain/repositories/account_ownership_status_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/game_account_verification_gateway.dart';
import 'package:lost_party/features/player/domain/entities/player_session.dart';
import 'package:lost_party/main.dart';

import 'support/party_read_fakes.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Raid status is the initial tab', (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('레이드 현황'), findsNWidgets(2));
    expect(find.text('진행 중'), findsOneWidget);
    expect(find.text('진행 중인 레이드가 없습니다.'), findsOneWidget);
    expect(find.text('내 계정'), findsOneWidget);
    expect(find.text('레이드 모집'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('Navigation bar opens account and recruitment tabs', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await _tapDestination(tester, '내 계정');
    expect(find.text('내 계정'), findsNWidgets(2));

    await _tapDestination(tester, '레이드 모집');
    await tester.pumpAndSettle();

    expect(find.text('파티 모집'), findsOneWidget);
    expect(find.text('레이드 모집'), findsOneWidget);
    expect(find.text('현재 모집 중인 파티가 없습니다.'), findsOneWidget);
    expect(find.text('모집 만들기'), findsOneWidget);
  });

  testWidgets('Horizontal swipe changes only the raid status page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(TabBarView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('신청 중인 레이드가 없습니다.'), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 0);

    await _tapDestination(tester, '내 계정');
    await _tapDestination(tester, '레이드 현황');

    expect(find.text('신청 중인 레이드가 없습니다.'), findsOneWidget);
  });

  testWidgets('Settings opens verification and API token pages', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await _tapDestination(tester, '설정');

    await tester.tap(
      find.byKey(const ValueKey('settingsGameAccountVerification')),
    );
    await tester.pumpAndSettle();
    expect(find.text('내 게임계정 인증'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settingsGameAccountVerification')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settingsApiToken')));
    await tester.pumpAndSettle();
    expect(find.text('API 토큰'), findsOneWidget);

    await _tapDestination(tester, '설정');
    expect(find.text('API 토큰'), findsNothing);
    expect(find.byKey(const ValueKey('settingsApiToken')), findsOneWidget);
  });

  testWidgets(
    'Missing token dialog can be dismissed without blocking the app',
    (WidgetTester tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle();

      await _tapDestination(tester, '내 계정');
      await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
      await tester.pumpAndSettle();

      expect(find.text('API 토큰 필요'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('API 토큰 필요'), findsNothing);

      await _tapDestination(tester, '레이드 모집');

      expect(find.text('파티 모집'), findsOneWidget);
      expect(find.text('레이드 모집'), findsOneWidget);
    },
  );

  testWidgets('Token can be registered without exposing it again', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await _tapDestination(tester, '내 계정');
    await tester.tap(find.byKey(const ValueKey('loadAccountDataButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('토큰 등록'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('apiTokenField')),
      'secret-jwt-value',
    );
    await tester.tap(find.text('토큰 저장'));
    await tester.pumpAndSettle();

    expect(find.text('내 계정'), findsNWidgets(2));
    expect(find.text('secret-jwt-value'), findsNothing);

    await tester.tap(find.byTooltip('API 토큰 설정'));
    await tester.pumpAndSettle();

    expect(find.text('토큰 등록됨'), findsOneWidget);
    expect(find.text('secret-jwt-value'), findsNothing);

    await tester.tap(find.text('토큰 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('API 토큰을 삭제할까요?'), findsOneWidget);
    expect(
      find.textContaining('Lost Ark API를 사용하는 기능이 정상 작동하지 않습니다.'),
      findsOneWidget,
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('토큰 등록됨'), findsOneWidget);

    await tester.tap(find.text('토큰 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('내 계정'), findsNWidgets(2));
    await tester.tap(find.byTooltip('API 토큰 설정'));
    await tester.pumpAndSettle();
    expect(find.text('토큰 미등록'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  final database = AccountDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    MyApp(
      playerSession: PlayerSession(
        authUid: 'test-auth-uid',
        playerId: 'test-player',
      ),
      accountDatabase: database,
      ownershipStatusGateway: _AccountOwnershipStatusGateway(),
      gameAccountVerificationGateway: _GameAccountVerificationGateway(),
      partyReadRepository: FakePartyReadRepository(),
      partyEventSyncService: FakePartyEventSyncService(),
    ),
  );
}

class _AccountOwnershipStatusGateway
    implements AccountOwnershipStatusGateway {
  @override
  Future<Map<String, String>> loadStatuses(
    Iterable<String> gameAccountIds,
  ) async => const {};
}

class _GameAccountVerificationGateway
    implements GameAccountVerificationGateway {
  @override
  GameAccountVerificationChallenge? get activeChallenge => null;

  @override
  Future<GameAccountVerificationChallenge> start({
    required String characterName,
    required String source,
    int? localAccountId,
  }) async => GameAccountVerificationChallenge(
    challengeId: 'test-challenge',
    characterName: characterName,
    requiredUnequippedSlots: const ['투구'],
    expiresAt: DateTime(2100),
  );

  @override
  Future<GameAccountVerificationResult> confirm(String challengeId) async =>
      const GameAccountVerificationResult(status: 'expired');
}

Future<void> _tapDestination(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  await tester.tap(destination);
  await tester.pumpAndSettle();
}
