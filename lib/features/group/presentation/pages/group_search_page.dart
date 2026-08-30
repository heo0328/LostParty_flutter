import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/group_summary.dart';
import '../viewmodels/group_read_view_model.dart';

class GroupSearchPage extends StatefulWidget {
  const GroupSearchPage({required this.viewModel, super.key});

  final GroupSearchViewModel viewModel;

  @override
  State<GroupSearchPage> createState() => _GroupSearchPageState();
}

class _GroupSearchPageState extends State<GroupSearchPage> {
  final _query = TextEditingController();
  List<GroupPublicSummary> _results = const [];
  bool _searching = true;
  bool _requestInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.viewModel.search(_query.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = groupReadFailureMessage(error);
        _searching = false;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('그룹 검색'),
        actions: [
          TextButton(
            key: const ValueKey('groupSearchJoinByCodeButton'),
            onPressed: () => context.push('/groups/join-by-code'),
            child: const Text('초대코드로 가입'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('groupSearchField'),
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '그룹명 또는 대표 캐릭터명',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('groupSearchSubmitButton'),
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(child: _resultsView(context)),
        ],
      ),
    );
  }

  Widget _resultsView(BuildContext context) {
    if (_searching) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('검색 결과가 없습니다.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = _results[index];
        return ListTile(
          key: ValueKey('groupSearchResult-${group.groupId}'),
          leading: const Icon(Icons.diversity_3_outlined),
          title: Text(group.name),
          subtitle: Text(
            '${group.representativeCharacterNameSnapshot} · ${group.representativeServerNameSnapshot} · ${group.memberCount}명',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/groups/${group.groupId}'),
        );
      },
    );
  }
}
