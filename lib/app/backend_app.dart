import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_session_view.dart';

import '../features/auth/data/android_google_authentication_gateway.dart';
import '../features/auth/data/auth_session_store.dart';
import '../features/auth/data/backend_auth_api.dart';
import '../features/auth/domain/auth_session_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/account/data/local/account_database.dart';
import '../features/account/data/backend_account_read_api.dart';
import '../features/account/data/server_account_verification_client.dart';
import '../features/account/data/ownership_command_store.dart';
import '../features/account/presentation/widgets/ownership_notice_title.dart';
import '../features/account/presentation/viewmodels/ownership_dispute_controller.dart';
import '../features/account/presentation/pages/server_verification_page.dart';
import '../features/account/presentation/viewmodels/server_verification_view_model.dart';
import '../features/account/presentation/viewmodels/server_registration_view_model.dart';
import '../features/account/presentation/viewmodels/server_combat_power_view_model.dart';
import '../features/account/presentation/viewmodels/member_settings_view_model.dart';
import '../features/account/presentation/pages/server_registration_page.dart';
import '../features/account/domain/account_read_session.dart';
import '../features/account/domain/server_account_read_repository.dart';
import '../features/account/presentation/viewmodels/server_account_read_view_model.dart';
import '../features/account/presentation/widgets/server_accounts_panel.dart';
import '../features/account/presentation/widgets/server_registration_edit_dialog.dart';
import '../features/account/domain/policies/account_label_policy.dart';
import '../features/account/presentation/pages/server_account_characters_page.dart';

import '../features/account/data/datasources/local_account_data_source.dart';
import '../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../features/account/data/repositories/account_repository_impl.dart';
import '../features/account/data/mappers/sibling_character_mapper.dart';
import '../features/account/domain/entities/local_game_account.dart';
import '../features/account/domain/services/character_summary_sync_service.dart';
import '../features/account/presentation/pages/my_account_page.dart';
import '../features/account/presentation/pages/character_management_page.dart';
import '../features/account/data/scoped_character_management_gateway.dart';
import '../features/account/data/member_weekly_store.dart';
import '../features/account/presentation/pages/api_token_settings_page.dart';
import '../features/account/presentation/pages/member_key_page.dart';
import '../features/account/presentation/viewmodels/member_lostark_key.dart';
import '../shared/lost_ark_api/client/api_cooldown.dart';
import '../shared/lost_ark_api/auth/secure_api_token_store.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/recruitment_list/data/repositories/pending_backend_party_read_repository.dart';
import '../features/recruitment_list/presentation/pages/recruitment_list_page.dart';
import '../features/recruitment_list/data/backend_recruitment_repository.dart';
import '../features/recruitment_list/data/cycle_read_repository.dart';
import '../features/recruitment_list/presentation/pages/cycle_own_rooms_page.dart';
import '../features/recruitment_list/presentation/pages/backend_recruitment_create_page.dart';
import '../features/recruitment_list/presentation/pages/backend_recruitment_detail_page.dart';
import '../features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import '../features/account/data/member_raid_client.dart';
import '../features/account/domain/services/account_detail_access.dart';
import '../features/recruitment_list/domain/services/party_cycle_runtime.dart';
import '../shared/game_catalog/data/datasources/asset_game_catalog_data_source.dart';
import '../shared/game_catalog/data/repositories/game_catalog_repository_impl.dart';
import '../shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart';
import '../shared/raid_catalog/data/repositories/raid_catalog_repository_impl.dart';
import '../shared/lost_ark_api/client/lost_ark_api_client.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'bootstrap/lost_party_entry_screen.dart';
import 'bootstrap/startup_entry_gate.dart';
import 'backend_account_lifecycle.dart';
import 'backend_member_account.dart';
import '../features/account/presentation/pages/member_account_page.dart';
import '../features/account/presentation/scoped_account_routes.dart';
import '../features/account/presentation/widgets/scoped_server_accounts_panel.dart';

bool allowedAuthBaseUrl(String value, {required bool debug}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  if (uri.scheme == 'https') return true;
  return debug && uri.scheme == 'http';
}

class BackendApp extends StatefulWidget {
  const BackendApp({super.key});
  @override
  State<BackendApp> createState() => _BackendAppState();
}

class _BackendAppState extends State<BackendApp> with WidgetsBindingObserver {
  MemberLostArkKey? _memberKey;
  ApiCooldown? _cooldown;
  AccountDatabase? _database;
  AuthSessionController? _auth;
  ServerAccountReadViewModel? _serverReads;
  ServerRegistrationViewModel? _serverWrites;
  ServerCombatPowerViewModel? _serverPowers;
  MemberSettingsViewModel? _memberSettings;
  ServerVerificationViewModel? _verification;
  OwnershipDisputeController? _ownership;
  BackendAccountLifecycle? _accountLifecycle;
  BackendMemberAccount? _memberAccount;
  BackendRecruitmentCreateViewModel? _recruitmentCreate;
  final _managementGateways =
      <(String, String, int, String), ScopedCharacterManagementGateway>{};
  GoRouter? _router;
  OwnershipNoticeNavigation? _ownershipNavigation;
  PartyCycleRuntime? _cycle;
  Dio? _dio;
  String? _configurationError;
  final _setupNavigatorKey = GlobalKey<NavigatorState>();
  final _entryGate = StartupEntryGate();
  @override
  void initState() {
    super.initState();
    _entryGate.addListener(_entryReady);
    WidgetsBinding.instance.addObserver(this);
    const configured = String.fromEnvironment('BACKEND_BASE_URL');
    final base = configured.isNotEmpty
        ? configured
        : (kDebugMode ? 'http://10.0.2.2:8000' : '');
    _initializeServices(base);
  }

  void _entryReady() {
    if (mounted) setState(() {});
  }

  void _initializeServices(String base) {
    if (!allowedAuthBaseUrl(base, debug: kDebugMode)) {
      _configurationError = 'Backend HTTPS 주소를 BACKEND_BASE_URL로 설정해 주세요.';
      return;
    }
    _database = AccountDatabase();
    _cycle = PartyCycleRuntime();
    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        followRedirects: false,
      ),
    );
    _auth = AuthSessionController(
      api: DioBackendAuthApi(_dio!),
      google: AndroidGoogleAuthenticationGateway(),
      store: SecureAuthSessionStore(environment: Uri.parse(base).origin),
      serverClientId: const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue:
            '574337852234-vdkvdobbq8es2rdpumc1icqt6ja3a3cr.apps.googleusercontent.com',
      ),
    );
    try {
      _router = _createRouter();
      _ownershipNavigation = OwnershipNoticeNavigation(_router!, _ownership!);
    } on AccountReadException {
      _configurationError = '서버 연결 주소를 확인하지 못했습니다. 연결 설정을 확인한 뒤 앱을 다시 실행해 주세요.';
      return;
    }
    _entryGate.start();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    await _auth!.restore();
    if (!mounted) return;
  }

  GoRouter _createRouter() {
    final auth = _auth!;
    final readSession = AuthAccountReadSession(auth);
    _cooldown = ApiCooldown();
    final accountApi = DioBackendAccountReadApi(
      _dio!,
      readSession,
      cooldown: _cooldown,
    );
    _memberKey = MemberLostArkKey(
      accountApi,
      readSession,
      SecureMemberKeyStorage(Uri.parse(_dio!.options.baseUrl).origin),
      SecureApiTokenStore(),
      _cooldown!,
    );
    _memberSettings = MemberSettingsViewModel(accountApi, readSession);
    _verification = ServerVerificationViewModel(
      ServerAccountVerificationClient(accountApi, readSession),
      cooldown: _cooldown,
    );
    final serverAccounts = ServerAccountReadRepository(accountApi, readSession);
    final lifecycle = _accountLifecycle = BackendAccountLifecycle(
      api: accountApi,
      registrations: serverAccounts,
      enabled: true,
      allowHttp: kDebugMode,
      bootstrapEnabled: const bool.fromEnvironment(
        'BACKEND_ACCOUNT_BOOTSTRAP_ENABLED',
        defaultValue: true,
      ),
    );
    if (!lifecycle.enabled) {
      _serverReads = ServerAccountReadViewModel(serverAccounts, readSession);
    }
    _serverWrites = ServerRegistrationViewModel(
      accountApi,
      serverAccounts,
      readSession,
      cooldown: _cooldown,
      onCommandStarted: lifecycle.onCommandStarted,
      onCommandFinished: lifecycle.onCommandFinished,
    );
    _serverPowers = ServerCombatPowerViewModel(
      serverAccounts,
      _serverWrites!,
      readSession,
    );
    final tokenStore = _memberKey!;
    Future<void> reloadServerState() async {
      if (!readSession.isAuthenticated) return;
      final scope = accountReadScope(readSession);
      if (lifecycle.enabled) {
        await lifecycle.refresh(scope);
      } else {
        await _serverReads!.load();
      }
      if (lifecycle.isCurrent(scope)) await _serverPowers!.reload();
    }

    Future<void> manageServerAccounts(BuildContext context) async {
      final scope = readSession.isAuthenticated
          ? accountReadScope(readSession)
          : null;
      await context.push('/account/server-management');
      if (scope != null && lifecycle.isCurrent(scope)) {
        await reloadServerState();
      }
    }

    var editingRegistration = false;
    Future<void> editServerAccount(BuildContext context, String id) async {
      if (editingRegistration) return;
      if (!_serverWrites!.canWrite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _serverWrites!.hasPending
                  ? '등록 관리에서 변경 결과를 확인해 주세요.'
                  : '잠시 후 다시 시도해 주세요.',
            ),
            action: _serverWrites!.hasPending
                ? SnackBarAction(
                    label: '등록 관리',
                    onPressed: () => manageServerAccounts(context),
                  )
                : null,
          ),
        );
        return;
      }
      editingRegistration = true;
      final scope = accountReadScope(readSession);
      try {
        final registrations = await serverAccounts.loadRegistrations();
        if (!context.mounted || !lifecycle.isCurrent(scope)) return;
        final account = registrations
            .where((r) => r.registrationId == id)
            .firstOrNull;
        if (account == null) {
          throw const AccountReadException('REGISTRATION_NOT_FOUND');
        }
        final result = await showServerRegistrationEditDialog(
          context,
          account: account,
          displayLabel: AccountLabelPolicy.serverLabels(registrations)[id]!,
          session: readSession,
        );
        if (result == null || !context.mounted || !lifecycle.isCurrent(scope)) {
          return;
        }
        await _serverWrites!.edit(account, result.$1, result.$2);
        if (!context.mounted || !lifecycle.isCurrent(scope)) return;
        await reloadServerState();
        await _memberAccount?.model.refresh();
        if (!context.mounted || !lifecycle.isCurrent(scope)) return;
        final writes = _serverWrites!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              writes.failure != null
                  ? accountReadErrorMessage(writes.failure!)
                  : writes.hasPending
                  ? '변경 결과 확인 필요'
                  : '원정대 정보를 저장했습니다.',
            ),
            action: writes.hasPending
                ? SnackBarAction(
                    label: '등록 관리',
                    onPressed: () => manageServerAccounts(context),
                  )
                : null,
          ),
        );
      } on AccountReadException catch (error) {
        if (context.mounted && lifecycle.isCurrent(scope)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(accountReadErrorMessage(error))),
          );
        }
      } finally {
        editingRegistration = false;
      }
    }

    final remote = LostArkCharacterRemoteDataSource(
      apiClient: LostArkApiClient(
        apiTokenStore: tokenStore,
        cooldown: _cooldown,
        scopeIdentity: () => (
          readSession.userId,
          readSession.generation,
          readSession.isAuthenticated,
          _memberKey?.value?.version,
        ),
      ),
    );
    final catalog = GameCatalogRepositoryImpl(
      dataSource: AssetGameCatalogDataSource(),
    );
    if (lifecycle.enabled) {
      _memberAccount = BackendMemberAccount(
        automaticRefreshEnabled: true,
        weeklyStore: const SecureMemberWeeklyStore(),
        lifecycle: lifecycle,
        settings: _memberSettings!,
        key: _memberKey!,
        remote: remote,
        catalog: catalog,
        cooldown: _cooldown!,
      );
      _memberAccount!.initialize();
    }
    _ownership = OwnershipDisputeController(
      api: accountApi,
      session: readSession,
      baseUrl: _dio!.options.baseUrl,
      currentBaseUrl: () => _dio!.options.baseUrl,
      allowHttp: kDebugMode,
      commands: OwnershipCommandStore(const SecureOwnershipJournalStorage()),
      onAccountStateChanged: (scope) async {
        requireAccountReadScope(readSession, scope);
        if (lifecycle.model?.commandInProgress == true ||
            lifecycle.runtime?.characterSettingsBusy == true) {
          // Current ownership changed: fence old reads immediately even when
          // an existing account writer must finish before reconciliation.
          lifecycle.model?.invalidate();
          throw const AccountReadException(
            'REQUEST_IN_PROGRESS',
            retryAfter: Duration(seconds: 2),
          );
        }
        final gate = lifecycle.model;
        if (gate != null) {
          gate.beginCommand();
          await gate.finishCommand();
        } else {
          await reloadServerState();
        }
        requireAccountReadScope(readSession, scope);
        if (lifecycle.model?.failure case final failure?) {
          throw AccountReadException(failure.code);
        }
        await _memberAccount?.model.refresh();
        requireAccountReadScope(readSession, scope);
        if (_memberAccount?.model.failure case final failure?) {
          throw AccountReadException(failure);
        }
      },
    )..initialize();
    final accounts = AccountRepositoryImpl(
      basicOnly: true,
      remoteDataSource: remote,
      localDataSource: LocalAccountDataSource(
        database: _database!,
        gameCatalogRepository: catalog,
      ),
    );
    final summary = CharacterSummarySyncService(
      accountRepository: accounts,
      fetchSummaries: (name) async => (await remote.fetchSiblings(
        name,
      )).map((dto) => dto.toDomain()).toList(),
      syncGateway: null,
    );
    Future<void> openCharacters(BuildContext context, String id) async {
      await context.push('/account/characters/manage?registrationId=$id');
    }

    final raidCatalog = RaidCatalogRepositoryImpl(
      dataSource: AssetRaidCatalogDataSource(),
    );
    final cycleReads = CycleReadRepository(accountApi);
    String cycleScopeKey() =>
        '${_dio!.options.baseUrl}/${readSession.userId}/${readSession.generation}/${lifecycle.runtime?.readGeneration}';
    final recruitmentGateway = BackendRecruitmentRepository(
      api: accountApi,
      accounts: serverAccounts,
      raids: MemberRaidClient(accountApi),
    );
    final recruitmentCreate = _recruitmentCreate =
        BackendRecruitmentCreateViewModel(
          gateway: recruitmentGateway,
          session: readSession,
          accessChanges: _memberAccount?.model ?? auth,
          hasVerifiedAccount: () =>
              _memberAccount?.model.sections.any(
                (s) => hasAccountDetailAccess(
                  ownershipStatus: s.registration.ownershipStatus,
                  accountId: s.registration.accountId,
                  ownershipRevision: s.registration.ownershipRevision,
                ),
              ) ??
              false,
        );
    Widget pending(
      String title, {
      bool protected = true,
      bool alertOnEntry = false,
    }) => _PendingFeaturePage(
      auth: auth,
      title: title,
      protected: protected,
      alertOnEntry: alertOnEntry,
    );
    Widget localAccounts(BuildContext context) => MyAccountPage(
      basicOnly: true,
      onAuthenticate: () => readSession.isAuthenticated
          ? context.push('/settings/game-account-verification')
          : showLoginRequired(context, auth),
      apiTokenStore: tokenStore,
      apiCooldown: _cooldown,
      accountRepository: accounts,
      summarySyncService: summary,
      showServerOwnership: false,
      serverAccountsSection: lifecycle.model != null
          ? ScopedServerAccountsPanel(
              model: lifecycle.model!,
              onLogin: () => showLoginRequired(context, auth),
              onManage: () => manageServerAccounts(context),
              onOpen: (id) async {
                await context.push('/account/server/$id');
              },
              onHistory: () async {
                await context.push('/account/character-retirements');
              },
            )
          : ServerAccountsPanel(
              viewModel: _serverReads!,
              onLogin: () => showLoginRequired(context, auth),
              onManage: () => manageServerAccounts(context),
              onOpen: (id) => context.push('/account/server/$id'),
            ),
    );
    return GoRouter(
      initialLocation: '/account',
      refreshListenable: auth,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
            navigationShell: shell,
            scopedStartupRefresh:
                _memberAccount?.automaticRefreshEnabled == true
                ? _memberAccount!.runner
                : null,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/raid-status',
                  builder: (context, _) => _memberAccount?.weekly == null
                      ? pending('레이드 현황')
                      : CycleOwnRoomsPage(
                          weekly: _memberAccount!.weekly!,
                          repository: cycleReads,
                          scopeKey: cycleScopeKey,
                          onLogin: () => showLoginRequired(context, auth),
                          onRoom: (id, t) => context.push(
                            '/recruitments/$id?target_cycle_key=$t',
                          ),
                        ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/account',
                  builder: (context, _) => AccountSessionView(
                    session: readSession,
                    localBuilder: localAccounts,
                    memberBuilder: _memberAccount != null
                        ? (context) => MemberAccountPage(
                            model: _memberAccount!.model,
                            availability: _memberAccount!.availability,
                            weekly: _memberAccount!.weekly,
                            onParticipation: (id, t) => context.push(
                              '/recruitments/$id?target_cycle_key=$t',
                            ),
                            settings: _memberSettings!,
                            onSettings: () => context.push('/settings'),
                            onKey: () => context.push('/settings/api-token'),
                            onVerify: () => context.push(
                              '/settings/game-account-verification',
                            ),
                            onManage: () => manageServerAccounts(context),
                            automaticRefreshAvailable:
                                _memberAccount!.automaticRefreshEnabled,
                            onEdit: (id) => editServerAccount(context, id),
                            onVerifyRegistration: (id) => context
                                .push(
                                  '/settings/game-account-verification?registrationId=$id',
                                )
                                .then((_) async {
                                  if (readSession.isAuthenticated) {
                                    await _memberAccount?.model.refresh();
                                  }
                                }),
                            onHistory: () =>
                                context.push('/account/character-retirements'),
                            onServerStatus: (id) =>
                                context.push('/account/server/$id'),
                            onCharacters: (id) => openCharacters(context, id),
                          )
                        : null,
                  ),
                  routes: [
                    GoRoute(
                      path: 'server-management',
                      builder: (context, _) => ServerRegistrationPage(
                        writes: _serverWrites!,
                        reads: serverAccounts,
                        session: readSession,
                        onLogin: () => showLoginRequired(context, auth),
                        onOpen: (id) => context.push('/account/server/$id'),
                        onVerify: (id) => context.push(
                          '/settings/game-account-verification?registrationId=$id',
                        ),
                      ),
                    ),
                    ...serverAccountReadRoutes(
                      model: lifecycle.model,
                      legacyCharacters: (context, id) =>
                          ServerAccountCharactersPage(
                            registrationId: id,
                            repository: serverAccounts,
                            session: readSession,
                            onLogin: () => showLoginRequired(context, auth),
                            powers: _serverPowers,
                          ),
                      onLogin: (context) => showLoginRequired(context, auth),
                    ),
                    GoRoute(
                      path: 'characters/manage',
                      builder: (context, state) {
                        final id = state.uri.queryParameters['registrationId'];
                        final runtime = lifecycle.runtime;
                        if (id != null &&
                            runtime != null &&
                            readSession.isAuthenticated) {
                          final member = accountReadScope(readSession);
                          final key = (
                            runtime.baseUrl,
                            member.userId,
                            member.generation,
                            id,
                          );
                          final gateway = _managementGateways.putIfAbsent(
                            key,
                            () => ScopedCharacterManagementGateway(
                              runtime,
                              id,
                              otherWorkPending: () =>
                                  _memberAccount?.model.managementBlocked ??
                                  true,
                            ),
                          );
                          return CharacterManagementPage(
                            accountRepository: accounts,
                            managementGateway: gateway,
                            onSaved: () => _memberAccount!.model
                                .restoreAfterManagement(gateway),
                            memberSettings: _memberSettings,
                            automaticRefreshAvailable:
                                _memberAccount!.automaticRefreshEnabled,
                          );
                        }
                        return _BasicCharacterAccessPage(
                          onAuthenticate: () => readSession.isAuthenticated
                              ? context.push(
                                  '/settings/game-account-verification',
                                )
                              : showLoginRequired(context, auth),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'characters/:characterId',
                      builder: (_, state) {
                        final character = state.extra;
                        if (character is! LocalAccountCharacter) {
                          return const Scaffold(
                            body: Center(child: Text('캐릭터 정보를 찾을 수 없습니다.')),
                          );
                        }
                        return _BasicCharacterAccessPage(
                          onAuthenticate: () => readSession.isAuthenticated
                              ? context.push(
                                  '/settings/game-account-verification',
                                )
                              : showLoginRequired(context, auth),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recruitments',
                  builder: (_, _) => RecruitmentListPage(
                    partyReadRepository: PendingBackendPartyReadRepository(),
                    backendConnectionPending: true,
                    cycleKey: _cycle!.current.key,
                    currentPlayerId: '',
                    accountDatabase: _database,
                    raidCatalogRepository: raidCatalog,
                  ),
                  routes: [
                    GoRoute(
                      path: 'create',
                      builder: (context, _) => BackendRecruitmentCreatePage(
                        model: recruitmentCreate,
                        onLogin: () => showLoginRequired(context, auth),
                      ),
                    ),
                    GoRoute(
                      path: ':recruitmentId',
                      builder: (context, state) =>
                          state.uri.queryParameters.containsKey(
                            'target_cycle_key',
                          )
                          ? CycleRoomReadPage(
                              key: ValueKey((
                                state.pathParameters['recruitmentId'],
                                state.uri.queryParameters['target_cycle_key'],
                              )),
                              repository: cycleReads,
                              roomId: state.pathParameters['recruitmentId']!,
                              target: state
                                  .uri
                                  .queryParameters['target_cycle_key']!,
                              scopeKey: cycleScopeKey,
                              changes: _memberAccount?.model ?? auth,
                              catalog: _memberAccount?.weekly?.catalog,
                              onLogin: () => showLoginRequired(context, auth),
                            )
                          : BackendRecruitmentDetailPage(
                              key: ValueKey(
                                state.pathParameters['recruitmentId'],
                              ),
                              gateway: recruitmentGateway,
                              session: readSession,
                              roomId: state.pathParameters['recruitmentId']!,
                              onLogin: () => showLoginRequired(context, auth),
                              onCreateAnother: recruitmentCreate.startAnother,
                            ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/groups',
                  builder: (_, _) => pending('그룹'),
                  routes: [
                    GoRoute(
                      path: 'search',
                      builder: (_, _) => pending('그룹 검색', protected: false),
                    ),
                    GoRoute(
                      path: 'create',
                      builder: (_, _) => pending('그룹 만들기', alertOnEntry: true),
                    ),
                    GoRoute(
                      path: 'join-by-code',
                      builder: (_, _) => pending('그룹 가입', alertOnEntry: true),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(
            auth: auth,
            termsUrl: const String.fromEnvironment('TERMS_URL'),
            privacyUrl: const String.fromEnvironment('PRIVACY_URL'),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => SettingsPage(auth: auth),
          routes: [
            GoRoute(
              path: 'api-token',
              builder: (context, _) => MemberKeyPage(
                model: tokenStore,
                onLogin: () => showLoginRequired(context, auth),
              ),
            ),
            GoRoute(
              path: 'device-api-token',
              builder: (context, _) => auth.isAuthenticated
                  ? MemberKeyPage(
                      model: tokenStore,
                      onLogin: () => showLoginRequired(context, auth),
                    )
                  : ApiTokenSettingsPage(apiTokenStore: tokenStore),
            ),
            GoRoute(
              path: 'game-account-verification',
              builder: (context, state) => ServerVerificationPage(
                model: _verification!,
                ownership: _ownership!,
                proofId: state.uri.queryParameters['proofId'],
                disputeId: state.uri.queryParameters['disputeId'],
                accounts: serverAccounts,
                onLogin: () => showLoginRequired(context, auth),
                onVerified: reloadServerState,
                onRegister: () => manageServerAccounts(context),
                onCompleted: () {
                  if (!context.mounted) return;
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/account');
                  }
                },
                initialRegistrationId:
                    state.uri.queryParameters['registrationId'],
                onVerifiedRegistration: lifecycle.enabled
                    ? (id) async {
                        final runtime = lifecycle.runtime!;
                        final member = accountReadScope(readSession),
                            scope = runtime.scope;
                        final roster = await runtime.loadMemberRoster();
                        runtime.requireCurrent(member, scope);
                        final owned = roster.rosters.any(
                          (r) =>
                              r.registration.registrationId == id &&
                              r.registration.ownershipStatus == 'owned' &&
                              r.registration.accountId != null,
                        );
                        if (!owned) {
                          throw const AccountReadException(
                            'OWNERSHIP_REQUIRED',
                          );
                        }
                      }
                    : null,
              ),
            ),
            GoRoute(
              path: 'manual-verification',
              builder: (_, _) => pending('수동 인증', alertOnEntry: true),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_memberKey?.reload());
      unawaited(_ownership?.resume());
      unawaited(_memberAccount?.weekly?.refresh());
    }
  }

  @override
  void dispose() {
    for (final gateway in _managementGateways.values) {
      gateway.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _router?.dispose();
    _entryGate.removeListener(_entryReady);
    _entryGate.dispose();
    _recruitmentCreate?.dispose();
    _memberAccount?.dispose();
    _ownership?.dispose();
    unawaited(_accountLifecycle?.close());
    _serverReads?.dispose();
    _serverPowers?.dispose();
    _memberSettings?.dispose();
    _verification?.dispose();
    _serverWrites?.dispose();
    _memberKey?.dispose();
    _cooldown?.dispose();
    _auth?.dispose();
    _dio?.close(force: true);
    _cycle?.dispose();
    unawaited(_database?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null || !_entryGate.canEnter) {
      return MaterialApp(
        navigatorKey: _setupNavigatorKey,
        theme: AppTheme.light,
        home: _configurationError != null
            ? Scaffold(body: Center(child: Text(_configurationError!)))
            : const LostPartyEntryScreen(embedded: true),
      );
    }
    return MaterialApp.router(
      title: 'LOSTPARTY',
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => OwnershipNoticeScope(
        controller: _ownership!,
        onOpen: _ownershipNavigation!.onOpen,
        child: child!,
      ),
    );
  }
}

class _PendingFeaturePage extends StatefulWidget {
  const _PendingFeaturePage({
    required this.auth,
    required this.title,
    required this.protected,
    required this.alertOnEntry,
  });
  final AuthSessionController auth;
  final String title;
  final bool protected, alertOnEntry;
  @override
  State<_PendingFeaturePage> createState() => _PendingFeaturePageState();
}

class _PendingFeaturePageState extends State<_PendingFeaturePage> {
  @override
  void initState() {
    super.initState();
    if (widget.alertOnEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.auth.isAuthenticated) {
          unawaited(showLoginRequired(context, widget.auth));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: OwnershipNoticeTitle(child: Text(widget.title)),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.protected && !widget.auth.isAuthenticated
                    ? '로그인 후 이용할 수 있습니다.'
                    : '이 기능의 신규 서버 연결을 준비 중입니다.',
              ),
              if (widget.protected && !widget.auth.isAuthenticated)
                TextButton(
                  onPressed: widget.auth.isBusy
                      ? null
                      : () => showLoginRequired(context, widget.auth),
                  child: const Text('로그인'),
                ),
              if (widget.auth.errorCode != null)
                Text(authErrorMessage(widget.auth.errorCode!)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BasicCharacterAccessPage extends StatelessWidget {
  const _BasicCharacterAccessPage({required this.onAuthenticate});
  final VoidCallback onAuthenticate;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const OwnershipNoticeTitle(child: Text('캐릭터 사용 안내'))),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '기기 조회 목록은 소유 인증 자료가 아닙니다.\n소유 인증 후 회원 캐릭터에서 상세 정보를 확인해 주세요.',
            textAlign: TextAlign.center,
          ),
          FilledButton(onPressed: onAuthenticate, child: const Text('원정대 인증')),
        ],
      ),
    ),
  );
}
