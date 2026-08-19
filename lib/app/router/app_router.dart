import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../../features/account/data/datasources/local_account_data_source.dart';
import '../../features/account/data/local/account_database.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/presentation/pages/api_token_settings_page.dart';
import '../../features/account/presentation/pages/character_management_page.dart';
import '../../features/account/presentation/pages/character_detail_page.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/account/domain/entities/local_game_account.dart';
import '../../features/recruitment_list/presentation/pages/recruitment_list_page.dart';
import '../../shared/lost_ark_api/auth/secure_api_token_store.dart';
import '../../shared/lost_ark_api/client/lost_ark_api_client.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _accountNavigatorKey = GlobalKey<NavigatorState>();
final _recruitmentNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({required AccountDatabase accountDatabase}) {
  final apiTokenStore = SecureApiTokenStore();
  final apiClient = LostArkApiClient(apiTokenStore: apiTokenStore);
  final accountRepository = AccountRepositoryImpl(
    remoteDataSource: LostArkCharacterRemoteDataSource(apiClient: apiClient),
    localDataSource: LocalAccountDataSource(database: accountDatabase),
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
                    path: 'characters/manage',
                    builder: (context, state) => CharacterManagementPage(
                      accountRepository: accountRepository,
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
                builder: (context, state) => const RecruitmentListPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
