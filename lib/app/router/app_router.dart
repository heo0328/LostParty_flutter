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
import '../../features/account/presentation/pages/api_token_settings_page.dart';
import '../../features/account/presentation/pages/character_management_page.dart';
import '../../features/account/presentation/pages/character_detail_page.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/account/presentation/pages/game_account_verification_page.dart';
import '../../features/account/domain/entities/local_game_account.dart';
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
import '../../shared/game_catalog/data/datasources/asset_game_catalog_data_source.dart';
import '../../shared/game_catalog/data/repositories/game_catalog_repository_impl.dart';
import '../../shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import '../../shared/raid_catalog/data/repositories/raid_catalog_repository_impl.dart';
import '../../shared/lost_ark_api/auth/secure_api_token_store.dart';
import '../../shared/lost_ark_api/client/lost_ark_api_client.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _accountNavigatorKey = GlobalKey<NavigatorState>();
final _recruitmentNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({required AccountDatabase accountDatabase}) {
  final apiTokenStore = SecureApiTokenStore();
  final apiClient = LostArkApiClient(apiTokenStore: apiTokenStore);
  final gameCatalogRepository = GameCatalogRepositoryImpl(
    dataSource: AssetGameCatalogDataSource(),
  );
  final remoteDataSource = LostArkCharacterRemoteDataSource(
    apiClient: apiClient,
  );
  final accountRepository = AccountRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: LocalAccountDataSource(
      database: accountDatabase,
      gameCatalogRepository: gameCatalogRepository,
    ),
    ownershipStatusGateway: FirestoreAccountOwnershipStatusGateway(
      firestore: FirebaseFirestore.instance,
      firebaseAuth: FirebaseAuth.instance,
    ),
  );
  final verificationGateway = LocalGameAccountVerificationGateway(
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
    initialLocation: '/account',
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AppBranchPageView(
            navigationShell: navigationShell,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => MyAccountPage(
                  apiTokenStore: apiTokenStore,
                  accountRepository: accountRepository,
                ),
                routes: [
                  GoRoute(
                    path: 'api-token',
                    builder: (context, state) =>
                        ApiTokenSettingsPage(apiTokenStore: apiTokenStore),
                  ),
                  GoRoute(
                    path: 'verify',
                    builder: (context, state) => GameAccountVerificationPage(
                      accountRepository: accountRepository,
                      accountManagementRepository: accountRepository,
                      mappingRepository: accountRepository,
                      gateway: verificationGateway,
                    ),
                  ),
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
                builder: (context, state) =>
                    RecruitmentListPage(repository: recruitmentRepository),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => RecruitmentCreatePage(
                      catalogRepository: raidCatalogRepository,
                      commandService: recruitmentCommandService,
                      candidateService: recruitmentLeaderCandidateService,
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
        ],
      ),
    ],
  );
}
