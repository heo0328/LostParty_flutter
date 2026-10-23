import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/cycle_outcome.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'cycle_participation_widgets.dart';

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
    this.showCompletion = true,
    this.showClosure = true,
    this.completeLabel = '레이드 완료',
    super.key,
  });
  final CycleParticipationController controller;
  final String room, target, current, role;
  final bool playable, continuation;
  final String Function(Map) raidLabel;
  final bool showCompletion, showClosure;
  final String completeLabel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Wrap(
      spacing: 8,
      children: [
        for (final action in cycleOutcomeLabels.keys)
          if ((action == 'complete_item' &&
                  showCompletion &&
                  role == 'leader') ||
              (action == 'personal_completion' &&
                  showCompletion &&
                  {'leader', 'member'}.contains(role)) ||
              (action == 'close_weekly' &&
                  showClosure &&
                  continuation &&
                  {'leader', 'member'}.contains(role)))
            TextButton(
              onPressed:
                  controller.canAct &&
                      target == current &&
                      playable &&
                      {'leader', 'member'}.contains(role) &&
                      (action != 'complete_item' || role == 'leader')
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => _OutcomeDialog(
                        controller: controller,
                        room: room,
                        target: target,
                        action: action,
                        raidLabel: raidLabel,
                      ),
                    )
                  : null,
              child: Text(
                action == 'complete_item'
                    ? completeLabel
                    : cycleOutcomeLabels[action]!,
              ),
            ),
      ],
    ),
  );
}

class _OutcomeDialog extends StatefulWidget {
  const _OutcomeDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.action,
    required this.raidLabel,
  });
  final CycleParticipationController controller;
  final String room, target, action;
  final String Function(Map) raidLabel;
  @override
  State<_OutcomeDialog> createState() => _OutcomeDialogState();
}

class _OutcomeDialogState extends State<_OutcomeDialog> {
  CycleOutcomePreview? preview;
  CycleScheduleView? plan;
  String? round;
  late final String binding;
  bool loading = true;
  CycleParticipationController get c => widget.controller;
  bool get valid =>
      mounted && c.session.isAuthenticated && binding == c.scopeKey();
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    unawaited(load());
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
    if (!valid) return;
    setState(() {
      loading = true;
      preview = null;
    });
    final result = await c.scheduleRead(widget.room, widget.target, 'plan');
    if (!valid) return;
    plan = result;
    if (widget.action != 'close_weekly') {
      if (!choices.any((i) => i['round_id'] == round)) {
        round = choices.firstOrNull?['round_id'] as String?;
      }
      if (round == null) {
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
    if (c.failure == null && !c.hasPending) {
      Navigator.pop(context);
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
                  if (!p.permission.allowed)
                    Text(recruitmentFailureMessage(p.permission.reason)),
                ],
                if (!loading && p == null && c.failure == null)
                  const Text('진행 가능한 레이드가 없습니다.'),
                CycleCommandBanner(controller: c),
                if (!loading && valid && c.canAct)
                  TextButton(onPressed: load, child: const Text('최신 상태 다시 확인')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed:
                valid && !loading && c.canAct && p?.permission.allowed == true
                ? submit
                : null,
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
