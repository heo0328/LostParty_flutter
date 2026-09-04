import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/group_join_command.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_member_display.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../viewmodels/group_application_view_model.dart';
import '../viewmodels/group_character_options.dart';
import '../viewmodels/group_join_code_view_model.dart';
import '../viewmodels/group_join_view_model.dart';
import '../viewmodels/group_read_view_model.dart';
import '../widgets/group_character_refresh_guard.dart';

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
  Future<GroupMemberDisplayLoadResult>? _members;
  Future<GroupMember?>? _myMembership;
  bool _busy = false;
  bool _refreshing = false;
  bool _loadingPlayerCharacters = false;
  int _selectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (_refreshing) return;
    _refreshing = true;
    _group = widget.readRepository.loadGroup(widget.groupId);
    _relation = widget.actionViewModel.loadMyRelation(
      playerId: widget.playerId,
      groupId: widget.groupId,
    );
    _members = null;
    _myMembership = null;
    unawaited(_finishLoad());
  }

  Future<void> _finishLoad() async {
    try {
      final relation = await _relation;
      if (relation?.isMember == true && mounted) {
        setState(_loadMemberViews);
      }
      await _group;
      await _members;
      await _myMembership;
    } catch (_) {
      // 개별 FutureBuilder가 읽기 오류를 표시한다.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _loadMemberViews() {
    _members = widget.actionViewModel.loadMemberDisplays(
      groupId: widget.groupId,
      playerId: widget.playerId,
    );
    _myMembership = widget.actionViewModel.loadMyMembership(
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
            onPressed: _refreshing || _busy ? null : () => setState(_load),
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
              Text(
                group.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
              _GroupDetailRow(label: '생성', value: _formatDate(group.createdAt)),
              _GroupDetailRow(
                label: '마지막 활동',
                value: _formatDate(group.lastActivityAt),
              ),
              const SizedBox(height: 24),
              _MemberSection(
                membersFuture: _members,
                onMemberTap: _showPlayerCharacters,
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
              _LeaveGroupEntry(
                membershipFuture: _myMembership,
                busy: _busy,
                onLeave: _leaveGroup,
                onLeaderExit: _leaderExit,
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
    if (accept) {
      final generation = ++_selectionGeneration;
      final refresh = await widget.actionViewModel.ensureInvitationFresh(
        relation,
        generation: generation,
      );
      if (!refresh.found) {
        if (mounted) {
          setState(() => _busy = false);
          _showMessage('초대에 사용된 본인 캐릭터를 확인할 수 없습니다.');
        }
        return;
      }
      if (!mounted ||
          !await confirmGroupCharacterRefresh(
            context,
            refresh.result,
            characterId: refresh.characterId,
            generation: _selectionGeneration,
          )) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    final result = accept
        ? await widget.actionViewModel.acceptInvitation(relation)
        : await widget.actionViewModel.rejectInvitation(relation);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
    _report(result.failure, accept ? '초대를 수락했습니다.' : '초대를 거절했습니다.');
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
    final generation = ++_selectionGeneration;
    final refresh = await widget.actionViewModel.ensureFresh(
      character,
      generation: generation,
    );
    if (!mounted ||
        !await confirmGroupCharacterRefresh(
          context,
          refresh,
          characterId: character.localCharacterId,
          generation: _selectionGeneration,
        )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
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

  Future<void> _showPlayerCharacters(GroupMemberDisplay display) async {
    if (_loadingPlayerCharacters) return;
    _loadingPlayerCharacters = true;
    List<GroupRequestCharacter> characters;
    try {
      characters = await widget.actionViewModel.loadPlayerCharacters(
        display.member.playerId,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('캐릭터 목록을 불러오지 못했습니다.');
      return;
    } finally {
      _loadingPlayerCharacters = false;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${display.characterName}의 활동 캐릭터',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (characters.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  key: const ValueKey('groupMemberActivityCharactersEmpty'),
                  display.member.playerId == widget.playerId
                      ? '선택한 활동 캐릭터가 없습니다. 캐릭터 관리에서 사용할 캐릭터를 저장해 주세요.'
                      : '선택한 활동 캐릭터가 없습니다. 상대가 캐릭터 관리에서 다시 저장하면 표시됩니다.',
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final character in characters)
                      ListTile(
                        key: ValueKey(
                          'memberCharacter-${character.characterId}',
                        ),
                        title: Text(character.characterName),
                        subtitle: Text(
                          '${character.serverName} · ${character.characterClassName}'
                          ' · ${_formatLevel(character.itemLevel)}'
                          ' · ${_formatCombatPower(character.combatPower)}',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 탈퇴'),
        content: const Text('이 그룹에서 탈퇴하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('groupLeaveConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.actionViewModel.leave(groupId: widget.groupId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.failure != null) {
      _showMessage(groupLeaveFailureMessage(result.failure!));
      return;
    }
    _showMessage('그룹에서 탈퇴했습니다.');
    context.go('/groups');
  }

  Future<void> _leaderExit() async {
    final group = await _group;
    if (!mounted || group == null) return;
    final membersResult = await _members;
    if (!mounted) return;
    final candidates = [
      for (final display
          in membersResult?.members ?? const <GroupMemberDisplay>[])
        if (!display.isLeader && display.member.playerId != widget.playerId)
          display,
    ];
    final choice = await showDialog<_LeaderExitChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹장 나가기'),
        content: Text(
          candidates.isEmpty
              ? '그룹장이 한 명이면 그룹을 해산할 수 있습니다. 대기 중인 초대·신청, 그룹만 공개 레이드, 활성 초대코드가 없어야 합니다.'
              : '바로 탈퇴할 수 없습니다. 다른 그룹원에게 그룹장을 넘기거나 조건을 갖춘 뒤 해산하세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          if (candidates.isNotEmpty)
            TextButton(
              key: const ValueKey('groupLeaderTransferChoiceButton'),
              onPressed: () =>
                  Navigator.of(context).pop(_LeaderExitChoice.transfer),
              child: const Text('그룹장 이전'),
            ),
          FilledButton(
            key: const ValueKey('groupDisbandChoiceButton'),
            onPressed: () =>
                Navigator.of(context).pop(_LeaderExitChoice.disband),
            child: const Text('그룹 해산'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _LeaderExitChoice.transfer) {
      await _transferLeadership(group, candidates);
      return;
    }
    await _disbandGroup(group);
  }

  Future<void> _transferLeadership(
    GroupPublicSummary group,
    List<GroupMemberDisplay> candidates,
  ) async {
    final target = await showDialog<GroupMemberDisplay>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('후임 그룹장 선택'),
        children: [
          for (final candidate in candidates)
            SimpleDialogOption(
              key: ValueKey('groupTransferTarget-${candidate.member.playerId}'),
              onPressed: () => Navigator.of(context).pop(candidate),
              child: Text(candidate.characterName),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹장 이전'),
        content: Text(
          '${target.characterName}에게 그룹장을 즉시 이전합니다. 이전 즉시 그룹 관리 권한이 넘어가며 자동으로 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('groupTransferConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이전'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.actionViewModel.transferLeadership(
      groupId: widget.groupId,
      targetPlayerId: target.member.playerId,
      expectedGroupRevision: group.revision,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.failure != null) {
      _showMessage(groupJoinFailureMessage(result.failure!));
      return;
    }
    _showMessage('그룹장이 이전되었습니다. 이제 그룹에서 탈퇴할 수 있습니다.');
    _load();
  }

  Future<void> _disbandGroup(GroupPublicSummary group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 해산'),
        content: const Text(
          '그룹을 해산하면 목록과 검색에서 바로 사라집니다. 연결된 레이드방은 자동으로 없어지지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('groupDisbandConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('해산'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.actionViewModel.disband(
      groupId: widget.groupId,
      expectedGroupRevision: group.revision,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.failure != null) {
      _showMessage(groupDisbandFailureMessage(result.failure!));
      return;
    }
    _showMessage('그룹을 해산했습니다.');
    context.go('/groups');
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}.$month.$day $hour:$minute';
}

String _formatLevel(double? value) =>
    value == null ? '아이템 레벨 -' : '아이템 ${value.toStringAsFixed(0)}';

String _formatCombatPower(double? value) =>
    value == null ? '전투력 -' : '전투력 ${value.toStringAsFixed(0)}';

class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.membersFuture,
    required this.onMemberTap,
  });

  final Future<GroupMemberDisplayLoadResult>? membersFuture;
  final ValueChanged<GroupMemberDisplay> onMemberTap;

  @override
  Widget build(BuildContext context) {
    final membersFuture = this.membersFuture;
    if (membersFuture == null) return const SizedBox.shrink();
    return FutureBuilder<GroupMemberDisplayLoadResult>(
      future: membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _GroupDetailMessage(
            message: groupReadFailureMessage(snapshot.error!),
          );
        }
        final result = snapshot.data;
        final members = result?.members ?? const <GroupMemberDisplay>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('그룹원', style: Theme.of(context).textTheme.titleMedium),
            if (result?.syncFailed == true)
              const Padding(
                key: ValueKey('groupDisplaySyncWarning'),
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '내 캐릭터 표시 정보 동기화에 실패했습니다. 저장된 정보를 표시합니다. 잠시 후 새로고침해 주세요.',
                ),
              ),
            if (members.any((member) => member.combatPower == null))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '전투력이 없는 캐릭터는 소유자가 내 계정에서 정보를 저장한 뒤 그룹을 새로고침해 주세요.',
                ),
              ),
            const SizedBox(height: 12),
            for (final display in members)
              _GroupMemberCard(
                display: display,
                onTap: () => onMemberTap(display),
              ),
          ],
        );
      },
    );
  }
}

class _GroupMemberCard extends StatelessWidget {
  const _GroupMemberCard({required this.display, required this.onTap});

  final GroupMemberDisplay display;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('groupMemberCard-${display.member.playerId}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      display.characterName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (display.isLeader)
                    Chip(
                      label: const Text('그룹장'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${display.className} · ${_formatLevel(display.itemLevel)}'),
              Text(_formatCombatPower(display.combatPower)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LeaderExitChoice { transfer, disband }

class _LeaveGroupEntry extends StatelessWidget {
  const _LeaveGroupEntry({
    required this.membershipFuture,
    required this.busy,
    required this.onLeave,
    required this.onLeaderExit,
  });

  final Future<GroupMember?>? membershipFuture;
  final bool busy;
  final VoidCallback onLeave;
  final VoidCallback onLeaderExit;

  @override
  Widget build(BuildContext context) {
    final membershipFuture = this.membershipFuture;
    if (membershipFuture == null) return const SizedBox.shrink();
    return FutureBuilder<GroupMember?>(
      future: membershipFuture,
      builder: (context, snapshot) {
        final member = snapshot.data;
        if (member == null) return const SizedBox.shrink();
        if (member.isLeader) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              key: const ValueKey('groupLeaderExitButton'),
              onPressed: busy ? null : onLeaderExit,
              icon: const Icon(Icons.logout),
              label: const Text('그룹 나가기'),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            key: const ValueKey('groupLeaveButton'),
            onPressed: busy ? null : onLeave,
            icon: const Icon(Icons.logout),
            label: const Text('그룹 탈퇴'),
          ),
        );
      },
    );
  }
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
          onPressed: () => context.push('/groups/${widget.groupId}/join-code'),
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
