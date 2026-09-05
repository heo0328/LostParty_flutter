import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lost_party/app/shell/app_shell.dart';
import 'package:lost_party/features/account/domain/entities/game_account_verification.dart';
import 'package:lost_party/features/account/domain/services/startup_character_refresh_orchestrator.dart';
import 'package:lost_party/features/manual_verification/domain/entities/manual_verification_request.dart';
import 'package:lost_party/features/manual_verification/domain/repositories/manual_verification_repository.dart';
import 'package:lost_party/features/manual_verification/presentation/manual_verification_dispute_alert.dart';

void main() {
  final dispute = ManualVerificationRequest(
    id: 'dispute-1',
    requesterPlayerId: 'claimer',
    targetIdentityKey: 'key',
    localAccountLabelSnapshot: '메인 계정',
    proofServerName: '루페온',
    proofCharacterName: '이슈아이',
    verificationCode: 'LP-7K4M2Q',
    status: ManualVerificationStatus.awaitingOwnerResponse,
    attemptNumberForTarget: 1,
    totalAttemptNumberForPlayer: 1,
    createdAt: DateTime.utc(2026, 8, 28, 3),
    expiresAt: DateTime.utc(2026, 8, 30, 3),
    ownerResponseDeadlineAt: DateTime.utc(2026, 8, 30, 3),
  );

  testWidgets('탭 이동 시 방어 대기 분쟁이 있으면 앱 실행당 한 번 알림을 띄운다', (
    tester,
  ) async {
    final repository = _FakeManualRepository(disputes: [dispute]);
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(
            navigationShell: navigationShell,
            manualVerificationRepository: repository,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: Text('home')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('settings')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('소유권 방어 필요'), findsNothing);

    await tester.tap(find.text('내 계정'));
    await tester.pumpAndSettle();

    expect(find.text('소유권 방어 필요'), findsOneWidget);
    expect(find.textContaining('메인 계정'), findsOneWidget);

    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('레이드 현황'));
    await tester.pumpAndSettle();

    expect(find.text('소유권 방어 필요'), findsNothing);
  });

  testWidgets('분쟁 알림에서 수동 인증으로 이동할 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showManualVerificationDisputeAlert(
                context,
                disputes: [dispute],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('수동 인증으로 이동'), findsOneWidget);
  });

  testWidgets('시작 Character 갱신 중에만 내 계정 탭 인디케이터를 표시한다', (
    tester,
  ) async {
    final refreshRunner = _FakeStartupCharacterRefreshRunner();
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(
            navigationShell: navigationShell,
            startupCharacterRefreshRunner: refreshRunner,
          ),
          branches: [
            for (var index = 0; index < 4; index++)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: index == 0 ? '/' : '/tab-$index',
                    builder: (context, state) => Scaffold(
                      body: Text('tab $index'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('startupCharacterRefreshIndicator')),
      findsNothing,
    );

    refreshRunner.emit(StartupCharacterRefreshPhase.running);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('startupCharacterRefreshIndicator')),
      findsWidgets,
    );

    refreshRunner.emit(StartupCharacterRefreshPhase.completed);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('startupCharacterRefreshIndicator')),
      findsNothing,
    );
  });
}

class _FakeStartupCharacterRefreshRunner
    implements StartupCharacterRefreshRunner {
  final StreamController<StartupCharacterRefreshState> _states =
      StreamController.broadcast(sync: true);
  StartupCharacterRefreshState _state =
      const StartupCharacterRefreshState.idle();

  @override
  StartupCharacterRefreshState get state => _state;

  @override
  Stream<StartupCharacterRefreshState> get states => _states.stream;

  void emit(StartupCharacterRefreshPhase phase) {
    _state = StartupCharacterRefreshState(
      phase: phase,
      totalCount: phase == StartupCharacterRefreshPhase.idle ? 0 : 1,
      completedCount: phase == StartupCharacterRefreshPhase.completed ? 1 : 0,
      failedCount: 0,
    );
    _states.add(_state);
  }

  @override
  Future<StartupCharacterRefreshReport> runOnce() async =>
      const StartupCharacterRefreshReport(items: []);

  @override
  Future<void> dispose() => _states.close();
}

class _FakeManualRepository implements ManualVerificationRepository {
  _FakeManualRepository({required this.disputes});

  final List<ManualVerificationRequest> disputes;

  @override
  Stream<List<ManualVerificationRequest>> watchIncomingDisputes() =>
      Stream.value(disputes);

  @override
  Future<ManualVerificationRequest> createRequest({
    required int localAccountId,
    required String localAccountLabel,
    required String proofServerName,
    required String proofCharacterName,
    String? proofClassName,
    String? targetGameAccountId,
    Iterable<String> rosterIdentityKeys = const [],
    String? defenseOfRequestId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancelRequest(String requestId) => throw UnimplementedError();

  @override
  Future<GameAccountVerificationResult> loadApprovedResult(String requestId) =>
      throw UnimplementedError();

  @override
  Future<ManualVerificationReviewContext> loadReviewContext(
    ManualVerificationRequest request,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<ManualVerificationRequest>> loadPendingQueue() =>
      throw UnimplementedError();

  @override
  Future<ManualVerificationRequest> reissueRequest(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> reviewBlock({
    required String requestId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> reviewCancel({
    required String requestId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<GameAccountVerificationResult> reviewApprove(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> reviewApproveDefense(String defenseRequestId) =>
      throw UnimplementedError();

  @override
  Future<GameAccountVerificationResult> reviewRejectDefense(
    String defenseRequestId,
  ) => throw UnimplementedError();

  @override
  Future<GameAccountVerificationResult> reviewForceApprove(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> syncExpiredDisputes() async {}

  @override
  Stream<List<ManualVerificationRequest>> watchMyRequests() =>
      Stream.value(const []);

  @override
  Future<GameAccountVerificationResult> reviewApproveUnowned(
    String requestId,
  ) =>
      reviewApprove(requestId);
}
