import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/app_services_initializer.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/account/data/local/account_database.dart';
import 'features/account/domain/repositories/account_ownership_status_gateway.dart';
import 'features/account/domain/repositories/character_summary_sync_gateway.dart';
import 'features/account/domain/repositories/game_account_verification_gateway.dart';
import 'features/account/domain/repositories/weekly_raid_claim_repository.dart';
import 'features/account/domain/repositories/weekly_raid_claim_command_repository.dart';
import 'features/player/domain/entities/player_session.dart';
import 'features/raid_status/domain/services/party_event_sync_service.dart';
import 'features/recruitment_list/domain/repositories/party_read_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap<PlayerSession>(
      initialize: initializeAppServices,
      appBuilder: (_, playerSession) => MyApp(playerSession: playerSession),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    required this.playerSession,
    this.accountDatabase,
    this.ownershipStatusGateway,
    this.gameAccountVerificationGateway,
    this.partyReadRepository,
    this.partyEventSyncService,
    this.weeklyRaidClaimRepository,
    this.characterSummarySyncGateway,
    this.weeklyRaidClaimCommandRepository,
    super.key,
  });

  final PlayerSession playerSession;
  final AccountDatabase? accountDatabase;
  final AccountOwnershipStatusGateway? ownershipStatusGateway;
  final GameAccountVerificationGateway? gameAccountVerificationGateway;
  final PartyReadRepository? partyReadRepository;
  final PartyEventSyncService? partyEventSyncService;
  final WeeklyRaidClaimRepository? weeklyRaidClaimRepository;
  final CharacterSummarySyncGateway? characterSummarySyncGateway;
  final WeeklyRaidClaimCommandRepository? weeklyRaidClaimCommandRepository;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  late final AccountDatabase _accountDatabase;
  late final bool _ownsAccountDatabase;

  @override
  void initState() {
    super.initState();
    _ownsAccountDatabase = widget.accountDatabase == null;
    _accountDatabase = widget.accountDatabase ?? AccountDatabase();
    _router = createAppRouter(
      accountDatabase: _accountDatabase,
      playerSession: widget.playerSession,
      ownershipStatusGateway: widget.ownershipStatusGateway,
      gameAccountVerificationGateway: widget.gameAccountVerificationGateway,
      partyReadRepository: widget.partyReadRepository,
      partyEventSyncService: widget.partyEventSyncService,
      weeklyRaidClaimRepository: widget.weeklyRaidClaimRepository,
      characterSummarySyncGateway: widget.characterSummarySyncGateway,
      weeklyRaidClaimCommandRepository: widget.weeklyRaidClaimCommandRepository,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    if (_ownsAccountDatabase) {
      _accountDatabase.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LOSTPARTY',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
