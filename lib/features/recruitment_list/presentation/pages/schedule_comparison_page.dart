import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/domain/play_availability.dart';
import '../../data/membership_readers.dart';
import '../../data/schedule_notice_store.dart';
import '../../domain/schedule_comparison.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/schedule_comparison_view_model.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../widgets/recruitment_section.dart';
import '../widgets/membership_record_view.dart';
import '../widgets/schedule_timeline.dart';
import 'schedule_command_page.dart';

Future<bool> showUnsetScheduleNotice(
  BuildContext context,
  CycleParticipationController controller, {
  ScheduleNoticeStore? store,
}) async {
  final binding = controller.scopeKey(), user = controller.session.userId;
  final scope =
      '${controller.commandTransport?.baseUrl() ?? binding.split('/$user/').first}/$user';
  final preferences = store ?? ScheduleNoticeStore();
  if (!await preferences.shouldShow(scope, controller.now())) return true;
  if (!context.mounted || binding != controller.scopeKey()) return false;
  var hide = false;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('가능 시간을 설정하지 않았어요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '시간표가 없으면 어느 시간에 출발이 확정돼도 참가할 수 있는 것으로 조율합니다. 가능한 시간이 정해져 있다면 내 계정에서 시간표를 설정해 주세요.',
              style: TextStyle(fontSize: 13),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('오늘은 다시 보지 않기', style: TextStyle(fontSize: 12)),
              value: hide,
              onChanged: (v) => setState(() => hide = v == true),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    ),
  );
  if (confirm != true || !context.mounted || binding != controller.scopeKey()) {
    return false;
  }
  try {
    await preferences.acknowledge(scope, controller.now(), hide: hide);
  } catch (_) {
    /* This preference does not block the command. */
  }
  return true;
}

/// Explicit copy of the saved personal timetable; never a room-specific editor.
Future<bool> updateRoomTimetable(
  BuildContext context,
  CycleParticipationController controller,
  String room,
  String target,
) async {
  final binding = controller.scopeKey(), old = controller.scheduleSuccess?.$1;
  final preview = await controller.schedulePreview(room, target, 'submission');
  if (!context.mounted || binding != controller.scopeKey() || preview == null) {
    return false;
  }
  if (preview.personal!.intervals.isEmpty &&
      !await showUnsetScheduleNotice(context, controller)) {
    return false;
  }
  if (!context.mounted || binding != controller.scopeKey()) return false;
  await controller.scheduleCommand(preview, const {});
  final success = controller.scheduleSuccess;
  return context.mounted &&
      binding == controller.scopeKey() &&
      success?.$1 != old &&
      success?.$2 == room &&
      success?.$3 == target;
}

class ScheduleComparisonPage extends StatefulWidget {
  const ScheduleComparisonPage({
    super.key,
    required this.controller,
    required this.room,
    required this.target,
    this.reader,
    this.anchor,
    this.readOnly = false,
    this.onSettings,
    this.onConfirm,
  });
  final CycleParticipationController controller;
  final String room, target;
  final MembershipReadGateway? reader;
  final MembershipRecordAnchor? anchor;
  final bool readOnly;
  final Future<void> Function(BuildContext)? onSettings;
  final Future<void> Function(BuildContext, String)? onConfirm;
  @override
  State<ScheduleComparisonPage> createState() => _ScheduleComparisonPageState();
}

class _ScheduleComparisonPageState extends State<ScheduleComparisonPage> {
  late final ScheduleComparisonViewModel model;
  bool noticeShown = false;
  @override
  void initState() {
    super.initState();
    model = ScheduleComparisonViewModel(
      controller: widget.controller,
      room: widget.room,
      target: widget.target,
      reader: widget.reader,
      anchor: widget.anchor,
      forceReadOnly: widget.readOnly,
    );
    unawaited(load());
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> load() async {
    await model.load();
    if (!mounted || !model.valid || model.readOnly) return;
    final mine = model.plan?.data['my_membership']?['cycle_member_id'];
    final row = model.comparison?.members
        .where((m) => m.id == mine)
        .firstOrNull;
    if (!noticeShown && row?.state == TimetableState.unset) {
      noticeShown = true;
      await showUnsetScheduleNotice(context, widget.controller);
    }
  }

  Future<void> propose({String? proposal}) async {
    final comparison = model.comparison, binding = widget.controller.scopeKey();
    final preview = await widget.controller.schedulePreview(
      widget.room,
      widget.target,
      proposal == null ? 'propose' : 'respond',
      id: proposal,
    );
    if (!mounted || binding != widget.controller.scopeKey()) return;
    if (preview == null) {
      setState(() => model.failure = widget.controller.failure);
      return;
    }
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleCommandPage(
          controller: widget.controller,
          preview: preview,
          comparison: comparison,
          selected: Set.unmodifiable(model.selected),
          initialDay: model.weekday,
        ),
      ),
    );
    if (mounted && success == true) await load();
  }

  Future<void> update() async {
    final success = await updateRoomTimetable(
      context,
      widget.controller,
      widget.room,
      widget.target,
    );
    if (!mounted) return;
    if (success) {
      await load();
    } else if (widget.controller.failure != null) {
      setState(() => model.failure = widget.controller.failure);
    }
  }

  Widget card(String title, List<Widget> children) =>
      RecruitmentSection(title: title, children: children);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final p = model.plan, comparison = model.comparison;
        final canEdit =
            model.valid &&
            !model.readOnly &&
            model.failure == null &&
            !model.loading &&
            widget.controller.canAct;
        final canPropose =
            canEdit &&
            p?.data['my_target_role'] == 'leader' &&
            (p!.data['sessions'] as List).any(
              (s) => s['permissions']?['propose_schedule']?['allowed'] == true,
            );
        return Scaffold(
          appBar: AppBar(
            title: const Text('공대원 일정'),
            actions: [
              IconButton(
                tooltip: '새로고침',
                onPressed: !model.loading && model.valid ? load : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.target} 주차 · KST',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (model.loading) const LinearProgressIndicator(),
              if (model.failure != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    recruitmentFailureMessage(model.failure),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (model.profile?.projection.record case final record?)
                card('본인 참가 기록', [MembershipRecordView(record: record)]),
              if (p == null &&
                  model.profile != null &&
                  model.profile!.projection.record == null)
                Text(membershipRecoveryLabel(model.profile!.projection)),
              if (p != null) ...[
                card('현재 출발', [
                  for (final session in p.data['sessions'] as List)
                    if (session['state'] != 'cancelled')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          scheduleStamp(session['starts_at']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  for (final participation
                      in p.data['my_participations'] as List) ...[
                    Text(
                      participation['confirmation_state'] == 'confirmed'
                          ? '일정 참가 확인됨'
                          : participation['confirmation_state'] ==
                                'confirmation_pending'
                          ? '일정 참가 미확인'
                          : '시간 미확정',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '내 예약: ${const {'active': '예약 중', 'partial': '일부 예약', 'released': '해제됨', 'none': '없음'}[participation['reservation_state']] ?? '정보 없음'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if ((participation['warnings'] as List).isNotEmpty)
                      Text(
                        (participation['warnings'] as List)
                            .map(
                              (v) => v == 'TIME_OVERLAP'
                                  ? '다른 예약과 겹침'
                                  : '제출한 가능 시간 밖',
                            )
                            .join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    if (widget.onConfirm != null &&
                        !model.readOnly &&
                        participation['permissions']?['confirm_participation']?['allowed'] ==
                            true)
                      OutlinedButton(
                        onPressed: canEdit
                            ? () async {
                                await widget.onConfirm!(
                                  context,
                                  participation['session_id'] as String,
                                );
                                if (mounted) await load();
                              }
                            : null,
                        child: const Text('이 일정 참가 확인'),
                      ),
                  ],
                ]),
                if (comparison != null) ...[
                  card('가능한 시간 비교', [
                    Text(
                      '${comparison.date(model.weekday).month}/${comparison.date(model.weekday).day}(${' 월화수목금토일'[model.weekday]})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final day in playWeekdays)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Semantics(
                                selected: model.weekday == day,
                                button: true,
                                label: '${' 월화수목금토일'[day]}요일',
                                child: Material(
                                  color: model.weekday == day
                                      ? AppColors.primarySubtle
                                      : AppColors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: model.weekday == day
                                          ? AppColors.primary
                                          : AppColors.outline,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey('schedule-day-$day'),
                                    onTap: !model.loading
                                        ? () => model.selectDay(day)
                                        : null,
                                    child: SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: Text(
                                          ' 월화수목금토일'[day],
                                          style: TextStyle(
                                            color: model.weekday == day
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ScheduleTimeline(
                      comparison: comparison,
                      weekday: model.weekday,
                      selected: Set.unmodifiable(model.selected),
                    ),
                  ]),
                  card('비교할 공대원', [
                    const Text(
                      '체크는 시간 비교에만 사용돼요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final member in comparison.members)
                            SizedBox(
                              width: (box.maxWidth - 8) / 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: model.selected.contains(member.id),
                                  onChanged: !model.loading
                                      ? (v) =>
                                            model.toggle(member.id, v == true)
                                      : null,
                                  title: Text(
                                    member.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  ...myTimetable(),
                ],
                if (canPropose)
                  FilledButton.icon(
                    onPressed: () => propose(),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('일정 제안하기'),
                  ),
                if (widget.onSettings != null &&
                    p.data['permissions']?['edit_schedule_groups']?['allowed'] ==
                        true)
                  OutlinedButton(
                    onPressed: canEdit
                        ? () async {
                            await widget.onSettings!(context);
                            if (mounted) await load();
                          }
                        : null,
                    child: const Text('자동 조율 설정'),
                  ),
                for (final proposal in p.data['proposals'] as List)
                  if (proposal['state'] == 'pending')
                    card('진행 중인 일정 제안', [
                      for (final proposed
                          in proposal['proposed_sessions'] as List)
                        for (final segment in proposed['segments'] as List)
                          if (segment['state'] == 'planned')
                            Text(scheduleStamp(segment['starts_at'])),
                      for (final vote in proposal['votes'] as List)
                        Text(
                          '동의 ${vote['accepted_count']} / 필요한 동의 ${vote['required_votes']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (!model.readOnly &&
                          proposal['permissions']?['respond_proposal']?['allowed'] ==
                              true)
                        OutlinedButton(
                          onPressed: canEdit
                              ? () => propose(
                                  proposal: proposal['proposal_id'] as String,
                                )
                              : null,
                          child: const Text('제안 확인 · 응답'),
                        ),
                    ]),
              ],
              CycleCommandBanner(controller: widget.controller),
            ],
          ),
        );
      },
    ),
  );
  List<Widget> myTimetable() {
    final mine = model.plan?.data['my_membership']?['cycle_member_id'];
    final row = model.comparison?.members
        .where((m) => m.id == mine)
        .firstOrNull;
    if (row == null) return [];
    return [
      RecruitmentSection(
        title: '내 레이드 가능 시간',
        trailing: OutlinedButton.icon(
          onPressed:
              !model.readOnly &&
                  model.failure == null &&
                  !model.loading &&
                  widget.controller.canAct
              ? update
              : null,
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('내 일정 갱신'),
        ),
        children: [
          const Text(
            '내 계정에서 가져온 시간표예요. 수정은 내 계정에서 해 주세요.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (row.state == TimetableState.unset)
            const Text(
              '시간 미설정 · 모든 시간에 참가 가능한 상태로 조율합니다.',
              style: TextStyle(fontSize: 12),
            )
          else if (row.state == TimetableState.unavailable)
            const Text('시간표를 불러오지 못했습니다.', style: TextStyle(fontSize: 12))
          else
            for (final day in playWeekdays)
              if (row.intervals.any((r) => r.weekday == day))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${' 월화수목금토일'[day]}요일',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.intervals
                              .where((r) => r.weekday == day)
                              .map(
                                (r) =>
                                    '${clock(r.start!)} – ${r.endDayOffset == 1 ? '다음 날 ' : ''}${clock(r.end!)}',
                              )
                              .join('\n'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    ];
  }
}
