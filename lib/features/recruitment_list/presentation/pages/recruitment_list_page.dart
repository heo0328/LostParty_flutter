import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/party_read_repository.dart';
import '../viewmodels/public_recruitment_list_view_model.dart';
import '../widgets/local_recruitment_card.dart';

class RecruitmentListPage extends StatefulWidget {
  const RecruitmentListPage({
    required this.partyReadRepository,
    required this.cycleKey,
    super.key,
  });

  final PartyReadRepository partyReadRepository;
  final String cycleKey;

  @override
  State<RecruitmentListPage> createState() => _RecruitmentListPageState();
}

class _RecruitmentListPageState extends State<RecruitmentListPage> {
  late final PublicRecruitmentListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PublicRecruitmentListViewModel(
      repository: widget.partyReadRepository,
      cycleKey: widget.cycleKey,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('파티 모집')),
    body: _buildBody(),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey('createRecruitmentButton'),
      onPressed: () => context.push('/recruitments/create'),
      icon: const Icon(Icons.add),
      label: const Text('모집 만들기'),
    ),
  );

  Widget _buildBody() {
    final state = _viewModel.state;
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.items.isEmpty) {
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
    if (state.isEmpty) {
      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isFromCache) const _OfflineNotice(),
            const SizedBox(height: 120),
            const Center(child: Text('현재 모집 중인 파티가 없습니다.')),
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
    return const _InlineNotice(
      message: '오프라인 상태입니다. 마지막으로 받은 내용을 표시합니다.',
    );
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
