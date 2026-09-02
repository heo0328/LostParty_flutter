import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';
import 'package:lost_party/features/account/domain/repositories/weekly_raid_claim_repository.dart';
import 'package:lost_party/features/account/domain/repositories/activity_characters_repository.dart';
import 'package:lost_party/features/account/domain/repositories/character_summary_sync_gateway.dart';

import 'package:lost_party/features/account/data/local/account_database.dart';
import 'package:lost_party/features/account/domain/entities/game_account_verification.dart';
import 'package:lost_party/features/account/domain/repositories/account_ownership_status_gateway.dart';
import 'package:lost_party/features/account/domain/repositories/game_account_verification_gateway.dart';
import 'package:lost_party/features/group/domain/entities/group_blocked_player.dart';
import 'package:lost_party/features/group/domain/entities/group_create_command.dart';
import 'package:lost_party/features/group/domain/entities/group_create_result.dart';
import 'package:lost_party/features/group/domain/entities/group_join_code_command.dart';
import 'package:lost_party/features/group/domain/entities/group_join_command.dart';
import 'package:lost_party/features/group/domain/entities/group_leader_exit_command.dart';
import 'package:lost_party/features/group/domain/entities/group_leave_command.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display_snapshot_refresh_command.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_summary.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';
import 'package:lost_party/features/group/domain/repositories/group_application_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_character_search_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_create_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_join_code_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_join_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
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
    expect(find.text('그룹'), findsOneWidget);
    expect(find.text('설정'), findsNothing);
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
    expect(
      find.text('참여 가능한 공개 모집이 없습니다. 내가 참여 중인 파티는 레이드 현황에서 확인할 수 있습니다.'),
      findsOneWidget,
    );
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

  testWidgets('My account gear opens settings and its child pages', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await _tapDestination(tester, '내 계정');
    await tester.tap(find.byKey(const ValueKey('myAccountSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);

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

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('API 토큰'), findsNothing);
    expect(find.byKey(const ValueKey('settingsApiToken')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('내 계정'), findsNWidgets(2));
  });

  testWidgets('Group tab replaces the settings destination', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await _tapDestination(tester, '그룹');

    expect(find.text('내 그룹'), findsOneWidget);
    expect(find.text('요청 현황'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
    expect(find.text('가입한 그룹이 없습니다. 그룹을 만들거나 검색해 보세요.'), findsOneWidget);
  });

  testWidgets('Group tab destinations open create, search, join-by-code', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();
    await _tapDestination(tester, '그룹');

    await tester.tap(find.byKey(const ValueKey('groupCreateButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsWidgets);
    expect(find.text('그룹 만들기'), findsWidgets);
    // 인증 캐릭터가 없으면 제출 대신 안내 문구가 나온다.
    expect(find.textContaining('인증'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('groupSearchButton')));
    await tester.pumpAndSettle();
    expect(find.text('그룹 검색'), findsOneWidget);
    expect(find.byKey(const ValueKey('groupSearchField')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('groupJoinByCodeButton')));
    await tester.pumpAndSettle();
    expect(find.text('초대코드로 가입'), findsOneWidget);
    expect(find.byKey(const ValueKey('groupJoinByCodeField')), findsOneWidget);
  });

  testWidgets('Group requests tab shows empty request status', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();
    await _tapDestination(tester, '그룹');

    await tester.tap(find.byKey(const ValueKey('groupRequestsTab')));
    await tester.pumpAndSettle();

    expect(find.text('받은 초대와 보낸 신청이 없습니다.'), findsOneWidget);
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
      weeklyRaidClaimRepository: _WeeklyRaidClaimRepository(),
      characterSummarySyncGateway: _CharacterSummarySyncGateway(),
      activityCharactersRepository: _ActivityCharactersRepository(),
      groupReadRepository: _GroupReadRepository(),
      characterSearchRepository: _GroupCharacterSearchRepository(),
      groupCreateRepository: _GroupCreateRepository(),
      groupJoinCommandRepository: _GroupJoinCommandRepository(),
      groupApplicationCommandRepository: _GroupApplicationCommandRepository(),
      groupJoinCodeCommandRepository: _GroupJoinCodeCommandRepository(),
    ),
  );
}

class _ActivityCharactersRepository implements ActivityCharactersRepository {
  @override
  Future<ActivityCharacters> load({required String playerId}) async =>
      ActivityCharacters(playerId: playerId, characterIds: const {});

  @override
  Future<ActivityCharacters> save(
    SaveActivityCharactersCommand command,
  ) async => ActivityCharacters(
    playerId: 'test-player',
    characterIds: command.activityCharacterIds,
  );
}

class _GroupCharacterSearchRepository
    implements GroupCharacterSearchRepository {
  @override
  Future<List<GroupRequestCharacter>> searchActiveCharactersByExactName(
    String characterName, {
    int limit = groupCharacterSearchPageSize,
  }) async => const [];

  @override
  Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(
    String ownerPlayerId, {
    int limit = groupCharacterSearchPageSize,
  }) async => const [];
}

class _GroupCreateRepository implements GroupCreateRepository {
  @override
  Future<GroupCreateResult> create(GroupCreateCommand command) async =>
      const GroupCreateResult.failure(GroupCreateFailure.unknown);
}

class _GroupJoinCodeCommandRepository
    implements GroupJoinCodeCommandRepository {
  @override
  Future<GroupJoinCodeCommandResult> createCode(
    GroupJoinCodeCreateCommand command,
  ) async => const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown);

  @override
  Future<GroupJoinCodeCommandResult> revokeCode(
    GroupJoinCodeRevokeCommand command,
  ) async => const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown);

  @override
  Future<GroupJoinCodeCommandResult> setVisibility(
    GroupJoinCodeVisibilityCommand command,
  ) async => const GroupJoinCodeCommandResult.success(visibleToMembers: true);

  @override
  Future<GroupJoinCodeCommandResult> joinByCode(
    GroupJoinByCodeCommand command,
  ) async => const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown);
}

class _GroupApplicationCommandRepository
    implements GroupApplicationCommandRepository {
  @override
  Future<GroupJoinCommandResult> approveApplication(
    GroupApplicationDecisionCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.accepted);

  @override
  Future<GroupJoinCommandResult> rejectApplication(
    GroupApplicationDecisionCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.rejected);

  @override
  Future<GroupJoinCommandResult> blockApplicant(
    GroupApplicationDecisionCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.blocked);

  @override
  Future<GroupJoinCommandResult> releaseBlock(
    GroupBlockReleaseCommand command,
  ) async => const GroupJoinCommandResult.completed();
}

class _GroupJoinCommandRepository implements GroupJoinCommandRepository {
  @override
  Future<GroupJoinCommandResult> invite(GroupInviteCommand command) async =>
      const GroupJoinCommandResult.success(GroupRequestStatus.pending);

  @override
  Future<GroupJoinCommandResult> apply(GroupApplyCommand command) async =>
      const GroupJoinCommandResult.success(GroupRequestStatus.pending);

  @override
  Future<GroupJoinCommandResult> acceptInvitation(
    GroupInvitationDecisionCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.accepted);

  @override
  Future<GroupJoinCommandResult> rejectInvitation(
    GroupInvitationDecisionCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.rejected);

  @override
  Future<GroupJoinCommandResult> cancelInvitation(
    GroupInvitationCancelCommand command,
  ) async => const GroupJoinCommandResult.success(GroupRequestStatus.cancelled);

  @override
  Future<GroupJoinCommandResult> leave(GroupLeaveCommand command) async =>
      const GroupJoinCommandResult.completed();

  @override
  Future<GroupJoinCommandResult> transferLeadership(
    GroupLeaderTransferCommand command,
  ) async => const GroupJoinCommandResult.completed();

  @override
  Future<GroupJoinCommandResult> disband(GroupDisbandCommand command) async =>
      const GroupJoinCommandResult.completed();

  @override
  Future<void> refreshMyDisplaySnapshot(
    GroupMemberDisplaySnapshotRefreshCommand command,
  ) async {}
}

class _GroupReadRepository implements GroupReadRepository {
  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) =>
      Stream.value(
        const GroupReadSnapshot(items: <GroupRelation>[], isFromCache: false),
      );

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyRequests(String playerId) =>
      Stream.value(
        const GroupReadSnapshot(items: <GroupRelation>[], isFromCache: false),
      );

  @override
  Future<List<GroupPublicSummary>> searchGroups({
    required String query,
    int limit = groupSearchPageSize,
  }) async => const [];

  @override
  Future<GroupPublicSummary?> loadGroup(String groupId) async => null;

  @override
  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  }) async => null;

  @override
  Future<List<GroupJoinRelation>> loadGroupJoinRelations({
    required String groupId,
    required GroupJoinRelationKind kind,
    int limit = groupSearchPageSize,
  }) async => const [];

  @override
  Future<GroupMember?> loadGroupMember({
    required String groupId,
    required String playerId,
  }) async => null;

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async => const [];

  @override
  Future<List<GroupMemberDisplay>> loadGroupMemberDisplays(
    String groupId,
  ) async => const [];

  @override
  Future<List<GroupBlockedPlayer>> loadBlockedPlayers({
    required String groupId,
    int limit = groupSearchPageSize,
  }) async => const [];
}

class _WeeklyRaidClaimRepository implements WeeklyRaidClaimRepository {
  @override
  Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({
    required String playerId,
    required String cycleKey,
  }) => const Stream.empty();
}

class _CharacterSummarySyncGateway implements CharacterSummarySyncGateway {
  @override
  Future<void> updateSummaries(
    List<CharacterSummaryServerPatch> patches,
  ) async {}
}

class _AccountOwnershipStatusGateway implements AccountOwnershipStatusGateway {
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
