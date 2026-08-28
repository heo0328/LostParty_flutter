import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../domain/entities/operator_user.dart';
import '../../domain/repositories/operator_access_repository.dart';

class OperatorUserListPage extends StatefulWidget {
  const OperatorUserListPage({required this.repository, super.key});

  final OperatorAccessRepository repository;

  @override
  State<OperatorUserListPage> createState() => _OperatorUserListPageState();
}

class _OperatorUserListPageState extends State<OperatorUserListPage> {
  static const _pageSize = 50;
  var _limit = _pageSize;
  late Future<_OperatorUserListState> _state;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  Future<_OperatorUserListState> _load() async {
    if (!await widget.repository.isCurrentPlayerOperator()) {
      return const _OperatorUserListState.denied();
    }
    return _OperatorUserListState.allowed(
      await widget.repository.loadUsers(limit: _limit),
    );
  }

  void _retry() => setState(() => _state = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 확인')),
      body: FutureBuilder<_OperatorUserListState>(
        future: _state,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageBody(
              icon: Icons.cloud_off_outlined,
              message: '사용자 목록을 불러오지 못했습니다.',
              actionLabel: '다시 시도',
              onAction: _retry,
            );
          }
          final state = snapshot.data;
          if (state == null || !state.allowed) {
            return const _MessageBody(
              icon: Icons.lock_outline,
              message: '운영자 권한이 없습니다.',
            );
          }
          if (state.users.isEmpty) {
            return const _MessageBody(
              icon: Icons.people_outline,
              message: '표시할 사용자가 없습니다.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() => _state = next);
              await next;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount:
                  state.users.length + (state.users.length == _limit ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == state.users.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      key: const ValueKey('operatorUsersLoadMore'),
                      onPressed: () {
                        setState(() {
                          _limit += _pageSize;
                          _state = _load();
                        });
                      },
                      child: const Text('더 보기'),
                    ),
                  );
                }
                final user = state.users[index];
                return ListTile(
                  key: ValueKey('operatorUser-${user.playerId}'),
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(
                    user.representativeCharacterName ?? '대표 캐릭터 지정 안 됨',
                  ),
                  subtitle: Text(_subtitle(user)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/settings/operator/users/${user.playerId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _subtitle(OperatorUserSummary user) {
    final lastSeen = user.lastSeenAt == null
        ? '접속 기록 없음'
        : '마지막 접속 ${KoreaTimeFormatter.dayAndTime(user.lastSeenAt!)}';
    final verification = user.hasVerifiedGameAccount ? '인증 계정 있음' : '인증 계정 없음';
    return '${user.displayId} · $lastSeen · $verification';
  }
}

class _OperatorUserListState {
  const _OperatorUserListState.allowed(this.users) : allowed = true;
  const _OperatorUserListState.denied() : allowed = false, users = const [];

  final bool allowed;
  final List<OperatorUserSummary> users;
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
