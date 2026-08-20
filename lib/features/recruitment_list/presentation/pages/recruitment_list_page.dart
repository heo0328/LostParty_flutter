import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/recruitment_state_repository.dart';
import '../viewmodels/recruitment_list_view_model.dart';
import '../widgets/local_recruitment_card.dart';

class RecruitmentListPage extends StatefulWidget {
  const RecruitmentListPage({required this.repository, super.key});
  final RecruitmentStateRepository repository;
  @override
  State<RecruitmentListPage> createState() => _RecruitmentListPageState();
}

class _RecruitmentListPageState extends State<RecruitmentListPage> {
  late final RecruitmentListViewModel _viewModel;
  @override
  void initState() {
    super.initState();
    _viewModel = RecruitmentListViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadRecruitments();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('파티 모집')),
    body: _buildBody(),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey('createRecruitmentButton'),
      onPressed: _openCreate,
      icon: const Icon(Icons.add),
      label: const Text('모집 만들기'),
    ),
  );
  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.errorMessage case final message?) {
      return Center(child: Text(message));
    }
    if (_viewModel.recruitments.isEmpty) {
      return const Center(child: Text('현재 모집 중인 파티가 없습니다.'));
    }
    return RefreshIndicator(
      onRefresh: _viewModel.loadRecruitments,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _viewModel.recruitments.length,
        itemBuilder: (context, index) {
          final item = _viewModel.recruitments[index];
          return LocalRecruitmentCard(
            recruitment: item,
            onTap: () => context.push('/recruitments/${item.id}'),
          );
        },
      ),
    );
  }

  Future<void> _openCreate() async {
    await context.push('/recruitments/create');
    await _viewModel.loadRecruitments();
  }
}
