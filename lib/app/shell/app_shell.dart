import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/domain/services/startup_character_refresh_orchestrator.dart';
import '../../features/manual_verification/domain/entities/manual_verification_request.dart';
import '../../features/manual_verification/domain/repositories/manual_verification_repository.dart';
import '../../features/manual_verification/presentation/manual_verification_dispute_alert.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigationShell,
    this.manualVerificationRepository,
    this.startupCharacterRefreshRunner,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final ManualVerificationRepository? manualVerificationRepository;
  final StartupCharacterRefreshRunner? startupCharacterRefreshRunner;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _alertShownThisSession = false;
  StreamSubscription<List<ManualVerificationRequest>>? _disputeSubscription;
  List<ManualVerificationRequest> _incomingDisputes = const [];
  StreamSubscription<StartupCharacterRefreshState>? _refreshSubscription;
  var _isStartupCharacterRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    final refreshRunner = widget.startupCharacterRefreshRunner;
    if (refreshRunner != null) {
      _isStartupCharacterRefreshRunning = refreshRunner.state.isRunning;
      _refreshSubscription = refreshRunner.states.listen((state) {
        if (!mounted || _isStartupCharacterRefreshRunning == state.isRunning) {
          return;
        }
        setState(() => _isStartupCharacterRefreshRunning = state.isRunning);
      });
    }
    final repository = widget.manualVerificationRepository;
    if (repository == null) return;
    _disputeSubscription = repository.watchIncomingDisputes().listen(
      (disputes) {
        if (!mounted) return;
        setState(() => _incomingDisputes = disputes);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _disputeSubscription?.cancel();
    _refreshSubscription?.cancel();
    final refreshRunner = widget.startupCharacterRefreshRunner;
    if (refreshRunner != null) {
      unawaited(refreshRunner.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _selectBranch,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '레이드 현황',
          ),
          NavigationDestination(
            icon: _accountIcon(Icons.person_outline),
            selectedIcon: _accountIcon(Icons.person),
            label: '내 계정',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: '레이드 모집',
          ),
          const NavigationDestination(
            icon: Icon(Icons.diversity_3_outlined),
            selectedIcon: Icon(Icons.diversity_3),
            label: '그룹',
          ),
        ],
      ),
    );
  }

  Widget _accountIcon(IconData icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (_isStartupCharacterRefreshRunning)
          const Positioned(
            right: -8,
            top: -5,
            child: SizedBox.square(
              key: ValueKey('startupCharacterRefreshIndicator'),
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  void _selectBranch(int index) {
    widget.navigationShell.goBranch(index, initialLocation: true);
    unawaited(_maybeShowDisputeAlert());
  }

  Future<void> _maybeShowDisputeAlert() async {
    if (_alertShownThisSession || _incomingDisputes.isEmpty || !mounted) {
      return;
    }
    _alertShownThisSession = true;
    await showManualVerificationDisputeAlert(
      context,
      disputes: _incomingDisputes,
    );
  }
}
