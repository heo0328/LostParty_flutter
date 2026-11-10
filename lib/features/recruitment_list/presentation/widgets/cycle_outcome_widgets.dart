import 'cycle_action_dialog_route.dart';
import 'batch_completion_dialog.dart';
import '../../data/batch_completion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/cycle_outcome.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'completion_dialog_feedback.dart';
import 'cycle_member_action_widgets.dart';

class CycleOutcomeActions extends StatelessWidget {
  const CycleOutcomeActions({
    required this.controller,
    required this.room,
    required this.target,
    required this.current,
    required this.role,
    required this.playable,
    required this.continuation,
    required this.raidLabel,
    this.raidName,
    this.showCompletion = true,
    this.showClosure = true,
    this.completeLabel = '레이드 완료',
    this.isCurrent,
    super.key,
  });
  final CycleParticipationController controller;
  final String room, target, current, role;
  final bool playable, continuation;
  final String Function(Map) raidLabel;
  final String Function(Map)? raidName;
  final bool showCompletion, showClosure;
  final String completeLabel;
  final bool Function()? isCurrent;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in cycleOutcomeLabels.keys)
          if ((action == 'complete_item' &&
                  showCompletion &&
                  (role == 'leader' ||
                      controller.matchesCompletion(
                        room,
                        target,
                        'complete_item',
                      ))) ||
              (action == 'personal_completion' &&
                  showCompletion &&
                  ({'leader', 'member'}.contains(role) ||
                      controller.matchesCompletion(
                        room,
                        target,
                        'personal_completion',
                      ))) ||
              (action == 'close_weekly' &&
                  controller.weeklyInterruptionEnabled &&
                  showClosure &&
                  continuation &&
                  {'leader', 'member'}.contains(role)))
            _action(context, action),
      ],
    ),
  );

  Widget _action(BuildContext context, String action) {
    final enabled =
        controller.matchesCompletion(room, target, action) ||
        (controller.canAct &&
            target == current &&
            playable &&
            {'leader', 'member'}.contains(role) &&
            (action != 'complete_item' || role == 'leader'));
    final VoidCallback? onPressed = enabled
        ? () =>
              controller.batchCompletionEnabled &&
                  action != 'close_weekly' &&
                  (!controller.matchesCompletion(room, target, action) ||
                      controller.pendingBatchKind != null)
              ? showBatchCompletion(
                  context,
                  controller,
                  room: room,
                  target: target,
                  kind: action == 'complete_item'
                      ? BatchCompletionKind.party
                      : BatchCompletionKind.personalDeparture,
                  raidName: raidName ?? raidLabel,
                  isCurrent: isCurrent ?? () => true,
                )
              : action == 'personal_completion'
              ? showDeparture(
                  context,
                  controller,
                  room: room,
                  target: target,
                  raidLabel: raidLabel,
                  isCurrent: isCurrent ?? () => true,
                )
              : showDialog<void>(
                  context: context,
                  routeSettings: cycleActionDialogRoute(room, target),
                  builder: (_) => _OutcomeDialog(
                    controller: controller,
                    room: room,
                    target: target,
                    action: action,
                    raidLabel: raidLabel,
                    isCurrent: isCurrent ?? () => true,
                  ),
                )
        : null;
    if (action == 'complete_item') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.task_alt),
          label: Text(completeLabel),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          action == 'personal_completion'
              ? '나혼자 완료처리이후 탈퇴'
              : cycleOutcomeLabels[action]!,
        ),
      ),
    );
  }
}

class _OutcomeDialog extends StatefulWidget {
  const _OutcomeDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.action,
    required this.raidLabel,
    required this.isCurrent,
  });
  final CycleParticipationController controller;
  final String room, target, action;
  final String Function(Map) raidLabel;
  final bool Function() isCurrent;
  @override
  State<_OutcomeDialog> createState() => _OutcomeDialogState();
}

class _OutcomeDialogState extends State<_OutcomeDialog> {
  CycleOutcomePreview? preview;
  CycleScheduleView? plan;
  String? round;
  late final String binding;
  late final CompletionDialogFeedback feedback;
  bool loading = true;
  bool closing = false;
  CycleParticipationController get c => widget.controller;
  bool get valid =>
      mounted &&
      feedback.active &&
      c.session.isAuthenticated &&
      binding == c.scopeKey() &&
      widget.isCurrent();
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    feedback = CompletionDialogFeedback(
      c,
      widget.room,
      widget.target,
      widget.action,
    );
    c.addListener(completionChanged);
    if (feedback.matchesPending) {
      round = feedback.round;
      loading = false;
      unawaited(
        feedback.readTargetLabel(widget.raidLabel).then((_) {
          if (valid) setState(() {});
        }),
      );
    } else {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    c.removeListener(completionChanged);
    feedback.close();
    super.dispose();
  }

  void close() {
    feedback.close();
    Navigator.pop(context);
  }

  void completionChanged() {
    if (!valid || closing || !feedback.finished) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (valid && ModalRoute.of(context)?.isCurrent == true) close();
    });
  }

  Future<void> recover({bool refresh = false}) async {
    if (!valid || loading || c.busy) return;
    setState(() => loading = true);
    if (feedback.matchesPending) await c.retry();
    if (!valid) return;
    if ((refresh || feedback.acknowledged) && !feedback.matchesPending) {
      await c.refreshCompletion(widget.room, widget.target);
    }
    if (!valid) return;
    feedback.capture();
    if (feedback.acknowledged &&
        !feedback.refreshFailed &&
        !c.hasPending &&
        c.failure == null) {
      close();
    } else {
      setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get choices => [
    for (final item in (plan?.data['game_items'] as List? ?? []))
      if (item['round_state'] == 'active' &&
          (widget.action != 'personal_completion' ||
              (plan!.data['my_assignments'] as List).any(
                (a) =>
                    a['round_id'] == item['round_id'] && a['state'] == 'active',
              )))
        Map<String, dynamic>.from(item as Map),
  ];
  Future<void> load() async {
    if (!valid || feedback.matchesPending) return;
    setState(() {
      loading = true;
      preview = null;
    });
    c.failure = null;
    final result = await c.scheduleRead(widget.room, widget.target, 'plan');
    if (!valid) return;
    feedback.capture(query: true);
    plan = result;
    if (result == null) {
      setState(() => loading = false);
      return;
    }
    if (widget.action != 'close_weekly') {
      if (!choices.any((i) => i['round_id'] == round)) {
        round = choices.firstOrNull?['round_id'] as String?;
      }
      if (round == null) {
        feedback.code = 'ROUND_NOT_ACTIVE';
        setState(() => loading = false);
        return;
      }
    }
    await loadContext();
  }

  Future<void> loadContext() async {
    if (!valid) return;
    setState(() {
      loading = true;
      preview = null;
    });
    final result = await c.outcome(
      widget.room,
      widget.target,
      widget.action,
      round: round,
    );
    if (!valid) return;
    feedback.capture(query: true);
    setState(() {
      preview = result;
      plan = result?.plan ?? plan;
      loading = false;
    });
  }

  Future<void> submit() async {
    final p = preview;
    if (!valid || p == null || loading || !c.canAct) return;
    setState(() => loading = true);
    await c.complete(p);
    if (!mounted || !valid) return;
    feedback.capture(query: feedback.requestKey == null);
    if (c.failure == null && !c.hasPending && !feedback.refreshFailed) {
      close();
    } else {
      setState(() {
        loading = false;
        preview = null;
      });
    }
  }

  String label(Map item) => widget.raidLabel(item);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      return AlertDialog(
        title: Text(cycleOutcomeLabels[widget.action]!),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('대상 주차 · ${widget.target}'),
                if (loading) const LinearProgressIndicator(),
                if (!loading &&
                    !feedback.matchesPending &&
                    widget.action != 'close_weekly' &&
                    choices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(round),
                    initialValue: choices.any((i) => i['round_id'] == round)
                        ? round
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '완료할 레이드'),
                    items: [
                      for (final item in choices)
                        DropdownMenuItem(
                          value: item['round_id'] as String,
                          child: Text(label(item)),
                        ),
                    ],
                    onChanged: valid && c.canAct
                        ? (value) {
                            round = value;
                            unawaited(loadContext());
                          }
                        : null,
                  ),
                if (p != null) ...[
                  for (final item in p.items.where(
                    (i) =>
                        (p.impact['round_ids'] as List).contains(i['round_id']),
                  ))
                    Text(label(item)),
                  const SizedBox(height: 8),
                  Text(
                    '대상 ${p.impact['membership_count']}명 · 참가 ${p.impact['assignment_count']}건',
                  ),
                  Text(
                    '예약 해제 ${p.impact['reservation_segment_count']}구간 · 기존 완료 ${p.impact['completed_preserved_count']}건 보존',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.action == 'close_weekly'
                        ? '남은 레이드를 미완료로 종료합니다. 완료 기록은 추가되지 않으며 다음 주 참가는 유지됩니다.'
                        : widget.action == 'personal_completion'
                        ? '선택한 레이드에서 나만 완료합니다. 다른 공대원과 다음 주 참가는 유지됩니다.'
                        : '선택한 레이드의 참가자들을 완료 처리합니다. 다른 레이드와 다음 주 참가는 유지됩니다.',
                  ),
                  if (widget.action != 'close_weekly')
                    const Text('완료된 참가와 예약은 복구할 수 없습니다.'),
                ],
                if (feedback.matchesPending && round != null)
                  Text(feedback.targetLabel ?? '선택했던 레이드의 요청을 다시 시도합니다.'),
                CompletionDialogNotice(
                  feedback: feedback,
                  reason: p?.permission.allowed == false
                      ? p?.permission.reason
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          CompletionDialogButtons(
            feedback: feedback,
            loading: loading,
            canSubmit: valid && c.canAct && p?.permission.allowed == true,
            onClose: close,
            onSubmit: submit,
            onRead: load,
            onRetry: recover,
            onRefresh: () => recover(refresh: true),
            reason: p?.permission.allowed == false
                ? p?.permission.reason
                : null,
          ),
        ],
      );
    },
  );
}
