import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/features/operator_access/domain/entities/operator_user.dart';
import 'package:lost_party/features/operator_access/domain/entities/operator_write_readiness.dart';
import 'package:lost_party/features/operator_access/domain/repositories/operator_access_repository.dart';
import 'package:lost_party/features/operator_access/presentation/pages/operator_user_detail_page.dart';
import 'package:lost_party/features/operator_access/presentation/pages/operator_user_list_page.dart';
import 'package:lost_party/features/settings/presentation/pages/settings_page.dart';

void main() {
  final user = OperatorUserSummary(
    playerId: 'player-123456',
    status: 'active',
    createdAt: DateTime.utc(2026, 8, 1),
    lastSeenAt: DateTime.utc(2026, 8, 27, 3, 30),
    hasVerifiedGameAccount: true,
  );

  testWidgets('일반 사용자 설정에는 운영자 진입점이 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          operatorAccessRepository: _FakeOperatorRepository(isOperator: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsOperatorUsers')), findsNothing);
    expect(
      find.byKey(const ValueKey('settingsOperatorManualVerification')),
      findsNothing,
    );
  });

  testWidgets('운영자 설정에는 사용자 확인 진입점이 표시된다', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) =>
              SettingsPage(operatorAccessRepository: _FakeOperatorRepository()),
          routes: [
            GoRoute(
              path: 'operator/users',
              builder: (_, _) => const Scaffold(body: Text('운영자 목록')),
            ),
            GoRoute(
              path: 'operator/manual-verification',
              builder: (_, _) => const Scaffold(body: Text('수동 인증 대기')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settingsOperatorUsers')));
    await tester.pumpAndSettle();

    expect(find.text('운영자 목록'), findsOneWidget);
  });

  testWidgets('운영자 설정에는 수동 인증 확인 진입점이 표시된다', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) =>
              SettingsPage(operatorAccessRepository: _FakeOperatorRepository()),
          routes: [
            GoRoute(
              path: 'operator/manual-verification',
              builder: (_, _) => const Scaffold(body: Text('수동 인증 대기')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('settingsOperatorManualVerification')),
    );
    await tester.pumpAndSettle();

    expect(find.text('수동 인증 대기'), findsOneWidget);
  });

  testWidgets('사용자 목록은 대표 미지정과 마지막 접속을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorUserListPage(
          repository: _FakeOperatorRepository(users: [user]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('대표 캐릭터 지정 안 됨'), findsOneWidget);
    expect(find.textContaining('마지막 접속 8/27(목) 12:30'), findsOneWidget);
    expect(find.textContaining('인증 계정 있음'), findsOneWidget);
  });

  testWidgets('사용자 목록은 여러 계정의 대표 캐릭터 요약을 표시한다', (tester) async {
    final representedUser = OperatorUserSummary(
      playerId: user.playerId,
      status: user.status,
      createdAt: user.createdAt,
      lastSeenAt: user.lastSeenAt,
      hasVerifiedGameAccount: true,
      representativeCharacterName: '가나다 외 1개',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorUserListPage(
          repository: _FakeOperatorRepository(users: [representedUser]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('가나다 외 1개'), findsOneWidget);
  });

  testWidgets('직접 진입한 일반 사용자에게 권한 없음 화면을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorUserListPage(
          repository: _FakeOperatorRepository(isOperator: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영자 권한이 없습니다.'), findsOneWidget);
  });

  testWidgets('사용자 상세는 서버 계정과 캐릭터만 표시한다', (tester) async {
    final detail = OperatorUserDetail(
      user: user,
      gameAccounts: const [
        OperatorGameAccountSummary(
          gameAccountId: 'account-1',
          status: 'active',
          ownershipStatus: 'active',
          lookupCharacterName: '인증점요',
          representativeCharacterId: 'character-1',
          characters: [
            OperatorCharacterSummary(
              characterId: 'character-1',
              characterName: '인증점요',
              serverName: '루페온',
              className: '바드',
              status: 'active',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorUserDetailPage(
          playerId: user.playerId,
          repository: _FakeOperatorRepository(detail: detail),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('인증점요'), findsOneWidget);
    await tester.tap(find.text('인증점요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('대표 인증점요'), findsOneWidget);
    expect(find.textContaining('루페온 · 바드'), findsOneWidget);
  });
}

class _FakeOperatorRepository implements OperatorAccessRepository {
  _FakeOperatorRepository({
    this.isOperator = true,
    this.users = const [],
    this.detail,
  });

  final bool isOperator;
  final List<OperatorUserSummary> users;
  final OperatorUserDetail? detail;

  @override
  Future<bool> isCurrentPlayerOperator() async => isOperator;

  @override
  Future<OperatorWriteReadiness> loadWriteReadiness() async => OperatorWriteReadiness(
    authUid: 'auth-1',
    playerId: 'player-1',
    bindingActive: isOperator,
    playerExists: isOperator,
    playerActive: isOperator,
    assignmentActive: isOperator,
  );

  @override
  Future<OperatorUserDetail?> loadUserDetail(String playerId) async => detail;

  @override
  Future<List<OperatorUserSummary>> loadUsers({int limit = 50}) async => users;
}
