import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/router/app_router.dart';
import 'features/account/data/local/account_database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({this.accountDatabase, super.key});

  final AccountDatabase? accountDatabase;

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
    _router = createAppRouter(accountDatabase: _accountDatabase);
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
