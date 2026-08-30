import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/manual_verification/domain/entities/manual_verification_request.dart';
import '../../features/manual_verification/domain/repositories/manual_verification_repository.dart';
import '../../features/manual_verification/presentation/manual_verification_dispute_alert.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigationShell,
    this.manualVerificationRepository,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final ManualVerificationRepository? manualVerificationRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _alertShownThisSession = false;
  StreamSubscription<List<ManualVerificationRequest>>? _disputeSubscription;
  List<ManualVerificationRequest> _incomingDisputes = const [];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _selectBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '레이드 현황',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 계정',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: '레이드 모집',
          ),
          NavigationDestination(
            icon: Icon(Icons.diversity_3_outlined),
            selectedIcon: Icon(Icons.diversity_3),
            label: '그룹',
          ),
        ],
      ),
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
