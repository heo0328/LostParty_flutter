import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../../account/data/local/account_database.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../group/domain/repositories/group_character_search_repository.dart';
import '../../../group/domain/repositories/group_read_repository.dart';
import '../../../raid_status/data/repositories/drift_raid_status_filter_store.dart';
import '../../../raid_status/domain/repositories/raid_status_filter_store.dart';
import '../../../raid_status/presentation/widgets/raid_status_filter_sheet.dart';
import '../../domain/repositories/party_read_repository.dart';
import '../viewmodels/public_recruitment_list_view_model.dart';
import '../widgets/local_recruitment_card.dart';

class RecruitmentListPage extends StatefulWidget {
  const RecruitmentListPage({
    required this.partyReadRepository,
    required this.cycleKey,
    required this.currentPlayerId,
    this.backfillOwnGroupListings,
    this.accountDatabase,
    this.filterStore,
    this.raidCatalogRepository,
    this.groupReadRepository,
    this.activityCharactersRepository,
    this.characterSearchRepository,
    super.key,
  });

  final PartyReadRepository partyReadRepository;
  final String cycleKey;
  final String currentPlayerId;
  final Future<void> Function()? backfillOwnGroupListings;
  final AccountDatabase? accountDatabase;
  final RaidStatusFilterStore? filterStore;
  final RaidCatalogRepository? raidCatalogRepository;
  final GroupReadRepository? groupReadRepository;
  final ActivityCharactersRepository? activityCharactersRepository;
  final GroupCharacterSearchRepository? characterSearchRepository;

  @override
  State<RecruitmentListPage> createState() => _RecruitmentListPageState();
}

class _RecruitmentListPageState extends State<RecruitmentListPage> {
  late final PublicRecruitmentListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final database = widget.accountDatabase;
    _viewModel = PublicRecruitmentListViewModel(
      repository: widget.partyReadRepository,
      cycleKey: widget.cycleKey,
      currentPlayerId: widget.currentPlayerId,
      backfillOwnGroupListings: widget.backfillOwnGroupListings,
      filterStore:
          widget.filterStore ??
          (database == null ? null : DriftRaidStatusFilterStore(database)),
      catalogRepository: widget.raidCatalogRepository,
      groupReadRepository: widget.groupReadRepository,
      activityCharactersRepository: widget.activityCharactersRepository,
      characterSearchRepository: widget.characterSearchRepository,
    )..addListener(_onChanged);
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (metrics.pixels < metrics.maxScrollExtent - 240) return;
    if (!_viewModel.state.canLoadMore) return;
    _viewModel.loadMore();
  }

  Future<void> _openFilter() {
    return showRaidStatusFilterSheet(context: context, viewModel: _viewModel);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('파티 모집')),
    body: Column(
      children: [
        RaidStatusFilterBar(
          label: _viewModel.filterBarLabel,
          onOpen: _openFilter,
        ),
        Expanded(child: _buildBody()),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey('createRecruitmentButton'),
      onPressed: () => context.push('/recruitments/create'),
      icon: const Icon(Icons.add),
      label: const Text('모집 만들기'),
    ),
  );

  Widget _buildBody() {
    final state = _viewModel.state;
    if (state.isLoading ||
        (state.isLoadingMore && state.originalItems.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.originalItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _failureMessage(state.failure!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('publicListRetryButton'),
                onPressed: _viewModel.refresh,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.isEmptyOriginal) {
      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isFromCache) const _OfflineNotice(),
            const SizedBox(height: 120),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '참여 가능한 공개 모집이 없습니다. 내가 참여 중인 파티는 레이드 현황에서 확인할 수 있습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (state.isEmptyFiltered) {
      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isFromCache) const _OfflineNotice(),
            if (state.pendingCharacterCheckCount > 0)
              const _InlineNotice(message: '참가 캐릭터를 확인하는 중입니다.'),
            if (state.characterCheckFailed)
              _CharacterCheckFailure(onRetry: _viewModel.retryCharacterChecks),
            const SizedBox(height: 80),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '조건에 맞는 모집이 없습니다. 필터를 바꾸거나 다음 페이지를 불러올 수 있습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (state.canLoadMore || state.appendFailure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: state.appendFailure != null
                    ? _AppendErrorFooter(
                        message: _failureMessage(state.appendFailure!),
                        onRetry: state.isLoadingMore
                            ? null
                            : _viewModel.retryAppend,
                      )
                    : OutlinedButton(
                        key: const ValueKey('publicListLoadMoreButton'),
                        onPressed: state.isLoadingMore
                            ? null
                            : _viewModel.loadMore,
                        child: const Text('더 불러오기'),
                      ),
              ),
          ],
        ),
      );
    }

    final footerCount = state.isLoadingMore || state.appendFailure != null
        ? 1
        : 0;
    return Column(
      children: [
        if (state.isFromCache) const _OfflineNotice(),
        if (state.hasFailureWithItems)
          _InlineNotice(message: _failureMessage(state.failure!)),
        if (state.pendingCharacterCheckCount > 0)
          const _InlineNotice(message: '참가 캐릭터를 확인하는 중입니다.'),
        if (state.characterCheckFailed)
          _CharacterCheckFailure(onRetry: _viewModel.retryCharacterChecks),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _viewModel.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _maybeLoadMore(notification.metrics);
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: state.items.length + footerCount,
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    if (state.isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _AppendErrorFooter(
                      message: _failureMessage(state.appendFailure!),
                      onRetry: state.isLoadingMore
                          ? null
                          : _viewModel.retryAppend,
                    );
                  }
                  final item = state.items[index];
                  return LocalRecruitmentCard(
                    recruitment: item,
                    onTap: () => context.go('/raid-status/${item.id}'),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return const _InlineNotice(message: '오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.');
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(message),
      ),
    );
  }
}

class _CharacterCheckFailure extends StatelessWidget {
  const _CharacterCheckFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Expanded(child: Text('참가 캐릭터를 확인하지 못했습니다.')),
            TextButton(
              key: const ValueKey('publicListCharacterCheckRetry'),
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppendErrorFooter extends StatelessWidget {
  const _AppendErrorFooter({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('publicListAppendRetryButton'),
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

String _failureMessage(PartyReadFailureType failure) => switch (failure) {
  PartyReadFailureType.permissionDenied => '조회 권한을 확인하지 못했습니다.',
  PartyReadFailureType.unavailable => '일시적으로 연결할 수 없습니다.',
  PartyReadFailureType.contract => '모집 데이터 형식을 확인하지 못했습니다.',
  PartyReadFailureType.unknown => '모집 목록을 불러오지 못했습니다.',
};
