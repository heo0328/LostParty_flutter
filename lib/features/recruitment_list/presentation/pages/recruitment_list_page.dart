import 'package:flutter/material.dart';

import '../viewmodels/recruitment_list_view_model.dart';
import '../widgets/recruitment_card.dart';

class RecruitmentListPage extends StatefulWidget {
  const RecruitmentListPage({super.key});

  @override
  State<RecruitmentListPage> createState() => _RecruitmentListPageState();
}

class _RecruitmentListPageState extends State<RecruitmentListPage> {
  late final RecruitmentListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RecruitmentListViewModel.local();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadRecruitments();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recruitments')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _viewModel.errorMessage;
    if (errorMessage != null) {
      return Center(child: Text(errorMessage));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          for (final recruitment in _viewModel.recruitments)
            RecruitmentCard(recruitment: recruitment),
        ],
      ),
    );
  }
}
