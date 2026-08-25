import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/app_services_initializer.dart';
import 'app/router/app_router.dart';
import 'features/account/data/local/account_database.dart';
import 'features/account/domain/repositories/account_ownership_status_gateway.dart';
import 'features/account/domain/repositories/game_account_verification_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialize: initializeAppServices,
      appBuilder: (_) => const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    this.accountDatabase,
    this.ownershipStatusGateway,
    this.gameAccountVerificationGateway,
    super.key,
  });

  final AccountDatabase? accountDatabase;
  final AccountOwnershipStatusGateway? ownershipStatusGateway;
  final GameAccountVerificationGateway? gameAccountVerificationGateway;

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
      ownershipStatusGateway: widget.ownershipStatusGateway,
      gameAccountVerificationGateway: widget.gameAccountVerificationGateway,
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
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    return MaterialApp.router(
      title: 'LOSTPARTY',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
      ),
      routerConfig: _router,
    );
  }
}
