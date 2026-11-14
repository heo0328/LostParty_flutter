import '../../features/recruitment_list/presentation/viewmodels/raid_room_usage_controller.dart';
import 'dart:async';
import '../../features/recruitment_list/presentation/viewmodels/roster_issue_controller.dart';
import '../../features/recruitment_list/presentation/widgets/roster_issue_badge.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/domain/services/startup_character_refresh_orchestrator.dart';
import '../../features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';
import '../../features/manual_verification/domain/entities/manual_verification_request.dart';
import '../../features/manual_verification/domain/repositories/manual_verification_repository.dart';
import '../../features/manual_verification/presentation/manual_verification_dispute_alert.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigationShell,
    this.manualVerificationRepository,
    this.startupCharacterRefreshRunner,
    this.scopedStartupRefresh,
    this.onRaidStatusSelected,
    this.onAccountSelected,
    this.raidUsage,
    this.rosterIssues,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final ManualVerificationRepository? manualVerificationRepository;
  final StartupCharacterRefreshRunner? startupCharacterRefreshRunner;
  final ScopedStartupRefreshController? scopedStartupRefresh;
  final VoidCallback? onRaidStatusSelected;
  final VoidCallback? onAccountSelected;
  final RaidRoomUsageController? raidUsage;
  final RosterIssueController? rosterIssues;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  GoRouter? _accountRouter;
  String? _accountPath;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_accountRouter, router)) {
      _accountRouter?.routeInformationProvider.removeListener(
        _accountRouteChanged,
      );
      _accountRouter = router;
      router.routeInformationProvider.addListener(_accountRouteChanged);
      _accountRouteChanged();
    }
  }

  void _accountRouteChanged() {
    final path = _accountRouter?.routeInformationProvider.value.uri.path;
    if (path == _accountPath) return;
    _accountPath = path;
    if (path == '/account') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _accountPath == '/account') {
          widget.onAccountSelected?.call();
        }
      });
    }
  }

  static const _navigationMaxWidth = 600.0;

  var _alertShownThisSession = false;
  StreamSubscription<List<ManualVerificationRequest>>? _disputeSubscription;
  List<ManualVerificationRequest> _incomingDisputes = const [];
  StreamSubscription<StartupCharacterRefreshState>? _refreshSubscription;
  var _isStartupCharacterRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    widget.scopedStartupRefresh?.addListener(_scopedRefreshChanged);
    _isStartupCharacterRefreshRunning =
        widget.scopedStartupRefresh?.isBusy ?? false;
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
    _disputeSubscription = repository.watchIncomingDisputes().listen((
      disputes,
    ) {
      if (!mounted) return;
      setState(() => _incomingDisputes = disputes);
    }, onError: (_) {});
  }

  void _scopedRefreshChanged() {
    if (!mounted) return;
    final running = widget.scopedStartupRefresh?.isBusy ?? false;
    if (running != _isStartupCharacterRefreshRunning) {
      setState(() => _isStartupCharacterRefreshRunning = running);
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopedStartupRefresh != widget.scopedStartupRefresh) {
      oldWidget.scopedStartupRefresh?.removeListener(_scopedRefreshChanged);
      widget.scopedStartupRefresh?.addListener(_scopedRefreshChanged);
      _isStartupCharacterRefreshRunning =
          widget.scopedStartupRefresh?.isBusy ??
          widget.startupCharacterRefreshRunner?.state.isRunning ??
          false;
    }
  }

  @override
  void dispose() {
    _accountRouter?.routeInformationProvider.removeListener(
      _accountRouteChanged,
    );
    _disputeSubscription?.cancel();
    widget.scopedStartupRefresh?.removeListener(_scopedRefreshChanged);
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
      bottomNavigationBar: ColoredBox(
        color:
            NavigationBarTheme.of(context).backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainer,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _navigationMaxWidth),
            child: NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _selectBranch,
              destinations: [
                NavigationDestination(
                  icon: _raidIcon(Icons.event_note_outlined),
                  selectedIcon: _raidIcon(Icons.event_note),
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
          ),
        ),
      ),
    );
  }

  Widget _raidIcon(IconData icon) {
    final usage = widget.raidUsage;
    if (usage == null) return Icon(icon);
    return ListenableBuilder(
      listenable: Listenable.merge([
        usage,
        if (widget.rosterIssues != null) widget.rosterIssues!,
      ]),
      builder: (context, _) => RosterIssueBadge(
        visible: widget.rosterIssues?.hasIssues == true,
        child: Tooltip(
          message: widget.rosterIssues?.failure != null
              ? '캐릭터 경고 갱신 실패 · 다시 확인해 주세요.'
              : widget.rosterIssues?.value == null
              ? '캐릭터 경고 미확인'
              : '레이드 현황',
          child: Badge(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            textColor: Theme.of(context).colorScheme.onPrimaryContainer,
            isLabelVisible: usage.authenticated,
            label: Text(
              usage.label,
              semanticsLabel: usage.label == '—/—'
                  ? '참가 모집방 사용량 미확인'
                  : '참가 모집방 ${usage.label}',
            ),
            child: Icon(icon),
          ),
        ),
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
    if (index == 0) widget.onRaidStatusSelected?.call();
    if (index == 1) widget.onAccountSelected?.call();
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
