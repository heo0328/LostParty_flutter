import 'dart:async';

import 'package:flutter/material.dart';

import '../../../account/data/local/account_database.dart';
import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/entities/party_recruitment.dart';
import '../../../recruitment_list/domain/entities/recruitment_application.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';
import '../../domain/services/party_event_sync_service.dart';
import '../viewmodels/party_read_stream_view_model.dart';
import '../viewmodels/raid_history_view_model.dart';

class RaidStatusPage extends StatefulWidget {
  const RaidStatusPage({
    required this.partyReadRepository,
    required this.accountDatabase,
    required this.eventSyncService,
    required this.playerId,
    required this.cycleKey,
    super.key,
  });

  final PartyReadRepository partyReadRepository;
  final AccountDatabase accountDatabase;
  final PartyEventSyncService eventSyncService;
  final String playerId;
  final String cycleKey;

  @override
  State<RaidStatusPage> createState() => _RaidStatusPageState();
}

class _RaidStatusPageState extends State<RaidStatusPage> {
  late final PartyReadStreamViewModel<ActiveRaidSummary> _activeRaids;
  late final PartyReadStreamViewModel<PartyApplicationSummary> _applications;
  late final RaidHistoryViewModel _history;

  @override
  void initState() {
    super.initState();
    _activeRaids = PartyReadStreamViewModel<ActiveRaidSummary>(
      streamFactory: () =>
          widget.partyReadRepository.watchActiveRaids(playerId: widget.playerId),
    )..start();
    _applications = PartyReadStreamViewModel<PartyApplicationSummary>(
      streamFactory: () => widget.partyReadRepository.watchApplications(
        playerId: widget.playerId,
        cycleKey: widget.cycleKey,
      ),
    )..start();
    _history = RaidHistoryViewModel(
      database: widget.accountDatabase,
      playerId: widget.playerId,
      syncService: widget.eventSyncService,
    );
    unawaited(_history.initialize());
  }

  @override
  void dispose() {
    _activeRaids.dispose();
    _applications.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('레이드 현황'),
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey('activeRaidsTab'), text: '진행 중'),
              Tab(key: ValueKey('pendingRaidsTab'), text: '신청 중'),
              Tab(key: ValueKey('raidHistoryTab'), text: '완료 기록'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PartyReadTab<ActiveRaidSummary>(
              key: const ValueKey('activeRaidsPage'),
              viewModel: _activeRaids,
              icon: Icons.event_available_outlined,
              emptyTitle: '진행 중인 레이드가 없습니다.',
              emptyDescription: '생성하거나 가입이 확정된 레이드가 여기에 표시됩니다.',
              itemBuilder: (context, item) => _ActiveRaidTile(summary: item),
            ),
            _PartyReadTab<PartyApplicationSummary>(
              key: const ValueKey('pendingRaidsPage'),
              viewModel: _applications,
              icon: Icons.hourglass_empty_outlined,
              emptyTitle: '신청 중인 레이드가 없습니다.',
              emptyDescription: '승인 대기 신청과 처리 결과가 여기에 표시됩니다.',
              itemBuilder: (context, item) => _ApplicationTile(summary: item),
            ),
            _RaidHistoryTab(
              key: const ValueKey('raidHistoryPage'),
              viewModel: _history,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyReadTab<T> extends StatelessWidget {
  const _PartyReadTab({
    required this.viewModel,
    required this.icon,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.itemBuilder,
    super.key,
  });

  final PartyReadStreamViewModel<T> viewModel;
  final IconData icon;
  final String emptyTitle;
  final String emptyDescription;
  final Widget Function(BuildContext context, T item) itemBuilder;

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
          return _RaidStatusMessageView(
            icon: Icons.error_outline,
            title: _failureMessage(state.failure!),
            description: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
          );
        }
        if (state.isEmpty) {
          return Column(
            children: [
              if (state.isFromCache) const _OfflineNotice(),
              Expanded(
                child: _RaidStatusMessageView(
                  icon: icon,
                  title: emptyTitle,
                  description: emptyDescription,
                ),
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
                itemCount: state.items.length,
                itemBuilder: (context, index) =>
                    itemBuilder(context, state.items[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RaidHistoryTab extends StatelessWidget {
  const _RaidHistoryTab({required this.viewModel, super.key});

  final RaidHistoryViewModel viewModel;

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
            onRefresh: viewModel.syncNow,
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
          onRefresh: viewModel.syncNow,
          child: Column(
            children: [
              if (state.syncFailure != null)
                _InlineNotice(
                  icon: Icons.sync_problem_outlined,
                  message: _syncFailureMessage(state.syncFailure!),
                ),
              Expanded(
                child: state.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          _RaidStatusMessageView(
                            icon: Icons.history_outlined,
                            title: '완료 기록이 없습니다.',
                            description: '이번 주 완료와 지난 회차 기록이 여기에 표시됩니다.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) =>
                            _RaidHistoryTile(item: state.items[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveRaidTile extends StatelessWidget {
  const _ActiveRaidTile({required this.summary});

  final ActiveRaidSummary summary;

  @override
  Widget build(BuildContext context) {
    final metadata = summary.metadata;
    return ListTile(
      title: Text(summary.title),
      subtitle: Text(
        '${metadata.raidName} - ${metadata.difficultyName}'
        ' · ${summary.memberCount}/${summary.maxMemberCount}명',
      ),
      trailing: summary.isOwnedByCurrentPlayer
          ? const Chip(label: Text('내가 만든 방'))
          : null,
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.summary});

  final PartyApplicationSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(summary.characterName),
      subtitle: Text(
        '${summary.className} · ${_roleLabel(summary.requestedRole)}',
      ),
      trailing: Text(_applicationStatusLabel(summary.status)),
    );
  }
}

class _RaidHistoryTile extends StatelessWidget {
  const _RaidHistoryTile({required this.item});

  final RaidHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${item.raidId} - ${item.difficultyId}'),
      subtitle: Text('${item.cycleKey} 회차'),
      trailing: Text(
        item.isLocallyCorrected
            ? '${_historyStatusLabel(item.serverStatus)} (정정됨)'
            : _historyStatusLabel(item.serverStatus),
      ),
    );
  }
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

String _roleLabel(PartyRole role) =>
    role == PartyRole.support ? '서포터' : '딜러';

String _applicationStatusLabel(RecruitmentApplicationStatus status) =>
    switch (status) {
      RecruitmentApplicationStatus.pending => '승인 대기',
      RecruitmentApplicationStatus.approved => '승인됨',
      RecruitmentApplicationStatus.rejected => '거절됨',
      RecruitmentApplicationStatus.withdrawn => '철회함',
      RecruitmentApplicationStatus.superseded => '종료됨',
    };

String _historyStatusLabel(RaidHistoryServerStatus status) => switch (status) {
  RaidHistoryServerStatus.completed => '완료',
  RaidHistoryServerStatus.incompleteEnded => '미완료 종료',
  RaidHistoryServerStatus.completionCancelled => '완료 취소',
};
