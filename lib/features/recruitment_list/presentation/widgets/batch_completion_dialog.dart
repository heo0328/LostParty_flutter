import 'dart:async';
import 'package:flutter/material.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/batch_completion.dart';
import '../../data/beta/cycle_group_policy.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'completion_dialog_feedback.dart';
import 'cycle_action_dialog_route.dart';

Future<void> showBatchCompletion(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required BatchCompletionKind kind,
  required String Function(Map) raidName,
  required bool Function() isCurrent,
}) => showDialog<void>(
  context: context,
  routeSettings: cycleActionDialogRoute(room, target),
  builder: (_) => _BatchCompletionDialog(
    controller: controller,
    room: room,
    target: target,
    kind: kind,
    raidName: raidName,
    isCurrent: isCurrent,
  ),
);

class _BatchCompletionDialog extends StatefulWidget {
  const _BatchCompletionDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.kind,
    required this.raidName,
    required this.isCurrent,
  });
  final CycleParticipationController controller;
  final String room, target;
  final BatchCompletionKind kind;
  final String Function(Map) raidName;
  final bool Function() isCurrent;
  @override
  State<_BatchCompletionDialog> createState() => _BatchCompletionDialogState();
}

class _BatchCompletionDialogState extends State<_BatchCompletionDialog> {
  CycleParticipationController get c => widget.controller;
  late final String binding;
  late final CompletionDialogFeedback feedback;
  CycleScheduleView? plan;
  BatchCompletionPreview? preview;
  Set<String> selected = {};
  bool initialized = false,
      loadingPlan = true,
      reading = false,
      submitting = false,
      closing = false;
  int generation = 0;
  String? hint;
  bool get valid =>
      mounted &&
      feedback.active &&
      c.session.isAuthenticated &&
      c.scopeKey() == binding &&
      widget.isCurrent();
  List<Map> get choices => [
    for (final item in plan?.data['game_items'] as List? ?? [])
      if (item['round_state'] == 'active' &&
          (widget.kind == BatchCompletionKind.party ||
              (plan!.data['my_assignments'] as List).any(
                (a) =>
                    a['round_id'] == item['round_id'] && a['state'] == 'active',
              )))
        item as Map,
  ];
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    feedback = CompletionDialogFeedback(
      c,
      widget.room,
      widget.target,
      widget.kind.uiAction,
    );
    c.addListener(changed);
    if (feedback.matchesPending) {
      selected = c.pendingCompletionRounds.toSet();
      initialized = true;
      loadingPlan = false;
    } else {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    c.removeListener(changed);
    feedback.close();
    super.dispose();
  }

  void close() {
    feedback.close();
    Navigator.pop(context);
  }

  void changed() {
    if (!valid || closing || !feedback.finished) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (valid && ModalRoute.of(context)?.isCurrent == true) close();
    });
  }

  Future<void> load() async {
    if (!valid ||
        feedback.matchesPending ||
        loadingPlan && initialized ||
        c.busy) {
      return;
    }
    final readGeneration = ++generation;
    setState(() {
      loadingPlan = true;
      preview = null;
      hint = null;
    });
    c.failure = null;
    final value = await c.scheduleRead(widget.room, widget.target, 'plan');
    if (!valid || readGeneration != generation) return;
    feedback.capture(query: true);
    setState(() {
      plan = value;
      loadingPlan = false;
      if (value != null) {
        final available = choices.map((i) => i['round_id'] as String).toSet();
        selected = initialized ? selected.intersection(available) : available;
        initialized = true;
      }
    });
    if (value != null) await readPreview();
  }

  void select(String id, bool value) {
    if (!valid ||
        !c.canAct ||
        loadingPlan ||
        submitting ||
        feedback.matchesPending) {
      return;
    }
    setState(() {
      selected = {...selected};
      value ? selected.add(id) : selected.remove(id);
      generation++;
      preview = null;
      hint = null;
      feedback.code = null;
      feedback.error = null;
    });
    unawaited(readPreview());
  }

  Future<void> readPreview() async {
    if (!valid || reading || feedback.matchesPending || loadingPlan) return;
    setState(() => reading = true);
    try {
      while (valid && !feedback.matchesPending) {
        final e = generation;
        if (selected.isEmpty) break;
        final ids = selected.toList();
        final value = await c.batchCompletion(
          widget.room,
          widget.target,
          widget.kind,
          ids,
          isCurrent: () => valid && e == generation,
        );
        if (!valid) return;
        if (e != generation) continue;
        try {
          value?.bindPlan(plan!);
          preview = value;
        } on AccountReadException catch (error) {
          c.failure = error.code;
          preview = null;
        }
        feedback.capture(query: true);
        break;
      }
    } finally {
      reading = false;
      if (valid) setState(() {});
    }
  }

  Future<void> submit() async {
    final p = preview, e = generation;
    if (!valid ||
        p == null ||
        loadingPlan ||
        reading ||
        submitting ||
        !c.canAct ||
        !p.permission.allowed ||
        selected.isEmpty) {
      return;
    }
    setState(() {
      submitting = true;
      hint = null;
    });
    final revised = await c.completeBatch(
      p,
      isCurrent: () => valid && e == generation,
    );
    if (!valid) return;
    feedback.capture(query: feedback.requestKey == null);
    setState(() {
      submitting = false;
      preview = revised;
      if (revised != null) hint = '정보가 변경되었습니다. 내용을 확인해 주세요.';
    });
    if (feedback.finished) close();
  }

  Future<void> recover({bool refresh = false}) async {
    if (!valid || c.busy || submitting) return;
    setState(() => submitting = true);
    if (feedback.matchesPending) await c.retry();
    if (!valid) return;
    if (refresh && !feedback.matchesPending) {
      await c.refreshCompletion(widget.room, widget.target);
    }
    if (!valid) return;
    feedback.capture();
    if (feedback.finished) {
      close();
    } else {
      setState(() => submitting = false);
    }
  }

  String names(BatchCompletionPreview p, String effect) {
    final ids = p.assignments
        .where((a) => a['effect'] == effect)
        .map((a) => a['round_id'])
        .toSet();
    return p.displayRounds
        .where((r) => ids.contains(r['round_id']))
        .map((r) => r['raid_name'])
        .join(', ');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      final pending = feedback.matchesPending;
      final loading = loadingPlan || reading || submitting;
      return AlertDialog(
        title: Text(
          widget.kind == BatchCompletionKind.party ? '레이드 완료' : '나혼자 완료처리이후 탈퇴',
        ),
        content: SizedBox(
          width: 420,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('대상 주차 · ${widget.target}'),
                  if (loading) const LinearProgressIndicator(),
                  if (pending)
                    Text(
                      feedback.targetLabel ??
                          '선택했던 레이드 ${selected.length}개의 요청을 다시 시도합니다.',
                    )
                  else ...[
                    for (final item in choices)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(widget.raidName(item)),
                        value: selected.contains(item['round_id']),
                        onChanged:
                            valid && c.canAct && !loadingPlan && !submitting
                            ? (v) =>
                                  select(item['round_id'] as String, v == true)
                            : null,
                      ),
                    if (!loadingPlan && plan != null && choices.isEmpty)
                      const Text('완료할 레이드가 없습니다.'),
                    if (choices.isNotEmpty && selected.isEmpty)
                      const Text('완료할 레이드를 선택해 주세요.'),
                  ],
                  if (p != null) ...[
                    Text('완료 · ${names(p, 'complete')}'),
                    if (widget.kind == BatchCompletionKind.personalDeparture &&
                        p.impact['cancelled_assignment_ids'].isNotEmpty)
                      Text('참가 취소 · ${names(p, 'cancel')}'),
                    for (final raid
                        in p.impact['preserved_completed']['raids'] as List)
                      Text(
                        '기존 완료 유지 · ${raid['raid_name']} ${raid['assignment_count']}건',
                      ),
                    const SizedBox(height: 8),
                    for (final effect in p.groupEffects)
                      Text(
                        '${effect['target_cycle_key']} · ${CycleGroupEffect(effect).description}',
                      ),
                    Text(
                      widget.kind == BatchCompletionKind.party
                          ? '선택한 레이드의 참가자들을 완료 처리합니다. 다른 레이드와 다음 주 참가는 유지됩니다.'
                          : '선택한 레이드는 나만 완료하고, 나머지 참가는 취소한 뒤 이 주차에서 탈퇴합니다. 다음 주 참가는 유지됩니다.',
                    ),
                    if (p.data['departure']?['successor'] != null)
                      Text(
                        '공대장은 ${p.data['departure']['successor']['character_name'] ?? '다음 참가자'}에게 승계됩니다.',
                      ),
                    if (p.data['departure'] != null &&
                        (p.data['departure']['effect'] as String).startsWith(
                          'close_',
                        ))
                      const Text('마지막 참가자이므로 이 주차의 모집이 종료됩니다.'),
                    const Text('완료된 참가와 예약은 복구할 수 없습니다.'),
                  ],
                  if (hint != null) Text(hint!),
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
        ),
        actions: [
          CompletionDialogButtons(
            feedback: feedback,
            loading: loading,
            canSubmit:
                valid &&
                c.canAct &&
                selected.isNotEmpty &&
                p?.permission.allowed == true,
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
