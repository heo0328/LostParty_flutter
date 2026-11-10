import 'package:flutter/material.dart';
import '../viewmodels/completion_failure.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'cycle_participation_widgets.dart' show CompletionDiagnosticInfo;

/// These widgets consume a dialog's feedback, never the shared banner's errors.
class CompletionDialogNotice extends StatelessWidget {
  const CompletionDialogNotice({
    required this.feedback,
    this.reason,
    super.key,
  });
  final CompletionDialogFeedback feedback;
  final String? reason;
  @override
  Widget build(BuildContext context) {
    final guidance = _guidance(feedback, reason);
    if (guidance == null) return const SizedBox.shrink();
    final code =
        feedback.error?.code ??
        feedback.code ??
        reason ??
        feedback.controller.recoveryIssue ??
        'REQUEST_IN_PROGRESS';
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(guidance.$1, style: TextStyle(color: colors.error)),
              ),
            ],
          ),
          CompletionDiagnosticInfo(
            diagnostic: completionDiagnostic(code, feedback.error),
          ),
          if ((feedback.queryFailure && feedback.readFailures >= 2) ||
              code == 'LOCAL_STORAGE_UNAVAILABLE')
            const Text('계속 문제가 발생하면 앱을 다시 실행해 주세요.'),
        ],
      ),
    );
  }
}

class CompletionDialogButtons extends StatelessWidget {
  const CompletionDialogButtons({
    required this.feedback,
    required this.loading,
    required this.canSubmit,
    required this.onClose,
    required this.onSubmit,
    required this.onRead,
    required this.onRetry,
    required this.onRefresh,
    this.reason,
    super.key,
  });
  final CompletionDialogFeedback feedback;
  final bool loading, canSubmit;
  final VoidCallback onClose, onSubmit, onRead, onRetry, onRefresh;
  final String? reason;
  @override
  Widget build(BuildContext context) {
    final c = feedback.controller;
    final guidance = _guidance(feedback, reason);
    final action = guidance?.$2;
    final enabled = !loading && !c.busy && !c.restoring;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action == 'confirm')
          FilledButton(onPressed: onClose, child: const Text('확인'))
        else ...[
          TextButton(onPressed: onClose, child: const Text('취소')),
          if (action != 'none') ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: !enabled
                  ? null
                  : feedback.matchesPending
                  ? c.canRetry
                        ? onRetry
                        : null
                  : action == 'refresh-result'
                  ? onRefresh
                  : action == 'read' || action == 'refresh'
                  ? onRead
                  : canSubmit
                  ? onSubmit
                  : null,
              child: Text(
                action == 'refresh' || action == 'refresh-result'
                    ? '새로고침'
                    : action == 'read' || action == 'retry'
                    ? '재시도'
                    : '확인',
              ),
            ),
          ],
        ],
      ],
    );
  }
}

(String, String)? _guidance(CompletionDialogFeedback f, String? reason) {
  if (!f.active) return null;
  final c = f.controller;
  final code = f.code ?? reason;
  if (f.refreshFailed) return ('완료되었습니다. 새로고침해 주세요.', 'refresh-result');
  if (const {
    'IDEMPOTENCY_CONFLICT',
    'IDEMPOTENCY_EXPIRED',
    'REQUEST_REVIEW_REQUIRED',
    'ROOM_REVIEW_REQUIRED',
  }.contains(code)) {
    return ('결과를 확인할 수 없습니다.', 'none');
  }
  if (f.matchesPending) {
    if (c.needsReview ||
        (!c.canRetry && !c.busy && !c.restoring && !c.waitingToRetry)) {
      return ('결과를 확인할 수 없습니다.', 'none');
    }
    if (c.pendingAcknowledged) return ('완료되었습니다. 새로고침해 주세요.', 'refresh-result');
    if (code == 'REQUEST_IN_PROGRESS' || c.waitingToRetry || c.busy) {
      return ('처리 중입니다. 잠시 후 다시 시도해 주세요.', 'retry');
    }
    return ('결과를 확인하지 못했습니다. 다시 시도해 주세요.', 'retry');
  }
  if (code == null) return null;
  if (const {
    'IDEMPOTENCY_CONFLICT',
    'IDEMPOTENCY_EXPIRED',
    'REQUEST_REVIEW_REQUIRED',
    'ROOM_REVIEW_REQUIRED',
  }.contains(code)) {
    return ('결과를 확인할 수 없습니다.', 'none');
  }
  if (const {
    'TARGET_LEADER_REQUIRED',
    'WEEKLY_PARTICIPANT_REQUIRED',
    'PERMISSION_DENIED',
    'SESSION_EXPIRED',
    'SESSION_REVOKED',
    'UNAUTHENTICATED',
    'CLIENT_UPGRADE_REQUIRED',
    'RECRUITMENT_COMMAND_NOT_READY',
    'GROUP_FEATURE_NOT_READY',
    'TARGET_CYCLE_NOT_CURRENT',
    'PLAY_NOT_STARTED',
  }.contains(code)) {
    return (completionFailureMessage(code)!, 'confirm');
  }
  final message = completionFailureMessage(code);
  if (message != null &&
      !const {'NETWORK_UNAVAILABLE', 'SERVICE_UNAVAILABLE'}.contains(code)) {
    return (message, code == 'REQUEST_IN_PROGRESS' ? 'read' : 'refresh');
  }
  return f.queryFailure
      ? ('정보를 불러오지 못했습니다. 다시 시도해 주세요.', 'read')
      : ('결과를 확인할 수 없습니다.', 'none');
}
