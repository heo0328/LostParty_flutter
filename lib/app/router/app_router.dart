import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/account/presentation/pages/api_token_settings_page.dart';
import '../../features/recruitment_list/presentation/pages/recruitment_list_page.dart';
import '../../shared/lost_ark_api/auth/secure_api_token_store.dart';
import '../../shared/lost_ark_api/client/lost_ark_api_client.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _accountNavigatorKey = GlobalKey<NavigatorState>();
final _recruitmentNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  final apiTokenStore = SecureApiTokenStore();
  final apiClient = LostArkApiClient(apiTokenStore: apiTokenStore);
  final accountRepository = AccountRepositoryImpl(
    remoteDataSource: LostArkCharacterRemoteDataSource(apiClient: apiClient),
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
