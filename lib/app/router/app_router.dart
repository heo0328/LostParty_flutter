import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../../features/account/data/datasources/local_account_data_source.dart';
import '../../features/account/data/local/account_database.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/data/gateways/local_game_account_verification_gateway.dart';
import '../../features/account/data/gateways/firestore_account_ownership_status_gateway.dart';
import '../../features/account/data/gateways/firestore_character_summary_sync_gateway.dart';
import '../../features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart';
import '../../features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart';
import '../../features/account/data/gateways/firestore_representative_character_sync_gateway.dart';
import '../../features/account/data/mappers/sibling_character_mapper.dart';
import '../../features/account/data/repositories/firestore_weekly_raid_claim_repository.dart';
import '../../features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart';
import '../../features/account/data/repositories/firestore_weekly_raid_status_repository.dart';
import '../../features/account/data/repositories/local_character_weekly_raid_display_repository.dart';
import '../../features/account/data/repositories/local_nice_group_auto_refresh_settings_repository.dart';
import '../../features/account/presentation/pages/api_token_settings_page.dart';
import '../../features/account/presentation/pages/character_management_page.dart';
import '../../features/account/presentation/pages/character_detail_page.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/account/presentation/pages/game_account_verification_page.dart';
import '../../features/account/domain/repositories/weekly_raid_claim_repository.dart';
import '../../features/account/domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../features/account/domain/repositories/weekly_raid_status_repository.dart';
import '../../features/account/domain/entities/local_game_account.dart';
import '../../features/account/domain/repositories/account_ownership_status_gateway.dart';
import '../../features/account/domain/repositories/character_summary_sync_gateway.dart';
import '../../features/account/domain/repositories/character_weekly_raid_display_repository.dart';
import '../../features/account/domain/repositories/game_account_verification_gateway.dart';
import '../../features/account/data/repositories/firestore_activity_characters_repository.dart';
import '../../features/account/domain/repositories/activity_characters_repository.dart';
import '../../features/account/domain/repositories/representative_character_sync_gateway.dart';
import '../../features/account/domain/services/character_summary_sync_service.dart';
import '../../features/account/domain/services/character_auto_refresh_coordinator.dart';
import '../../features/account/domain/services/character_minimum_display_sync_service.dart';
import '../../features/account/domain/services/representative_character_sync_service.dart';
import '../../features/account/domain/services/startup_character_refresh_orchestrator.dart';
import '../../features/player/domain/entities/player_session.dart';
import '../../features/group/data/repositories/firestore_group_application_command_repository.dart';
import '../../features/group/data/repositories/firestore_group_character_search_repository.dart';
import '../../features/group/data/repositories/firestore_group_create_repository.dart';
import '../../features/group/data/repositories/firestore_group_join_code_command_repository.dart';
import '../../features/group/data/repositories/firestore_group_join_command_repository.dart';
import '../../features/group/data/repositories/firestore_group_read_repository.dart';
import '../../features/group/domain/repositories/group_application_command_repository.dart';
import '../../features/group/domain/repositories/group_character_search_repository.dart';
import '../../features/group/domain/repositories/group_create_repository.dart';
import '../../features/group/domain/repositories/group_join_code_command_repository.dart';
import '../../features/group/domain/repositories/group_join_command_repository.dart';
import '../../features/group/domain/repositories/group_read_repository.dart';
import '../../features/group/domain/services/group_local_member_display_lookup.dart';
import '../../features/group/presentation/pages/group_applications_page.dart';
import '../../features/group/presentation/pages/group_create_page.dart';
import '../../features/group/presentation/pages/group_detail_page.dart';
import '../../features/group/presentation/pages/group_invite_page.dart';
import '../../features/group/presentation/pages/group_join_by_code_page.dart';
import '../../features/group/presentation/pages/group_join_code_page.dart';
import '../../features/group/presentation/pages/group_search_page.dart';
import '../../features/group/presentation/pages/group_tab_page.dart';
import '../../features/group/presentation/viewmodels/group_application_view_model.dart';
import '../../features/group/presentation/viewmodels/group_create_view_model.dart';
import '../../features/group/presentation/viewmodels/group_join_code_view_model.dart';
import '../../features/group/presentation/viewmodels/group_join_view_model.dart';
import '../../features/group/presentation/viewmodels/group_read_view_model.dart';
import '../../features/manual_verification/data/firestore_manual_verification_repository.dart';
import '../../features/manual_verification/domain/entities/manual_verification_request.dart';
import '../../features/manual_verification/domain/repositories/manual_verification_repository.dart';
import '../../features/manual_verification/presentation/pages/manual_verification_page.dart';
import '../../features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart';
import '../../features/manual_verification/presentation/pages/operator_manual_verification_queue_page.dart';
import '../../features/operator_access/data/repositories/firestore_operator_access_repository.dart';
import '../../features/operator_access/domain/repositories/operator_access_repository.dart';
import '../../features/operator_access/presentation/pages/operator_user_detail_page.dart';
import '../../features/operator_access/presentation/pages/operator_user_list_page.dart';
import '../../features/raid_status/data/repositories/drift_raid_status_filter_store.dart';
import '../../features/raid_status/data/services/firestore_party_event_sync_service.dart';
import '../../features/raid_status/domain/services/party_event_sync_service.dart';
import '../../features/raid_status/presentation/pages/party_notifications_page.dart';
import '../../features/raid_status/presentation/pages/party_read_detail_page.dart';
import '../../features/raid_status/presentation/pages/raid_status_page.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_active_raid_assignment_lookup.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart';
import '../../features/recruitment_list/data/repositories/party_atomic_cycle_command_adapter.dart';
import '../../features/recruitment_list/data/repositories/party_atomic_membership_command_adapter.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_read_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart';
import '../../features/recruitment_list/domain/repositories/party_read_repository.dart';
import '../../features/recruitment_list/domain/policies/party_cycle_policy.dart';
import '../../features/recruitment_list/presentation/pages/recruitment_list_page.dart';
import '../../features/recruitment_list/presentation/pages/recruitment_create_page.dart';
import '../../features/recruitment_list/presentation/pages/recruitment_detail_page.dart';
import '../../features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';
import '../../features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import '../../features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart';
import '../../features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart';
import '../../features/recruitment_list/data/fakes/local_recruitment_demo_seed.dart';
import '../../features/recruitment_list/domain/services/recruitment_command_service.dart';
import '../../features/recruitment_list/domain/services/recruitment_application_candidate_service.dart';
import '../../features/recruitment_list/domain/services/recruitment_leader_candidate_service.dart';
import '../../features/recruitment_list/domain/services/lazy_cycle_reconciler.dart';
import '../../features/recruitment_list/domain/policies/participation_conflict_policy.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/game_catalog/data/datasources/asset_game_catalog_data_source.dart';
import '../../shared/game_catalog/data/repositories/game_catalog_repository_impl.dart';
import '../../shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import '../../shared/raid_catalog/data/repositories/raid_catalog_repository_impl.dart';
import '../../shared/lost_ark_api/auth/secure_api_token_store.dart';
import '../../shared/lost_ark_api/client/lost_ark_api_client.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _raidStatusNavigatorKey = GlobalKey<NavigatorState>();
final _accountNavigatorKey = GlobalKey<NavigatorState>();
final _recruitmentNavigatorKey = GlobalKey<NavigatorState>();
final _groupNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  required AccountDatabase accountDatabase,
  required PlayerSession playerSession,
  AccountOwnershipStatusGateway? ownershipStatusGateway,
  GameAccountVerificationGateway? gameAccountVerificationGateway,
  PartyReadRepository? partyReadRepository,
  PartyEventSyncService? partyEventSyncService,
  WeeklyRaidClaimRepository? weeklyRaidClaimRepository,
  WeeklyRaidStatusRepository? weeklyRaidStatusRepository,
  CharacterSummarySyncGateway? characterSummarySyncGateway,
  WeeklyRaidClaimCommandRepository? weeklyRaidClaimCommandRepository,
  CharacterWeeklyRaidDisplayRepository? weeklyRaidDisplayRepository,
  RepresentativeCharacterSyncGateway? representativeCharacterSyncGateway,
  ActivityCharactersRepository? activityCharactersRepository,
  OperatorAccessRepository? operatorAccessRepository,
  ManualVerificationRepository? manualVerificationRepository,
  GroupReadRepository? groupReadRepository,
  GroupCharacterSearchRepository? characterSearchRepository,
  GroupCreateRepository? groupCreateRepository,
  GroupJoinCommandRepository? groupJoinCommandRepository,
  GroupApplicationCommandRepository? groupApplicationCommandRepository,
  GroupJoinCodeCommandRepository? groupJoinCodeCommandRepository,
  StartupCharacterRefreshRunner? startupCharacterRefreshRunner,
}) {
  final operatorAccessRepositoryOrDefault =
      operatorAccessRepository ?? FirestoreOperatorAccessRepository();
  GroupReadRepository? groupReadRepositoryCache = groupReadRepository;
  GroupReadRepository groupReadRepositoryForRoute() =>
      groupReadRepositoryCache ??= FirestoreGroupReadRepository(
        firestore: FirebaseFirestore.instance,
      );
  GroupCharacterSearchRepository? characterSearchRepositoryCache =
      characterSearchRepository;
  GroupCharacterSearchRepository characterSearchRepositoryForRoute() =>
      characterSearchRepositoryCache ??=
          FirestoreGroupCharacterSearchRepository(
            firestore: FirebaseFirestore.instance,
          );
  GroupCreateRepository? groupCreateRepositoryCache = groupCreateRepository;
  GroupJoinCommandRepository? groupJoinCommandRepositoryCache =
      groupJoinCommandRepository;
  GroupApplicationCommandRepository? groupApplicationCommandRepositoryCache =
      groupApplicationCommandRepository;
  GroupApplicationCommandRepository
  groupApplicationCommandRepositoryForRoute() =>
      groupApplicationCommandRepositoryCache ??=
          FirestoreGroupApplicationCommandRepository(
            firestore: FirebaseFirestore.instance,
            firebaseAuth: FirebaseAuth.instance,
          );
  GroupJoinCodeCommandRepository? groupJoinCodeCommandRepositoryCache =
      groupJoinCodeCommandRepository;
  GroupJoinCodeManageViewModel? groupJoinCodeManageViewModelCache;
  GroupApplicationsViewModel groupApplicationsViewModelForRoute() =>
      GroupApplicationsViewModel(
        readRepository: groupReadRepositoryForRoute(),
        commandRepository: groupApplicationCommandRepositoryForRoute(),
      );
  final partyReadRepositoryOrDefault =
      partyReadRepository ??
      FirestorePartyReadRepository(firestore: FirebaseFirestore.instance);
  final backfillOwnGroupListings = partyReadRepository == null
      ? FirestorePartyRaidListingBackfill(
          firestore: FirebaseFirestore.instance,
        ).backfillOwnGroupListings
      : null;
  final partyEventSyncServiceOrDefault =
      partyEventSyncService ??
      FirestorePartyEventSyncService(
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
        database: accountDatabase,
      );
  final defaultWeeklyRaidClaimRepository = weeklyRaidClaimRepository == null
      ? FirestoreWeeklyRaidClaimRepository(
          firestore: FirebaseFirestore.instance,
          firebaseAuth: FirebaseAuth.instance,
        )
      : null;
  final weeklyRaidClaimRepositoryOrDefault =
      weeklyRaidClaimRepository ?? defaultWeeklyRaidClaimRepository!;
  final weeklyRaidClaimCommandRepositoryOrDefault =
      weeklyRaidClaimCommandRepository ??
      (weeklyRaidClaimRepository == null
          ? FirestoreWeeklyRaidStatusCommandRepository(
              firestore: FirebaseFirestore.instance,
              firebaseAuth: FirebaseAuth.instance,
            )
          : (weeklyRaidClaimRepositoryOrDefault
                    is WeeklyRaidClaimCommandRepository
                ? weeklyRaidClaimRepositoryOrDefault
                      as WeeklyRaidClaimCommandRepository
                : null));
  final weeklyRaidStatusRepositoryOrDefault =
      weeklyRaidStatusRepository ??
      (weeklyRaidClaimRepository == null
          ? FirestoreWeeklyRaidStatusRepository(
              firestore: FirebaseFirestore.instance,
            )
          : null);
  final weeklyRaidDisplayRepositoryOrDefault =
      weeklyRaidDisplayRepository ??
      LocalCharacterWeeklyRaidDisplayRepository(database: accountDatabase);
  final niceGroupSettingsRepository =
      LocalNiceGroupAutoRefreshSettingsRepository(database: accountDatabase);
  const cyclePolicy = PartyCyclePolicy();
  final currentCycleKey = cyclePolicy.keyFor(DateTime.now());
  final currentCycle = cyclePolicy.fromKey(currentCycleKey)!;
  final partyAtomicCommandRepository = FirestorePartyAtomicCommandRepository(
    firestore: FirebaseFirestore.instance,
    firebaseAuth: FirebaseAuth.instance,
  );
  final partyCycleCommandRepository = PartyAtomicCycleCommandAdapter(
    firestore: FirebaseFirestore.instance,
    firebaseAuth: FirebaseAuth.instance,
    atomicCommandRepository: partyAtomicCommandRepository,
  );
  final lazyCycleReconciler = LazyCycleReconciler(
    gateway: FirestoreLazyCycleReconciliationGateway(
      firestore: FirebaseFirestore.instance,
      cycleRepository: partyCycleCommandRepository,
    ),
    cyclePolicy: cyclePolicy,
  );
  final apiTokenStore = SecureApiTokenStore();
  final apiClient = LostArkApiClient(apiTokenStore: apiTokenStore);
  final gameCatalogRepository = GameCatalogRepositoryImpl(
    dataSource: AssetGameCatalogDataSource(),
  );
  final remoteDataSource = LostArkCharacterRemoteDataSource(
    apiClient: apiClient,
  );
  final localAccountDataSource = LocalAccountDataSource(
    database: accountDatabase,
    gameCatalogRepository: gameCatalogRepository,
  );
  final accountRepository = AccountRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localAccountDataSource,
    ownershipStatusGateway:
        ownershipStatusGateway ??
        FirestoreAccountOwnershipStatusGateway(
          firestore: FirebaseFirestore.instance,
          firebaseAuth: FirebaseAuth.instance,
        ),
  );
  final startupCharacterRefreshRunnerOrDefault =
      startupCharacterRefreshRunner ??
      StartupCharacterRefreshOrchestrator(
        playerId: playerSession.playerId,
        accountRepository: accountRepository,
        niceGroupAutoRefreshSettingsRepository: niceGroupSettingsRepository,
        refreshGateway: CharacterAutoRefreshCoordinator(
          accountRepository: accountRepository,
          minimumDisplaySync: CharacterMinimumDisplaySyncService(
            accountRepository: accountRepository,
            gateway: FirestoreCharacterMinimumDisplaySyncGateway(
              firestore: FirebaseFirestore.instance,
              firebaseAuth: FirebaseAuth.instance,
            ),
          ),
        ),
      );
  final activityCharactersRepositoryOrDefault =
      activityCharactersRepository ??
      FirestoreActivityCharactersRepository(
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
      );
  GroupLocalMemberDisplayLookup groupLocalMemberDisplayLookupForRoute() =>
      GroupLocalMemberDisplayLookup(
        accountRepository: accountRepository,
        activityCharactersRepository: activityCharactersRepositoryOrDefault,
        playerId: playerSession.playerId,
      );
  GroupCreateRepository groupCreateRepositoryForRoute() =>
      groupCreateRepositoryCache ??= FirestoreGroupCreateRepository(
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
        localMemberDisplayLookup: groupLocalMemberDisplayLookupForRoute(),
      );
  GroupJoinCommandRepository groupJoinCommandRepositoryForRoute() =>
      groupJoinCommandRepositoryCache ??= FirestoreGroupJoinCommandRepository(
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
        localMemberDisplayLookup: groupLocalMemberDisplayLookupForRoute(),
      );
  GroupJoinCodeCommandRepository groupJoinCodeCommandRepositoryForRoute() =>
      groupJoinCodeCommandRepositoryCache ??=
          FirestoreGroupJoinCodeCommandRepository(
            firestore: FirebaseFirestore.instance,
            firebaseAuth: FirebaseAuth.instance,
            localMemberDisplayLookup: groupLocalMemberDisplayLookupForRoute(),
          );
  GroupJoinCodeManageViewModel groupJoinCodeManageViewModelForRoute() =>
      groupJoinCodeManageViewModelCache ??= GroupJoinCodeManageViewModel(
        readRepository: groupReadRepositoryForRoute(),
        commandRepository: groupJoinCodeCommandRepositoryForRoute(),
      );
  final representativeSyncGatewayOrDefault =
      representativeCharacterSyncGateway ??
      FirestoreRepresentativeCharacterSyncGateway(
        playerId: playerSession.playerId,
      );
  final representativeSyncService = RepresentativeCharacterSyncService(
    accountRepository: accountRepository,
    gateway: representativeSyncGatewayOrDefault,
  );
  final characterSummarySyncService = CharacterSummarySyncService(
    accountRepository: accountRepository,
    fetchSummaries: (characterName) async {
      final dtos = await remoteDataSource.fetchSiblings(characterName);
      return dtos.map((dto) => dto.toDomain()).toList(growable: false);
    },
    syncGateway:
        characterSummarySyncGateway ??
        FirestoreCharacterSummarySyncGateway(
          firestore: FirebaseFirestore.instance,
          firebaseAuth: FirebaseAuth.instance,
        ),
  );
  final verificationGateway =
      gameAccountVerificationGateway ??
      LocalGameAccountVerificationGateway(
        remoteDataSource: remoteDataSource,
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
      );
  final manualVerificationRepositoryOrDefault =
      manualVerificationRepository ??
      (Firebase.apps.isEmpty
          ? null
          : FirestoreManualVerificationRepository(
              remoteDataSource: remoteDataSource,
            ));
  ManualVerificationRepository manualVerificationRepositoryForRoute() =>
      manualVerificationRepositoryOrDefault ??
      FirestoreManualVerificationRepository(remoteDataSource: remoteDataSource);
  final raidCatalogRepository = RaidCatalogRepositoryImpl(
    dataSource: AssetRaidCatalogDataSource(),
  );
  final recruitmentRepository = InMemoryRecruitmentStateRepository();
  recruitmentRepository.seed(createLocalRecruitmentDemoSeed(DateTime.now()));
  final weeklyRaidClearRepository = InMemoryWeeklyRaidClearRepository();
  const participationConflictPolicy = ParticipationConflictPolicy(
    scheduleConflictsEnabled: false,
  );
  final activeRaidAssignmentRepository = InMemoryActiveRaidAssignmentRepository(
    conflictPolicy: participationConflictPolicy,
  );
  final serverActiveRaidAssignmentLookup = FirestoreActiveRaidAssignmentLookup(
    firestore: FirebaseFirestore.instance,
  );
  final recruitmentCommandService = RecruitmentCommandService(
    session: FakeUserSession(playerSession.playerId),
    clock: FakeRecruitmentClock(DateTime.now()),
    idGenerator: SequentialRecruitmentIdGenerator(),
    repository: recruitmentRepository,
    weeklyClearRepository: weeklyRaidClearRepository,
    assignmentRepository: activeRaidAssignmentRepository,
  );
  final recruitmentCandidateService = RecruitmentApplicationCandidateService(
    accountRepository: accountRepository,
    weeklyClearRepository: weeklyRaidClearRepository,
    session: recruitmentCommandService.session,
    clock: recruitmentCommandService.clock,
    assignmentRepository: activeRaidAssignmentRepository,
    assignmentLookup: serverActiveRaidAssignmentLookup,
    recruitmentRepository: recruitmentRepository,
    weeklyRaidClaimRepository: weeklyRaidClaimRepositoryOrDefault,
    weeklyRaidStatusRepository: weeklyRaidStatusRepositoryOrDefault,
    claimPlayerId: playerSession.playerId,
    activityCharactersRepository: activityCharactersRepositoryOrDefault,
    conflictPolicy: participationConflictPolicy,
  );
  final recruitmentLeaderCandidateService = RecruitmentLeaderCandidateService(
    accountRepository: accountRepository,
    weeklyClearRepository: weeklyRaidClearRepository,
    session: recruitmentCommandService.session,
    clock: recruitmentCommandService.clock,
    assignmentRepository: activeRaidAssignmentRepository,
    assignmentLookup: serverActiveRaidAssignmentLookup,
    recruitmentRepository: recruitmentRepository,
    weeklyRaidClaimRepository: weeklyRaidClaimRepositoryOrDefault,
    weeklyRaidStatusRepository: weeklyRaidStatusRepositoryOrDefault,
    claimPlayerId: playerSession.playerId,
    activityCharactersRepository: activityCharactersRepositoryOrDefault,
    conflictPolicy: participationConflictPolicy,
  );

  final raidStatusRefreshSignal = ValueNotifier<int>(0);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/raid-status',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(
            navigationShell: navigationShell,
            manualVerificationRepository: manualVerificationRepositoryOrDefault,
            startupCharacterRefreshRunner:
                startupCharacterRefreshRunnerOrDefault,
            onRaidStatusSelected: () => raidStatusRefreshSignal.value++,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _raidStatusNavigatorKey,
            routes: [
              GoRoute(
                path: '/raid-status',
                builder: (context, state) => RaidStatusPage(
                  partyReadRepository: partyReadRepositoryOrDefault,
                  accountDatabase: accountDatabase,
                  eventSyncService: partyEventSyncServiceOrDefault,
                  playerId: playerSession.playerId,
                  cycleKey: currentCycleKey,
                  raidCatalogRepository: raidCatalogRepository,
                  groupReadRepository: groupReadRepositoryForRoute(),
                  activityCharactersRepository:
                      activityCharactersRepositoryOrDefault,
                  characterSearchRepository:
                      characterSearchRepositoryForRoute(),
                  onInitialLoadComplete: () {
                    unawaited(startupCharacterRefreshRunnerOrDefault.runOnce());
                  },
                  refreshSignal: raidStatusRefreshSignal,
                  cycleReconciler: lazyCycleReconciler,
                  applicationCleanupRepository:
                      FirestorePartyApplicationCleanupRepository(
                        firestore: FirebaseFirestore.instance,
                        firebaseAuth: FirebaseAuth.instance,
                      ),
                ),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => PartyNotificationsPage(
                      accountDatabase: accountDatabase,
                      eventSyncService: partyEventSyncServiceOrDefault,
                      playerId: playerSession.playerId,
                    ),
                  ),
                  GoRoute(
                    path: ':recruitmentId',
                    builder: (context, state) {
                      final recruitmentId =
                          state.pathParameters['recruitmentId']!;
                      return PartyReadDetailPage(
                        key: ValueKey(recruitmentId),
                        recruitmentId: recruitmentId,
                        partyReadRepository: partyReadRepositoryOrDefault,
                        applicationCommandRepository:
                            FirestorePartyAtomicApplicationCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        joinCommandRepository:
                            FirestorePartyAtomicJoinCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        membershipCommandRepository:
                            PartyAtomicMembershipCommandAdapter(
                              mutationRepository:
                                  FirestorePartyAtomicMemberMutationRepository(
                                    firestore: FirebaseFirestore.instance,
                                    firebaseAuth: FirebaseAuth.instance,
                                  ),
                              removalRepository:
                                  FirestorePartyAtomicMemberRemovalRepository(
                                    firestore: FirebaseFirestore.instance,
                                    firebaseAuth: FirebaseAuth.instance,
                                  ),
                            ),
                        cycleCommandRepository: partyCycleCommandRepository,
                        cycleReconciler: lazyCycleReconciler,
                        weeklyRaidClaimCommandRepository:
                            weeklyRaidClaimCommandRepositoryOrDefault,
                        visibilityCommandRepository:
                            FirestorePartyAtomicVisibilityCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        eventSyncService: partyEventSyncServiceOrDefault,
                        accountDatabase: accountDatabase,
                        candidateService: recruitmentLeaderCandidateService,
                        groupReadRepository: groupReadRepositoryForRoute(),
                        playerId: playerSession.playerId,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => MyAccountPage(
                  apiTokenStore: apiTokenStore,
                  accountRepository: accountRepository,
                  summarySyncService: characterSummarySyncService,
                  representativeSyncService: representativeSyncService,
                  weeklyRaidClaimRepository: weeklyRaidClaimRepositoryOrDefault,
                  weeklyRaidStatusRepository:
                      weeklyRaidStatusRepositoryOrDefault,
                  weeklyRaidDisplayRepository:
                      weeklyRaidDisplayRepositoryOrDefault,
                  raidCatalogRepository: raidCatalogRepository,
                  playerId: playerSession.playerId,
                  cycleKey: currentCycleKey,
                  cycleStartedAt: currentCycle.startedAt,
                  cycleEndsAt: currentCycle.endsAt,
                  weeklyRaidClaimCommandRepository:
                      weeklyRaidClaimCommandRepositoryOrDefault,
                  manualCharacterRefreshRunner:
                      startupCharacterRefreshRunnerOrDefault
                          is ManualCharacterRefreshRunner
                      ? startupCharacterRefreshRunnerOrDefault
                            as ManualCharacterRefreshRunner
                      : null,
                ),
                routes: [
                  GoRoute(
                    path: 'characters/manage',
                    builder: (context, state) => CharacterManagementPage(
                      accountRepository: accountRepository,
                      representativeSyncGateway:
                          representativeSyncGatewayOrDefault,
                      activityCharactersRepository:
                          activityCharactersRepositoryOrDefault,
                      niceGroupSettingsRepository: niceGroupSettingsRepository,
                      playerId: playerSession.playerId,
                      accountId: state.extra as int?,
                    ),
                  ),
                  GoRoute(
                    path: 'characters/:characterId',
                    builder: (context, state) {
                      final character = state.extra;
                      if (character is! LocalAccountCharacter) {
                        return const Scaffold(
                          body: Center(child: Text('캐릭터 정보를 찾을 수 없습니다.')),
                        );
                      }
                      return CharacterDetailPage(
                        character: character,
                        accountRepository: accountRepository,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _recruitmentNavigatorKey,
            routes: [
              GoRoute(
                path: '/recruitments',
                builder: (context, state) => RecruitmentListPage(
                  partyReadRepository: partyReadRepositoryOrDefault,
                  cycleKey: currentCycleKey,
                  currentPlayerId: playerSession.playerId,
                  accountDatabase: accountDatabase,
                  filterStore: DriftRaidStatusFilterStore(accountDatabase),
                  raidCatalogRepository: raidCatalogRepository,
                  groupReadRepository: groupReadRepositoryForRoute(),
                  activityCharactersRepository:
                      activityCharactersRepositoryOrDefault,
                  characterSearchRepository:
                      characterSearchRepositoryForRoute(),
                  backfillOwnGroupListings: backfillOwnGroupListings == null
                      ? null
                      : () => backfillOwnGroupListings(
                          playerId: playerSession.playerId,
                        ),
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => RecruitmentCreatePage(
                      catalogRepository: raidCatalogRepository,
                      commandService: recruitmentCommandService,
                      candidateService: recruitmentLeaderCandidateService,
                      partyCreateRepository:
                          FirestorePartyAtomicCreateRepository(
                            firestore: FirebaseFirestore.instance,
                            firebaseAuth: FirebaseAuth.instance,
                          ),
                      groupReadRepository: groupReadRepositoryForRoute(),
                      playerId: playerSession.playerId,
                      newRecruitmentId: () => FirebaseFirestore.instance
                          .collection('recruitments')
                          .doc()
                          .id,
                      cycleKey: currentCycleKey,
                    ),
                  ),
                  GoRoute(
                    path: ':recruitmentId',
                    builder: (context, state) => RecruitmentDetailPage(
                      recruitmentId: state.pathParameters['recruitmentId']!,
                      repository: recruitmentRepository,
                      commandService: recruitmentCommandService,
                      candidateService: recruitmentCandidateService,
                      catalogRepository: raidCatalogRepository,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _groupNavigatorKey,
            routes: [
              GoRoute(
                path: '/groups',
                builder: (context, state) => GroupTabPage(
                  readRepository: groupReadRepositoryForRoute(),
                  requestsViewModel: GroupRequestsViewModel(
                    readRepository: groupReadRepositoryForRoute(),
                    commandRepository: groupJoinCommandRepositoryForRoute(),
                  ),
                  applicationsViewModel: groupApplicationsViewModelForRoute(),
                  playerId: playerSession.playerId,
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => GroupCreatePage(
                      viewModel: GroupCreateViewModel(
                        accountRepository: accountRepository,
                        createRepository: groupCreateRepositoryForRoute(),
                        activityCharactersRepository:
                            activityCharactersRepositoryOrDefault,
                        playerId: playerSession.playerId,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => GroupSearchPage(
                      viewModel: GroupSearchViewModel(
                        readRepository: groupReadRepositoryForRoute(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'join-by-code',
                    builder: (context, state) => GroupJoinByCodePage(
                      viewModel: GroupJoinByCodeViewModel(
                        accountRepository: accountRepository,
                        commandRepository:
                            groupJoinCodeCommandRepositoryForRoute(),
                        activityCharactersRepository:
                            activityCharactersRepositoryOrDefault,
                        playerId: playerSession.playerId,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':groupId',
                    builder: (context, state) => GroupDetailPage(
                      key: ValueKey(state.pathParameters['groupId']),
                      groupId: state.pathParameters['groupId']!,
                      playerId: playerSession.playerId,
                      readRepository: groupReadRepositoryForRoute(),
                      actionViewModel: GroupMembershipActionViewModel(
                        accountRepository: accountRepository,
                        combatPowerSyncGateway:
                            FirestoreCharacterCombatPowerSyncGateway(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        activityCharactersRepository:
                            activityCharactersRepositoryOrDefault,
                        playerId: playerSession.playerId,
                        readRepository: groupReadRepositoryForRoute(),
                        commandRepository: groupJoinCommandRepositoryForRoute(),
                        characterSearchRepository:
                            characterSearchRepositoryForRoute(),
                      ),
                      applicationsViewModel:
                          groupApplicationsViewModelForRoute(),
                      joinCodeManageViewModel:
                          groupJoinCodeManageViewModelForRoute(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (context, state) => GroupInvitePage(
                          groupId: state.pathParameters['groupId']!,
                          viewModel: GroupInviteViewModel(
                            searchRepository:
                                characterSearchRepositoryForRoute(),
                            commandRepository:
                                groupJoinCommandRepositoryForRoute(),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'applications',
                        builder: (context, state) => GroupApplicationsPage(
                          groupId: state.pathParameters['groupId']!,
                          viewModel: groupApplicationsViewModelForRoute(),
                        ),
                      ),
                      GoRoute(
                        path: 'join-code',
                        builder: (context, state) => GroupJoinCodePage(
                          groupId: state.pathParameters['groupId']!,
                          playerId: playerSession.playerId,
                          readRepository: groupReadRepositoryForRoute(),
                          viewModel: groupJoinCodeManageViewModelForRoute(),
                          leadershipViewModel:
                              groupApplicationsViewModelForRoute(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsPage(
          operatorAccessRepository: operatorAccessRepositoryOrDefault,
        ),
        routes: [
          GoRoute(
            path: 'game-account-verification',
            builder: (context, state) => GameAccountVerificationPage(
              accountRepository: accountRepository,
              accountManagementRepository: accountRepository,
              mappingRepository: accountRepository,
              gateway: verificationGateway,
            ),
          ),
          GoRoute(
            path: 'manual-verification',
            builder: (context, state) => ManualVerificationPage(
              accountRepository: accountRepository,
              mappingRepository: accountRepository,
              repository: manualVerificationRepositoryForRoute(),
            ),
          ),
          GoRoute(
            path: 'api-token',
            builder: (context, state) =>
                ApiTokenSettingsPage(apiTokenStore: apiTokenStore),
          ),
          GoRoute(
            path: 'operator/users',
            builder: (context, state) => OperatorUserListPage(
              repository: operatorAccessRepositoryOrDefault,
            ),
            routes: [
              GoRoute(
                path: ':playerId',
                builder: (context, state) => OperatorUserDetailPage(
                  playerId: state.pathParameters['playerId']!,
                  repository: operatorAccessRepositoryOrDefault,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'operator/manual-verification',
            builder: (context, state) => OperatorManualVerificationQueuePage(
              operatorAccessRepository: operatorAccessRepositoryOrDefault,
              repository: manualVerificationRepositoryForRoute(),
            ),
            routes: [
              GoRoute(
                path: ':requestId',
                builder: (context, state) =>
                    OperatorManualVerificationDetailPage(
                      requestId: state.pathParameters['requestId']!,
                      initialRequest: state.extra is ManualVerificationRequest
                          ? state.extra as ManualVerificationRequest
                          : null,
                      operatorAccessRepository:
                          operatorAccessRepositoryOrDefault,
                      repository: manualVerificationRepositoryForRoute(),
                    ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
