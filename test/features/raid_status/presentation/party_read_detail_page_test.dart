import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_catalog_detection.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_build_draft.dart';
import 'package:lost_party/features/account/domain/entities/character_profile.dart';
import 'package:lost_party/features/account/domain/entities/character_summary.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/roster_summary_apply_result.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/raid_status/presentation/pages/party_read_detail_page.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_application_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_gem_validation_snapshot.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';
import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_cycle_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_visibility_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_join_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_membership_command.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_application_command_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_cycle_command_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_visibility_command_repository.dart';
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
    PartyCycleCommandRepository? cycleCommandRepository,
    PartyVisibilityCommandRepository? visibilityCommandRepository,
    RecruitmentLeaderCandidateService? candidateService,
    GroupReadRepository? groupReadRepository,
    String? playerId,
    AccountDatabase? accountDatabase,
    PartyEventSyncService? eventSyncService,
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
          cycleCommandRepository: cycleCommandRepository,
          visibilityCommandRepository: visibilityCommandRepository,
          candidateService: candidateService,
          groupReadRepository: groupReadRepository,
          playerId: playerId,
          accountDatabase: accountDatabase,
          eventSyncService: eventSyncService,
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
              playerId: 'p-b053f130',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
              itemLevel: 1720,
              combatPower: 300000,
            ),
            PartyMemberDisplay(
              playerId: 'p-c2d8f28e',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 1,
              slotIndex: 0,
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
    expect(find.text('이번주 레이드완료'), findsNothing);
    expect(find.text('2/8명 · 모집 중 (딜러 1/6, 서포터 1/2)'), findsOneWidget);
    expect(find.text('1파티 · 딜러 1/3 · 서포터 0/1'), findsOneWidget);
    expect(find.text('2파티 · 딜러 0/3 · 서포터 1/1'), findsOneWidget);
    expect(find.textContaining('1파티 · 딜러'), findsOneWidget);
    expect(find.textContaining('2파티 · 딜러'), findsOneWidget);
    expect(find.text('1번'), findsWidgets);
    expect(find.text('이슈아이'), findsWidgets);
    expect(find.text('기상술사'), findsOneWidget);
    expect(find.text('공대장'), findsOneWidget);
    expect(find.text('빈자리'), findsWidgets);
    expect(find.text('현재 별도 참가 조건 없음'), findsWidgets);
    expect(find.textContaining('서폿캐릭'), findsOneWidget);
    expect(find.textContaining('전투력 300,000'), findsOneWidget);
    expect(find.textContaining('조회 전용'), findsOneWidget);
    expect(find.byKey(const ValueKey('openApplicationButton')), findsNothing);
  });

  testWidgets('방 진입 즉시 이벤트를 읽음 처리하고 구성 옆 팝업에 표시한다', (tester) async {
    final database = AccountDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.syncPartyNotificationReceipt(
      eventId: 'event-room',
      playerId: 'player-1',
      type: PartyEventType.memberJoined.wireName,
      recruitmentId: 'recruitment-1',
      characterNameSnapshot: '새멤버',
      occurredAt: DateTime.utc(2026, 8, 26, 12),
      expiresAt: DateTime.utc(2026, 9, 23),
    );

    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      members: Stream.value(
        const PartyReadSnapshot(items: [], isFromCache: false),
      ),
      playerId: 'player-1',
      accountDatabase: database,
      eventSyncService: const _NoopEventSyncService(),
    );
    await tester.pumpAndSettle();

    final rows = await database.loadRecentPartyNotifications('player-1');
    expect(rows.single.readAt, isNotNull);
    await tester.tap(find.byKey(const ValueKey('roomEventHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.text('이벤트 히스토리'), findsOneWidget);
    expect(find.text('새멤버님이 파티에 참가했습니다.'), findsOneWidget);
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
        PartyReadDetailSnapshot(
          item: _pendingApplication(),
          isFromCache: false,
        ),
      ),
      applicationCommandRepository: _FakeApplicationCommandRepository(),
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('withdrawApplicationButton')),
      findsOneWidget,
    );
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

    await tapVisible(
      tester,
      find.byKey(const ValueKey('openApplicationButton')),
    );
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('apply-candidate-1-dealer')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastApply?.characterId, 'server-character-1');
    expect(repository.lastApply?.requestedRole, PartyRole.dealer);
    expect(repository.lastApply?.cycleKey, '2026-08-19');
    expect(
      repository.lastApply?.gemValidation?.status,
      PartyGemValidationStatus.foreignClass,
    );
    expect(find.text('가입을 신청했습니다.'), findsOneWidget);
  });

  testWidgets('지원자 카드에서 타 직업 보석만 빨간 경고로 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      recruitmentApplications: Stream.value(
        PartyReadSnapshot(
          items: [
            _pendingApplication(
              gemValidation: PartyGemValidationSnapshot(
                status: PartyGemValidationStatus.foreignClass,
                foreignClassGemCount: 1,
                unverifiedSameClassGemCount: 0,
                validatedAt: DateTime.utc(2026, 9, 8),
                catalogVersion: '2026.09.04',
              ),
            ),
          ],
          isFromCache: false,
        ),
      ),
      joinCommandRepository: _FakeJoinCommandRepository(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(find.text('보석 확인 요망 · 타 직업 보석 1개'), findsOneWidget);
    final text = tester.widget<Text>(find.text('보석 확인 요망 · 타 직업 보석 1개'));
    expect(
      text.style?.color,
      Theme.of(tester.element(find.byType(Card).first)).colorScheme.error,
    );
  });

  testWidgets('철회 버튼이 pending 신청 revision으로 명령을 보낸다', (tester) async {
    final repository = _FakeApplicationCommandRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      myApplication: Stream.value(
        PartyReadDetailSnapshot(
          item: _pendingApplication(),
          isFromCache: false,
        ),
      ),
      applicationCommandRepository: repository,
      candidateService: _candidateService(),
      playerId: 'player-applicant',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('withdrawApplicationButton')),
    );
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
    await tapVisible(
      tester,
      find.byKey(const ValueKey('openApplicationButton')),
    );
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('apply-candidate-1-dealer')),
    );
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
        PartyReadSnapshot(items: [_pendingApplication()], isFromCache: false),
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
        PartyReadSnapshot(items: [_pendingApplication()], isFromCache: false),
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

    await tapVisible(
      tester,
      find.byKey(const ValueKey('deleteOwnRecruitmentButton')),
    );
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

  testWidgets('파티장이 파티 전체 완료를 누르면 complete 명령을 보낸다', (tester) async {
    final cycle = _RecordingCycleRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'char-leader',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
          ],
          isFromCache: false,
        ),
      ),
      cycleCommandRepository: cycle,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(find.text('파티 전체 완료'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('completeCycleButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmCompleteCycleButton')));
    await tester.pumpAndSettle();

    expect(cycle.completeCommands, hasLength(1));
    expect(cycle.completeCommands.single.cycleKey, '2026-08-19');
    expect(find.textContaining('회차를 완료했습니다.'), findsOneWidget);
  });

  testWidgets('일반 멤버는 파티 전체 완료 버튼을 보지 못한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(item: _summary(), isFromCache: false),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'char-leader',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterId: 'char-member',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      cycleCommandRepository: _RecordingCycleRepository(),
      playerId: 'player-2',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completeCycleButton')), findsNothing);
    expect(find.text('파티 전체 완료'), findsNothing);
  });

  testWidgets('파티장이 다인 방을 해산하면 disband 명령을 보낸다', (tester) async {
    final cycle = _RecordingCycleRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 2),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'char-leader',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterId: 'char-member',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      cycleCommandRepository: cycle,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('disbandPartyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmDisbandPartyButton')));
    await tester.pumpAndSettle();

    expect(cycle.disbandCommands, hasLength(1));
    expect(cycle.disbandCommands.single.expectedRecruitmentRevision, 1);
    expect(find.text('파티를 해산했습니다.'), findsOneWidget);
  });

  testWidgets('멤버가 더 있으면 모집 삭제 버튼을 숨긴다', (tester) async {
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
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'char-leader',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterId: 'char-member',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      candidateService: _candidateService(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('deleteOwnRecruitmentButton')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('leavePartyButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('changeParticipatingCharacterButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kickMemberButton-player-2')),
      findsOneWidget,
    );
  });

  testWidgets('확정 멤버가 탈퇴하면 leave 명령을 보낸다', (tester) async {
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
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      playerId: 'player-2',
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('leavePartyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmLeavePartyButton')));
    await tester.pumpAndSettle();

    expect(membership.leaveCommands, hasLength(1));
    expect(membership.leaveCommands.single.targetPlayerId, 'player-2');
    expect(find.text('파티에서 탈퇴했습니다.'), findsOneWidget);
  });

  testWidgets('파티장이 다른 멤버를 추방하면 kick 명령을 보낸다', (tester) async {
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
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('kickMemberButton-player-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmKickMemberButton')));
    await tester.pumpAndSettle();

    expect(membership.kickCommands, hasLength(1));
    expect(membership.kickCommands.single.targetPlayerId, 'player-2');
    expect(find.text('파티원을 추방했습니다.'), findsOneWidget);
  });

  testWidgets('참가 캐릭터 변경이 changeCharacter 명령을 보낸다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 1, maxMemberCount: 4),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'server-character-1',
              characterName: '지원바드',
              className: '바드',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      candidateService: _multiCharacterCandidateService(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('changeParticipatingCharacterButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-candidate-2-dealer')));
    await tester.pumpAndSettle();

    expect(membership.changeCommands, hasLength(1));
    expect(
      membership.changeCommands.single.newCharacterId,
      'server-character-2',
    );
    expect(membership.changeCommands.single.newRole, PartyRole.dealer);
    expect(find.text('참가 캐릭터를 변경했습니다.'), findsOneWidget);
  });

  testWidgets('참가 캐릭터를 반대 역할 설정으로 변경할 수 있다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 1, maxMemberCount: 4),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'server-character-1',
              characterName: '지원바드',
              className: '바드',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      candidateService: _multiCharacterCandidateService(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('changeParticipatingCharacterButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-candidate-2-support')));
    await tester.pumpAndSettle();

    expect(membership.changeCommands.single.newRole, PartyRole.support);
    expect(
      membership.changeCommands.single.newCharacterId,
      'server-character-2',
    );
  });

  testWidgets('같은 참가 캐릭터의 반대 역할 설정으로 바로 변경할 수 있다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(memberCount: 1, maxMemberCount: 4),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterId: 'server-character-1',
              characterName: '지원바드',
              className: '바드',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      candidateService: _multiCharacterCandidateService(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('changeParticipatingCharacterButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-candidate-1-support')));
    await tester.pumpAndSettle();

    expect(membership.changeCommands.single.newRole, PartyRole.support);
    expect(
      membership.changeCommands.single.newCharacterId,
      'server-character-1',
    );
  });

  testWidgets('같은 State에서 recruitmentId가 바뀌면 새 방 제목을 구독한다', (tester) async {
    final repository = FakePartyReadRepository(
      recruitmentForId: (recruitmentId) => Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            id: recruitmentId,
            title: recruitmentId == 'room-a' ? '방 A 모집' : '방 B 모집',
          ),
          isFromCache: false,
        ),
      ),
      membersForId: (_) =>
          Stream.value(const PartyReadSnapshot(items: [], isFromCache: false)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PartyReadDetailPage(
          recruitmentId: 'room-a',
          partyReadRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('방 A 모집'), findsOneWidget);
    expect(find.text('방 B 모집'), findsNothing);
    expect(repository.requestedRecruitmentIds, ['room-a']);

    await tester.pumpWidget(
      MaterialApp(
        home: PartyReadDetailPage(
          recruitmentId: 'room-b',
          partyReadRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('방 B 모집'), findsOneWidget);
    expect(find.text('방 A 모집'), findsNothing);
    expect(repository.requestedRecruitmentIds, ['room-a', 'room-b']);
  });

  testWidgets('1회성 완료 후 해산 전이면 파티 구성 옆에 이번주 레이드완료를 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(status: 'completed', currentCycleStatus: 'completed'),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(items: [], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('파티 구성'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('thisWeekRaidCompleteLabel')),
      findsOneWidget,
    );
    final completeLabel = tester.widget<Text>(
      find.byKey(const ValueKey('thisWeekRaidCompleteLabel')),
    );
    final recruitmentTitle = tester.widget<Text>(find.text('4막 노말 모집'));
    final theme = Theme.of(tester.element(find.text('4막 노말 모집')));
    expect(completeLabel.style?.fontSize, recruitmentTitle.style?.fontSize);
    expect(completeLabel.style?.color, theme.colorScheme.error);
  });

  testWidgets('반복방 다음주 대기에서도 파티 구성 옆에 이번주 레이드완료를 표시한다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            continueTogether: true,
            currentCycleStatus: 'completed',
          ),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(items: [], isFromCache: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('thisWeekRaidCompleteLabel')),
      findsOneWidget,
    );
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('thisWeekRaidCompleteLabel')),
    );
    final recruitmentTitle = tester.widget<Text>(find.text('4막 노말 모집'));
    expect(label.style?.fontSize, recruitmentTitle.style?.fontSize);
    expect(
      label.style?.color,
      Theme.of(tester.element(find.text('4막 노말 모집'))).colorScheme.error,
    );
  });

  group('파티 구성판 반응형 그룹 배치', () {
    void setSurface(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Stream<PartyReadSnapshot<PartyMemberDisplay>> membersStream(
      List<PartyMemberDisplay> members,
    ) => Stream.value(PartyReadSnapshot(items: members, isFromCache: false));

    Future<void> pumpComposition(
      WidgetTester tester, {
      required Size surface,
      required PublicRecruitmentSummary summary,
      required List<PartyMemberDisplay> members,
    }) async {
      setSurface(tester, surface);
      await pumpPage(
        tester,
        recruitment: Stream.value(
          PartyReadDetailSnapshot(item: summary, isFromCache: false),
        ),
        members: membersStream(members),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('partyCompositionBoard')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('좁은 4인: 파티 1열이며 Slot Card가 구성판 전체 폭을 쓴다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(400, 1400),
        summary: _summary(maxMemberCount: 4, memberCount: 1),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
        ],
      );

      expect(find.byKey(const ValueKey('partyGroupRow')), findsNothing);
      expect(find.byKey(const ValueKey('partyGroup-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('partyGroup-1')), findsNothing);
      expect(find.textContaining('2파티 · 딜러'), findsNothing);

      final boardWidth = tester
          .getSize(find.byKey(const ValueKey('partyCompositionBoard')))
          .width;
      final cardWidth = tester
          .getSize(find.byKey(const ValueKey('slotCard-0-0')))
          .width;
      expect(cardWidth, closeTo(boardWidth, 0.5));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-1'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-0'))).dy,
        ),
      );
    });

    testWidgets('좁은 8인: 1파티 다음 2파티가 세로로 배치된다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(400, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 2),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
          PartyMemberDisplay(
            playerId: 'p-6086be75',
            characterName: '서폿캐릭',
            className: '바드',
            role: PartyRole.support,
            partyIndex: 1,
            slotIndex: 0,
          ),
        ],
      );

      expect(find.byKey(const ValueKey('partyGroupRow')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('partyGroup-1'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('partyGroup-0'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('partyGroup-0'))).dx,
        closeTo(
          tester.getTopLeft(find.byKey(const ValueKey('partyGroup-1'))).dx,
          0.5,
        ),
      );
    });

    testWidgets('넓은 4인: 1파티가 왼쪽 절반이고 Slot Card는 파티 내부 1열이다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(800, 1400),
        summary: _summary(maxMemberCount: 4, memberCount: 1),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
        ],
      );

      expect(find.byKey(const ValueKey('partyGroupRow')), findsOneWidget);
      expect(find.byKey(const ValueKey('partyGroup-1')), findsNothing);

      final boardWidth = tester
          .getSize(find.byKey(const ValueKey('partyCompositionBoard')))
          .width;
      final groupWidth = tester
          .getSize(find.byKey(const ValueKey('partyGroup-0')))
          .width;
      final cardWidth = tester
          .getSize(find.byKey(const ValueKey('slotCard-0-0')))
          .width;

      expect(groupWidth, lessThan(boardWidth * 0.6));
      expect(cardWidth, closeTo(groupWidth, 0.5));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-1'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-0'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-0'))).dx,
        closeTo(
          tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-1'))).dx,
          0.5,
        ),
      );
    });

    testWidgets('넓은 8인: 1·2파티가 좌우 동일 폭이며 Slot은 1열이다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(800, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 2),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
          PartyMemberDisplay(
            playerId: 'p-6086be75',
            characterName: '서폿캐릭',
            className: '바드',
            role: PartyRole.support,
            partyIndex: 1,
            slotIndex: 0,
          ),
        ],
      );

      expect(find.byKey(const ValueKey('partyGroupRow')), findsOneWidget);
      final left = find.byKey(const ValueKey('partyGroup-0'));
      final right = find.byKey(const ValueKey('partyGroup-1'));
      expect(
        tester.getSize(left).width,
        closeTo(tester.getSize(right).width, 0.5),
      );
      expect(
        tester.getTopLeft(right).dx,
        greaterThan(tester.getTopLeft(left).dx),
      );
      expect(
        tester.getTopLeft(left).dy,
        closeTo(tester.getTopLeft(right).dy, 0.5),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-1'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-0'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('slotCard-1-0'))).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('slotCard-0-0'))).dx,
        ),
      );
    });

    testWidgets('넓은 화면에서도 자리 미정은 파티 아래 전체 폭을 쓴다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(800, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 2),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
          PartyMemberDisplay(
            playerId: 'p-63764396',
            characterName: '서폿캐릭',
            className: '바드',
            role: PartyRole.support,
            partyIndex: 1,
          ),
        ],
      );

      expect(find.text('자리 미정'), findsOneWidget);
      final boardTop = tester.getTopLeft(
        find.byKey(const ValueKey('partyCompositionBoard')),
      );
      final unassignedTop = tester.getTopLeft(find.text('자리 미정'));
      final partyBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('partyGroupRow')),
      );
      expect(unassignedTop.dy, greaterThan(partyBottom.dy));
      expect(unassignedTop.dx, closeTo(boardTop.dx, 0.5));
    });

    testWidgets('넓은 8인: 같은 자리의 좌우 Slot Card 높이가 같다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(800, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 1),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-fa97298b',
            characterName: '아주아주긴캐릭터이름입니다',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
            itemLevel: 1720,
            combatPower: 300000,
          ),
        ],
      );

      final leftHeight = tester
          .getSize(find.byKey(const ValueKey('slotCard-0-0')))
          .height;
      final rightHeight = tester
          .getSize(find.byKey(const ValueKey('slotCard-1-0')))
          .height;
      expect(leftHeight, greaterThan(0));
      expect(rightHeight, closeTo(leftHeight, 0.5));
    });

    testWidgets('펼친 폴드급 폭(650)에서도 파티 그룹이 좌우로 배치된다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(650, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 1),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
        ],
      );

      expect(find.byKey(const ValueKey('partyGroupRow')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('partyGroup-1'))).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('partyGroup-0'))).dx,
        ),
      );
    });

    testWidgets('넓은 8인에서도 읽기 순서는 1파티 다음 2파티다', (tester) async {
      await pumpComposition(
        tester,
        surface: const Size(800, 1800),
        summary: _summary(maxMemberCount: 8, memberCount: 1),
        members: const [
          PartyMemberDisplay(
            playerId: 'p-53b6414d',
            characterName: '이슈아이',
            className: '기상술사',
            role: PartyRole.dealer,
            partyIndex: 0,
            slotIndex: 0,
          ),
        ],
      );

      final partyLabels = find.textContaining('파티');
      // titleMedium '파티 구성' 다음에 titleSmall '1파티', '2파티'
      expect(find.text('파티 구성'), findsOneWidget);
      expect(find.text('이번주 레이드완료'), findsNothing);
      final partyOne = find.textContaining('1파티 · 딜러');
      final partyTwo = find.textContaining('2파티 · 딜러');
      expect(partyOne, findsOneWidget);
      expect(partyTwo, findsOneWidget);
      expect(
        tester.getTopLeft(partyOne).dx,
        lessThan(tester.getTopLeft(partyTwo).dx),
      );
      expect(partyLabels, findsWidgets);
    });
  });

  testWidgets('그룹 레이드 파티장에게 그룹만 공개 스위치를 보여 준다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            groupId: 'group-1',
            visibility: RecruitmentVisibility.group,
          ),
          isFromCache: false,
        ),
      ),
      visibilityCommandRepository: _RecordingVisibilityRepository(),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('groupOnlyVisibilitySwitch')),
      findsOneWidget,
    );
    expect(find.text('그룹만 공개'), findsWidgets);
  });

  testWidgets('그룹 전용 레이드에서 그룹을 떠난 파티원에 그룹 탈퇴와 정리를 보여 준다', (tester) async {
    final membership = _RecordingMembershipRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            memberCount: 2,
            groupId: 'group-1',
            visibility: RecruitmentVisibility.group,
          ),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: membership,
      groupReadRepository: _GroupMembers({'player-1'}),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(find.text('그룹 탈퇴'), findsWidgets);
    expect(
      find.byKey(const ValueKey('removeLostGroupQualificationButton-player-2')),
      findsOneWidget,
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('removeLostGroupQualificationButton-player-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirmRemoveLostGroupQualificationButton')),
    );
    await tester.pumpAndSettle();
    expect(membership.lostQualificationCommands, hasLength(1));
    expect(
      membership.lostQualificationCommands.single.targetPlayerId,
      'player-2',
    );
  });

  testWidgets('전체 공개 그룹 연결 레이드는 그룹 탈퇴만으로 정리 대상이 되지 않는다', (tester) async {
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            memberCount: 2,
            groupId: 'group-1',
            visibility: 'public',
          ),
          isFromCache: false,
        ),
      ),
      members: Stream.value(
        const PartyReadSnapshot(
          items: [
            PartyMemberDisplay(
              playerId: 'player-1',
              characterName: '이슈아이',
              className: '기상술사',
              role: PartyRole.dealer,
              partyIndex: 0,
              slotIndex: 0,
            ),
            PartyMemberDisplay(
              playerId: 'player-2',
              characterName: '서폿캐릭',
              className: '바드',
              role: PartyRole.support,
              partyIndex: 0,
              slotIndex: 1,
            ),
          ],
          isFromCache: false,
        ),
      ),
      membershipCommandRepository: _RecordingMembershipRepository(),
      groupReadRepository: _GroupMembers({'player-1'}),
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    expect(find.text('그룹 탈퇴'), findsNothing);
    expect(
      find.byKey(const ValueKey('removeLostGroupQualificationButton-player-2')),
      findsNothing,
    );
  });

  testWidgets('파티장이 전체 공개로 바꾸면 확인 후 명령을 보낸다', (tester) async {
    final visibility = _RecordingVisibilityRepository();
    await pumpPage(
      tester,
      recruitment: Stream.value(
        PartyReadDetailSnapshot(
          item: _summary(
            groupId: 'group-1',
            visibility: RecruitmentVisibility.group,
          ),
          isFromCache: false,
        ),
      ),
      visibilityCommandRepository: visibility,
      playerId: 'player-1',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('groupOnlyVisibilitySwitch')),
    );
    await tester.tap(find.byKey(const ValueKey('groupOnlyVisibilitySwitch')));
    await tester.pumpAndSettle();
    expect(find.text('전체 공개로 바꿀까요?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmVisibilityChangeButton')),
    );
    await tester.pumpAndSettle();

    expect(visibility.commands, hasLength(1));
    expect(visibility.commands.single.visibility, RecruitmentVisibility.public);
    expect(find.text('전체 공개로 바꿨습니다.'), findsOneWidget);
  });
}

PublicRecruitmentSummary _summary({
  String id = 'recruitment-1',
  String title = '4막 노말 모집',
  ApprovalMode approvalMode = ApprovalMode.leaderOnly,
  int memberCount = 2,
  int maxMemberCount = 8,
  int membersPerParty = 4,
  int partyCount = 2,
  int supportsPerParty = 1,
  int dealerCount = 1,
  int supportCount = 1,
  String status = 'active',
  String currentCycleStatus = 'active',
  bool continueTogether = false,
  String visibility = 'public',
  String? groupId,
}) => PublicRecruitmentSummary(
  id: id,
  title: title,
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
  maxMemberCount: maxMemberCount,
  membersPerParty: membersPerParty,
  partyCount: partyCount,
  supportsPerParty: supportsPerParty,
  dealerCount: dealerCount,
  supportCount: supportCount,
  isRecruiting: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 8, 20),
  currentCycleKey: '2026-08-19',
  approvalMode: approvalMode,
  status: status,
  currentCycleStatus: currentCycleStatus,
  continueTogether: continueTogether,
  visibility: visibility,
  groupId: groupId,
);

PartyApplicationSummary _pendingApplication({
  PartyGemValidationSnapshot? gemValidation,
}) => PartyApplicationSummary(
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
  gemValidation: gemValidation,
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

RecruitmentLeaderCandidateService _multiCharacterCandidateService() {
  return RecruitmentLeaderCandidateService(
    accountRepository: _MultiDealerAccountRepository(),
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
      id: characterId,
      characterId: characterId,
      role: CharacterBuildRole.dealer,
      rawJson: '{}',
      itemLevel: 1700,
      combatPower: 300000,
      capturedAt: DateTime.utc(2026, 8, 1),
      dataVersion: 1,
      analysis: const CharacterBuildAnalysis(
        runeCount: 0,
        gemEffects: [
          GemSkillEffect(
            gemSlot: 0,
            gemLevel: 10,
            skillName: '타 직업 스킬',
            descriptions: [],
            category: GemSkillCategory.normal,
            validationStatus: GemValidationStatus.foreignClass,
          ),
        ],
        arkGridConditions: [],
        arkGridCorePoints: [],
        notices: [],
        catalogDetection: CharacterBuildCatalogDetection(
          catalogVersion: '2026.09.04',
          status: CharacterBuildDetectionStatus.detected,
          classId: 'bard',
          branchId: 'dealer',
          branchDisplayName: '딜러',
          detectedRole: CharacterBuildRole.dealer,
          matchedTier1Node: '진실된 용맹',
          matchedRelatedNodes: [],
        ),
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
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
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

class _MultiDealerAccountRepository extends _AccountRepository {
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
        LocalAccountCharacter(
          id: 2,
          serverName: '루페온',
          characterName: '교체딜러',
          characterLevel: 70,
          characterClassName: '블레이드',
          itemLevel: 1710,
          combatPower: 310000,
          isVisible: true,
          displayOrder: 1,
          serverCharacterId: 'server-character-2',
          preferredRole: CharacterBuildRole.dealer,
        ),
      ],
    ),
  ];

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async => [
    ...await super.loadCharacterBuildSnapshots(characterId),
    if (characterId == 1 || characterId == 2)
      CharacterBuildSnapshot(
        id: 20,
        characterId: characterId,
        role: CharacterBuildRole.support,
        rawJson: '{}',
        itemLevel: 1710,
        combatPower: 310000,
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
}

class _RecordingMembershipRepository
    implements PartyMembershipCommandRepository {
  final leaveCommands = <PartyRemoveMemberCommand>[];
  final kickCommands = <PartyRemoveMemberCommand>[];
  final lostQualificationCommands = <PartyRemoveMemberCommand>[];
  final changeCommands = <PartyChangeCharacterCommand>[];

  @override
  Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) async {
    leaveCommands.add(command);
    return const PartyMembershipResult.success();
  }

  @override
  Future<PartyMembershipResult> changeCharacter(
    PartyChangeCharacterCommand command,
  ) async {
    changeCommands.add(command);
    return const PartyMembershipResult.success();
  }

  @override
  Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) async {
    kickCommands.add(command);
    return const PartyMembershipResult.success();
  }

  @override
  Future<PartyMembershipResult> removeLostGroupQualification(
    PartyRemoveMemberCommand command,
  ) async {
    lostQualificationCommands.add(command);
    return const PartyMembershipResult.success();
  }

  @override
  Future<PartyMembershipResult> setApprovalPermission(
    PartySetApprovalPermissionCommand command,
  ) => throw UnimplementedError();
}

class _RecordingCycleRepository implements PartyCycleCommandRepository {
  final completeCommands = <PartyCompleteCycleCommand>[];
  final disbandCommands = <PartyDisbandCommand>[];

  @override
  Future<PartyCycleResult> complete(PartyCompleteCycleCommand command) async {
    completeCommands.add(command);
    return const PartyCycleResult.success();
  }

  @override
  Future<PartyCycleResult> cancelCompletion(
    PartyCancelCompletionCommand command,
  ) => throw UnimplementedError();

  @override
  Future<PartyCycleResult> setRecurrence(PartySetRecurrenceCommand command) =>
      throw UnimplementedError();

  @override
  Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command) =>
      throw UnimplementedError();

  @override
  Future<PartyCycleResult> disband(PartyDisbandCommand command) async {
    disbandCommands.add(command);
    return const PartyCycleResult.success();
  }

  @override
  Future<PartyCycleResult> purgeStaleOwnAssignment(
    PartyPurgeStaleAssignmentCommand command,
  ) async => const PartyCycleResult.success();
}

class _RecordingVisibilityRepository
    implements PartyVisibilityCommandRepository {
  final commands = <PartyVisibilityCommand>[];

  @override
  Future<PartyVisibilityResult> setVisibility(
    PartyVisibilityCommand command,
  ) async {
    commands.add(command);
    return const PartyVisibilityResult.success();
  }
}

class _GroupMembers extends Fake implements GroupReadRepository {
  _GroupMembers(this.memberPlayerIds);
  final Set<String> memberPlayerIds;

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async => [
    for (final playerId in memberPlayerIds)
      GroupMember(
        groupId: groupId,
        playerId: playerId,
        role: playerId == 'player-1'
            ? GroupMemberRole.leader
            : GroupMemberRole.member,
        joinedAt: DateTime.utc(2026, 8, 20),
        joinSequence: 1,
        joinedBy: GroupJoinedBy.created,
        displayCharacterIdSnapshot: 'character-$playerId',
        displayCharacterNameSnapshot: playerId,
        revision: 1,
      ),
  ];
}

class _NoopEventSyncService implements PartyEventSyncService {
  const _NoopEventSyncService();

  @override
  Future<PartyEventSyncResult> sync() async =>
      const PartyEventSyncResult.success(0);
}
