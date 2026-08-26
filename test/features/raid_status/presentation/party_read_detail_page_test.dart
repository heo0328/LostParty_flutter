import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/raid_status/presentation/pages/party_read_detail_page.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_application_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_join_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_membership_command.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_application_command_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_join_command_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_membership_command_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';

import '../../../support/party_read_fakes.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>>
    recruitment,
    Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>>? myApplication,
    Stream<PartyReadSnapshot<PartyMemberDisplay>>? members,
    Stream<PartyReadSnapshot<PartyApplicationSummary>>? recruitmentApplications,
    PartyApplicationCommandRepository? applicationCommandRepository,
    PartyJoinCommandRepository? joinCommandRepository,
    PartyMembershipCommandRepository? membershipCommandRepository,
    RecruitmentLeaderCandidateService? candidateService,
    String? playerId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PartyReadDetailPage(
          recruitmentId: 'recruitment-1',
          partyReadRepository: FakePartyReadRepository(
            recruitment: recruitment,
            myApplication: myApplication,
            members: members,
            recruitmentApplications: recruitmentApplications,
          ),
          applicationCommandRepository: applicationCommandRepository,
          joinCommandRepository: joinCommandRepository,
          membershipCommandRepository: membershipCommandRepository,
          candidateService: candidateService,
          playerId: playerId,
        ),
      ),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('첫 snapshot 전에는 로딩을 표시한다', (tester) async {
    final pending =
        StreamController<PartyReadDetailSnapshot<PublicRecruitmentSummary>>();
    addTearDown(pending.close);

    await pumpPage(tester, recruitment: pending.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('모집 정보를 찾을 수 없습니다.'), findsNothing);
  });

  testWidgets('문서가 없으면 누락 안내를 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        const PartyReadDetailSnapshot(item: null, isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('모집 정보를 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
  });

  testWidgets('명령 Repository가 없으면 조회 전용 안내를 둔다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
              itemLevel: 1720,
              combatPower: 300000,
            ),
            PartyMemberDisplay(
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 1,
              itemLevel: 1710,
              combatPower: 280000,
            ),
          ],
          isFromCache: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4막 노말 모집'), findsOneWidget);
    expect(find.textContaining('이슈아이 · 기상술사'), findsWidgets);
    expect(find.text('파티 구성'), findsOneWidget);
    expect(find.text('1파티'), findsOneWidget);
    expect(find.text('2파티'), findsOneWidget);
    expect(find.text('1번'), findsWidgets);
    expect(find.text('이슈아이'), findsWidgets);
    expect(find.text('기상술사'), findsOneWidget);
    expect(find.text('공대장'), findsOneWidget);
    expect(find.text('빈자리'), findsWidgets);
    expect(find.text('현재 별도 참가 조건 없음'), findsWidgets);
    expect(find.text('자리 미정'), findsOneWidget);
    expect(find.text('자리 정보 없음'), findsOneWidget);
    expect(find.textContaining('서폿캐릭'), findsOneWidget);
    expect(find.textContaining('전투력 300,000'), findsOneWidget);
    expect(find.textContaining('조회 전용'), findsOneWidget);
    expect(find.byKey(const ValueKey('openApplicationButton')), findsNothing);
  });

  testWidgets('모집 중이면 지원하기를 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        const PartyReadDetailSnapshot(item: null, isFromCache: false),
      ),
      applicationCommandRepository: _FakeApplicationCommandRepository(),
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('openApplicationButton')), findsOneWidget);
    expect(find.textContaining('조회 전용'), findsNothing);
  });

  testWidgets('승인 대기 신청이면 철회 버튼을 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        PartyReadDetailSnapshot(item: _pendingApplication(), isFromCache: false),
      ),
      applicationCommandRepository: _FakeApplicationCommandRepository(),
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('withdrawApplicationButton')), findsOneWidget);
    expect(find.textContaining('승인 대기'), findsOneWidget);
  });

  testWidgets('지원하기에서 인증된 캐릭터로 신청 명령을 보낸다', (tester) async {
    final repository = _FakeApplicationCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        const PartyReadDetailSnapshot(item: null, isFromCache: false),
      ),
      applicationCommandRepository: repository,
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('openApplicationButton')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('apply-candidate-1-dealer')));
    await tester.pumpAndSettle();

    expect(repository.lastApply?.characterId, 'server-character-1');
    expect(repository.lastApply?.requestedRole, PartyRole.dealer);
    expect(repository.lastApply?.cycleKey, '2026-08-19');
    expect(find.text('가입을 신청했습니다.'), findsOneWidget);
  });

  testWidgets('철회 버튼이 pending 신청 revision으로 명령을 보낸다', (tester) async {
    final repository = _FakeApplicationCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        PartyReadDetailSnapshot(item: _pendingApplication(), isFromCache: false),
      ),
      applicationCommandRepository: repository,
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('withdrawApplicationButton')));
    await tester.pumpAndSettle();

    expect(repository.lastWithdraw?.expectedRevision, 3);
    expect(find.text('신청을 철회했습니다.'), findsOneWidget);
  });

  testWidgets('거절된 신청은 횟수 안내와 다시 지원하기를 보여 준다', (tester) async {
    final repository = _FakeApplicationCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        PartyReadDetailSnapshot(
          item: _rejectedApplication(rejectionCount: 2),
          isFromCache: false,
        ),
      ),
      applicationCommandRepository: repository,
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2회 거절되었습니다'), findsOneWidget);
    expect(find.text('다시 지원하기'), findsOneWidget);
    expect(find.textContaining('아직 연결되지 않았습니다'), findsNothing);
  });

  testWidgets('즉시 가입 모집은 joinDirectly 명령을 보낸다', (tester) async {
    final repository = _FakeJoinCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(approvalMode: ApprovalMode.directJoin),
          isFromCache: false,
        ),
      ),
      myApplication: Stream.value(
        const PartyReadDetailSnapshot(item: null, isFromCache: false),
      ),
      joinCommandRepository: repository,
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    expect(find.text('바로 가입'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('openApplicationButton')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('apply-candidate-1-dealer')));
    await tester.pumpAndSettle();

    expect(repository.lastDirectJoin?.characterId, 'server-character-1');
    expect(repository.lastDirectJoin?.expectedRecruitmentRevision, 1);
    expect(find.text('파티에 참가했습니다.'), findsOneWidget);
  });

  testWidgets('파티장은 pending 신청을 승인할 수 있다', (tester) async {
    final repository = _FakeJoinCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      recruitmentApplications: Stream.value(
        PartyReadSnapshot(
          items: [_pendingApplication()],
          isFromCache: false,
        ),
      ),
      joinCommandRepository: repository,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(find.text('가입 신청 관리'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('approveApplication-player-applicant')),
    );
    await tester.pumpAndSettle();
    expect(repository.lastApprove?.applicantPlayerId, 'player-applicant');
    expect(find.text('가입 신청을 승인했습니다.'), findsOneWidget);
  });

  testWidgets('파티장은 pending 신청을 거절할 수 있다', (tester) async {
    final repository = _FakeJoinCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      recruitmentApplications: Stream.value(
        PartyReadSnapshot(
          items: [_pendingApplication()],
          isFromCache: false,
        ),
      ),
      joinCommandRepository: repository,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('rejectApplication-player-applicant')),
    );
    await tester.pumpAndSettle();
    expect(repository.lastReject?.applicantPlayerId, 'player-applicant');
    expect(find.text('가입 신청을 거절했습니다.'), findsOneWidget);
  });

  testWidgets('캐시 snapshot이면 오프라인 안내를 함께 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsOneWidget);
  });

  testWidgets('목록 없이 발생한 오류는 실패 안내로 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.error(
        const PartyReadException(PartyReadFailureType.permissionDenied),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('조회 권한을 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('4막 노말 모집'), findsNothing);
  });

  testWidgets('파티장이 단독 모집을 삭제하면 leave 명령을 보낸다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 1),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(items: [], isFromCache: false),
      ),
      membershipCommandRepository: membership,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('deleteOwnRecruitmentButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirmDeleteOwnRecruitmentButton')),
    );
    await tester.pumpAndSettle();

    expect(membership.leaveCommands, hasLength(1));
    expect(membership.leaveCommands.single.targetPlayerId, 'player-1');
    expect(membership.leaveCommands.single.expectedRecruitmentRevision, 1);
    expect(find.text('모집을 삭제했습니다.'), findsOneWidget);
  });

  testWidgets('멤버가 더 있으면 모집 삭제를 막는다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 2),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(items: [], isFromCache: false),
      ),
      membershipCommandRepository: membership,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('deleteOwnRecruitmentButton')));
    await tester.pumpAndSettle();

    expect(membership.leaveCommands, isEmpty);
    expect(find.textContaining('다른 파티원이 있는 방'), findsOneWidget);
  });
}

PublicRecruitmentSummary _summary({
  ApprovalMode approvalMode = ApprovalMode.leaderOnly,
  int memberCount = 2,
}) => PublicRecruitmentSummary(
  id: 'recruitment-1',
  title: '4막 노말 모집',
  leaderUserId: 'player-1',
  leaderCharacterName: '이슈아이',
  leaderClassName: '기상술사',
  metadata: const RecruitmentMetadata(
    catalogVersion: '2026-08-01',
    raidId: 'act4',
    difficultyId: 'normal',
    raidName: '4막',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 2,
    minItemLevel: 1680,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  memberCount: memberCount,
  maxMemberCount: 8,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
  currentCycleKey: '2026-08-19',
  approvalMode: approvalMode,
);

PartyApplicationSummary _pendingApplication() => PartyApplicationSummary(
  recruitmentId: 'recruitment-1',
  applicantPlayerId: 'player-applicant',
  cycleKey: '2026-08-19',
  characterId: 'server-character-1',
  characterName: '지원바드',
  className: '바드',
  requestedRole: PartyRole.support,
  status: RecruitmentApplicationStatus.pending,
  revision: 3,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 21),
);

PartyApplicationSummary _rejectedApplication({required int rejectionCount}) =>
    PartyApplicationSummary(
      recruitmentId: 'recruitment-1',
      applicantPlayerId: 'player-applicant',
      cycleKey: '2026-08-19',
      characterId: 'server-character-1',
      characterName: '지원바드',
      className: '바드',
      requestedRole: PartyRole.support,
      status: RecruitmentApplicationStatus.rejected,
      revision: 4,
      rejectionCount: rejectionCount,
      resolutionReason: 'rejectedByApprover',
      createdAt: DateTime.utc(2026, 8, 20),
      decidedAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
    );

RecruitmentLeaderCandidateService _candidateService() {
  return RecruitmentLeaderCandidateService(
    accountRepository: _AccountRepository(),
    weeklyClearRepository: InMemoryWeeklyRaidClearRepository(),
    session: FakeUserSession('local-user'),
    clock: FakeRecruitmentClock(DateTime.utc(2026, 8, 20)),
    assignmentRepository: InMemoryActiveRaidAssignmentRepository(),
    recruitmentRepository: InMemoryRecruitmentStateRepository(),
  );
}

class _FakeApplicationCommandRepository
    implements PartyApplicationCommandRepository {
  PartyApplyCommand? lastApply;
  PartyWithdrawApplicationCommand? lastWithdraw;

  @override
  Future<PartyApplicationCommandResult> apply(PartyApplyCommand command) async {
    lastApply = command;
    return const PartyApplicationCommandResult.success();
  }

  @override
  Future<PartyApplicationCommandResult> withdraw(
    PartyWithdrawApplicationCommand command,
  ) async {
    lastWithdraw = command;
    return const PartyApplicationCommandResult.success();
  }
}

class _FakeJoinCommandRepository implements PartyJoinCommandRepository {
  PartyDirectJoinCommand? lastDirectJoin;
  PartyDecideApplicationCommand? lastApprove;
  PartyDecideApplicationCommand? lastReject;

  @override
  Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command) async {
    lastDirectJoin = command;
    return const PartyJoinResult.success();
  }

  @override
  Future<PartyJoinResult> approve(PartyDecideApplicationCommand command) async {
    lastApprove = command;
    return const PartyJoinResult.success();
  }

  @override
  Future<PartyJoinResult> reject(PartyDecideApplicationCommand command) async {
    lastReject = command;
    return const PartyJoinResult.success();
  }
}

class _AccountRepository implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '본계정',
      isMain: true,
      lookupCharacterName: '지원바드',
      representativeCharacterId: 1,
      displayLimit: 6,
      serverGameAccountId: 'ga-1',
      serverOwnershipStatus: 'active',
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverName: '루페온',
          characterName: '지원바드',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
          serverCharacterId: 'server-character-1',
          preferredRole: CharacterBuildRole.dealer,
        ),
      ],
    ),
  ];

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    CharacterBuildSnapshot(
      id: 1,
      characterId: characterId,
      role: CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1700,
      combatPower: 300000,
      capturedAt: DateTime.utc(2026, 8, 1),
      dataVersion: 1,
      analysis: const CharacterBuildAnalysis(
        runeCount: 0,
        gemEffects: [],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
      ),
    ),
  ];

  @override
  Future<RosterSummaryApplyResult> applyRosterSummarySync({
    required int accountId,
    required String lookupCharacterName,
    required List<CharacterSummary> summaries,
    required DateTime fetchedAt,
  }) async =>
      const RosterSummaryApplyResult(updatedLocalCount: 0, serverPatches: []);

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) =>
      throw UnimplementedError();

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) =>
      throw UnimplementedError();

  @override
  Future<LocalGameAccount?> loadMainAccount() async =>
      (await loadAccounts()).first;

  @override
  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  }) => throw UnimplementedError();

  @override
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) => throw UnimplementedError();

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();

  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) => throw UnimplementedError();

  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) => throw UnimplementedError();

  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) => throw UnimplementedError();

  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) => throw UnimplementedError();

  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) => throw UnimplementedError();
}

class _RecordingMembershipRepository implements PartyMembershipCommandRepository {
  final leaveCommands = <PartyRemoveMemberCommand>[];

  @override
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) async {
    leaveCommands.add(command);
    return const PartyMembershipResult.success();
  }

  @override
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  ) => throw UnimplementedError();

  @override
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) =>
      throw UnimplementedError();

  @override
  Future<PartyMembershipResult> setApprovalPermission(
    PartySetApprovalPermissionCommand command,
  ) => throw UnimplementedError();
}
