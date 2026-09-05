import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/group_relation.dart';
import '../../domain/repositories/group_read_repository.dart';
import '../viewmodels/group_application_view_model.dart';
import '../viewmodels/group_join_view_model.dart';
import '../viewmodels/group_read_view_model.dart';

/// 그룹 첫 화면. 계약 §11에 따라 `내 그룹`이 기본이며 `요청 현황`을 별도 탭으로 둔다.
class GroupTabPage extends StatelessWidget {
  const GroupTabPage({
    required this.readRepository,
    required this.requestsViewModel,
    required this.playerId,
    this.applicationsViewModel,
    super.key,
  });

  final GroupReadRepository readRepository;
  final GroupRequestsViewModel requestsViewModel;
  final String playerId;

  /// 그룹장에게 들어온 신청 진입을 요청 현황 탭에 함께 보여 준다.
  final GroupApplicationsViewModel? applicationsViewModel;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('그룹'),
          actions: [
            IconButton(
              key: const ValueKey('groupJoinByCodeButton'),
              onPressed: () => context.push('/groups/join-by-code'),
              icon: const Icon(Icons.vpn_key_outlined),
              tooltip: '초대코드로 가입',
            ),
            IconButton(
              key: const ValueKey('groupSearchButton'),
              onPressed: () => context.push('/groups/search'),
              icon: const Icon(Icons.search),
              tooltip: '그룹 검색',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey('myGroupsTab'), text: '내 그룹'),
              Tab(key: ValueKey('groupRequestsTab'), text: '요청 현황'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('groupCreateButton'),
          onPressed: () => context.push('/groups/create'),
          icon: const Icon(Icons.add),
          label: const Text('그룹 만들기'),
        ),
        body: TabBarView(
          children: [
            _MyGroupsTab(readRepository: readRepository, playerId: playerId),
            _GroupRequestsTab(
              viewModel: requestsViewModel,
              readRepository: readRepository,
              applicationsViewModel: applicationsViewModel,
              playerId: playerId,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyGroupsTab extends StatefulWidget {
  const _MyGroupsTab({required this.readRepository, required this.playerId});

  final GroupReadRepository readRepository;
  final String playerId;

  @override
  State<_MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<_MyGroupsTab> {
  late final Stream<GroupReadSnapshot<GroupRelation>> _relations = widget
      .readRepository
      .watchMyGroups(widget.playerId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupReadSnapshot<GroupRelation>>(
      stream: _relations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GroupTabMessage(
            message: groupReadFailureMessage(snapshot.error!),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.items.isEmpty) {
          return const _GroupTabMessage(
            message: '가입한 그룹이 없습니다. 그룹을 만들거나 검색해 보세요.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: data.items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final relation = data.items[index];
            return ListTile(
              key: ValueKey('myGroup-${relation.groupId}'),
              leading: const Icon(Icons.diversity_3_outlined),
              title: Text(relation.groupNameSnapshot),
              subtitle: Text(relation.displayCharacterNameSnapshot),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/groups/${relation.groupId}'),
            );
          },
        );
      },
    );
  }
}

/// 계약 §11. 받은 초대, 내가 보낸 신청과 내가 그룹장인 그룹에 들어온 신청을
/// 권한에 맞게 나눠 보여 준다.
class _GroupRequestsTab extends StatefulWidget {
  const _GroupRequestsTab({
    required this.viewModel,
    required this.readRepository,
    required this.playerId,
    this.applicationsViewModel,
  });

  final GroupRequestsViewModel viewModel;
  final GroupReadRepository readRepository;
  final GroupApplicationsViewModel? applicationsViewModel;
  final String playerId;

  @override
  State<_GroupRequestsTab> createState() => _GroupRequestsTabState();
}

class _GroupRequestsTabState extends State<_GroupRequestsTab> {
  late final Stream<GroupReadSnapshot<GroupRelation>> _requests = widget
      .viewModel
      .watchMyRequests(widget.playerId);
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupReadSnapshot<GroupRelation>>(
      stream: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GroupTabMessage(
            message: groupReadFailureMessage(snapshot.error!),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final invitations = data.items
            .where((relation) => relation.relation == GroupRelationKind.invited)
            .toList(growable: false);
        final applications = data.items
            .where((relation) => relation.relation == GroupRelationKind.applied)
            .toList(growable: false);
        final viewModel = widget.applicationsViewModel;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (viewModel != null)
              _LeaderApplicationsSection(
                readRepository: widget.readRepository,
                viewModel: viewModel,
                playerId: widget.playerId,
              ),
            if (invitations.isEmpty && applications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('받은 초대와 보낸 신청이 없습니다.', textAlign: TextAlign.center),
              ),
            if (invitations.isNotEmpty) ...[
              const _GroupRequestsSectionHeader(title: '받은 초대'),
              for (final relation in invitations)
                _GroupInvitationTile(
                  relation: relation,
                  busy: _busy,
                  onAccept: () => _decide(relation, accept: true),
                  onReject: () => _decide(relation, accept: false),
                ),
            ],
            if (applications.isNotEmpty) ...[
              const _GroupRequestsSectionHeader(title: '내가 보낸 신청'),
              for (final relation in applications)
                ListTile(
                  key: ValueKey('myApplication-${relation.groupId}'),
                  leading: const Icon(Icons.outbox_outlined),
                  title: Text(relation.groupNameSnapshot),
                  subtitle: Text(
                    '${relation.displayCharacterNameSnapshot} · '
                    '${groupRequestStatusLabel(relation)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/${relation.groupId}'),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _decide(GroupRelation relation, {required bool accept}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = accept
        ? await widget.viewModel.acceptInvitation(relation)
        : await widget.viewModel.rejectInvitation(relation);
    if (!mounted) return;
    setState(() => _busy = false);
    final failure = result.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? (accept ? '초대를 수락했습니다.' : '초대를 거절했습니다.')
              : groupJoinFailureMessage(failure),
        ),
      ),
    );
  }
}

/// 내가 그룹장인 그룹만 신청 관리 진입을 노출한다. membership 확인 실패는
/// 권한을 확대하지 않고 진입을 감추는 쪽으로만 처리한다.
class _LeaderApplicationsSection extends StatefulWidget {
  const _LeaderApplicationsSection({
    required this.readRepository,
    required this.viewModel,
    required this.playerId,
  });

  final GroupReadRepository readRepository;
  final GroupApplicationsViewModel viewModel;
  final String playerId;

  @override
  State<_LeaderApplicationsSection> createState() =>
      _LeaderApplicationsSectionState();
}

class _LeaderApplicationsSectionState
    extends State<_LeaderApplicationsSection> {
  late final Stream<GroupReadSnapshot<GroupRelation>> _myGroups = widget
      .readRepository
      .watchMyGroups(widget.playerId);
  final _leadership = <String, bool>{};
  final _resolving = <String>{};

  Future<void> _resolve(List<GroupRelation> relations) async {
    final unknown = relations
        .map((relation) => relation.groupId)
        .where((id) => !_leadership.containsKey(id) && !_resolving.contains(id))
        .toList(growable: false);
    if (unknown.isEmpty) return;
    _resolving.addAll(unknown);
    for (final groupId in unknown) {
      bool isLeader;
      try {
        isLeader = await widget.viewModel.isLeader(
          groupId: groupId,
          playerId: widget.playerId,
        );
      } catch (_) {
        isLeader = false;
      }
      if (!mounted) return;
      setState(() {
        _resolving.remove(groupId);
        _leadership[groupId] = isLeader;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupReadSnapshot<GroupRelation>>(
      stream: _myGroups,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        unawaited(_resolve(data.items));
        final led = data.items
            .where((relation) => _leadership[relation.groupId] == true)
            .toList(growable: false);
        if (led.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _GroupRequestsSectionHeader(title: '내 그룹에 들어온 신청'),
            for (final relation in led)
              ListTile(
                key: ValueKey('leaderApplications-${relation.groupId}'),
                leading: const Icon(Icons.inbox_outlined),
                title: Text(relation.groupNameSnapshot),
                subtitle: const Text('가입 신청 승인·거절·금지'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/groups/${relation.groupId}/applications'),
              ),
          ],
        );
      },
    );
  }
}

class _GroupInvitationTile extends StatelessWidget {
  const _GroupInvitationTile({
    required this.relation,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final GroupRelation relation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final actionable = isActionableGroupInvitation(relation);
    return ListTile(
      key: ValueKey('incomingInvitation-${relation.groupId}'),
      leading: const Icon(Icons.mail_outline),
      title: Text(relation.groupNameSnapshot),
      subtitle: Text(
        '${relation.displayCharacterNameSnapshot} · '
        '${groupRequestStatusLabel(relation)}',
      ),
      trailing: actionable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: ValueKey('rejectInvitation-${relation.groupId}'),
                  onPressed: busy ? null : onReject,
                  child: const Text('거절'),
                ),
                FilledButton(
                  key: ValueKey('acceptInvitation-${relation.groupId}'),
                  onPressed: busy ? null : onAccept,
                  child: const Text('수락'),
                ),
              ],
            )
          : null,
      onTap: () => context.push('/groups/${relation.groupId}'),
    );
  }
}

class _GroupRequestsSectionHeader extends StatelessWidget {
  const _GroupRequestsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _GroupTabMessage extends StatelessWidget {
  const _GroupTabMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
