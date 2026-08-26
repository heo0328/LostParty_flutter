import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../../features/account/data/datasources/local_account_data_source.dart';
import '../../features/account/data/local/account_database.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/data/gateways/local_game_account_verification_gateway.dart';
import '../../features/account/data/gateways/firestore_account_ownership_status_gateway.dart';
import '../../features/account/data/gateways/firestore_character_summary_sync_gateway.dart';
import '../../features/account/data/mappers/sibling_character_mapper.dart';
import '../../features/account/presentation/pages/api_token_settings_page.dart';
import '../../features/account/presentation/pages/character_management_page.dart';
import '../../features/account/presentation/pages/character_detail_page.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/account/presentation/pages/game_account_verification_page.dart';
import '../../features/account/domain/entities/local_game_account.dart';
import '../../features/account/domain/repositories/account_ownership_status_gateway.dart';
import '../../features/account/domain/repositories/game_account_verification_gateway.dart';
import '../../features/account/domain/services/character_summary_sync_service.dart';
import '../../features/player/domain/entities/player_session.dart';
import '../../features/raid_status/data/services/firestore_party_event_sync_service.dart';
import '../../features/raid_status/domain/services/party_event_sync_service.dart';
import '../../features/raid_status/presentation/pages/party_read_detail_page.dart';
import '../../features/raid_status/presentation/pages/raid_status_page.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_create_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart';
import '../../features/recruitment_list/data/repositories/firestore_party_read_repository.dart';
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
final _settingsNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  required AccountDatabase accountDatabase,
  required PlayerSession playerSession,
  AccountOwnershipStatusGateway? ownershipStatusGateway,
  GameAccountVerificationGateway? gameAccountVerificationGateway,
  PartyReadRepository? partyReadRepository,
  PartyEventSyncService? partyEventSyncService,
}) {
  final partyReadRepositoryOrDefault =
      partyReadRepository ??
      FirestorePartyReadRepository(firestore: FirebaseFirestore.instance);
  final partyEventSyncServiceOrDefault =
      partyEventSyncService ??
      FirestorePartyEventSyncService(
        firestore: FirebaseFirestore.instance,
        firebaseAuth: FirebaseAuth.instance,
        database: accountDatabase,
      );
  final currentCycleKey = const PartyCyclePolicy().keyFor(DateTime.now());
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
  final characterSummarySyncService = CharacterSummarySyncService(
    accountRepository: accountRepository,
    fetchSummaries: (characterName) async {
      final dtos = await remoteDataSource.fetchSiblings(characterName);
      return dtos.map((dto) => dto.toDomain()).toList(growable: false);
    },
    syncGateway: FirestoreCharacterSummarySyncGateway(
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
  final recruitmentCommandService = RecruitmentCommandService(
    session: FakeUserSession('local-user'),
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
    recruitmentRepository: recruitmentRepository,
    conflictPolicy: participationConflictPolicy,
  );
  final recruitmentLeaderCandidateService = RecruitmentLeaderCandidateService(
    accountRepository: accountRepository,
    weeklyClearRepository: weeklyRaidClearRepository,
    session: recruitmentCommandService.session,
    clock: recruitmentCommandService.clock,
    assignmentRepository: activeRaidAssignmentRepository,
    recruitmentRepository: recruitmentRepository,
    conflictPolicy: participationConflictPolicy,
  );

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/raid-status',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
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
                ),
                routes: [
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
                            FirestorePartyApplicationCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        joinCommandRepository:
                            FirestorePartyJoinCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        membershipCommandRepository:
                            FirestorePartyMembershipCommandRepository(
                              firestore: FirebaseFirestore.instance,
                              firebaseAuth: FirebaseAuth.instance,
                            ),
                        candidateService: recruitmentLeaderCandidateService,
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
                ),
                routes: [
                  GoRoute(
                    path: 'characters/manage',
                    builder: (context, state) => CharacterManagementPage(
                      accountRepository: accountRepository,
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
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => RecruitmentCreatePage(
                      catalogRepository: raidCatalogRepository,
                      commandService: recruitmentCommandService,
                      candidateService: recruitmentLeaderCandidateService,
                      partyCreateRepository: FirestorePartyCreateRepository(
                        firestore: FirebaseFirestore.instance,
                        firebaseAuth: FirebaseAuth.instance,
                      ),
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
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
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
                    path: 'api-token',
                    builder: (context, state) =>
                        ApiTokenSettingsPage(apiTokenStore: apiTokenStore),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
