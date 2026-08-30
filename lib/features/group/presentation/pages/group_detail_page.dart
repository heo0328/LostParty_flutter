import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../viewmodels/group_application_view_model.dart';
import '../viewmodels/group_character_options.dart';
import '../viewmodels/group_join_code_view_model.dart';
import '../viewmodels/group_join_view_model.dart';
import '../viewmodels/group_read_view_model.dart';

/// 기본 상세는 계약 §4.2 공개 필드만 읽는다. 멤버·요청 관리 읽기는 후속 단위다.
/// 행동 버튼은 내 `groupRelations` Projection 한 건으로만 결정한다.
class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    required this.groupId,
    required this.playerId,
    required this.readRepository,
    required this.actionViewModel,
    this.applicationsViewModel,
    this.joinCodeManageViewModel,
    super.key,
  });

  final String groupId;
  final String playerId;
  final GroupReadRepository readRepository;
  final GroupMembershipActionViewModel actionViewModel;

  /// 그룹장에게만 신청 관리 진입을 노출한다. 권한은 Rules가 최종 판정한다.
  final GroupApplicationsViewModel? applicationsViewModel;

  /// 그룹장 초대코드 관리. 세션 메모리에 생성 코드를 유지한다.
  final GroupJoinCodeManageViewModel? joinCodeManageViewModel;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late Future<GroupPublicSummary?> _group;
  late Future<GroupRelation?> _relation;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _group = widget.readRepository.loadGroup(widget.groupId);
    _relation = widget.actionViewModel.loadMyRelation(
      playerId: widget.playerId,
      groupId: widget.groupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('그룹 정보'),
        actions: [
          IconButton(
            key: const ValueKey('groupDetailRefreshButton'),
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: FutureBuilder<GroupPublicSummary?>(
        future: _group,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _GroupDetailMessage(
              message: groupReadFailureMessage(snapshot.error!),
            );
          }
          final group = snapshot.data;
          if (group == null) {
            return const _GroupDetailMessage(message: '그룹을 찾을 수 없습니다.');
          }
          if (!group.isActive) {
            return const _GroupDetailMessage(message: '종료된 그룹입니다.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _GroupDetailRow(
                label: '대표 캐릭터',
                value:
                    '${group.representativeCharacterNameSnapshot} · ${group.representativeServerNameSnapshot}',
              ),
              _GroupDetailRow(
                label: '그룹장 표시 캐릭터',
                value: group.leaderDisplayCharacterNameSnapshot,
              ),
              _GroupDetailRow(label: '현재 인원', value: '${group.memberCount}명'),
              _GroupDetailRow(
                label: '생성',
                value: _formatDate(group.createdAt),
              ),
              _GroupDetailRow(
                label: '마지막 활동',
                value: _formatDate(group.lastActivityAt),
              ),
              const SizedBox(height: 24),
              _actions(),
            ],
          );
        },
      ),
    );
  }

  Widget _actions() {
    return FutureBuilder<GroupRelation?>(
      future: _relation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _GroupDetailMessage(
            message: groupReadFailureMessage(snapshot.error!),
          );
        }
        final relation = snapshot.data;
        if (relation != null && relation.isMember) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const ValueKey('groupInviteEntryButton'),
                onPressed: () =>
                    context.push('/groups/${widget.groupId}/invite'),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('멤버 초대'),
              ),
              if (widget.applicationsViewModel != null)
                _LeaderApplicationsEntry(
                  groupId: widget.groupId,
                  playerId: widget.playerId,
                  viewModel: widget.applicationsViewModel!,
                ),
              if (widget.joinCodeManageViewModel != null &&
                  widget.applicationsViewModel != null)
                _LeaderJoinCodeEntry(
                  groupId: widget.groupId,
                  playerId: widget.playerId,
                  leadershipViewModel: widget.applicationsViewModel!,
                ),
            ],
          );
        }
        if (relation != null && isActionableGroupInvitation(relation)) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('groupDetailRejectInvitation'),
                  onPressed: _busy ? null : () => _decide(relation, false),
                  child: const Text('초대 거절'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('groupDetailAcceptInvitation'),
                  onPressed: _busy ? null : () => _decide(relation, true),
                  child: const Text('초대 수락'),
                ),
              ),
            ],
          );
        }
        if (relation != null &&
            relation.relation == GroupRelationKind.applied &&
            relation.requestStatus == GroupRequestStatus.pending &&
            !relation.isExpiredAt(DateTime.now())) {
          return const Center(child: Text('가입 신청이 대기 중입니다.'));
        }
        return FilledButton.icon(
          key: const ValueKey('groupApplyButton'),
          onPressed: _busy ? null : _apply,
          icon: const Icon(Icons.how_to_reg_outlined),
          label: const Text('가입 신청'),
        );
      },
    );
  }

  Future<void> _decide(GroupRelation relation, bool accept) async {
    setState(() => _busy = true);
    final result = accept
        ? await widget.actionViewModel.acceptInvitation(relation)
        : await widget.actionViewModel.rejectInvitation(relation);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    _report(
      result.failure,
      accept ? '초대를 수락했습니다.' : '초대를 거절했습니다.',
    );
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    final List<GroupCharacterOption> options;
    try {
      options = await widget.actionViewModel.loadAuthenticatedCharacters();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('인증 캐릭터를 불러오지 못했습니다.');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (options.isEmpty) {
      _showMessage('인증한 캐릭터가 없습니다. 내 계정에서 캐릭터를 인증해 주세요.');
      return;
    }
    final character = await showModalBottomSheet<GroupCharacterOption>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('신청에 사용할 캐릭터'),
            ),
            for (final option in options)
              ListTile(
                key: ValueKey('applyCharacter-${option.serverCharacterId}'),
                title: Text(option.characterName),
                subtitle: Text('${option.serverName} · ${option.className}'),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (character == null || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.actionViewModel.apply(
      groupId: widget.groupId,
      character: character,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    _report(result.failure, '가입 신청을 보냈습니다.');
  }

  void _report(GroupJoinFailure? failure, String success) => _showMessage(
    failure == null ? success : groupJoinFailureMessage(failure),
  );

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}.$month.$day $hour:$minute';
}

/// membership 확인 뒤에만 그룹장 여부를 읽는다. 실패하면 진입을 감추고
/// 화면은 권한을 확대하지 않는다.
class _LeaderApplicationsEntry extends StatefulWidget {
  const _LeaderApplicationsEntry({
    required this.groupId,
    required this.playerId,
    required this.viewModel,
  });

  final String groupId;
  final String playerId;
  final GroupApplicationsViewModel viewModel;

  @override
  State<_LeaderApplicationsEntry> createState() =>
      _LeaderApplicationsEntryState();
}

class _LeaderApplicationsEntryState extends State<_LeaderApplicationsEntry> {
  late final Future<bool> _isLeader = widget.viewModel.isLeader(
    groupId: widget.groupId,
    playerId: widget.playerId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _isLeader,
    builder: (context, snapshot) {
      if (snapshot.data != true) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          key: const ValueKey('groupApplicationsEntryButton'),
          onPressed: () =>
              context.push('/groups/${widget.groupId}/applications'),
          icon: const Icon(Icons.how_to_reg_outlined),
          label: const Text('가입 신청 관리'),
        ),
      );
    },
  );
}

class _LeaderJoinCodeEntry extends StatefulWidget {
  const _LeaderJoinCodeEntry({
    required this.groupId,
    required this.playerId,
    required this.leadershipViewModel,
  });

  final String groupId;
  final String playerId;
  final GroupApplicationsViewModel leadershipViewModel;

  @override
  State<_LeaderJoinCodeEntry> createState() => _LeaderJoinCodeEntryState();
}

class _LeaderJoinCodeEntryState extends State<_LeaderJoinCodeEntry> {
  late final Future<bool> _isLeader = widget.leadershipViewModel.isLeader(
    groupId: widget.groupId,
    playerId: widget.playerId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _isLeader,
    builder: (context, snapshot) {
      if (snapshot.data != true) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          key: const ValueKey('groupJoinCodeEntryButton'),
          onPressed: () =>
              context.push('/groups/${widget.groupId}/join-code'),
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('초대코드 관리'),
        ),
      );
    },
  );
}

class _GroupDetailRow extends StatelessWidget {
  const _GroupDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _GroupDetailMessage extends StatelessWidget {
  const _GroupDetailMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
