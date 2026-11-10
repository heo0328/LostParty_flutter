import 'package:flutter/material.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/completion_failure.dart';
import 'batch_completion_dialog.dart';
import 'cycle_member_action_widgets.dart';
import 'cycle_outcome_widgets.dart';
import 'recovery_notice_card.dart';

class ParticipationRecoveryCard extends StatelessWidget {
  const ParticipationRecoveryCard({required this.controller, super.key});
  final CycleParticipationController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, state = controller.recoveryState;
      if (state == null || c.completionDialogOpen) {
        return const SizedBox.shrink();
      }
      final requestLabel = switch (state.kind) {
        'batch_personal_completion_departure' || 'departure' => '이전 완료·탈퇴 요청',
        'batch_completion' => '이전 공대 완료 요청',
        _ => state.completion ? '이전 완료 요청' : '이전 참가·관리 요청',
      };
      final refreshing = !c.hasPending && c.completionRefreshFailed;
      final storage = state.storageIssue != null;
      final label = refreshing
          ? '새로고침'
          : storage && state.requestKey == null
          ? '이전 요청 다시 불러오기'
          : state.acknowledged
          ? '결과 정리 다시 시도'
          : '요청 결과 확인';
      final detail = c.completionRefreshError ?? c.failureDetails;
      final code = detail?.code ?? state.storageIssue ?? c.failure;
      final canOpen =
          !c.busy && !c.restoring && (refreshing || state.canRecover);
      return RecoveryNoticeCard(
        title: refreshing
            ? '처리는 완료되었습니다. 최신 정보를 불러오지 못했습니다'
            : storage
            ? '이전 요청을 불러오거나 정리하지 못했습니다'
            : state.acknowledged
            ? '처리는 완료되었습니다. 결과 정리가 필요합니다'
            : state.completion
            ? '이전 완료 요청의 결과 확인이 필요합니다'
            : '이전 요청의 결과 확인이 필요합니다',
        message: [
          if (state.target != null) '$requestLabel · 대상 주차 ${state.target}',
          if (state.rounds.isNotEmpty) '선택한 레이드 ${state.rounds.length}개',
          refreshing
              ? '처리를 반복하지 않고 최신 정보만 다시 불러옵니다.'
              : '확인이 끝날 때까지 새로운 참가·완료·관리 요청이 제한됩니다. 현재 모집의 조회는 이용할 수 있습니다.',
          if (state.needsReview) '자동으로 다시 보낼 수 없는 요청입니다. 오류 정보를 확인해 주세요.',
          if (state.waiting) '잠시 후 같은 요청의 결과를 다시 확인할 수 있습니다.',
        ].join('\n'),
        actionLabel: label,
        loading: c.busy || c.restoring,
        diagnostic: code == null ? null : completionDiagnostic(code, detail),
        onAction: !canOpen
            ? null
            : () async {
                // Mark this key before opening: recovery must not navigate a retained
                // detail or the account screen after replaying an already applied ACK.
                c.keepRecoveryOnCurrentScreen();
                if (refreshing) {
                  if (state.room != null && state.target != null) {
                    await c.refreshCompletion(state.room!, state.target!);
                  }
                  return;
                }
                final room = state.room, target = state.target;
                if (room == null || target == null || !c.pendingCompletion) {
                  await c.retry();
                  return;
                }
                final binding = c.scopeKey(), key = state.requestKey;
                bool current() =>
                    context.mounted &&
                    c.scopeKey() == binding &&
                    (c.pendingRequestKey == key || !c.hasPending);
                final batch = c.pendingBatchKind;
                if (batch != null) {
                  await showBatchCompletion(
                    context,
                    c,
                    room: room,
                    target: target,
                    kind: batch,
                    raidName: (_) => '이전 요청의 레이드',
                    isCurrent: current,
                  );
                } else if (c.matchesCompletion(
                  room,
                  target,
                  'personal_completion',
                )) {
                  await showDeparture(
                    context,
                    c,
                    room: room,
                    target: target,
                    initialRound: c.pendingCompletionRound,
                    closeOnSuccess: true,
                    raidLabel: (_) => '이전 요청의 레이드',
                    isCurrent: current,
                  );
                } else {
                  await showOutcomeRecovery(
                    context,
                    c,
                    room: room,
                    target: target,
                    isCurrent: current,
                  );
                }
              },
      );
    },
  );
}
