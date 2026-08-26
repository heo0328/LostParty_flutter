import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../account/data/local/account_database.dart';
import '../../domain/services/party_event_sync_service.dart';
import '../viewmodels/party_notification_view_model.dart';

class PartyNotificationsPage extends StatefulWidget {
  const PartyNotificationsPage({
    required this.accountDatabase,
    required this.eventSyncService,
    required this.playerId,
    super.key,
  });

  final AccountDatabase accountDatabase;
  final PartyEventSyncService eventSyncService;
  final String playerId;

  @override
  State<PartyNotificationsPage> createState() => _PartyNotificationsPageState();
}

class _PartyNotificationsPageState extends State<PartyNotificationsPage> {
  late final PartyNotificationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PartyNotificationViewModel(
      database: widget.accountDatabase,
      playerId: widget.playerId,
      syncService: widget.eventSyncService,
    );
    unawaited(_viewModel.initialize());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        return Scaffold(
          appBar: AppBar(title: const Text('알림')),
          body: RefreshIndicator(
            onRefresh: _viewModel.syncNow,
            child: _body(context, state),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PartyNotificationViewState state) {
    if (state.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (state.hasLoadFailure) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 48),
          Text('알림을 불러오지 못했습니다.', textAlign: TextAlign.center),
        ],
      );
    }
    if (state.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.notifications_none_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '새 알림이 없습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '파티 신청·가입·탈퇴 같은 소식이 여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.items.length + (state.syncFailure != null ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (state.syncFailure != null && index == 0) {
          return ListTile(
            leading: Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('최신 알림을 동기화하지 못했습니다.'),
            subtitle: const Text('아래로 당겨 다시 시도할 수 있습니다.'),
          );
        }
        final item =
            state.items[state.syncFailure != null ? index - 1 : index];
        return ListTile(
          key: ValueKey(item.eventId),
          leading: Icon(
            item.isRead
                ? Icons.notifications_none_outlined
                : Icons.notifications_active_outlined,
            color: item.isRead
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            item.message,
            style: TextStyle(
              fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          subtitle: Text(_formatOccurredAt(item.occurredAt)),
          onTap: () async {
            await _viewModel.openItem(item);
            if (!context.mounted) return;
            context.push(item.route);
          },
        );
      },
    );
  }
}

String _formatOccurredAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
