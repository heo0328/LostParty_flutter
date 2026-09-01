import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/group_join_code.dart';
import '../../domain/entities/group_join_command.dart';
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
    final remembered = widget.viewModel.rememberedCode(widget.groupId);
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
          group.hasActiveJoinCode && remembered == null
              ? '코드 원문은 그룹에 저장되지 않아 이 화면에서 다시 보이지 않습니다. '
                    '만료된 것이 아닙니다. 생성 직후 복사해 둔 20자 코드를 입력해야 폐기할 수 있습니다.'
              : '코드는 그룹 문서에 저장되지 않습니다. 생성 직후 한 번 복사해 두고, '
                    '폐기할 때 같은 코드를 입력하세요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (remembered != null) ...[
          const SizedBox(height: 16),
          SelectableText(
            key: const ValueKey('groupJoinCodeValue'),
            remembered,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('groupJoinCodeCopyButton'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: remembered));
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
            onPressed: _busy ? null : () => _revoke(remembered),
            icon: const Icon(Icons.link_off),
            label: const Text('코드 폐기'),
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: const ValueKey('groupJoinCodeVisibilitySwitch'),
          title: const Text('멤버에게 코드 표시'),
          subtitle: const Text('화면 공개 정책만 바꿉니다. 가입 가능 여부는 그대로입니다.'),
          value: group.joinCodeVisibleToMembers,
          onChanged: _busy
              ? null
              : (value) => _setVisibility(value),
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

  Future<void> _revoke(String? remembered) async {
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => _RevokeJoinCodeDialog(initialCode: remembered),
    );
    if (entered == null || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.viewModel.revokeCode(
      groupId: widget.groupId,
      code: entered,
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

/// 폐기 입력란의 컨트롤러는 대화상자가 닫힌 뒤에만 해제한다.
/// 대화상자를 연 쪽에서 바로 dispose하면 키보드가 내려가는 중 오류 화면이 난다.
class _RevokeJoinCodeDialog extends StatefulWidget {
  const _RevokeJoinCodeDialog({this.initialCode});

  final String? initialCode;

  @override
  State<_RevokeJoinCodeDialog> createState() => _RevokeJoinCodeDialogState();
}

class _RevokeJoinCodeDialogState extends State<_RevokeJoinCodeDialog> {
  late final TextEditingController _controller;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final parsed = GroupJoinCode.tryParse(_controller.text);
    if (parsed == null) {
      setState(() {
        _fieldError = widget.initialCode == null
            ? '복사해 둔 20자 초대코드를 입력하세요. 이 화면에는 원문이 없습니다.'
            : groupJoinCodeFailureMessage(GroupJoinFailure.joinCodeInvalid);
      });
      return;
    }
    Navigator.of(context).pop(parsed.value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('초대코드 폐기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.initialCode == null) ...[
            const Text(
              '활성 코드는 만료되지 않습니다. 생성 직후 복사해 둔 코드를 입력하세요.',
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const ValueKey('groupJoinCodeRevokeField'),
            controller: _controller,
            autofocus: widget.initialCode == null,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '폐기할 초대코드',
              border: const OutlineInputBorder(),
              errorText: _fieldError,
            ),
            onChanged: (_) {
              if (_fieldError != null) {
                setState(() => _fieldError = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('groupJoinCodeRevokeConfirm'),
          onPressed: _confirm,
          child: const Text('폐기'),
        ),
      ],
    );
  }
}
