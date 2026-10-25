import 'dart:async';
import '../pages/schedule_comparison_page.dart';
import '../pages/schedule_command_page.dart';
import '../../domain/beta_schedule_draft.dart';
import 'beta_schedule_editor.dart';
import 'package:flutter/material.dart';
import '../../../account/domain/play_availability.dart';
import '../../data/cycle_schedule.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../../data/membership_readers.dart';

String scheduleTime(Object? raw) {
  if (raw == null) return '미정';
  final d = DateTime.parse(raw as String).toUtc().add(const Duration(hours: 9));
  return '${d.month}/${d.day}(${playWeekdayLabels[d.weekday - 1]}) ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _proposalTime(Map session) {
  final segments =
      (session['segments'] as List)
          .where((s) => s['state'] == 'planned')
          .toList()
        ..sort(
          (a, b) =>
              (a['starts_at'] as String).compareTo(b['starts_at'] as String),
        );
  return segments.isEmpty
      ? '일정 미확인'
      : '${scheduleTime(segments.first['starts_at'])} – ${scheduleTime(segments.last['ends_at'])}';
}

String _rows(List rows) => rows.isEmpty
    ? '제출 구간 없음'
    : rows
          .map(
            (r) =>
                '${playWeekdayLabels[(r['weekday'] as int) - 1]} ${r['start']}–${r['end_day_offset'] == 1 ? '다음 날 ' : ''}${r['end']}',
          )
          .join('\n');
bool _allowed(Map value, String permission) =>
    (value['permissions'] as Map?)?[permission]?['allowed'] == true;

Future<void> showCycleSchedule(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  bool readOnly = false,
  MembershipReadGateway? reader,
  MembershipRecordAnchor? anchor,
}) async {
  if (reader == null
      ? !controller.canAct
      : !controller.session.isAuthenticated) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScheduleComparisonPage(
        controller: controller,
        room: room,
        target: target,
        readOnly: readOnly,
        reader: reader,
        anchor: anchor,
        onSettings: (ctx) => showCycleScheduleCommand(
          ctx,
          controller,
          room: room,
          target: target,
          action: 'groups',
        ),
        onConfirm: (ctx, session) => showCycleScheduleCommand(
          ctx,
          controller,
          room: room,
          target: target,
          action: 'confirm',
          id: session,
        ),
      ),
    ),
  );
}

Future<void> showCycleScheduleCommand(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String action,
  String? id,
}) async {
  if (!controller.canAct) return;
  final binding = controller.scopeKey();
  final preview = await controller.schedulePreview(
    room,
    target,
    action,
    id: id,
  );
  if (!context.mounted ||
      !controller.session.isAuthenticated ||
      binding != controller.scopeKey()) {
    return;
  }
  if (preview == null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 확인'),
        content: Text(recruitmentFailureMessage(controller.failure)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    return;
  }
  if ({'propose', 'respond'}.contains(action)) {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ScheduleCommandPage(controller: controller, preview: preview),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _ScheduleCommandDialog(controller: controller, preview: preview),
  );
}

class _ScheduleCommandDialog extends StatefulWidget {
  const _ScheduleCommandDialog({
    required this.controller,
    required this.preview,
  });
  final CycleParticipationController controller;
  final CycleSchedulePreview preview;
  @override
  State<_ScheduleCommandDialog> createState() => _ScheduleCommandDialogState();
}

class _ScheduleCommandDialogState extends State<_ScheduleCommandDialog> {
  late final String binding;
  late final List<Map<String, dynamic>> groups;
  final changes = <String, Map<String, dynamic>>{};
  String? alternative, error;
  String response = 'accept';
  bool earlyEnabled = false, immediateConsent = false;
  int additionalMembers = 1;
  final proposalInputs = <String, BetaScheduleInput>{};
  bool get beta => p.plan.betaData != null;
  int proposalDuration(Map<String, dynamic> value) =>
      (value['item_durations'] as List).fold<int>(
        0,
        (sum, v) => sum + (v['duration_minutes'] as int? ?? 0),
      );
  DateTime get serverNow => DateTime.parse(
    p.plan.scope['server_now'] as String,
  ).add(widget.controller.now().toUtc().difference(receivedAt));
  late final DateTime receivedAt;

  bool sending = false;
  CycleSchedulePreview get p => widget.preview;
  @override
  void initState() {
    super.initState();
    binding = widget.controller.scopeKey();
    receivedAt = widget.controller.now().toUtc();
    final schedule = p.plan.betaData?['beta_schedule'];
    earlyEnabled = schedule?['early_coordination_enabled'] == true;
    additionalMembers = schedule?['early_additional_members'] as int? ?? 1;
    groups = [
      for (final g in p.plan.data['schedule_groups'] as List)
        {
          'client_group_key': g['client_group_key'],
          'existing_group_id': g['group_id'],
          'expected_group_revision': g['revision'],
          'occurrence_mode': g['occurrence_mode'],
          'planning_mode': g['planning_mode'],
          'required': g['required'],
          'auto_confirm_additional_members':
              g['auto_confirm_additional_members'],
          'day_scope': g['day_scope'],
          'alternatives': [
            for (final a in g['alternatives'] as List)
              {
                'client_alternative_key': 'alt-${a['alternative_id']}',
                'existing_session_id': null,
                'expected_session_revision': null,
                'weekday': a['weekday'],
                'starts_local': a['starts_local'],
                'leader_latest_start_local': a['leader_latest_start_local'],
                'item_ids': List<String>.from(a['item_ids'] as List),
              },
          ],
        },
    ];
  }

  Map<String, dynamic> newAlternative() => {
    'client_alternative_key': 'new-${DateTime.now().microsecondsSinceEpoch}',
    'existing_session_id': null,
    'expected_session_revision': null,
    'weekday': 3,
    'starts_local': null,
    'leader_latest_start_local': null,
    'item_ids': [
      for (final i in p.plan.data['game_items'] as List) i['item_id'],
    ],
  };
  Future<void> clock(Map<String, dynamic> value, String key) async {
    final old = value[key] as String?;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: old == null ? 20 : int.parse(old.substring(0, 2)),
        minute: old == null ? 0 : int.parse(old.substring(3)),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen.minute % 5 != 0) {
      setState(() => error = '시각은 5분 단위로 선택해 주세요.');
      return;
    }
    setState(
      () => value[key] =
          '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> proposalTime(Map<String, dynamic> t) async {
    final old = DateTime.parse(
      t['starts_at'] as String,
    ).toUtc().add(const Duration(hours: 9));
    final first = DateTime.parse('${p.plan.target}T00:00:00Z');
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(old.year, old.month, old.day),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(
        first.year,
        first.month,
        first.day,
      ).add(const Duration(days: 7)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: old.hour, minute: old.minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    if (time.minute % 5 != 0) {
      setState(() => error = '시각은 5분 단위로 선택해 주세요.');
      return;
    }
    setState(
      () => t['starts_at'] = DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).subtract(const Duration(hours: 9)).toIso8601String(),
    );
  }

  Future<void> submit() async {
    setState(() {
      sending = true;
      error = null;
    });
    await widget.controller.scheduleCommand(p, {
      'groups': groups,
      if (beta && p.action == 'groups') ...{
        'early_coordination_enabled': earlyEnabled,
        'early_additional_members': earlyEnabled ? additionalMembers : null,
        'accept_immediate_confirmation': immediateConsent,
      },
      'targets': changes.values.toList(),
      'alternative_id': alternative,
      'response': response,
    });
    if (!mounted) return;
    if (widget.controller.failure == null || widget.controller.hasPending) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      sending = false;
      error = recruitmentFailureMessage(widget.controller.failure);
    });
  }

  Widget note(String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(v, style: const TextStyle(fontSize: 12)),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final active =
          widget.controller.session.isAuthenticated &&
          binding == widget.controller.scopeKey();
      final selectionReady =
          (p.action != 'groups' ||
              !beta ||
              !earlyEnabled ||
              immediateConsent) &&
          (p.action != 'propose' ||
              changes.isNotEmpty &&
                  (!beta ||
                      changes.entries.every(
                        (e) =>
                            proposalInputs[e.key] != null &&
                            BetaScheduleEditor.valid(
                              p.plan.target,
                              serverNow,
                              proposalDuration(e.value),
                              p.plan.data['app_capacity'] as int,
                              proposalInputs[e.key]!,
                            ),
                      ))) &&
          (p.action != 'select' ||
              ((p.extra == null || p.extra!.data['state'] == 'ready') &&
                  (alternative != null ||
                      p.plan.find(
                                'schedule_groups',
                                'group_id',
                                p.id!,
                              )['planning_mode'] ==
                              'coordinated' &&
                          p.plan.find(
                                'schedule_groups',
                                'group_id',
                                p.id!,
                              )['occurrence_mode'] ==
                              'one_of')));
      return AlertDialog(
        title: Text(
          const {
            'submission': '개인 시간표 가져오기',
            'confirm': '일정 참가 확인',
            'groups': '일정 설정',
            'select': '진행 후보 선택',
            'propose': '일정 변경안',
            'respond': '일정 변경 응답',
          }[p.action]!,
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!active)
                  note('로그인 상태가 변경되었습니다. 닫고 다시 확인해 주세요.')
                else ...[
                  note('${p.plan.target} 주차'),
                  if (p.action == 'submission') ...[
                    note(
                      p.personal!.exists
                          ? _rows(
                              p.personal!.intervals
                                  .map((r) => r.toJson())
                                  .toList(),
                            )
                          : '개인 시간표를 먼저 설정해 주세요.',
                    ),
                    note(
                      '이 방·주차의 제출표를 현재 개인 시간표로 바꿉니다. 이후 개인 시간표 변경은 다시 가져올 때 반영됩니다.',
                    ),
                    if ((p.plan.data['schedule_groups'] as List).any(
                      (g) => g['planning_mode'] == 'coordinated',
                    ))
                      note(
                        '시간 조율 일정은 설정 인원과 공통 시간 조건이 갖춰지면 자동 확정되고 해당 일정이 예약됩니다.',
                      ),
                  ],
                  if (p.action == 'confirm') ...[
                    note(
                      '${scheduleTime(p.plan.find('sessions', 'session_id', p.id!)['starts_at'])} – ${scheduleTime(p.plan.find('sessions', 'session_id', p.id!)['ends_at'])}',
                    ),
                    note('이 일정의 본인 참가와 시간 예약을 확인합니다.'),
                    for (final warning
                        in p.plan.find(
                              'my_participations',
                              'session_id',
                              p.id!,
                            )['warnings']
                            as List)
                      note(
                        warning == 'TIME_OVERLAP'
                            ? '다른 예약과 겹칩니다.'
                            : '제출한 가능 시간 밖입니다.',
                      ),
                  ],
                  if (p.action == 'groups' && beta) ...[
                    note('더 빠른 시간이 없으면 약속한 출발 시간에 진행합니다.'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '더 일찍 출발할 수 있으면 자동으로 조율',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: earlyEnabled,
                      onChanged: sending
                          ? null
                          : (v) => setState(() {
                              earlyEnabled = v;
                              immediateConsent = false;
                            }),
                    ),
                    if (earlyEnabled) ...[
                      DropdownButtonFormField<int>(
                        initialValue: additionalMembers,
                        decoration: const InputDecoration(
                          labelText: '공대장 외 추가 참가 인원',
                        ),
                        items: [
                          for (
                            var i = 1;
                            i < (p.plan.data['app_capacity'] as int);
                            i++
                          )
                            DropdownMenuItem(value: i, child: Text('$i명')),
                        ],
                        onChanged: sending
                            ? null
                            : (v) => setState(() {
                                additionalMembers = v!;
                                immediateConsent = false;
                              }),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          '조건이 맞으면 즉시 출발 시간이 확정되는 것에 동의합니다.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: immediateConsent,
                        onChanged: sending
                            ? null
                            : (v) =>
                                  setState(() => immediateConsent = v == true),
                      ),
                    ],
                    note('출발 날짜·시각을 바꾸려면 일정 변경안을 제안해 주세요.'),
                  ],
                  if (p.action == 'groups' && !beta) ...[
                    note(
                      '이미 확정된 일정은 변경안으로 조정합니다. 수동 일정 설정은 본인의 일정 참가 동의를 포함합니다.',
                    ),
                    for (final g in groups) ...groupFields(g),
                    TextButton(
                      onPressed: sending
                          ? null
                          : () => setState(
                              () => groups.add({
                                'client_group_key':
                                    'new-${DateTime.now().microsecondsSinceEpoch}',
                                'existing_group_id': null,
                                'expected_group_revision': null,
                                'occurrence_mode': 'one_of',
                                'planning_mode': 'manual',
                                'required': true,
                                'auto_confirm_additional_members': null,
                                'day_scope': 'selected_weekdays',
                                'alternatives': [newAlternative()],
                              }),
                            ),
                      child: const Text('일정 추가'),
                    ),
                  ],
                  if (p.action == 'select') ...[
                    if (p.extra != null)
                      note(
                        p.extra!.data['state'] == 'ready'
                            ? '공통 후보 ${scheduleTime(p.extra!.data['earliest_start'])} ~ ${scheduleTime(p.extra!.data['latest_start'])}'
                            : '현재 확정 가능한 공통 후보가 없습니다.',
                      ),
                    note('수동 후보 선택은 본인의 일정 참가 동의를 포함합니다.'),
                    DropdownButtonFormField<String>(
                      initialValue: alternative,
                      decoration: const InputDecoration(labelText: '진행 후보'),
                      items: [
                        if (p.plan.find(
                                  'schedule_groups',
                                  'group_id',
                                  p.id!,
                                )['planning_mode'] ==
                                'coordinated' &&
                            p.plan.find(
                                  'schedule_groups',
                                  'group_id',
                                  p.id!,
                                )['occurrence_mode'] ==
                                'one_of')
                          const DropdownMenuItem(
                            value: '',
                            child: Text('모든 후보에서 공통 시간 조율'),
                          ),
                        for (final a
                            in p.plan.find(
                                  'schedule_groups',
                                  'group_id',
                                  p.id!,
                                )['alternatives']
                                as List)
                          if (a['session_id'] == null)
                            DropdownMenuItem(
                              value: a['alternative_id'] as String,
                              child: Text(
                                a['starts_local'] == null
                                    ? '${playWeekdayLabels[(a['weekday'] as int) - 1]} 시간 조율'
                                    : scheduleTime(
                                        cycleScheduleStart(
                                          p.plan.target,
                                          a['weekday'] as int,
                                          a['starts_local'] as String,
                                        ).toIso8601String(),
                                      ),
                              ),
                            ),
                      ],
                      onChanged: sending
                          ? null
                          : (v) => setState(
                              () => alternative = v == '' ? null : v,
                            ),
                    ),
                  ],
                  if (p.action == 'propose') ...[
                    note('선택한 모든 일정의 변경안을 한 번에 제안합니다. 동의 전에는 기존 일정이 유지됩니다.'),
                    note(
                      '참가자가 여럿이면 제안자의 동의가 함께 기록됩니다. 혼자 참가한 일정은 제안 후 직접 동의해 주세요.',
                    ),
                    for (final s in p.plan.data['sessions'] as List)
                      if (_allowed(s as Map, 'propose_schedule')) ...[
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            scheduleTime(s['starts_at']),
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: changes.containsKey(s['session_id']),
                          onChanged: sending
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    final set = p.plan.find(
                                      'session_segments',
                                      'session_id',
                                      s['session_id'] as String,
                                    );
                                    proposalInputs[s['session_id'] as String] =
                                        const BetaScheduleInput();
                                    changes[s['session_id'] as String] = {
                                      'session_id': s['session_id'],
                                      'expected_schedule_revision':
                                          s['schedule_revision'],
                                      'starts_at': s['starts_at'],
                                      'item_durations': [
                                        for (final seg
                                            in set['segments'] as List)
                                          if (seg['state'] == 'planned')
                                            {
                                              'item_id': seg['item_id'],
                                              'duration_minutes':
                                                  seg['duration_minutes'],
                                            },
                                      ],
                                    };
                                  } else {
                                    changes.remove(s['session_id']);
                                  }
                                }),
                        ),
                        if (changes.containsKey(s['session_id'])) ...[
                          if (beta)
                            BetaScheduleEditor(
                              target: p.plan.target,
                              now: serverNow,
                              duration: proposalDuration(
                                changes[s['session_id']]!,
                              ),
                              capacity: p.plan.data['app_capacity'] as int,
                              value: proposalInputs[s['session_id']]!,
                              enabled: !sending,
                              showCoordination: false,
                              onChanged: (v) => setState(() {
                                proposalInputs[s['session_id'] as String] = v;
                                if (v.weekday != null && v.minute != null) {
                                  changes[s['session_id']]!['starts_at'] =
                                      BetaScheduleEditor.config(
                                        p.plan.target,
                                        v,
                                      )['base_starts_at'];
                                }
                              }),
                            ),
                          if (!beta)
                            TextButton(
                              onPressed: sending
                                  ? null
                                  : () =>
                                        proposalTime(changes[s['session_id']]!),
                              child: Text(
                                '제안 출발 ${scheduleTime(changes[s['session_id']]!['starts_at'])}',
                              ),
                            ),
                          for (final duration
                              in changes[s['session_id']]!['item_durations']
                                  as List)
                            TextFormField(
                              key: ValueKey(
                                '${s['session_id']}/${duration['item_id']}',
                              ),
                              initialValue:
                                  duration['duration_minutes']?.toString() ??
                                  '',
                              enabled: !sending,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    '레이드 ${(p.plan.data['game_items'] as List).indexWhere((i) => i['item_id'] == duration['item_id']) + 1} 진행시간(분)',
                                hintText: '비우면 난이도 기본값',
                              ),
                              onChanged: (v) => duration['duration_minutes'] =
                                  v.isEmpty ? null : int.tryParse(v) ?? -1,
                            ),
                        ],
                      ],
                  ],
                  if (p.action == 'respond') ...[
                    for (final t
                        in p.plan.find(
                              'proposals',
                              'proposal_id',
                              p.id!,
                            )['proposed_sessions']
                            as List)
                      note('제안 ${_proposalTime(t as Map)}'),
                    note(
                      '동의하면 대상 일정의 본인 참가 동의가 기록됩니다. 정족수가 충족되면 제안된 일정 전체가 적용됩니다.',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: response,
                      items: const [
                        DropdownMenuItem(value: 'accept', child: Text('동의')),
                        DropdownMenuItem(value: 'reject', child: Text('거절')),
                      ],
                      onChanged: sending
                          ? null
                          : (v) => setState(() => response = v!),
                    ),
                  ],
                ],
                if (error != null) note(error!),
                if (sending) const LinearProgressIndicator(),
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
                active &&
                    selectionReady &&
                    !sending &&
                    widget.controller.canAct &&
                    !(p.action == 'submission' && !p.personal!.exists)
                ? submit
                : null,
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
  List<Widget> groupFields(Map<String, dynamic> g) => [
    KeyedSubtree(
      key: ValueKey(g['client_group_key']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          DropdownButtonFormField<String>(
            key: ValueKey('${g['client_group_key']}/${g['occurrence_mode']}'),
            initialValue: g['occurrence_mode'] as String,
            decoration: const InputDecoration(labelText: '진행 방식'),
            items: const [
              DropdownMenuItem(value: 'one_of', child: Text('후보 중 1회')),
              DropdownMenuItem(value: 'each', child: Text('선택일마다 진행')),
            ],
            onChanged: sending
                ? null
                : (v) => setState(() => g['occurrence_mode'] = v),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('${g['client_group_key']}/${g['planning_mode']}'),
            initialValue: g['planning_mode'] as String,
            decoration: const InputDecoration(labelText: '출발 시간'),
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('직접 지정')),
              DropdownMenuItem(value: 'coordinated', child: Text('시간 조율')),
              DropdownMenuItem(value: 'unscheduled', child: Text('시간 미정')),
            ],
            onChanged: sending
                ? null
                : (v) => setState(() {
                    g['planning_mode'] = v;
                    g['auto_confirm_additional_members'] = v == 'coordinated'
                        ? (p.plan.data['app_capacity'] as int) - 1
                        : null;
                    if (v != 'coordinated') {
                      g['day_scope'] = 'selected_weekdays';
                    }
                    if ((g['alternatives'] as List).isEmpty &&
                        (v != 'coordinated' ||
                            g['day_scope'] == 'selected_weekdays')) {
                      (g['alternatives'] as List).add(newAlternative());
                    }
                    for (final a in g['alternatives'] as List) {
                      if (v != 'manual') a['starts_local'] = null;
                    }
                  }),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('필수 일정', style: TextStyle(fontSize: 12)),
            value: g['required'] as bool,
            onChanged: sending
                ? null
                : (v) => setState(() => g['required'] = v),
          ),
          if (g['planning_mode'] == 'coordinated') ...[
            DropdownButtonFormField<int>(
              initialValue: g['auto_confirm_additional_members'] as int?,
              decoration: const InputDecoration(labelText: '공대장 외 자동 확정 필요 인원'),
              items: [
                for (var i = 1; i < (p.plan.data['app_capacity'] as int); i++)
                  DropdownMenuItem(value: i, child: Text('$i명')),
              ],
              onChanged: sending
                  ? null
                  : (v) => setState(
                      () => g['auto_confirm_additional_members'] = v,
                    ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '선택 주차 전체에서 조율',
                style: TextStyle(fontSize: 12),
              ),
              value: g['day_scope'] == 'any_current_cycle',
              onChanged: sending
                  ? null
                  : (v) => setState(() {
                      g['day_scope'] = v == true
                          ? 'any_current_cycle'
                          : 'selected_weekdays';
                      if (v == true) {
                        g['occurrence_mode'] = 'one_of';
                        (g['alternatives'] as List).clear();
                      } else {
                        (g['alternatives'] as List).add(newAlternative());
                      }
                    }),
            ),
          ],
          for (final a in g['alternatives'] as List) ...[
            DropdownButtonFormField<int>(
              key: ValueKey(a['client_alternative_key']),
              initialValue: a['weekday'] as int,
              decoration: const InputDecoration(labelText: '요일'),
              items: [
                for (final day in playWeekdays)
                  DropdownMenuItem(
                    value: day,
                    child: Text(playWeekdayLabels[day - 1]),
                  ),
              ],
              onChanged: sending
                  ? null
                  : (v) => setState(() => a['weekday'] = v),
            ),
            if (g['planning_mode'] == 'manual')
              TextButton(
                onPressed: sending
                    ? null
                    : () => clock(a as Map<String, dynamic>, 'starts_local'),
                child: Text(
                  a['starts_local'] == null
                      ? '출발 선택'
                      : '출발 ${scheduleTime(cycleScheduleStart(p.plan.target, a['weekday'] as int, a['starts_local'] as String).toIso8601String())}',
                ),
              ),
            TextButton(
              onPressed: sending
                  ? null
                  : () => clock(
                      a as Map<String, dynamic>,
                      'leader_latest_start_local',
                    ),
              child: Text('출발 상한 ${a['leader_latest_start_local'] ?? '미정'}'),
            ),
            if (a['leader_latest_start_local'] != null)
              TextButton(
                onPressed: sending
                    ? null
                    : () =>
                          setState(() => a['leader_latest_start_local'] = null),
                child: const Text('상한 해제'),
              ),
            for (var i = 0; i < (a['item_ids'] as List).length; i++)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '레이드 ${(p.plan.data['game_items'] as List).indexWhere((item) => item['item_id'] == a['item_ids'][i]) + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: sending || i == 0
                        ? null
                        : () => setState(() {
                            final list = a['item_ids'] as List;
                            final item = list.removeAt(i);
                            list.insert(i - 1, item);
                          }),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    tooltip: '진행 순서 올리기',
                  ),
                ],
              ),
            TextButton(
              onPressed: sending
                  ? null
                  : () => setState(() => (g['alternatives'] as List).remove(a)),
              child: const Text('요일 후보 삭제'),
            ),
          ],
          if (g['day_scope'] == 'selected_weekdays')
            TextButton(
              onPressed: sending
                  ? null
                  : () => setState(
                      () => (g['alternatives'] as List).add(newAlternative()),
                    ),
              child: const Text('요일 후보 추가'),
            ),
          TextButton(
            onPressed: sending ? null : () => setState(() => groups.remove(g)),
            child: const Text('일정 삭제'),
          ),
        ],
      ),
    ),
  ];
}
