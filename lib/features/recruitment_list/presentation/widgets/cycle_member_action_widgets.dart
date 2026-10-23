import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/cycle_member_actions.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import 'cycle_participation_widgets.dart';

Future<void> showDeparture(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String Function(Map) raidLabel,
  required bool Function() isCurrent,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DepartureDialog(
    controller: controller,
    room: room,
    target: target,
    raidLabel: raidLabel,
    isCurrent: isCurrent,
  ),
);

class _DepartureDialog extends StatefulWidget {
  const _DepartureDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.raidLabel,
    required this.isCurrent,
  });
  final CycleParticipationController controller;
  final String room, target;
  final String Function(Map) raidLabel;
  final bool Function() isCurrent;
  @override
  State<_DepartureDialog> createState() => _DepartureDialogState();
}

class _DepartureDialogState extends State<_DepartureDialog> {
  CycleParticipationController get c => widget.controller;
  late final String binding;
  CycleScheduleView? plan;
  DeparturePreview? preview;
  String? round;
  bool loading = true;
  int epoch = 0;
  bool get valid =>
      mounted &&
      c.session.isAuthenticated &&
      c.scopeKey() == binding &&
      widget.isCurrent();
  List<Map> get choices => [
    for (final item in plan?.data['game_items'] as List? ?? [])
      if (item['round_state'] == 'active' &&
          (plan!.data['my_assignments'] as List).any(
            (a) => a['round_id'] == item['round_id'] && a['state'] == 'active',
          ))
        item as Map,
  ];
  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    unawaited(load());
  }

  Future<void> load() async {
    if (!valid) return;
    setState(() {
      loading = true;
      preview = null;
    });
    plan = await c.scheduleRead(widget.room, widget.target, 'plan');
    if (!valid) return;
    round =
        choices.where((i) => i['round_id'] == round).firstOrNull?['round_id'] ??
        choices.firstOrNull?['round_id'];
    await contextRead();
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
    setState(() {
      preview = value;
      loading = false;
    });
  }

  Future<void> submit() async {
    final value = preview;
    if (!valid || loading || value == null || !c.canAct) return;
    setState(() => loading = true);
    await c.depart(value, isCurrent: () => valid);
    if (!valid) return;
    // Page consumes the explicit success event, including successful retries.
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
                if (!loading && choices.length > 1)
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
                  if (!p.permission.allowed)
                    Text(
                      p.permission.reason == 'SUCCESSOR_UNAVAILABLE'
                          ? '승계 가능한 공대원이 없어 완료 후 탈퇴할 수 없습니다.'
                          : recruitmentFailureMessage(p.permission.reason),
                    ),
                ],
                if (!loading && p == null && c.failure == null)
                  const Text('완료 후 탈퇴할 수 있는 레이드가 없습니다.'),
                CycleCommandBanner(controller: c),
                if (!loading)
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
            onPressed: loading ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed:
                valid && !loading && c.canAct && p?.permission.allowed == true
                ? submit
                : null,
            child: const Text('완료 후 탈퇴'),
          ),
        ],
      );
    },
  );
}
