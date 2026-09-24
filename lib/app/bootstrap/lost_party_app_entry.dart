import 'package:flutter/material.dart';

import '../../features/player/domain/entities/player_session.dart';
import 'account_recovery_start_page.dart';
import 'app_bootstrap.dart';
import 'app_startup_result.dart';
import 'lost_party_entry_screen.dart';

class LostPartyAppEntry extends StatefulWidget {
  const LostPartyAppEntry({
    required this.initialize,
    required this.recover,
    required this.startNew,
    required this.appBuilder,
    super.key,
  });

  final Future<AppStartupResult> Function() initialize;
  final Future<PlayerSession?> Function() recover;
  final Future<PlayerSession> Function() startNew;
  final Widget Function(BuildContext context, PlayerSession session) appBuilder;

  @override
  State<LostPartyAppEntry> createState() => _LostPartyAppEntryState();
}

class _LostPartyAppEntryState extends State<LostPartyAppEntry> {
  PlayerSession? _session;

  void _useSession(PlayerSession session) {
    if (mounted) setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) return widget.appBuilder(context, session);

    return AppBootstrap<AppStartupResult>(
      initialize: widget.initialize,
      minimumLoadingDuration: lostPartyEntryAnimationDuration,
      transitionDuration: const Duration(milliseconds: 280),
      loadingBuilder: (_) => const LostPartyEntryScreen(),
      appBuilder: (context, result) => switch (result) {
        AppStartupReady(:final session) => widget.appBuilder(context, session),
        AppStartupAuthenticationRequired() => AccountRecoveryStartPage(
          recover: widget.recover,
          startNew: widget.startNew,
          onReady: _useSession,
        ),
      },
    );
  }
}
