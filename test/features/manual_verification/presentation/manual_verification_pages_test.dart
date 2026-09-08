import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/game_account_verification.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/entities/server_account_identity_binding.dart';
import 'package:lost_party/features/account/domain/repositories/account_identity_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/manual_verification/domain/entities/manual_verification_request.dart';
import 'package:lost_party/features/manual_verification/domain/repositories/manual_verification_repository.dart';
import 'package:lost_party/features/manual_verification/presentation/pages/manual_verification_page.dart';
import 'package:lost_party/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart';
import 'package:lost_party/features/manual_verification/presentation/pages/operator_manual_verification_queue_page.dart';
import 'package:lost_party/features/operator_access/domain/entities/operator_user.dart';
import 'package:lost_party/features/operator_access/domain/entities/operator_write_readiness.dart';
import 'package:lost_party/features/operator_access/domain/repositories/operator_access_repository.dart';

void main() {
  final request = ManualVerificationRequest(
    id: 'req-1',
    requesterPlayerId: 'player-1',
    targetIdentityKey: 'key',
    localAccountLabelSnapshot: '메인 계정',
    proofServerName: '루페온',
    proofCharacterName: '이슈아이',
    proofClassName: '도화가',
    verificationCode: 'LP-7K4M2Q',
    status: ManualVerificationStatus.pendingProof,
    attemptNumberForTarget: 2,
    totalAttemptNumberForPlayer: 3,
    createdAt: DateTime.utc(2026, 8, 28, 3),
    expiresAt: DateTime.utc(2026, 8, 30, 3),
  );

  testWidgets('사용자 화면은 코드 발급과 오픈카톡 안내만 표시한다', (tester) async {
    final repository = _FakeManualRepository(requests: [request]);
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _FakeAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manualVerificationCompletionNotice')),
      findsOneWidget,
    );
    expect(
      find.textContaining('이 페이지에 다시 진입해야 계정 연동이 완료됩니다'),
      findsOneWidget,
    );
    expect(find.textContaining('인증 완료 알림은 별도로 전송되지 않으니'), findsOneWidget);
    expect(
      find.textContaining('운영자 판단에 따라 해당 게임 계정의 추가 인증이 제한될 수 있습니다'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('manualVerificationCreate')));
    await tester.pumpAndSettle();

    expect(repository.created, isTrue);
    expect(find.text('LP-7K4M2Q'), findsOneWidget);
    expect(find.textContaining('아래 오픈채팅방으로 보내주세요'), findsOneWidget);
    expect(find.text('인증사진 전송 오픈채팅방'), findsOneWidget);
    expect(find.text('재발급'), findsNothing);
  });

  testWidgets('취소된 요청은 내 요청 목록에 올리지 않는다', (tester) async {
    final cancelled = ManualVerificationRequest(
      id: 'req-old',
      requesterPlayerId: request.requesterPlayerId,
      targetIdentityKey: request.targetIdentityKey,
      localAccountLabelSnapshot: request.localAccountLabelSnapshot,
      proofServerName: request.proofServerName,
      proofCharacterName: request.proofCharacterName,
      verificationCode: 'LP-AAAAAA',
      status: ManualVerificationStatus.cancelled,
      attemptNumberForTarget: 1,
      totalAttemptNumberForPlayer: 1,
      createdAt: DateTime.utc(2026, 8, 27, 3),
      expiresAt: DateTime.utc(2026, 8, 28, 3),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _FakeAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: _FakeManualRepository(requests: [cancelled, request]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LP-7K4M2Q'), findsOneWidget);
    expect(find.text('LP-AAAAAA'), findsNothing);
  });

  testWidgets('승인된 요청은 목록에서 숨겨도 로컬 서버 캐릭터를 연결한다', (tester) async {
    final approved = ManualVerificationRequest(
      id: request.id,
      requesterPlayerId: request.requesterPlayerId,
      targetIdentityKey: request.targetIdentityKey,
      localAccountLabelSnapshot: request.localAccountLabelSnapshot,
      proofServerName: request.proofServerName,
      proofCharacterName: request.proofCharacterName,
      verificationCode: request.verificationCode,
      status: ManualVerificationStatus.approved,
      attemptNumberForTarget: request.attemptNumberForTarget,
      totalAttemptNumberForPlayer: request.totalAttemptNumberForPlayer,
      createdAt: request.createdAt,
      expiresAt: request.expiresAt,
      targetGameAccountId: 'ga-1',
    );
    final mappingRepository = _FakeMappingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _FakeAccountRepository(),
          mappingRepository: mappingRepository,
          repository: _FakeManualRepository(
            requests: [approved],
            approvedResult: const GameAccountVerificationResult(
              status: 'verified',
              serverGameAccountId: 'ga-1',
              serverCharacters: [
                VerifiedServerCharacter(
                  serverName: '루페온',
                  characterName: '이슈아이',
                  serverCharacterId: 'character-11',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(mappingRepository.binding?.serverGameAccountId, 'ga-1');
    expect(
      mappingRepository.binding?.serverCharacterIdsByLocalId,
      {11: 'character-11'},
    );
    expect(find.text('LP-7K4M2Q'), findsNothing);
  });

  testWidgets('오픈채팅방 링크는 안내된 주소로 연다', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _FakeAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: _FakeManualRepository(requests: [request]),
          onOpenUri: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('manualVerificationOpenChat')));
    await tester.pumpAndSettle();

    expect(
      opened,
      Uri.parse('https://open.kakao.com/o/sT9XQ2Ki'),
    );
  });

  testWidgets('목록 구독이 실패해도 방금 발급한 코드는 유지한다', (tester) async {
    final repository = _FakeManualRepository(
      requests: [request],
      watchError: Exception('index'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _FakeAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('manualVerificationCreate')));
    await tester.pumpAndSettle();

    expect(find.text('LP-7K4M2Q'), findsOneWidget);
    expect(find.text('요청 목록을 불러오지 못했습니다.'), findsNothing);
  });

  testWidgets('운영자 대기 목록은 오래된 요청과 횟수를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorManualVerificationQueuePage(
          operatorAccessRepository: _FakeOperatorRepository(),
          repository: _FakeManualRepository(requests: [request]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('이슈아이 · LP-7K4M2Q'), findsOneWidget);
    expect(find.textContaining('대상 2회'), findsOneWidget);
    expect(find.textContaining('전체 3회'), findsOneWidget);
  });

  testWidgets('이미 인증한 계정은 코드 발급을 막는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _VerifiedAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: _FakeManualRepository(requests: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('이미 인증한 게임 계정입니다. 수동 인증을 다시 요청할 수 없습니다.'),
      findsOneWidget,
    );
    final create = tester.widget<FilledButton>(
      find.byKey(const ValueKey('manualVerificationCreate')),
    );
    expect(create.onPressed, isNull);
  });

  testWidgets('서버 불일치 계정은 등록된 원정대 캐릭터로 수동 인증할 수 있다', (
    tester,
  ) async {
    final repository = _FakeManualRepository(requests: [request]);
    await tester.pumpWidget(
      MaterialApp(
        home: ManualVerificationPage(
          accountRepository: _ServerMismatchAccountRepository(),
          mappingRepository: _FakeMappingRepository(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('이 원정대로 재인증할 수 있습니다'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.byKey(const ValueKey('manualVerificationCreate')),
    );
    expect(create.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('manualVerificationCreate')));
    await tester.pumpAndSettle();
    expect(repository.created, isTrue);
  });

  testWidgets('기존 소유자가 있으면 분쟁 개시와 강제 인증을 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorManualVerificationDetailPage(
          requestId: request.id,
          initialRequest: request,
          operatorAccessRepository: _FakeOperatorRepository(),
          repository: _FakeManualRepository(
            requests: [request],
            review: const ManualVerificationReviewContext(
              hasActiveOwner: true,
              isBlocked: false,
              rosterSummaries: ['루페온 이슈아이 · 도화가'],
              existingOwnerPlayerId: 'owner-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기존 소유자 있음'), findsOneWidget);
    expect(find.text('분쟁 개시 (24시간 방어)'), findsOneWidget);
    expect(find.text('강제 인증'), findsOneWidget);
    final approve = tester.widget<FilledButton>(
      find.byKey(const ValueKey('operatorManualApprove')),
    );
    expect(approve.onPressed, isNotNull);
    final force = tester.widget<FilledButton>(
      find.byKey(const ValueKey('operatorManualForceApprove')),
    );
    expect(force.onPressed, isNotNull);
  });

  testWidgets('무소유 계정은 승인만 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorManualVerificationDetailPage(
          requestId: request.id,
          initialRequest: request,
          operatorAccessRepository: _FakeOperatorRepository(),
          repository: _FakeManualRepository(requests: [request]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('승인'), findsOneWidget);
    expect(find.text('분쟁 개시 (24시간 방어)'), findsNothing);
    expect(find.byKey(const ValueKey('operatorManualForceApprove')), findsNothing);
  });

  testWidgets('요청자가 이미 소유 중이면 분쟁 개시를 막는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorManualVerificationDetailPage(
          requestId: request.id,
          initialRequest: request,
          operatorAccessRepository: _FakeOperatorRepository(),
          repository: _FakeManualRepository(
            requests: [request],
            review: ManualVerificationReviewContext(
              hasActiveOwner: true,
              isBlocked: false,
              rosterSummaries: const ['루페온 이슈아이 · 도화가'],
              existingOwnerPlayerId: request.requesterPlayerId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('요청자가 이미 소유 중'), findsOneWidget);
    final approve = tester.widget<FilledButton>(
      find.byKey(const ValueKey('operatorManualApprove')),
    );
    expect(approve.onPressed, isNull);
  });
}

class _FakeAccountRepository extends Fake implements AccountRepository {
  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      representativeCharacterId: 11,
      displayLimit: 1,
      characters: [
        LocalAccountCharacter(
          id: 11,
          serverName: '루페온',
          characterName: '이슈아이',
          characterLevel: 60,
          characterClassName: '도화가',
          itemLevel: 1700,
          combatPower: 100,
          isVisible: true,
          displayOrder: 1,
        ),
      ],
    ),
  ];
}

class _VerifiedAccountRepository extends _FakeAccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      representativeCharacterId: 11,
      displayLimit: 1,
      serverGameAccountId: 'ga-1',
      serverOwnershipStatus: 'active',
      characters: const [
        LocalAccountCharacter(
          id: 11,
          serverName: '루페온',
          characterName: '이슈아이',
          characterLevel: 60,
          characterClassName: '도화가',
          itemLevel: 1700,
          combatPower: 100,
          isVisible: true,
          displayOrder: 1,
        ),
      ],
    ),
  ];
}

class _ServerMismatchAccountRepository extends _FakeAccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '메인 계정',
      isMain: true,
      lookupCharacterName: '이슈아이',
      representativeCharacterId: 11,
      displayLimit: 1,
      serverGameAccountId: 'ga-1',
      serverOwnershipStatus: 'serverMismatch',
      characters: const [
        LocalAccountCharacter(
          id: 11,
          serverName: '루페온',
          characterName: '이슈아이',
          characterLevel: 60,
          characterClassName: '도화가',
          itemLevel: 1700,
          combatPower: 100,
          isVisible: true,
          displayOrder: 1,
        ),
      ],
    ),
  ];
}

class _FakeMappingRepository extends Fake
    implements AccountIdentityMappingRepository {
  ServerAccountIdentityBinding? binding;

  @override
  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding) async {
    this.binding = binding;
  }
}

class _FakeOperatorRepository extends Fake implements OperatorAccessRepository {
  @override
  Future<bool> isCurrentPlayerOperator() async => true;

  @override
  Future<OperatorWriteReadiness> loadWriteReadiness() async =>
      const OperatorWriteReadiness(
        authUid: 'auth-1',
        playerId: 'player-1',
        bindingActive: true,
        playerExists: true,
        playerActive: true,
        assignmentActive: true,
      );

  @override
  Future<List<OperatorUserSummary>> loadUsers({int limit = 50}) async =>
      const [];

  @override
  Future<OperatorUserDetail?> loadUserDetail(String playerId) async => null;
}

class _FakeManualRepository implements ManualVerificationRepository {
  _FakeManualRepository({
    required this.requests,
    this.review = const ManualVerificationReviewContext(
      hasActiveOwner: false,
      isBlocked: false,
      rosterSummaries: ['루페온 이슈아이 · 도화가'],
    ),
    this.watchError,
    this.approvedResult,
  });

  final List<ManualVerificationRequest> requests;
  final ManualVerificationReviewContext review;
  final Object? watchError;
  final GameAccountVerificationResult? approvedResult;
  var created = false;

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
  }) async {
    created = true;
    return requests.first;
  }

  @override
  Future<void> cancelRequest(String requestId) async {}

  @override
  Future<GameAccountVerificationResult> loadApprovedResult(
    String requestId,
  ) async {
    if (approvedResult != null) return approvedResult!;
    throw const ManualVerificationException('notApproved');
  }

  @override
  Future<List<ManualVerificationRequest>> loadPendingQueue() async => requests;

  @override
  Future<ManualVerificationReviewContext> loadReviewContext(
    ManualVerificationRequest request,
  ) async => review;

  @override
  Future<ManualVerificationRequest> reissueRequest(String requestId) async =>
      requests.first;

  @override
  Future<GameAccountVerificationResult> reviewApprove(String requestId) async =>
      const GameAccountVerificationResult(status: 'verified');

  @override
  Future<void> reviewApproveDefense(String defenseRequestId) async {}

  @override
  Future<GameAccountVerificationResult> reviewRejectDefense(
    String defenseRequestId,
  ) async => const GameAccountVerificationResult(status: 'verified');

  @override
  Future<GameAccountVerificationResult> reviewForceApprove(
    String requestId,
  ) async =>
      const GameAccountVerificationResult(status: 'verified');

  @override
  Future<void> syncExpiredDisputes() async {}

  @override
  Future<GameAccountVerificationResult> reviewApproveUnowned(
    String requestId,
  ) async =>
      reviewApprove(requestId);

  @override
  Stream<List<ManualVerificationRequest>> watchIncomingDisputes() =>
      Stream.value(const []);

  @override
  Future<void> reviewBlock({
    required String requestId,
    required String reason,
  }) async {}

  @override
  Future<void> reviewCancel({
    required String requestId,
    required String reason,
  }) async {}

  @override
  Stream<List<ManualVerificationRequest>> watchMyRequests() {
    if (watchError != null) {
      return Stream.error(watchError!);
    }
    return Stream.value(requests);
  }
}
