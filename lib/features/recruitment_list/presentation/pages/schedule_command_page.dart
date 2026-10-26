import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/cycle_schedule.dart';
import '../../domain/beta_schedule_draft.dart';
import '../../domain/schedule_comparison.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/beta_schedule_editor.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../widgets/schedule_design.dart';
import '../widgets/recruitment_design.dart';
import '../../domain/policies/recruitment_start_policy.dart';
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
  bool sending = false, closing = false, reviewing = false;
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
        minute:
            widget.initialMinute ??
            List.generate(288, (i) => i * 5)
                .where((m) => allowed(widget.initialDay, m))
                .where((m) => m >= 1200)
                .firstOrNull ??
            List.generate(
              288,
              (i) => i * 5,
            ).where((m) => allowed(widget.initialDay, m)).firstOrNull,
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
      if (!reviewing || !mounted || !ready) return;
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
      ScheduleCard(title: title, children: children);
  DateTime date(int day) => const RecruitmentStartPolicy().dateForDay(
    serverNow,
    day,
    targetCycleKey: p.plan.target,
  );
  bool allowed(int day, int minute) => const RecruitmentStartPolicy().allows(
    now: serverNow,
    weekday: day,
    minute: minute,
    durationMinutes: minutes,
    targetCycleKey: p.plan.target,
    precision: p.plan.betaData == null
        ? StartTimePrecision.fiveMinutes
        : StartTimePrecision.minute,
  );
  String get proposedStart =>
      BetaScheduleEditor.config(p.plan.target, input)['base_starts_at']
          as String;
  Widget currentCard() => card('현재 출발 약속', [
    for (final s in p.plan.data['sessions'] as List)
      if (s['state'] != 'cancelled' &&
          (!responding ||
              (p.plan.find(
                        'proposals',
                        'proposal_id',
                        p.id!,
                      )['target_session_ids']
                      as List)
                  .contains(s['session_id'])))
        Text(
          scheduleStamp(s['starts_at']),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
  ]);
  Widget footer() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Expanded(
          child: ScheduleAction(
            reviewing ? '시간 다시 고르기' : '취소',
            secondary: true,
            onPressed: sending
                ? null
                : () => reviewing
                      ? setState(() => reviewing = false)
                      : Navigator.maybePop(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: reviewing ? 1 : 2,
          child: ScheduleAction(
            reviewing ? '제안 보내기' : '제안 내용 확인',
            onPressed: ready
                ? () => reviewing ? submit() : setState(() => reviewing = true)
                : null,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !reviewing || closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && reviewing && !closing) {
          setState(() => reviewing = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leadingWidth: 36,
          titleSpacing: 0,
          leading: reviewing
              ? BackButton(onPressed: () => setState(() => reviewing = false))
              : null,
          title: Text(
            responding
                ? '일정 제안 확인'
                : reviewing
                ? '제안 내용 확인'
                : '일정 제안',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        bottomNavigationBar: active && !responding
            ? SafeArea(child: footer())
            : null,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!active)
              const Text('로그인 상태가 변경되었습니다. 상세 화면에서 다시 확인해 주세요.')
            else ...[
              Text(
                scheduleWeekLabel(
                  p.plan.target,
                  p.plan.scope['server_now'] as String?,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (responding)
                ...responseCards()
              else ...[
                if (!reviewing) ...[
                  ScheduleDaySelector(
                    target: p.plan.target,
                    value: input.weekday ?? widget.initialDay,
                    onChanged: !sending && requestKey == null
                        ? (day) =>
                              setState(() => input = input.copy(weekday: day))
                        : null,
                    allowed: (day) => List.generate(
                      288,
                      (i) => i * 5,
                    ).any((minute) => allowed(day, minute)),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.comparison != null)
                  ScheduleCard(
                    title:
                        '${date(input.weekday ?? widget.initialDay).month}월 ${date(input.weekday ?? widget.initialDay).day}일 ${' 월화수목금토일'[input.weekday ?? widget.initialDay]}요일',
                    trailing: input.minute == null
                        ? null
                        : ScheduleTag('선택 ${clock(input.minute!)}'),
                    children: [
                      ScheduleTimeline(
                        comparison: widget.comparison!,
                        weekday: input.weekday ?? widget.initialDay,
                        selected: widget.selected,
                        selectedMinute: input.minute,
                        onTimeSelected:
                            !reviewing &&
                                active &&
                                requestKey == null &&
                                !sending
                            ? (minute) => setState(
                                () => input = input.copy(minute: minute),
                              )
                            : null,
                      ),
                      if (reviewing)
                        Text(
                          '공대원 ${widget.selected.length}명 기준으로 비교 중',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                if (reviewing) ...[
                  card('이 일정으로 제안할까요?', [
                    Text(
                      scheduleStamp(proposedStart),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final s in p.plan.data['sessions'] as List)
                      if (s['session_id'] == sessionId)
                        Text(
                          '${scheduleStamp(s['starts_at'])} → ${scheduleStamp(proposedStart)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    const SizedBox(height: 8),
                    Text(
                      '예상 진행 시간 $minutes분',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...warningWidgets(),
                    const Text(
                      '공대원은 시간표와 달라도 참가할 수 있어요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ]),
                ] else ...[
                  card('제안할 일정', [
                    Text(
                      '${date(input.weekday ?? widget.initialDay).month}월 ${date(input.weekday ?? widget.initialDay).day}일 ${' 월화수목금토일'[input.weekday ?? widget.initialDay]}요일',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    _ScheduleTimeWheels(
                      value: input.minute,
                      step: p.plan.betaData == null ? 5 : 1,
                      enabled: !sending && requestKey == null,
                      allowed: (m) =>
                          allowed(input.weekday ?? widget.initialDay, m),
                      onChanged: (minute) =>
                          setState(() => input = input.copy(minute: minute)),
                    ),
                    const SizedBox(height: 12),
                    if (input.minute != null &&
                        !ready &&
                        requestKey == null &&
                        !sending)
                      const Text(
                        '선택한 시간에는 출발할 수 없어요. 다른 시간을 골라 주세요.',
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ...warningWidgets(),
                    Text(
                      '예상 진행 시간 $minutes분 · 시간표 밖이어도 제안할 수 있어요.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ]),
                ],
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
    ),
  );
  List<Widget> warningWidgets() => [
    if (warnings().isNotEmpty)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final warning in warnings())
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  warning,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9C5D13),
                  ),
                ),
              ),
          ],
        ),
      ),
  ];
  List<Widget> responseCards() {
    final proposal = p.plan.find('proposals', 'proposal_id', p.id!);
    final allowed =
        proposal['permissions']?['respond_proposal']?['allowed'] == true &&
        proposal['state'] == 'pending';
    return [
      currentCard(),
      ScheduleCard(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: ScheduleTag('일정 제안'),
          ),
          const SizedBox(height: 20),
          const Text(
            '새로 제안된 시간',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final set in proposal['proposed_sessions'] as List)
            for (final seg in set['segments'] as List)
              if (seg['state'] == 'planned') ...[
                Text(
                  '${scheduleStamp(seg['starts_at'])} 출발',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${seg['duration_minutes'] == null ? '진행 시간 정보 없음' : '예상 진행 ${seg['duration_minutes']}분'} · 종료 ${scheduleStamp(seg['ends_at'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
          const SizedBox(height: 24),
          const ScheduleTag('내 시간표 밖이어도 참가할 수 있다면 수락해 주세요.', warning: true),
          const SizedBox(height: 24),
          for (final vote in proposal['votes'] as List)
            Text(
              '동의 ${vote['accepted_count']} / 필요한 동의 ${vote['required_votes']} · 대상 ${vote['eligible_count']}명',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '내 응답: ${switch (proposal['my_response']?['response']) {
              'accept' => '수락',
              'reject' => '거절',
              _ => '응답 대기',
            }}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: RecruitmentPrimaryButton(
                  label: '어려워요',
                  secondary: true,
                  onPressed: ready && allowed ? () => submit('reject') : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RecruitmentPrimaryButton(
                  label: '참가할게요',
                  onPressed: ready && allowed ? () => submit('accept') : null,
                ),
              ),
            ],
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Text(
          '수락해도 내 계정 시간표는 바뀌지 않아요.\n시간표와 달라도 직접 동의할 수 있어요.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    ];
  }
}

class _ScheduleTimeWheels extends StatefulWidget {
  const _ScheduleTimeWheels({
    required this.value,
    required this.step,
    required this.enabled,
    required this.allowed,
    required this.onChanged,
  });
  final int? value;
  final int step;
  final bool enabled;
  final bool Function(int) allowed;
  final ValueChanged<int> onChanged;
  @override
  State<_ScheduleTimeWheels> createState() => _ScheduleTimeWheelsState();
}

class _ScheduleTimeWheelsState extends State<_ScheduleTimeWheels> {
  late final FixedExtentScrollController hours, minutes;
  bool syncing = false;
  @override
  void initState() {
    super.initState();
    final m = widget.value ?? 1200;
    hours = FixedExtentScrollController(initialItem: m ~/ 60);
    minutes = FixedExtentScrollController(initialItem: m % 60 ~/ widget.step);
  }

  @override
  void didUpdateWidget(covariant _ScheduleTimeWheels old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final m = widget.value ?? 1200;
        syncing = true;
        if (hours.hasClients && hours.selectedItem != m ~/ 60) {
          hours.jumpToItem(m ~/ 60);
        }
        if (minutes.hasClients &&
            minutes.selectedItem != m % 60 ~/ widget.step) {
          minutes.jumpToItem(m % 60 ~/ widget.step);
        }
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    hours.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minute = widget.value ?? 1200;
    Widget wheel(bool isHour) => Expanded(
      child: Column(
        children: [
          Text(
            isHour ? '시' : '분',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController: isHour ? hours : minutes,
              itemExtent: 38,
              squeeze: 1.1,
              onSelectedItemChanged: widget.enabled
                  ? (i) {
                      final current = widget.value ?? 1200;
                      final next = isHour
                          ? i * 60 + current % 60
                          : current ~/ 60 * 60 + i * widget.step;
                      if (!syncing && next != widget.value) {
                        widget.onChanged(next);
                      }
                    }
                  : null,
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  color: recruitmentSelectionFill.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              children: [
                for (var i = 0; i < (isHour ? 24 : 60 ~/ widget.step); i++)
                  Center(
                    child: Text(
                      '${isHour ? i : (i * widget.step).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color:
                            widget.allowed(
                              isHour
                                  ? i * 60 + minute % 60
                                  : minute ~/ 60 * 60 + i * widget.step,
                            )
                            ? AppColors.primary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      height: 126,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AbsorbPointer(
        absorbing: !widget.enabled,
        child: Row(
          children: [
            wheel(true),
            const Text(
              ':',
              style: TextStyle(fontSize: 22, color: AppColors.primary),
            ),
            wheel(false),
          ],
        ),
      ),
    );
  }
}
