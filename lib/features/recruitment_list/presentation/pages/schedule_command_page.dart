import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/cycle_schedule.dart';
import '../../domain/beta_schedule_draft.dart';
import '../../domain/schedule_comparison.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/beta_schedule_editor.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../widgets/recruitment_section.dart';
import '../widgets/schedule_timeline.dart';

String scheduleStamp(Object? raw) {
  if (raw == null) return '시간 정보 없음';
  final t = DateTime.parse(raw as String).toUtc().add(const Duration(hours: 9));
  return '${t.month}/${t.day}(${' 월화수목금토일'[t.weekday]}) ${clock(t.hour * 60 + t.minute)}';
}

class ScheduleCommandPage extends StatefulWidget {
  const ScheduleCommandPage({
    super.key,
    required this.controller,
    required this.preview,
    this.comparison,
    this.selected = const {},
    this.initialDay = 3,
    this.initialMinute,
  });
  final CycleParticipationController controller;
  final CycleSchedulePreview preview;
  final ScheduleComparison? comparison;
  final Set<String> selected;
  final int initialDay;
  final int? initialMinute;
  @override
  State<ScheduleCommandPage> createState() => _ScheduleCommandPageState();
}

class _ScheduleCommandPageState extends State<ScheduleCommandPage> {
  CycleSchedulePreview get p => widget.preview;
  late final String binding;
  late final DateTime received;
  BetaScheduleInput input = const BetaScheduleInput();
  String? sessionId, error, requestKey;
  bool sending = false, closing = false;
  String? successBefore;
  DateTime get serverNow => DateTime.parse(
    p.plan.scope['server_now'] as String,
  ).add(widget.controller.now().toUtc().difference(received));
  bool get active =>
      widget.controller.session.isAuthenticated &&
      binding == widget.controller.scopeKey();
  bool get responding => p.action == 'respond';
  List<Map<String, dynamic>> get sessions => (p.plan.data['sessions'] as List)
      .cast<Map<String, dynamic>>()
      .where((s) => s['permissions']?['propose_schedule']?['allowed'] == true)
      .toList();
  List<Map<String, dynamic>> get durations {
    if (sessionId == null) return [];
    final set = p.plan.find('session_segments', 'session_id', sessionId!);
    return [
      for (final seg in set['segments'] as List)
        if (seg['state'] == 'planned')
          {
            'item_id': seg['item_id'],
            'duration_minutes': seg['duration_minutes'],
          },
    ];
  }

  int get minutes {
    if (sessionId == null) return 0;
    final session = p.plan.find('sessions', 'session_id', sessionId!);
    if (session['duration_minutes'] case final int value) return value;
    return durations.fold(
      0,
      (sum, row) => sum + (row['duration_minutes'] as int? ?? 0),
    );
  }

  bool get ready =>
      active &&
      !sending &&
      requestKey == null &&
      widget.controller.canAct &&
      (responding ||
          sessionId != null &&
              BetaScheduleEditor.valid(
                p.plan.target,
                serverNow,
                minutes,
                p.plan.data['app_capacity'] as int,
                input,
              ));
  @override
  void initState() {
    super.initState();
    binding = widget.controller.scopeKey();
    received = widget.controller.now().toUtc();
    successBefore = widget.controller.scheduleSuccess?.$1;
    if (!responding) {
      final preferred = p.plan.betaData?['beta_schedule']?['session_id'];
      sessionId = sessions.any((s) => s['session_id'] == preferred)
          ? preferred as String?
          : sessions.length == 1
          ? sessions.single['session_id'] as String
          : null;
      input = BetaScheduleInput(
        weekday: widget.initialDay,
        minute: widget.initialMinute,
      );
    }
    widget.controller.addListener(observe);
  }

  @override
  void dispose() {
    widget.controller.removeListener(observe);
    super.dispose();
  }

  void observe() {
    final success = widget.controller.scheduleSuccess;
    if (!mounted ||
        !active ||
        closing ||
        requestKey == null ||
        success?.$1 != requestKey ||
        success?.$2 != p.plan.room ||
        success?.$3 != p.plan.target) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  List<String> warnings() {
    final comparison = widget.comparison;
    if (comparison == null || input.weekday == null || input.minute == null) {
      return [];
    }
    final time = input.minute!, day = input.weekday!;
    final start = DateTime.parse(
      BetaScheduleEditor.config(p.plan.target, input)['base_starts_at']
          as String,
    );
    final end = start.add(Duration(minutes: minutes));
    return [
      for (final member in comparison.members)
        if (member.state == TimetableState.unavailable || !member.busyAvailable)
          '${member.name} · 시간을 확인할 수 없습니다.'
        else if (!member.availableFor(day, time, minutes))
          '${member.name} · 등록한 가능 시간 밖입니다.'
        else if (member.busy.any(
          (s) => s.$1.isBefore(end) && s.$2.isAfter(start),
        ))
          '${member.name} · 다른 예약과 겹칩니다.',
    ];
  }

  Future<void> submit([String? response]) async {
    if (!ready) return;
    Map<String, dynamic> body;
    if (responding) {
      body = {'response': response};
    } else {
      final start =
          BetaScheduleEditor.config(p.plan.target, input)['base_starts_at']
              as String;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이 시간으로 제안할까요?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduleStamp(start),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('진행 시간 $minutes분'),
                const SizedBox(height: 12),
                ...warnings().map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ),
                const Text(
                  '시간표와 달라도 제안할 수 있어요. 공대원이 제안을 보고 직접 응답합니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('제안 보내기'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true || !ready) return;
      final session = p.plan.find('sessions', 'session_id', sessionId!);
      body = {
        'targets': [
          {
            'session_id': sessionId,
            'expected_schedule_revision': session['schedule_revision'],
            'starts_at': start,
            'item_durations': durations,
          },
        ],
      };
    }
    setState(() {
      sending = true;
      error = null;
    });
    await widget.controller.scheduleCommand(p, body);
    if (!mounted || !active) return;
    final success = widget.controller.scheduleSuccess;
    requestKey =
        widget.controller.pendingRequestKey ??
        (success?.$1 != successBefore ? success?.$1 : null);
    observe();
    if (!closing) {
      setState(() {
        sending = false;
        error = widget.controller.failure;
      });
    }
  }

  Widget card(String title, List<Widget> children) =>
      RecruitmentSection(title: title, children: children);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(responding ? '일정 제안 확인' : '일정 제안')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!active)
            const Text('로그인 상태가 변경되었습니다. 상세 화면에서 다시 확인해 주세요.')
          else ...[
            if (responding)
              ...responseCards()
            else ...[
              card('현재 출발', [
                for (final s in p.plan.data['sessions'] as List)
                  if (s['state'] == 'confirmed')
                    Text(scheduleStamp(s['starts_at'])),
              ]),
              if (widget.comparison != null)
                card('공대원 시간표', [
                  ScheduleTimeline(
                    comparison: widget.comparison!,
                    weekday: input.weekday ?? widget.initialDay,
                    selected: widget.selected,
                    onTimeSelected: ready || requestKey == null && !sending
                        ? (minute) =>
                              setState(() => input = input.copy(minute: minute))
                        : null,
                  ),
                ]),
              card('제안할 출발 시간', [
                if (sessions.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: sessionId,
                    decoration: const InputDecoration(labelText: '변경할 일정'),
                    items: [
                      for (final s in sessions)
                        DropdownMenuItem(
                          value: s['session_id'] as String,
                          child: Text(scheduleStamp(s['starts_at'])),
                        ),
                    ],
                    onChanged: !sending && requestKey == null
                        ? (v) => setState(() => sessionId = v)
                        : null,
                  ),
                BetaScheduleEditor(
                  target: p.plan.target,
                  now: serverNow,
                  duration: minutes,
                  capacity: p.plan.data['app_capacity'] as int,
                  value: input,
                  showCoordination: false,
                  enabled: !sending && requestKey == null,
                  onChanged: (v) => setState(() => input = v),
                ),
                Text(
                  '진행 시간 $minutes분 · KST',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  '시간표 밖이나 다른 예약과 겹치는 시간도 제안할 수 있어요.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
              FilledButton.icon(
                onPressed: ready ? () => submit() : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('제안 내용 확인'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  recruitmentFailureMessage(error),
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (sending) const LinearProgressIndicator(),
            CycleCommandBanner(controller: widget.controller),
          ],
        ],
      ),
    ),
  );
  List<Widget> responseCards() {
    final proposal = p.plan.find('proposals', 'proposal_id', p.id!);
    final allowed =
        proposal['permissions']?['respond_proposal']?['allowed'] == true &&
        proposal['state'] == 'pending';
    return [
      card('현재 출발', [
        for (final s in p.plan.data['sessions'] as List)
          if ((proposal['target_session_ids'] as List).contains(
            s['session_id'],
          ))
            Text(scheduleStamp(s['starts_at'])),
      ]),
      card('새로 제안된 시간', [
        for (final set in proposal['proposed_sessions'] as List)
          for (final seg in set['segments'] as List)
            if (seg['state'] == 'planned')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${scheduleStamp(seg['starts_at'])} – ${scheduleStamp(seg['ends_at'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
        for (final vote in proposal['votes'] as List)
          Text(
            '동의 ${vote['accepted_count']} / 필요한 동의 ${vote['required_votes']} · 대상 ${vote['eligible_count']}명',
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 12),
        const Text(
          '등록한 가능 시간과 달라도 수락할 수 있어요. 수락해도 내 계정의 시간표는 바뀌지 않습니다.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '내 응답: ${switch (proposal['my_response']?['response']) {
            'accept' => '수락',
            'reject' => '거절',
            _ => '응답 대기',
          }}',
          style: const TextStyle(fontSize: 12),
        ),
      ]),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: ready && allowed ? () => submit('reject') : null,
              child: const Text('거절'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: ready && allowed ? () => submit('accept') : null,
              child: const Text('수락'),
            ),
          ),
        ],
      ),
    ];
  }
}
