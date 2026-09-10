import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/data/local/account_database.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/entities/party_event.dart';
import '../../../recruitment_list/domain/entities/party_recruitment.dart';
import '../../../recruitment_list/domain/entities/recruitment_aggregate.dart';
import '../../../recruitment_list/domain/entities/recruitment_application.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../../recruitment_list/domain/services/lazy_cycle_reconciler.dart';
import '../../data/repositories/drift_raid_status_filter_store.dart';
import '../../domain/repositories/raid_status_filter_store.dart';
import '../../domain/services/party_event_sync_service.dart';
import '../../domain/services/throttled_party_event_sync_service.dart';
import '../viewmodels/active_raid_filter_view_model.dart';
import '../viewmodels/party_read_stream_view_model.dart';
import '../viewmodels/raid_history_view_model.dart';
import '../widgets/raid_list_sort_row.dart';
import '../widgets/raid_status_filter_sheet.dart';

class RaidStatusPage extends StatefulWidget {
  const RaidStatusPage({
    required this.partyReadRepository,
    required this.accountDatabase,
    required this.eventSyncService,
    required this.playerId,
    required this.cycleKey,
    this.raidCatalogRepository,
    this.filterStore,
    this.groupReadRepository,
    this.activityCharactersRepository,
    this.characterSearchRepository,
    this.onInitialLoadComplete,
    this.refreshSignal,
    this.cycleReconciler,
    super.key,
  });

  final PartyReadRepository partyReadRepository;
  final AccountDatabase accountDatabase;
  final PartyEventSyncService eventSyncService;
  final String playerId;
  final String cycleKey;
  final RaidCatalogRepository? raidCatalogRepository;
  final RaidStatusFilterStore? filterStore;
  final GroupReadRepository? groupReadRepository;
  final ActivityCharactersRepository? activityCharactersRepository;
  final GroupCharacterSearchRepository? characterSearchRepository;
  final VoidCallback? onInitialLoadComplete;
  final ValueListenable<int>? refreshSignal;
  final LazyCycleReconciler? cycleReconciler;

  @override
  State<RaidStatusPage> createState() => _RaidStatusPageState();
}

class _RaidStatusPageState extends State<RaidStatusPage>
    with SingleTickerProviderStateMixin {
  late final ActiveRaidFilterViewModel _activeRaids;
  late final PartyReadStreamViewModel<PartyApplicationSummary> _applications;
  late final RaidHistoryViewModel _history;
  late final PartyEventSyncService _refreshSyncService;
  late final TabController _tabController;
  var _unreadCount = 0;
  Map<String, int> _roomUnreadCounts = const {};
  var _supplementalInitialLoadComplete = false;
  var _firstFrameRendered = false;
  var _initialLoadReported = false;

  @override
  void initState() {
    super.initState();
    _activeRaids = ActiveRaidFilterViewModel(
      streamFactory: () => widget.partyReadRepository.watchActiveRaids(
        playerId: widget.playerId,
      ),
      playerId: widget.playerId,
      filterStore:
          widget.filterStore ??
          DriftRaidStatusFilterStore(widget.accountDatabase),
      catalogRepository: widget.raidCatalogRepository,
      membersStreamFactory: (recruitmentId) =>
          widget.partyReadRepository.watchRecruitmentMembers(recruitmentId),
      groupReadRepository: widget.groupReadRepository,
      activityCharactersRepository: widget.activityCharactersRepository,
      characterSearchRepository: widget.characterSearchRepository,
    );
    _applications = PartyReadStreamViewModel<PartyApplicationSummary>(
      streamFactory: () => widget.partyReadRepository.watchApplications(
        playerId: widget.playerId,
        cycleKey: widget.cycleKey,
      ),
    );
    _refreshSyncService = ThrottledPartyEventSyncService(
      delegate: widget.eventSyncService,
    );
    _history = RaidHistoryViewModel(
      database: widget.accountDatabase,
      playerId: widget.playerId,
      syncService: _refreshSyncService,
      catalogRepository: widget.raidCatalogRepository,
    );
    _activeRaids.addListener(_checkInitialLoadComplete);
    _activeRaids.addListener(_reconcileVisibleRaids);
    _applications.addListener(_checkInitialLoadComplete);
    _activeRaids.start();
    _applications.start();
    unawaited(_initializeStatus());
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    widget.refreshSignal?.addListener(_onRefreshSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFrameRendered = true;
      _checkInitialLoadComplete();
    });
  }

  Future<void> _initializeStatus() async {
    try {
      await _history.initialize();
    } catch (error, stackTrace) {
      debugPrint('완료 기록 초기화 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    await _refreshUnread();
    if (!mounted) return;
    _supplementalInitialLoadComplete = true;
    _checkInitialLoadComplete();
  }

  Future<void> _refreshUnread() async {
    try {
      final rows = await widget.accountDatabase.loadRecentPartyNotifications(
        widget.playerId,
        limit: null,
      );
      var count = 0;
      final roomCounts = <String, int>{};
      for (final row in rows) {
        if (row.readAt != null) continue;
        final type = PartyEventType.tryParse(row.type);
        if (type?.isRoomAttentionEvent == true) {
          roomCounts.update(
            row.recruitmentId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        } else {
          count++;
        }
      }
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
        _roomUnreadCounts = roomCounts;
      });
    } catch (error, stackTrace) {
      debugPrint('읽지 않은 알림 수 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshStatus() async {
    await _reconcileVisibleRaids();
    await _history.syncNow();
    await _refreshUnread();
  }

  void _onRefreshSignal() => unawaited(_refreshStatus());

  Future<void> _reconcileVisibleRaids() async {
    final reconciler = widget.cycleReconciler;
    if (reconciler == null || _activeRaids.state.isLoading) return;
    await reconciler.reconcileAll(
      _activeRaids.state.originalItems.map((item) => item.id),
    );
  }

  void _checkInitialLoadComplete() {
    if (_initialLoadReported ||
        !_firstFrameRendered ||
        !_supplementalInitialLoadComplete ||
        _activeRaids.state.isLoading ||
        _applications.state.isLoading) {
      return;
    }
    _initialLoadReported = true;
    widget.onInitialLoadComplete?.call();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // 완료 직후 상세에 머무르다 돌아오면 초기 sync만으로는 기록이 비어 보일 수 있다.
    if (_tabController.index == 2) {
      unawaited(_refreshStatus());
    }
  }

  @override
  void dispose() {
    _activeRaids.removeListener(_checkInitialLoadComplete);
    _activeRaids.removeListener(_reconcileVisibleRaids);
    _applications.removeListener(_checkInitialLoadComplete);
    _tabController.removeListener(_onTabChanged);
    widget.refreshSignal?.removeListener(_onRefreshSignal);
    _tabController.dispose();
    _activeRaids.dispose();
    _applications.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레이드 현황'),
        actions: [
          IconButton(
            key: const ValueKey('partyNotificationsButton'),
            tooltip: '알림',
            onPressed: () async {
              await context.push('/raid-status/notifications');
              await _refreshStatus();
            },
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: ValueKey('activeRaidsTab'), text: '진행 중'),
            Tab(key: ValueKey('pendingRaidsTab'), text: '신청 중'),
            Tab(key: ValueKey('raidHistoryTab'), text: '완료 기록'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveRaidsTab(
            key: const ValueKey('activeRaidsPage'),
            viewModel: _activeRaids,
            onOpenFilter: () => showRaidStatusFilterSheet(
              context: context,
              viewModel: _activeRaids,
            ),
            onOpenRaid: (id) async {
              await context.push('/raid-status/$id');
              await _refreshStatus();
            },
            onRefresh: _refreshStatus,
            unreadCounts: _roomUnreadCounts,
          ),
          _PartyReadTab<PartyApplicationSummary>(
            key: const ValueKey('pendingRaidsPage'),
            viewModel: _applications,
            icon: Icons.hourglass_empty_outlined,
            emptyTitle: '신청 중인 레이드가 없습니다.',
            emptyDescription: '승인 대기 신청과 처리 결과가 여기에 표시됩니다.',
            rowsBuilder: (items) => _applicationRows(
              items,
              onOpen: (recruitmentId) async {
                await context.push('/raid-status/$recruitmentId');
                await _refreshStatus();
              },
            ),
            onRefresh: _refreshStatus,
          ),
          _RaidHistoryTab(
            key: const ValueKey('raidHistoryPage'),
            viewModel: _history,
            onRefresh: _refreshStatus,
          ),
        ],
      ),
    );
  }
}

class _ActiveRaidsTab extends StatelessWidget {
  const _ActiveRaidsTab({
    required this.viewModel,
    required this.onOpenFilter,
    required this.onOpenRaid,
    required this.unreadCounts,
    required this.onRefresh,
    super.key,
  });

  final ActiveRaidFilterViewModel viewModel;
  final VoidCallback onOpenFilter;
  final ValueChanged<String> onOpenRaid;
  final Map<String, int> unreadCounts;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        return Column(
          children: [
            RaidStatusFilterBar(label: state.barLabel, onOpen: onOpenFilter),
            RaidListSortRow(
              sortSelection: state.sortSelection,
              remainingSlotsSelection: state.remainingSlotsSelection,
              onToggleMemberCountSort: () {
                unawaited(viewModel.toggleMemberCountSort());
              },
              onRemainingSlotsChanged: (selection) {
                unawaited(viewModel.setRemainingSlotsSelection(selection));
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: _buildBody(state),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ActiveRaidFilterViewState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.originalItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          _RaidStatusMessageView(
            icon: Icons.error_outline,
            title: _failureMessage(state.failure!),
            description: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
          ),
        ],
      );
    }
    if (state.isEmptyOriginal) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.isFromCache) const _OfflineNotice(),
          const SizedBox(height: 100),
          const _RaidStatusMessageView(
            icon: Icons.event_available_outlined,
            title: '진행 중인 레이드가 없습니다.',
            description: '생성하거나 가입이 확정된 레이드가 여기에 표시됩니다.',
          ),
        ],
      );
    }
    if (state.isEmptyFiltered) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.isFromCache) const _OfflineNotice(),
          const SizedBox(height: 100),
          const _RaidStatusMessageView(
            icon: Icons.filter_list_off,
            title: '조건에 맞는 레이드가 없습니다.',
            description: '필터를 바꾸면 진행 중인 레이드를 다시 볼 수 있습니다.',
          ),
        ],
      );
    }
    return Column(
      children: [
        if (state.isFromCache) const _OfflineNotice(),
        if (state.hasFailureWithItems)
          _InlineNotice(
            icon: Icons.error_outline,
            message: _failureMessage(state.failure!),
          ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _ActiveRaidCard(
                summary: item,
                unreadCount: unreadCounts[item.id] ?? 0,
                onOpen: () => onOpenRaid(item.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PartyReadTab<T> extends StatelessWidget {
  const _PartyReadTab({
    required this.viewModel,
    required this.icon,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.rowsBuilder,
    required this.onRefresh,
    super.key,
  });

  final PartyReadStreamViewModel<T> viewModel;
  final IconData icon;
  final String emptyTitle;
  final String emptyDescription;
  final List<Widget> Function(List<T> items) rowsBuilder;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.failure != null && state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                _RaidStatusMessageView(
                  icon: Icons.error_outline,
                  title: _failureMessage(state.failure!),
                  description: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                ),
              ],
            ),
          );
        }
        if (state.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (state.isFromCache) const _OfflineNotice(),
                const SizedBox(height: 100),
                _RaidStatusMessageView(
                  icon: icon,
                  title: emptyTitle,
                  description: emptyDescription,
                ),
              ],
            ),
          );
        }
        final rows = rowsBuilder(state.items);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (state.isFromCache) const _OfflineNotice(),
              if (state.hasFailureWithItems)
                _InlineNotice(
                  icon: Icons.error_outline,
                  message: _failureMessage(state.failure!),
                ),
              ...rows,
            ],
          ),
        );
      },
    );
  }
}

class _RaidHistoryTab extends StatelessWidget {
  const _RaidHistoryTab({
    required this.viewModel,
    required this.onRefresh,
    super.key,
  });

  final RaidHistoryViewModel viewModel;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasLoadFailure && state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                _RaidStatusMessageView(
                  icon: Icons.error_outline,
                  title: '저장된 기록을 불러오지 못했습니다.',
                  description: '아래로 당겨 다시 시도해 주세요.',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: Column(
            children: [
              if (state.syncFailure != null)
                _InlineNotice(
                  icon: Icons.sync_problem_outlined,
                  message: _syncFailureMessage(state.syncFailure!),
                ),
              _HiddenHistoryToggle(
                showHidden: state.showHidden,
                onChanged: viewModel.setShowHidden,
              ),
              Expanded(
                child: state.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          _RaidStatusMessageView(
                            icon: Icons.history_outlined,
                            title: '완료 기록이 없습니다.',
                            description: state.showHidden
                                ? '숨긴 기록도 아직 없습니다.'
                                : '이번 주 완료와 지난 회차 기록이 여기에 표시됩니다.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) => _RaidHistoryCard(
                          item: state.items[index],
                          viewModel: viewModel,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveRaidCard extends StatelessWidget {
  const _ActiveRaidCard({
    required this.summary,
    required this.unreadCount,
    required this.onOpen,
  });

  final ActiveRaidSummary summary;
  final int unreadCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          key: ValueKey(summary.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      summary.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      if (summary.isGroupOnly)
                        const _Badge(label: '그룹', tone: _BadgeTone.highlight),
                      if (summary.isRecurringWaitingForNextWeek)
                        const _Badge(label: '다음주 대기', tone: _BadgeTone.waiting)
                      else if (summary.isRecurringCurrentWeek)
                        const _Badge(label: '금주 진행', tone: _BadgeTone.highlight)
                      else if (summary.isAwaitingDisband)
                        const _Badge(label: '해산 대기', tone: _BadgeTone.waiting),
                      if (summary.isOwnedByCurrentPlayer)
                        const _Badge(
                          label: '내가 만든 방',
                          tone: _BadgeTone.neutral,
                        ),
                    ],
                  ),
                ],
              ),
              if (summary.isAwaitingDisband && summary.isOwnedByCurrentPlayer)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '회차 완료됨. 상세에서 해산하면 방이 닫힙니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _raidLabel(summary.metadata),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _leaderName(summary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_memberLabel(summary)} · ${_requirementLabel(summary.metadata)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
                ],
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            left: 10,
            top: 0,
            child: Badge(
              key: ValueKey('raidRoomUnreadBadge_${summary.id}'),
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            ),
          ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.summary, required this.onOpen});

  final PartyApplicationSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolution = _resolutionMessage(summary);
    return Card(
      key: ValueKey('${summary.recruitmentId}_${summary.characterId}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      summary.characterName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Badge(
                    label: _applicationStatusLabel(summary.status),
                    tone: _applicationStatusTone(summary.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${summary.className} · ${_roleLabel(summary.requestedRole)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (resolution != null) ...[
                const SizedBox(height: 8),
                Text(resolution, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 8),
              Text(
                _applicationTimeLabel(summary),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 승인 대기는 아직 결과를 기다리는 신청이므로 종료된 신청과 섞지 않는다.
List<Widget> _applicationRows(
  List<PartyApplicationSummary> items, {
  required ValueChanged<String> onOpen,
}) {
  final pending = <PartyApplicationSummary>[];
  final resolved = <PartyApplicationSummary>[];
  for (final item in items) {
    if (item.status == RecruitmentApplicationStatus.pending) {
      pending.add(item);
    } else {
      resolved.add(item);
    }
  }

  return [
    if (pending.isNotEmpty) const _SectionHeader(label: '승인 대기'),
    for (final item in pending)
      _ApplicationCard(summary: item, onOpen: () => onOpen(item.recruitmentId)),
    if (resolved.isNotEmpty) const _SectionHeader(label: '최근 처리 결과'),
    for (final item in resolved)
      _ApplicationCard(summary: item, onOpen: () => onOpen(item.recruitmentId)),
  ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

enum _BadgeTone { highlight, waiting, negative, neutral }

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _BadgeTone.highlight => colorScheme.secondaryContainer,
      _BadgeTone.waiting => colorScheme.primaryContainer,
      _BadgeTone.negative => colorScheme.errorContainer,
      _BadgeTone.neutral => colorScheme.surfaceContainerHighest,
    };
    final foreground = switch (tone) {
      _BadgeTone.highlight => colorScheme.onSecondaryContainer,
      _BadgeTone.waiting => colorScheme.onPrimaryContainer,
      _BadgeTone.negative => colorScheme.onErrorContainer,
      _BadgeTone.neutral => colorScheme.onSurfaceVariant,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HiddenHistoryToggle extends StatelessWidget {
  const _HiddenHistoryToggle({
    required this.showHidden,
    required this.onChanged,
  });

  final bool showHidden;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: FilterChip(
          label: const Text('숨긴 기록 보기'),
          selected: showHidden,
          onSelected: onChanged,
        ),
      ),
    );
  }
}

enum _HistoryAction {
  correctCompleted,
  correctIncomplete,
  clearCorrection,
  hide,
  restore,
}

class _RaidHistoryCard extends StatelessWidget {
  const _RaidHistoryCard({required this.item, required this.viewModel});

  final RaidHistoryItem item;
  final RaidHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey(item.eventId),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${item.raidName} - ${item.difficultyName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: _historyStatusLabel(item.serverStatus),
                  tone: _historyStatusTone(item.serverStatus),
                ),
                PopupMenuButton<_HistoryAction>(
                  onSelected: (action) => _run(action),
                  itemBuilder: (context) => _menuItems(),
                ),
              ],
            ),
            Text(
              '${item.cycleKey} 회차 · '
              '${KoreaTimeFormatter.dayAndTime(item.occurredAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (item.isLocallyCorrected) ...[
              const SizedBox(height: 8),
              _IconLine(
                icon: Icons.edit_note_outlined,
                text: _overrideLabel(item.localOverride!),
              ),
            ],
            if (item.isHidden) ...[
              const SizedBox(height: 8),
              const _IconLine(
                icon: Icons.visibility_off_outlined,
                text: '목록에서 숨긴 기록입니다.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<_HistoryAction>> _menuItems() => [
    if (item.localOverride != RaidHistoryLocalOverride.completed)
      const PopupMenuItem(
        value: _HistoryAction.correctCompleted,
        child: Text('완료로 정정'),
      ),
    if (item.localOverride != RaidHistoryLocalOverride.incomplete)
      const PopupMenuItem(
        value: _HistoryAction.correctIncomplete,
        child: Text('미완료로 정정'),
      ),
    if (item.isLocallyCorrected)
      const PopupMenuItem(
        value: _HistoryAction.clearCorrection,
        child: Text('정정 해제'),
      ),
    if (item.isHidden)
      const PopupMenuItem(value: _HistoryAction.restore, child: Text('다시 표시'))
    else
      const PopupMenuItem(value: _HistoryAction.hide, child: Text('숨기기')),
  ];

  Future<void> _run(_HistoryAction action) => switch (action) {
    _HistoryAction.correctCompleted => viewModel.setLocalOverride(
      item.eventId,
      RaidHistoryLocalOverride.completed,
    ),
    _HistoryAction.correctIncomplete => viewModel.setLocalOverride(
      item.eventId,
      RaidHistoryLocalOverride.incomplete,
    ),
    _HistoryAction.clearCorrection => viewModel.setLocalOverride(
      item.eventId,
      null,
    ),
    _HistoryAction.hide => viewModel.setHidden(item.eventId, true),
    _HistoryAction.restore => viewModel.setHidden(item.eventId, false),
  };
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return const _InlineNotice(
      icon: Icons.cloud_off_outlined,
      message: '오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.',
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _RaidStatusMessageView extends StatelessWidget {
  const _RaidStatusMessageView({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _failureMessage(PartyReadFailureType failure) => switch (failure) {
  PartyReadFailureType.permissionDenied => '조회 권한을 확인하지 못했습니다.',
  PartyReadFailureType.unavailable => '네트워크 연결이 불안정합니다.',
  PartyReadFailureType.contract => '데이터 형식을 확인하지 못했습니다.',
  PartyReadFailureType.unknown => '목록을 불러오지 못했습니다.',
};

String _syncFailureMessage(PartyEventSyncFailure failure) => switch (failure) {
  PartyEventSyncFailure.unauthenticated ||
  PartyEventSyncFailure.playerBindingMissing => '계정 연결을 준비하지 못했습니다.',
  PartyEventSyncFailure.permissionDenied => '기록 조회 권한을 확인하지 못했습니다.',
  PartyEventSyncFailure.temporarilyUnavailable => '네트워크 연결이 불안정합니다.',
  PartyEventSyncFailure.invalidData => '기록 형식을 확인하지 못했습니다.',
  PartyEventSyncFailure.unknown => '기록을 동기화하지 못했습니다.',
};

String _roleLabel(PartyRole role) => role == PartyRole.support ? '서포터' : '딜러';

String _raidLabel(RecruitmentMetadata metadata) {
  final difficulty = metadata.difficultyAlias == metadata.difficultyName
      ? metadata.difficultyName
      : '${metadata.difficultyName} (${metadata.difficultyAlias})';
  return '${metadata.raidName} - $difficulty · ${metadata.gateCount}관문';
}

String _memberLabel(ActiveRaidSummary summary) {
  final remaining = summary.maxMemberCount - summary.memberCount;
  final slot = remaining > 0 ? '남은 자리 $remaining' : '자리 마감';
  return '멤버 ${summary.memberCount}/${summary.maxMemberCount} · $slot';
}

String _leaderName(ActiveRaidSummary summary) {
  final name = summary.leaderCharacterName?.trim();
  if (name == null || name.isEmpty) {
    return '파티장 정보 없음';
  }
  return name;
}

String _requirementLabel(RecruitmentMetadata metadata) {
  return '${metadata.minCombatPower == null ? '전투력 제한 없음' : '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}'} · '
      '${metadata.experienceLevel == null ? '숙련도 제한 없음' : '숙련도 ${_experienceLabel(metadata.experienceLevel!)}'}';
}

String _experienceLabel(ExperienceLevel level) => switch (level) {
  ExperienceLevel.tryLevel => '트라이',
  ExperienceLevel.clearExp => '클경',
  ExperienceLevel.multiClearExp => '다클경',
  ExperienceLevel.semiExperienced => '반숙',
  ExperienceLevel.experienced => '숙련',
};

/// 모집 종료로 닫힌 신청은 거절과 구분해서 안내한다.
String? _resolutionMessage(PartyApplicationSummary summary) =>
    switch (summary.status) {
      RecruitmentApplicationStatus.superseded =>
        summary.resolutionReason == 'recruitmentClosed'
            ? '모집이 종료되어 신청이 닫혔습니다.'
            : '신청이 더 이상 유효하지 않습니다.',
      _ => null,
    };

String _applicationTimeLabel(PartyApplicationSummary summary) {
  if (summary.status == RecruitmentApplicationStatus.pending) {
    return '신청 ${KoreaTimeFormatter.dayAndTime(summary.createdAt)}';
  }
  final decidedAt = summary.decidedAt ?? summary.updatedAt;
  return '처리 ${KoreaTimeFormatter.dayAndTime(decidedAt)}';
}

_BadgeTone _applicationStatusTone(RecruitmentApplicationStatus status) =>
    switch (status) {
      RecruitmentApplicationStatus.pending => _BadgeTone.waiting,
      RecruitmentApplicationStatus.approved => _BadgeTone.highlight,
      RecruitmentApplicationStatus.rejected => _BadgeTone.negative,
      RecruitmentApplicationStatus.withdrawn ||
      RecruitmentApplicationStatus.superseded => _BadgeTone.neutral,
    };

String _applicationStatusLabel(RecruitmentApplicationStatus status) =>
    switch (status) {
      RecruitmentApplicationStatus.pending => '승인 대기',
      RecruitmentApplicationStatus.approved => '승인됨',
      RecruitmentApplicationStatus.rejected => '거절됨',
      RecruitmentApplicationStatus.withdrawn => '철회함',
      RecruitmentApplicationStatus.superseded => '종료됨',
    };

_BadgeTone _historyStatusTone(RaidHistoryServerStatus status) =>
    switch (status) {
      RaidHistoryServerStatus.completed => _BadgeTone.highlight,
      RaidHistoryServerStatus.incompleteEnded => _BadgeTone.neutral,
      RaidHistoryServerStatus.completionCancelled => _BadgeTone.negative,
    };

String _overrideLabel(RaidHistoryLocalOverride override) => switch (override) {
  RaidHistoryLocalOverride.completed => '완료로 정정했습니다.',
  RaidHistoryLocalOverride.incomplete => '미완료로 정정했습니다.',
};

String _historyStatusLabel(RaidHistoryServerStatus status) => switch (status) {
  RaidHistoryServerStatus.completed => '완료',
  RaidHistoryServerStatus.incompleteEnded => '미완료 종료',
  RaidHistoryServerStatus.completionCancelled => '완료 취소',
};
