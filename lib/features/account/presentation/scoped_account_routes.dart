import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/scoped_character_retirements_page.dart';
import 'pages/scoped_server_account_page.dart';
import 'viewmodels/scoped_account_view_model.dart';

/// Both modes use the app's existing /account branch and registration UUID.
List<GoRoute> serverAccountReadRoutes({
  required ScopedAccountViewModel? model,
  required Widget Function(BuildContext, String) legacyCharacters,
  required void Function(BuildContext) onLogin,
}) => [
  GoRoute(
    path: 'server/:registrationId',
    builder: (context, state) {
      final id = state.pathParameters['registrationId']!;
      if (model == null) return legacyCharacters(context, id);
      return ScopedServerAccountPage(
        model: model,
        registrationId: id,
        onLogin: () => onLogin(context),
        onPower: () async {
          await context.push('/account/server/$id/power');
        },
        onHistory: () async {
          await context.push('/account/character-retirements');
        },
        onVerify: () => context.push(
          '/settings/game-account-verification?registrationId=$id',
        ),
        onCharacters: () async {
          await context.push('/account/characters/manage?registrationId=$id');
        },
      );
    },
    routes: [
      if (model != null)
        GoRoute(
          path: 'power',
          builder: (context, state) => legacyCharacters(
            context,
            state.pathParameters['registrationId']!,
          ),
        ),
    ],
  ),
  if (model != null)
    GoRoute(
      path: 'character-retirements',
      builder: (context, _) => ScopedCharacterRetirementsPage(
        model: model,
        onLogin: () => onLogin(context),
      ),
    ),
];
