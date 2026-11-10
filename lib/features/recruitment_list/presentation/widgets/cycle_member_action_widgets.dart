import '../../data/beta/cycle_group_policy.dart';
import 'cycle_action_dialog_route.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'completion_dialog_feedback.dart';
import '../../data/cycle_member_actions.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import 'cycle_participation_widgets.dart';

Future<void> showMemberRemoval(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String membership,
  required String member,
  required bool Function() isCurrent,
}) => showDialog<void>(
  context: context,
  builder: (_) => _RemovalDialog(
    controller: controller,
    room: room,
    target: target,
    membership: membership,
    member: member,
    isCurrent: isCurrent,
  ),
);

class _RemovalDialog extends StatefulWidget {
  const _RemovalDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.membership,
    required this.member,
    required this.isCurrent,
  });
  final CycleParticipationController controller;
  final String room, target, membership, member;
  final bool Function() isCurrent;
  @override
  State<_RemovalDialog> createState() => _RemovalDialogState();
}

class _RemovalDialogState extends State<_RemovalDialog> {
  CycleParticipationController get c => widget.controller;
  late final String binding;
  RemovalPreview? preview;
  String? commandKey, hint;
  bool loading = true, closing = false;
  int epoch = 0;
  bool get valid =>
      mounted &&
      c.session.isAuthenticated &&
      c.scopeKey() == binding &&
      widget.isCurrent();
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    c.addListener(changed);
    unawaited(load());
  }

  void changed() {
    final success = c.removalSuccess;
    if (!valid ||
        closing ||
        commandKey == null ||
        success == null ||
        success.$1 != commandKey ||
        success.$2 != widget.room ||
        success.$3 != widget.target ||
        success.$4 != widget.member) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (valid && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> load() async {
    if (!valid) return;
    final e = ++epoch;
    setState(() {
      loading = true;
      preview = null;
    });
    final p = await c.removal(widget.room, widget.target, widget.member);
    if (!valid || e != epoch) return;
    setState(() {
      loading = false;
      if (p != null && p.membership == widget.membership) {
        preview = p;
      } else if (p != null) {
        hint = '참가자가 변경되었습니다. 상세 화면을 다시 확인해 주세요.';
      }
    });
  }

  Future<void> submit(String mode) async {
    final p = preview;
    if (!valid || loading || !c.canAct || p == null) return;
    setState(() {
      loading = true;
      hint = null;
    });
    await c.removeMember(
      p,
      mode,
      membership: widget.membership,
      isCurrent: () => valid,
      onPrepared: (key) => commandKey = key,
    );
    if (!valid || closing) return;
    setState(() => loading = false);
    if (!c.hasPending && c.failure != null) {
      hint = recruitmentFailureMessage(c.failure);
      await load();
    }
  }

  String reason(String mode, String? code) => switch (code) {
    'TARGET_LEADER_REQUIRED' =>
      mode == 'both'
          ? '두 주차 모두 공대장일 때 함께 내보낼 수 있습니다.'
          : '선택한 주차의 공대장만 내보낼 수 있습니다.',
    'ROOM_REMOVAL_TARGET_INVALID' => '본인이나 공대장은 내보낼 수 없습니다.',
    'ROOM_REVIEW_REQUIRED' => '참가 상태를 확인한 뒤 내보낼 수 있습니다.',
    _ => recruitmentFailureMessage(code),
  };
  @override
  void dispose() {
    c.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      final single = p?.scope['current_cycle_key'] == widget.target
          ? '이번주만 내보내기'
          : '다음주만 내보내기';
      return AlertDialog(
        title: const Text('참가자 내보내기'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('대상 주차 · ${widget.target}'),
                if (loading) const LinearProgressIndicator(),
                if (p != null) ...[
                  Text(p.source['character_name'] as String? ?? '선택한 참가자'),
                  if (p.opposite['status'] != 'none') ...[
                    const SizedBox(height: 8),
                    Text(
                      '${p.opposite['target_cycle_key']} 주차에도 참가 관계가 있습니다. 함께 내보내시겠습니까?',
                    ),
                    if (p.opposite['target'] != null)
                      Text(
                        p.opposite['target']['character_name'] as String? ??
                            '선택한 참가자',
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Text('선택한 주차의 참가와 예약을 해제합니다. 기존 완료 기록은 유지됩니다.'),
                  for (final mode in [
                    'current_only',
                    if (p.opposite['status'] != 'none') 'both',
                  ])
                    if (!p.permission(mode).allowed)
                      Text(
                        '${mode == 'both' ? '함께 내보내기' : single} · ${reason(mode, p.permission(mode).reason)}',
                      ),
                ],
                if (hint != null) Text(hint!),
                if (!valid) const Text('화면이 변경되었습니다. 닫은 뒤 다시 확인해 주세요.'),
                CycleCommandBanner(controller: c),
                if (!loading && !c.hasPending)
                  TextButton(
                    onPressed: valid && c.canAct ? load : null,
                    child: const Text('최신 상태 다시 확인'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: c.busy ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          if (p != null) ...[
            FilledButton(
              onPressed:
                  valid &&
                      !loading &&
                      c.canAct &&
                      p.permission('current_only').allowed
                  ? () => submit('current_only')
                  : null,
              child: Text(single),
            ),
            if (p.opposite['status'] != 'none')
              FilledButton(
                onPressed:
                    valid &&
                        !loading &&
                        c.canAct &&
                        p.permission('both').allowed
                    ? () => submit('both')
                    : null,
                child: const Text('함께 내보내기'),
              ),
          ],
        ],
      );
    },
  );
}

Future<void> showDeparture(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String Function(Map) raidLabel,
  required bool Function() isCurrent,
  String? initialRound,
  String? expectedCharacter,
  bool closeOnSuccess = false,
}) => showDialog<void>(
  context: context,
  routeSettings: cycleActionDialogRoute(room, target),
  builder: (_) => _DepartureDialog(
    controller: controller,
    room: room,
    target: target,
    raidLabel: raidLabel,
    isCurrent: isCurrent,
    initialRound: initialRound,
    expectedCharacter: expectedCharacter,
    closeOnSuccess: closeOnSuccess,
  ),
);

class _DepartureDialog extends StatefulWidget {
  const _DepartureDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.raidLabel,
    required this.isCurrent,
    this.initialRound,
    this.expectedCharacter,
    this.closeOnSuccess = false,
  });
  final CycleParticipationController controller;
  final String room, target;
  final String Function(Map) raidLabel;
  final bool Function() isCurrent;
  final String? initialRound, expectedCharacter;
  final bool closeOnSuccess;
  @override
  State<_DepartureDialog> createState() => _DepartureDialogState();
}

class _DepartureDialogState extends State<_DepartureDialog> {
  CycleParticipationController get c => widget.controller;
  late final String binding;
  late final CompletionDialogFeedback feedback;
  CycleScheduleView? plan;
  DeparturePreview? preview;
  String? round, submittedKey, selectionFailure;
  bool closing = false;
  bool loading = true;
  int epoch = 0;
  bool get valid =>
      mounted &&
      feedback.active &&
      c.session.isAuthenticated &&
      c.scopeKey() == binding &&
      widget.isCurrent();
  List<Map> get choices => [
    for (final item in plan?.data['game_items'] as List? ?? [])
      if ((widget.initialRound == null ||
              item['round_id'] == widget.initialRound) &&
          item['round_state'] == 'active' &&
          (plan!.data['my_assignments'] as List).any(
            (a) => a['round_id'] == item['round_id'] && a['state'] == 'active',
          ))
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
      'personal_completion',
    );
    c.addListener(completionChanged);
    if (widget.closeOnSuccess) c.addListener(_success);
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

  void _success() {
    final success = c.departureSuccess;
    if (!valid ||
        closing ||
        submittedKey == null ||
        c.scopeKey() != binding ||
        success?.$1 != submittedKey ||
        !c.completionNavigationAllowed(submittedKey!) ||
        success?.$2 != widget.room ||
        success?.$3 != widget.target) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (valid && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  void completionChanged() {
    if (!valid || closing || !feedback.finished) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (valid && ModalRoute.of(context)?.isCurrent == true) close();
    });
  }

  @override
  void dispose() {
    c.removeListener(completionChanged);
    feedback.close();
    if (widget.closeOnSuccess) c.removeListener(_success);
    super.dispose();
  }

  Future<void> load() async {
    if (!valid || feedback.matchesPending) return;
    setState(() {
      loading = true;
      preview = null;
    });
    c.failure = null;
    plan = await c.scheduleRead(widget.room, widget.target, 'plan');
    if (!valid) return;
    feedback.capture(query: true);
    if (plan == null) {
      setState(() => loading = false);
      return;
    }
    round =
        choices.where((i) => i['round_id'] == round).firstOrNull?['round_id'] ??
        choices.firstOrNull?['round_id'];
    await contextRead();
  }

  void close() {
    feedback.close();
    Navigator.pop(context);
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

  Future<void> contextRead() async {
    final e = ++epoch;
    if (!valid) return;
    setState(() {
      loading = true;
      preview = null;
    });
    final value = round == null
        ? null
        : await c.departure(widget.room, widget.target, round!);
    if (!valid || e != epoch) return;
    feedback.capture(query: true);
    if (round == null && plan != null) feedback.code = 'ROUND_NOT_ACTIVE';
    setState(() {
      final sameCharacter =
          widget.expectedCharacter == null ||
          value?.data['subject']['character_id'] == widget.expectedCharacter;
      preview = sameCharacter ? value : null;
      selectionFailure = sameCharacter ? null : 'REVISION_CONFLICT';
      loading = false;
    });
  }

  Future<void> submit() async {
    final value = preview;
    if (!valid || loading || value == null || !c.canAct) return;
    setState(() => loading = true);
    await c.depart(
      value,
      isCurrent: () => valid,
      onPrepared: (key) => submittedKey = key,
    );
    if (!valid) return;
    feedback.capture(query: feedback.requestKey == null);
    if (feedback.acknowledged &&
        !feedback.refreshFailed &&
        !c.hasPending &&
        c.failure == null) {
      close();
      return;
    }
    setState(() {
      loading = false;
      preview = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      return AlertDialog(
        title: const Text('나혼자 완료처리이후 탈퇴'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('대상 주차 · ${widget.target}'),
                if (loading) const LinearProgressIndicator(),
                if (!loading && !feedback.matchesPending && choices.length > 1)
                  DropdownButtonFormField<String>(
                    key: ValueKey(round),
                    initialValue: round,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '완료할 레이드'),
                    items: [
                      for (final i in choices)
                        DropdownMenuItem(
                          value: i['round_id'] as String,
                          child: Text(widget.raidLabel(i)),
                        ),
                    ],
                    onChanged: valid && c.canAct
                        ? (v) {
                            round = v;
                            unawaited(contextRead());
                          }
                        : null,
                  ),
                if (p != null) ...[
                  Text(
                    p.display['character_name'] as String? ?? '캐릭터 이름 확인 불가',
                  ),
                  for (final v in p.display['assignments'] as List)
                    Text(
                      '${const {'complete': '완료', 'cancel': '참가 취소', 'preserve_completed': '기존 완료 유지'}[v['effect']]} · ${v['raid_name']} · ${v['difficulty_name']}',
                    ),
                  const SizedBox(height: 8),
                  for (final effect in p.groupEffects)
                    Text(
                      '${effect['target_cycle_key']} · ${CycleGroupEffect(effect).description}',
                    ),
                  Text(
                    '이 주차에서 탈퇴하며 예약 ${p.impact['released_reservation_count']}건을 해제합니다. 다음 주 참가는 유지됩니다.',
                  ),
                  if (p.impact['successor'] != null)
                    Text(
                      '공대장은 ${p.impact['successor']['character_name'] ?? '다음 참가자'}에게 승계됩니다.',
                    ),
                  if ((p.impact['departure_effect'] as String).startsWith(
                    'close_',
                  ))
                    const Text('마지막 참가자이므로 이 주차의 모집이 종료됩니다.'),
                ],
                if (feedback.matchesPending)
                  Text(feedback.targetLabel ?? '선택했던 레이드의 요청을 다시 시도합니다.'),
                CompletionDialogNotice(
                  feedback: feedback,
                  reason:
                      selectionFailure ??
                      (p?.permission.allowed == false
                          ? p?.permission.reason
                          : null),
                ),
              ],
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
                p?.permission.allowed == true &&
                selectionFailure == null,
            onClose: close,
            onSubmit: submit,
            onRead: load,
            onRetry: recover,
            onRefresh: () => recover(refresh: true),
            reason:
                selectionFailure ??
                (p?.permission.allowed == false ? p?.permission.reason : null),
          ),
        ],
      );
    },
  );
}
