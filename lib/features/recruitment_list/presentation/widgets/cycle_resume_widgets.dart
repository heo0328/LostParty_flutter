import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/cycle_resume.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'cycle_participation_widgets.dart';
import 'cycle_schedule_widgets.dart' show scheduleTime;

class CycleResumeActions extends StatelessWidget {
  const CycleResumeActions({
    required this.controller,
    required this.room,
    required this.target,
    required this.current,
    required this.role,
    required this.state,
    required this.continuation,
    required this.playable,
    required this.raidLabel,
    super.key,
  });
  final CycleParticipationController controller;
  final String room, target, current, role, state;
  final bool continuation, playable;
  final String Function(Map) raidLabel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Wrap(
      spacing: 8,
      children: [
        if (continuation &&
            target == current &&
            {'leader', 'member'}.contains(role)) ...[
          if (role == 'leader' && state == 'stopped_incomplete')
            TextButton(
              onPressed: controller.canAct && playable
                  ? () => open(context, true)
                  : null,
              child: const Text('이번 주 재개 제안'),
            ),
          TextButton(
            onPressed: controller.canAct ? () => open(context, false) : null,
            child: const Text('재개 제안 확인'),
          ),
        ],
      ],
    ),
  );
  Future<void> open(BuildContext context, bool create) => showDialog<void>(
    context: context,
    builder: (_) => _ResumeDialog(
      controller: controller,
      room: room,
      target: target,
      create: create,
      raidLabel: raidLabel,
    ),
  );
}

class _ResumeDialog extends StatefulWidget {
  const _ResumeDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.create,
    required this.raidLabel,
  });
  final CycleParticipationController controller;
  final String room, target;
  final bool create;
  final String Function(Map) raidLabel;
  @override
  State<_ResumeDialog> createState() => _ResumeDialogState();
}

class _ResumeDialogState extends State<_ResumeDialog> {
  CycleResumePlan? index;
  CycleResumePreview? preview;
  String? proposal;
  bool loading = true, retain = true;
  late final String binding;
  CycleParticipationController get c => widget.controller;
  bool get valid =>
      mounted && c.session.isAuthenticated && binding == c.scopeKey();
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    unawaited(load());
  }

  Future<void> load() async {
    if (!valid || !c.canAct) return;
    setState(() {
      loading = true;
      preview = null;
    });
    if (widget.create) {
      final p = await c.resumePreview(
        widget.room,
        widget.target,
        groups: retain ? null : [],
      );
      if (!valid) return;
      setState(() {
        preview = p;
        loading = false;
      });
    } else {
      final list = await c.resumePlan(widget.room, widget.target);
      if (!valid) return;
      setState(() {
        index = list;
        loading = false;
      });
      if (list != null && list.entries.isNotEmpty) {
        proposal = list.entries.containsKey(proposal)
            ? proposal
            : list.entries.keys.last;
        await review();
      }
    }
  }

  Future<void> review() async {
    if (!valid || !c.canAct || proposal == null) return;
    setState(() {
      loading = true;
      preview = null;
    });
    final p = await c.resumePreview(
      widget.room,
      widget.target,
      proposalId: proposal,
    );
    if (!valid) return;
    setState(() {
      preview = p;
      loading = false;
    });
  }

  Future<void> submit(String? response) async {
    final p = preview;
    if (!valid || loading || !c.canAct || p == null || !p.review.canConfirm) {
      return;
    }
    setState(() => loading = true);
    await c.resume(p, response: response);
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

  List<Widget> details(CycleResumeReview r) {
    final d = r.display, e = r.effect;
    final items = d['items'] as List;
    String count(String key) => e[key]?.toString() ?? '미확인';
    String name(Object? id) =>
        widget.raidLabel(items.firstWhere((i) => i['item_id'] == id) as Map);
    return [
      if (d['status'] != 'ready')
        const Text('이 제안은 새 응답을 보낼 수 없습니다. 공대장이 최신 일정으로 새 제안을 만들어 주세요.'),
      for (final item in items) Text(widget.raidLabel(item as Map)),
      if ((d['groups'] as List).isEmpty) const Text('일정 미지정 · 재개 후 별도로 설정합니다.'),
      for (final group in d['groups'] as List) ...[
        const SizedBox(height: 8),
        Text(
          '${group['required'] == true ? '필수' : '선택'} · ${group['occurrence_mode'] == 'each' ? '선택일마다 진행' : '후보 중 1회'}',
        ),
        if ((group['alternatives'] as List).isEmpty) const Text('시간 조율 후 확정'),
        for (final a in group['alternatives'] as List) ...[
          Text((a['item_ids'] as List).map(name).join(' → ')),
          Text(
            a['time_state'] == 'bounded'
                ? '${scheduleTime(a['starts_at'])} – ${scheduleTime(a['ends_at'])}'
                : a['time_state'] == 'start_only'
                ? '${scheduleTime(a['starts_at'])} · 종료 미확인'
                : '출발 미정',
          ),
          Text(
            const {
              'on_apply': '재개 적용 시 일정 생성',
              'after_group_selection': '재개 후 진행 후보 선택 필요',
              'after_coordination': '재개 후 시간 조율 필요',
              'not_scheduled': '재개 후 일정 설정 필요',
            }[a['materialization']]!,
          ),
        ],
      ],
      const SizedBox(height: 8),
      Text(
        '동의 ${count('accepted_count')} / 필요 ${count('required_votes')} · 대상 ${count('eligible_count')}명',
      ),
      Text(
        '재개 레이드 ${count('new_round_count')}개 · 참가 ${count('new_assignment_count')}건 · 기존 완료 ${count('completed_preserved_count')}건 보존',
      ),
      Text(
        '대체할 제안 ${count('superseded_proposal_count')}개 · 내 즉시 시간동의 대상 ${count('my_immediate_session_count_on_accept')}개',
      ),
      if (widget.create)
        Text(
          e['creator_accept_on_submit'] == true
              ? '제안을 만들면 내 동의도 기록됩니다.'
              : '제안 등록 후 대상 참가자의 별도 응답이 필요합니다.',
        ),
      const SizedBox(height: 8),
      const Text('재개되면 유효한 중단 참가가 다시 연결됩니다. 거절·미응답은 탈퇴를 뜻하지 않습니다.'),
      const Text('동의한 사람의 해당 확정 일정만 시간동의·예약 대상이 됩니다. 실제 예약 여부는 재개 후 확인해 주세요.'),
      const Text('이번 주만 대상으로 하며 완료 기록과 다음 주 참가는 유지됩니다.'),
      if (!r.permission.allowed)
        Text(recruitmentFailureMessage(r.permission.reason)),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      final allowed =
          valid && !loading && c.canAct && p?.review.canConfirm == true;
      return AlertDialog(
        title: Text(widget.create ? '이번 주 재개 제안' : '재개 제안 확인'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('대상 주차 · ${widget.target}'),
                if (loading) const LinearProgressIndicator(),
                if (widget.create)
                  DropdownButtonFormField<bool>(
                    initialValue: retain,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('기존 일정 유지')),
                      DropdownMenuItem(
                        value: false,
                        child: Text('일정은 재개 후 설정'),
                      ),
                    ],
                    onChanged: valid && !loading && c.canAct
                        ? (v) {
                            retain = v!;
                            unawaited(load());
                          }
                        : null,
                  ),
                if (!widget.create &&
                    index != null &&
                    index!.entries.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(proposal),
                    initialValue: proposal,
                    isExpanded: true,
                    items: [
                      for (final id in index!.entries.keys)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            '재개 제안 ${index!.entries.keys.toList().indexOf(id) + 1} · ${const {'pending': '응답 중', 'applied': '재개됨', 'obsolete': '대체됨'}[index!.plan.find('proposals', 'proposal_id', id)['state']] ?? '종료'}',
                          ),
                        ),
                    ],
                    onChanged: valid && !loading && c.canAct
                        ? (v) {
                            proposal = v;
                            unawaited(review());
                          }
                        : null,
                  ),
                if (!loading && index != null && index!.entries.isEmpty)
                  const Text('등록된 재개 제안이 없습니다.'),
                if (p != null) ...[
                  if (p.proposalId != null)
                    Text(
                      '내 응답 · ${const {'pending': '미응답', 'accept': '동의', 'reject': '거절'}[p.plan.find('proposals', 'proposal_id', p.proposalId!)['my_response']] ?? '확인 필요'}',
                    ),
                  ...details(p.review),
                ],
                CycleCommandBanner(controller: c),
                if (valid && !loading && c.canAct)
                  TextButton(onPressed: load, child: const Text('최신 상태 다시 확인')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (!widget.create)
            TextButton(
              onPressed: allowed ? () => submit('reject') : null,
              child: const Text('거절'),
            ),
          FilledButton(
            onPressed: allowed
                ? () => submit(widget.create ? null : 'accept')
                : null,
            child: Text(widget.create ? '제안 등록' : '동의'),
          ),
        ],
      );
    },
  );
}
