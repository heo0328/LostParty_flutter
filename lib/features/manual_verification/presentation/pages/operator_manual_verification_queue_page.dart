import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../../operator_access/domain/repositories/operator_access_repository.dart';
import '../../domain/entities/manual_verification_request.dart';
import '../../domain/repositories/manual_verification_repository.dart';

class OperatorManualVerificationQueuePage extends StatefulWidget {
  const OperatorManualVerificationQueuePage({
    required this.operatorAccessRepository,
    required this.repository,
    super.key,
  });

  final OperatorAccessRepository operatorAccessRepository;
  final ManualVerificationRepository repository;

  @override
  State<OperatorManualVerificationQueuePage> createState() =>
      _OperatorManualVerificationQueuePageState();
}

class _OperatorManualVerificationQueuePageState
    extends State<OperatorManualVerificationQueuePage> {
  late Future<_QueueState> _state;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  Future<_QueueState> _load() async {
    if (!await widget.operatorAccessRepository.isCurrentPlayerOperator()) {
      return const _QueueState.denied();
    }
    return _QueueState.allowed(await widget.repository.loadPendingQueue());
  }

  void _retry() => setState(() => _state = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수동 인증 확인')),
      body: FutureBuilder<_QueueState>(
        future: _state,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return _MessageBody(
              message: error is ManualVerificationException
                  ? (error.message ?? '대기 목록을 불러오지 못했습니다.')
                  : '대기 목록을 불러오지 못했습니다.',
              actionLabel: '다시 시도',
              onAction: _retry,
            );
          }
          final state = snapshot.data;
          if (state == null || !state.allowed) {
            return const _MessageBody(message: '운영자 권한이 없습니다.');
          }
          if (state.requests.isEmpty) {
            return const _MessageBody(message: '대기 중인 수동 인증 요청이 없습니다.');
          }
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() => _state = next);
              await next;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = state.requests[index];
                return ListTile(
                  key: ValueKey('operatorManualRequest-${request.id}'),
                  title: Text(
                    '${request.proofCharacterName} · ${request.verificationCode}',
                  ),
                  subtitle: Text(
                    '${request.proofServerName} · '
                    '대상 ${request.attemptNumberForTarget}회 · '
                    '전체 ${request.totalAttemptNumberForPlayer}회 · '
                    '${KoreaTimeFormatter.dayAndTime(request.createdAt)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/settings/operator/manual-verification/${request.id}',
                    extra: request,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _QueueState {
  const _QueueState.denied() : allowed = false, requests = const [];

  const _QueueState.allowed(this.requests) : allowed = true;

  final bool allowed;
  final List<ManualVerificationRequest> requests;
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
