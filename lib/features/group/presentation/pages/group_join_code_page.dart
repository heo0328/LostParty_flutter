import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../viewmodels/group_application_view_model.dart';
import '../viewmodels/group_join_code_view_model.dart';
import '../viewmodels/group_read_view_model.dart';

/// 계약 §7. 그룹장이 초대코드를 생성·복사·폐기하고 멤버 표시 정책을 바꾼다.
class GroupJoinCodePage extends StatefulWidget {
  const GroupJoinCodePage({
    required this.groupId,
    required this.playerId,
    required this.readRepository,
    required this.viewModel,
    required this.leadershipViewModel,
    super.key,
  });

  final String groupId;
  final String playerId;
  final GroupReadRepository readRepository;
  final GroupJoinCodeManageViewModel viewModel;
  final GroupApplicationsViewModel leadershipViewModel;

  @override
  State<GroupJoinCodePage> createState() => _GroupJoinCodePageState();
}

class _GroupJoinCodePageState extends State<GroupJoinCodePage> {
  late Future<GroupPublicSummary?> _group;
  late Future<bool> _isLeader;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _group = widget.readRepository.loadGroup(widget.groupId);
    _isLeader = widget.leadershipViewModel.isLeader(
      groupId: widget.groupId,
      playerId: widget.playerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('초대코드')),
      body: FutureBuilder<bool>(
        future: _isLeader,
        builder: (context, leaderSnap) {
          if (leaderSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (leaderSnap.data != true) {
            return const Center(child: Text('그룹장만 초대코드를 관리할 수 있습니다.'));
          }
          return FutureBuilder<GroupPublicSummary?>(
            future: _group,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(groupReadFailureMessage(snapshot.error!)),
                );
              }
              final group = snapshot.data;
              if (group == null || !group.isActive) {
                return const Center(child: Text('그룹을 찾을 수 없습니다.'));
              }
              return _body(group);
            },
          );
        },
      ),
    );
  }

  Widget _body(GroupPublicSummary group) {
    final activeCode = widget.viewModel.activeCode(group);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          group.hasActiveJoinCode
              ? '활성 초대코드가 있습니다. 기간이 지나 만료되지 않으며, 폐기하기 전까지 유효합니다.'
              : '활성 초대코드가 없습니다.',
          key: const ValueKey('groupJoinCodeStatus'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          group.hasActiveJoinCode
              ? '초대코드는 폐기하기 전까지 유효하며 언제든 복사할 수 있습니다.'
              : '6자리 초대코드를 만들어 그룹원을 초대할 수 있습니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (activeCode != null) ...[
          const SizedBox(height: 16),
          SelectableText(
            key: const ValueKey('groupJoinCodeValue'),
            activeCode,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('groupJoinCodeCopyButton'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: activeCode));
              if (!mounted) return;
              _showMessage('초대코드를 복사했습니다.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('코드 복사'),
          ),
        ],
        const SizedBox(height: 24),
        if (!group.hasActiveJoinCode)
          FilledButton.icon(
            key: const ValueKey('groupJoinCodeCreateButton'),
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add_link),
            label: const Text('초대코드 만들기'),
          )
        else
          OutlinedButton.icon(
            key: const ValueKey('groupJoinCodeRevokeButton'),
            onPressed: _busy || activeCode == null
                ? null
                : () => _revoke(activeCode),
            icon: const Icon(Icons.link_off),
            label: const Text('코드 폐기'),
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: const ValueKey('groupJoinCodeVisibilitySwitch'),
          title: const Text('멤버에게 코드 표시'),
          subtitle: const Text('화면 공개 정책만 바꿉니다. 가입 가능 여부는 그대로입니다.'),
          value: group.joinCodeVisibleToMembers,
          onChanged: _busy ? null : (value) => _setVisibility(value),
        ),
      ],
    );
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final result = await widget.viewModel.createCode(widget.groupId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    if (result.failure != null) {
      _showMessage(groupJoinCodeFailureMessage(result.failure!));
      return;
    }
    _showMessage('초대코드를 만들었습니다. 지금 복사해 두세요.');
  }

  Future<void> _revoke(String activeCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초대코드 폐기'),
        content: const Text('현재 초대코드를 폐기할까요? 폐기한 코드는 더 이상 사용할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('groupJoinCodeRevokeConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('폐기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.viewModel.revokeCode(
      groupId: widget.groupId,
      code: activeCode,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    _showMessage(
      result.failure == null
          ? '초대코드를 폐기했습니다.'
          : groupJoinCodeFailureMessage(result.failure!),
    );
  }

  Future<void> _setVisibility(bool visible) async {
    setState(() => _busy = true);
    final result = await widget.viewModel.setVisibility(
      groupId: widget.groupId,
      visibleToMembers: visible,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    _showMessage(
      result.failure == null
          ? (visible ? '멤버에게 코드를 표시합니다.' : '멤버 표시를 껐습니다.')
          : groupJoinCodeFailureMessage(result.failure!),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
