import 'package:flutter/material.dart';

import '../../domain/entities/group_blocked_player.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_join_relation.dart';
import '../viewmodels/group_application_view_model.dart';
import '../viewmodels/group_join_view_model.dart';
import '../viewmodels/group_read_view_model.dart';

/// 계약 §8.6·§11. 그룹장에게 들어온 가입 신청과 금지 목록을 함께 보여 준다.
/// 만료된 신청은 쓰기 없이 만료로 표시하고 다음 명령에서 정리한다.
class GroupApplicationsPage extends StatefulWidget {
  const GroupApplicationsPage({
    required this.groupId,
    required this.viewModel,
    super.key,
  });

  final String groupId;
  final GroupApplicationsViewModel viewModel;

  @override
  State<GroupApplicationsPage> createState() => _GroupApplicationsPageState();
}

class _GroupApplicationsPageState extends State<GroupApplicationsPage> {
  late Future<GroupApplicationsSnapshot> _snapshot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.viewModel.load(widget.groupId);
  }

  void _reload() => setState(() {
    _snapshot = widget.viewModel.load(widget.groupId);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가입 신청 관리'),
        actions: [
          IconButton(
            key: const ValueKey('groupApplicationsRefreshButton'),
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: FutureBuilder<GroupApplicationsSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _GroupApplicationsMessage(
              message: groupReadFailureMessage(snapshot.error!),
            );
          }
          final data = snapshot.data!;
          final now = DateTime.now();
          final pending = data.actionableAt(now);
          final expired = data.expiredAt(now);
          if (pending.isEmpty &&
              expired.isEmpty &&
              data.blockedPlayers.isEmpty) {
            return const _GroupApplicationsMessage(
              message: '들어온 가입 신청이 없습니다.',
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (pending.isNotEmpty) ...[
                const _GroupApplicationsHeader(title: '대기 중인 신청'),
                for (final relation in pending)
                  _ApplicationTile(
                    relation: relation,
                    busy: _busy,
                    onApprove: () => _decide(
                      relation,
                      widget.viewModel.approve,
                      '가입 신청을 승인했습니다.',
                    ),
                    onReject: () => _decide(
                      relation,
                      widget.viewModel.reject,
                      '가입 신청을 거절했습니다.',
                    ),
                    onBlock: () => _confirmBlock(relation),
                  ),
              ],
              if (expired.isNotEmpty) ...[
                const _GroupApplicationsHeader(title: '만료된 신청'),
                for (final relation in expired)
                  _ApplicationTile(
                    relation: relation,
                    busy: _busy,
                    expired: true,
                    onReject: () => _decide(
                      relation,
                      widget.viewModel.reject,
                      '만료된 신청을 정리했습니다.',
                    ),
                  ),
              ],
              if (data.blockedPlayers.isNotEmpty) ...[
                const _GroupApplicationsHeader(title: '신청 금지 목록'),
                for (final blocked in data.blockedPlayers)
                  ListTile(
                    key: ValueKey('blockedPlayer-${blocked.playerId}'),
                    leading: const Icon(Icons.block_outlined),
                    title: Text(blocked.characterNameSnapshot),
                    subtitle: Text('신청 ${blocked.applicationCountSnapshot}회'),
                    trailing: TextButton(
                      key: ValueKey('releaseBlock-${blocked.playerId}'),
                      onPressed: _busy ? null : () => _release(blocked),
                      child: const Text('해제'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmBlock(GroupJoinRelation relation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청을 거절하고 금지할까요?'),
        content: Text(
          '${relation.characterNameSnapshot} 님은 캐릭터나 계정을 바꿔도 '
          '이 그룹에 신청·초대·코드 가입을 할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmBlockApplicant'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('거절하고 금지'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(relation, widget.viewModel.block, '신청을 거절하고 금지했습니다.');
  }

  Future<void> _decide(
    GroupJoinRelation relation,
    Future<GroupJoinCommandResult> Function(GroupJoinRelation) command,
    String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await command(relation);
    if (!mounted) return;
    setState(() => _busy = false);
    _report(result.failure, success);
    if (result.isSuccess) _reload();
  }

  Future<void> _release(GroupBlockedPlayer blocked) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.viewModel.releaseBlock(blocked);
    if (!mounted) return;
    setState(() => _busy = false);
    _report(result.failure, '금지를 해제했습니다. 이전 신청은 복원되지 않습니다.');
    if (result.isSuccess) _reload();
  }

  void _report(GroupJoinFailure? failure, String success) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure == null ? success : groupJoinFailureMessage(failure),
          ),
        ),
      );
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({
    required this.relation,
    required this.busy,
    required this.onReject,
    this.onApprove,
    this.onBlock,
    this.expired = false,
  });

  final GroupJoinRelation relation;
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback? onApprove;
  final VoidCallback? onBlock;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final itemLevel = relation.itemLevelSnapshot;
    return ListTile(
      key: ValueKey('incomingApplication-${relation.targetPlayerId}'),
      isThreeLine: true,
      leading: const Icon(Icons.person_add_alt_1_outlined),
      title: Text(relation.characterNameSnapshot),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${relation.serverNameSnapshot} · '
            '${relation.characterClassNameSnapshot}'
            '${itemLevel == null ? '' : ' · Lv ${itemLevel.toStringAsFixed(2)}'}',
          ),
          Text(
            expired
                ? '만료됨 · 신청 ${relation.applicationAttempt}회'
                : '신청 ${relation.applicationAttempt}회',
          ),
          Wrap(
            spacing: 8,
            children: [
              if (onApprove != null)
                FilledButton(
                  key: ValueKey('approveApplication-${relation.targetPlayerId}'),
                  onPressed: busy ? null : onApprove,
                  child: const Text('승인'),
                ),
              OutlinedButton(
                key: ValueKey('rejectApplication-${relation.targetPlayerId}'),
                onPressed: busy ? null : onReject,
                child: Text(expired ? '정리' : '거절'),
              ),
              if (onBlock != null)
                TextButton(
                  key: ValueKey('blockApplicant-${relation.targetPlayerId}'),
                  onPressed: busy ? null : onBlock,
                  child: const Text('거절하고 금지'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupApplicationsHeader extends StatelessWidget {
  const _GroupApplicationsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _GroupApplicationsMessage extends StatelessWidget {
  const _GroupApplicationsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
