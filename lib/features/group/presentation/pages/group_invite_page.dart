import 'package:flutter/material.dart';

import '../../domain/entities/group_request_character.dart';
import '../viewmodels/group_join_view_model.dart';
import '../viewmodels/group_read_view_model.dart';

/// 계약 §8.3. 정확한 캐릭터명으로만 검색하고 동명이인은 서버·직업·아이템 레벨을
/// 함께 표시해 Character ID로 대상을 확정한다.
class GroupInvitePage extends StatefulWidget {
  const GroupInvitePage({
    required this.groupId,
    required this.viewModel,
    super.key,
  });

  final String groupId;
  final GroupInviteViewModel viewModel;

  @override
  State<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends State<GroupInvitePage> {
  final _controller = TextEditingController();
  List<GroupRequestCharacter>? _candidates;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('멤버 초대')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('groupInviteQueryField'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: '캐릭터명',
                helperText: '정확한 캐릭터명을 입력해 주세요.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('groupInviteSearchButton'),
                  onPressed: _busy ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    final candidates = _candidates;
    if (candidates == null) {
      return const Center(child: Text('초대할 캐릭터명을 검색해 주세요.'));
    }
    if (candidates.isEmpty) {
      return const Center(child: Text('같은 이름의 인증 캐릭터를 찾을 수 없습니다.'));
    }
    return ListView.separated(
      itemCount: candidates.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return ListTile(
          key: ValueKey('inviteCandidate-${candidate.characterId}'),
          title: Text(candidate.characterName),
          subtitle: Text(
            '${candidate.serverName} · ${candidate.characterClassName}'
            '${candidate.itemLevel == null ? '' : ' · Lv ${candidate.itemLevel!.toStringAsFixed(2)}'}',
          ),
          trailing: FilledButton(
            onPressed: _busy ? null : () => _invite(candidate),
            child: const Text('초대'),
          ),
        );
      },
    );
  }

  Future<void> _search() async {
    final query = _controller.text;
    if (!widget.viewModel.isValidQuery(query)) {
      setState(() => _message = '캐릭터명을 확인해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final candidates = await widget.viewModel.search(query);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = groupReadFailureMessage(error);
      });
    }
  }

  Future<void> _invite(GroupRequestCharacter candidate) async {
    setState(() => _busy = true);
    final result = await widget.viewModel.invite(
      groupId: widget.groupId,
      character: candidate,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final failure = result.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? '${candidate.characterName} 님을 초대했습니다.'
              : groupJoinFailureMessage(failure),
        ),
      ),
    );
  }
}
