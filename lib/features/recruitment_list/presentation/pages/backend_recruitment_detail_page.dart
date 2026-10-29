import '../widgets/cycle_action_dialog_route.dart';
import 'dart:async';
import 'schedule_comparison_page.dart';
import '../widgets/schedule_design.dart';
import '../widgets/recruitment_design.dart';
import '../../data/beta/beta_read.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import '../../../account/presentation/widgets/member_cycle_selector.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/backend_recruitment_detail_view_model.dart';
import '../widgets/recruitment_section.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../widgets/cycle_management_widgets.dart';
import '../widgets/cycle_schedule_widgets.dart';
import '../widgets/cycle_outcome_widgets.dart';
import '../widgets/cycle_resume_widgets.dart';
import '../widgets/cycle_member_action_widgets.dart';
import '../../data/membership_actions.dart';
import '../widgets/cycle_membership_widgets.dart';
import '../../data/membership_readers.dart';
import '../widgets/membership_record_view.dart';

class BackendRecruitmentDetailPage extends StatefulWidget {
  const BackendRecruitmentDetailPage({
    required this.gateway,
    required this.session,
    required this.roomId,
    required this.onLogin,
    required this.onCreateAnother,
    this.target,
    this.accessChanges,
    this.scopeKey,
    this.participation,
    this.reader,
    this.recordAnchor,
    super.key,
  });
  final RecruitmentGateway gateway;
  final AccountReadSession session;
  final String roomId;
  final String? target;
  final CycleParticipationController? participation;
  final MembershipReadGateway? reader;
  final MembershipRecordAnchor? recordAnchor;
  final Listenable? accessChanges;
  final String Function()? scopeKey;
  final VoidCallback onLogin, onCreateAnother;
  @override
  State<BackendRecruitmentDetailPage> createState() =>
      _BackendRecruitmentDetailPageState();
}

class _BackendRecruitmentDetailPageState
    extends State<BackendRecruitmentDetailPage>
    with WidgetsBindingObserver {
  late final BackendRecruitmentDetailViewModel m;
  int _mutationVersion = 0;
  String? _departureKey;
  String? _completionKey;
  String? _membershipKey;
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    m = BackendRecruitmentDetailViewModel(
      gateway: widget.gateway,
      session: widget.session,
      roomId: widget.roomId,
      target: widget.target,
      accessChanges: widget.accessChanges,
      scopeKey: widget.scopeKey,
      reader: widget.reader,
      recordAnchor: widget.recordAnchor,
      membershipGateway:
          widget.participation?.gateway is MembershipActionGateway
          ? widget.participation!.gateway as MembershipActionGateway
          : null,
    );
    _departureKey = widget.participation?.departureSuccess?.$1;
    _completionKey = widget.participation?.completionSuccess?.$1;
    _membershipKey = widget.participation?.membershipSuccess?.$1;
    _mutationVersion = widget.participation?.mutationVersion ?? 0;
    widget.participation?.addListener(_changed);
    unawaited(m.load());
  }

  void _changed() {
    if (_leaving || widget.recordAnchor != null) return;
    final c = widget.participation!;
    final membership = c.membershipSuccess;
    if (membership != null && membership.$1 != _membershipKey) {
      _membershipKey = membership.$1;
      final result = membership.$2;
      if (result.room == widget.roomId && result.view == m.target) {
        if (result.exitsTarget(result.view)) {
          _exitToTarget(c, result.view, membership.$1);
          return;
        }
        // Opposite-week effects preserve this screen but invalidate its menu.
        unawaited(m.load());
      }
    }
    final departure = c.departureSuccess;
    if (departure != null &&
        departure.$1 != _departureKey &&
        departure.$2 == widget.roomId &&
        departure.$3 == m.target) {
      _departureKey = departure.$1;
      _exitToTarget(c, departure.$3, departure.$1);
      return;
    }
    final completion = c.completionSuccess;
    if (completion != null &&
        completion.$1 != _completionKey &&
        completion.$2 == widget.roomId &&
        completion.$3 == m.target) {
      _completionKey = completion.$1;
      _exitToTarget(c, completion.$3, completion.$1);
      return;
    }
    if (m.readOnly || c.mutationVersion == _mutationVersion) return;
    _mutationVersion = c.mutationVersion;
    if (c.lastRoom == widget.roomId && c.lastTarget == m.target) {
      unawaited(m.load());
    }
  }

  void _exitToTarget(
    CycleParticipationController c,
    String target,
    String key,
  ) {
    _leaving = true;
    final binding = c.scopeKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (binding != c.scopeKey() || m.target != target) {
        _leaving = false;
        return;
      }
      // Imperative pushes keep the provider URI at the originating list.
      // Read the active leaf, including imperative pushes; a retained branch's
      // own GoRouterState alone could still describe an inactive detail.
      final router = GoRouter.of(context);
      final active = router.state;
      if (active.uri.path != '/recruitments/${widget.roomId}' ||
          active.pageKey != GoRouterState.of(context).pageKey ||
          ModalRoute.of(context)?.isCurrent != true) {
        _leaving = false;
        return;
      }
      closeCycleActionDialogs(context, widget.roomId, target);
      router.go(
        Uri(
          path: '/raid-status',
          queryParameters: {
            'target_cycle_key': target,
            'return_command_key': key,
          },
        ).toString(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.participation?.removeListener(_changed);
    m.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(m.load());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('모집 상세')),
        actions: [
          IconButton(
            onPressed: m.loading ? null : m.load,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!m.readOnly &&
              m.cycles != null &&
              m.target != null &&
              widget.session.isAuthenticated)
            Padding(
              padding: const EdgeInsets.all(12),
              child: MemberCycleSelector(
                cycles: m.cycles!,
                value: m.target!,
                onChanged: m.selectCycle,
              ),
            ),
          Expanded(
            child: !widget.session.isAuthenticated
                ? Center(
                    child: FilledButton(
                      onPressed: widget.onLogin,
                      child: const Text('로그인 후 확인'),
                    ),
                  )
                : m.profile != null && m.value == null
                ? _projectionDetail()
                : m.value == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: m.loading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.failure == 'ROOM_NOT_FOUND' ||
                                          m.failure ==
                                              'ROOM_MEMBERSHIP_REQUIRED'
                                      ? '현재 이 모집을 확인할 수 없습니다.'
                                      : recruitmentFailureMessage(m.failure),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: m.load,
                                  child: const Text('상세 다시 불러오기'),
                                ),
                                if (m.membershipMenu != null)
                                  _membershipActions(),
                                if (!m.readOnly &&
                                    widget.participation != null &&
                                    m.cycles != null &&
                                    m.target == m.cycles!.next.key) ...[
                                  for (final action in ['open', 'reopen'])
                                    TextButton(
                                      onPressed: () => showCycleManagement(
                                        context,
                                        widget.participation!,
                                        room: m.roomId,
                                        target: m.target!,
                                        action: action,
                                      ),
                                      child: Text(
                                        action == 'open'
                                            ? '다음 주도 함께하기'
                                            : '선택 주차 모집 재개',
                                      ),
                                    ),
                                  CycleCommandBanner(
                                    controller: widget.participation!,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  )
                : RefreshIndicator(onRefresh: m.load, child: _detail()),
          ),
        ],
      ),
    ),
  );

  String _raidLabel(Map item) {
    final r = m.catalog?.raids
        .where((r) => r.raidId == item['raid_id'])
        .firstOrNull;
    final d = r?.difficulties
        .where((d) => d.difficultyId == item['difficulty_id'])
        .firstOrNull;
    return '${r?.displayName ?? item['raid_id']} · ${d?.name ?? item['difficulty_id']}';
  }

  bool get _canManage =>
      !m.readOnly &&
      m.profile?.projection.readOnly != true &&
      widget.participation != null &&
      m.value?.room['state'] != 'ended';

  bool get _canLead =>
      _canManage &&
      m.value?.room['my_target_role'] == 'leader' &&
      (m.profile == null || m.profile!.projection.allowed('manage_target'));

  Widget _projectionDetail() {
    final p = m.profile!.projection;
    return RefreshIndicator(
      onRefresh: m.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          RecruitmentSection(
            title: p.target['title'] as String,
            children: [
              Text('대상 주차 · ${m.target}'),
              const SizedBox(height: 8),
              if (p.record != null)
                MembershipRecordView(record: p.record!, raidLabel: _raidLabel)
              else
                Text(membershipRecoveryLabel(p)),
              if (p.allowed('view_plan') &&
                  widget.reader != null &&
                  widget.participation != null)
                OutlinedButton(
                  onPressed: !m.loading
                      ? () => showCycleSchedule(
                          context,
                          widget.participation!,
                          room: m.roomId,
                          target: m.target!,
                          reader: widget.reader,
                          anchor: m.recordIdentity,
                          readOnly: m.readOnly,
                        )
                      : null,
                  child: const Text('일정 확인'),
                ),
            ],
          ),
          if (!m.readOnly && m.membershipMenu != null) _membershipActions(),
          if (!m.readOnly && widget.participation != null)
            CycleCommandBanner(controller: widget.participation!),
        ],
      ),
    );
  }

  Widget _detail() {
    final value = m.value!, room = value.room;
    final items = room['items'] as List;
    final combat = room['combat_requirement'] as Map;
    final group = room['group_id'];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (retainedGroupLabel(value.betaData) case final label?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label),
          ),
        if (!m.readOnly && value.betaData?['recruitment_identity'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '모집번호 : ${value.betaData!['recruitment_identity']['number']} & ${value.betaData!['recruitment_identity']['password']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        RecruitmentSection(
          title: value.title,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                RecruitmentBadge(
                  value.betaData != null
                      ? betaScheduleLabel(value.betaData!)
                      : room['state'] == 'ended'
                      ? '종료'
                      : value.starts.isEmpty
                      ? '출발 미정'
                      : '시간 확정',
                  success: value.starts.isNotEmpty,
                ),
                RecruitmentBadge(room['scope'] == 'group' ? '그룹 전용' : '전체 공개'),
                if (room['restricted'] == true) const RecruitmentBadge('진행 제한'),
              ],
            ),
            const SizedBox(height: 14),
            for (final raw in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  _raidLabel(raw as Map),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            Text(
              '숙련도 · ${recruitmentExperiences[room['experience_level']] ?? '제한 없음'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (group != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  m.groupName == null ? '그룹 연결 모집' : '연결 그룹 ${m.groupName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '참가 ${value.memberCount}/${value.capacity} · ${room['admission_mode'] == 'direct_join' ? '바로 가입' : '파티장 승인'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '딜러 ${DisplayNumberFormatter.whole(combat['dealer_min'], missing: '제한 없음')} / 서포터 ${DisplayNumberFormatter.whole(combat['support_min'], missing: '제한 없음')}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            if (_canLead)
              Wrap(
                spacing: 8,
                children: [
                  _managementButton('settings', '모집 조건 변경'),
                  _managementButton('common', '공통 정보 변경'),
                ],
              ),
          ],
        ),
        if (widget.participation != null)
          CycleCommandBanner(controller: widget.participation!),
        if (_canManage) ...[
          ListenableBuilder(
            listenable: widget.participation!,
            builder: (context, _) => Wrap(
              spacing: 8,
              children: [
                if (m.waitingForApproval && !m.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '공대장의 승인 대기중입니다.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (room['my_target_role'] == 'none' && !m.waitingForApproval)
                  FilledButton(
                    onPressed:
                        widget.participation!.canAct && m.canStartAdmission
                        ? () => showCycleAdmission(
                            context,
                            widget.participation!,
                            room: widget.roomId,
                            target: m.target!,
                            intent: room['admission_mode'] == 'direct_join'
                                ? 'join'
                                : 'apply',
                          )
                        : null,
                    child: Text(
                      room['admission_mode'] == 'direct_join'
                          ? '바로 참가'
                          : '참가 신청',
                    ),
                  ),
                if (_canLead) _managementButton('transfer', '공대장 위임'),
              ],
            ),
          ),
          if (_canLead)
            CycleRoomApplications(
              key: ValueKey((
                widget.roomId,
                m.target,
                room['target_generation'],
              )),
              controller: widget.participation!,
              room: widget.roomId,
              target: m.target!,
            ),
        ],
        ScheduleCard(
          title: m.target == null ? '이번 주 진행 일정' : '선택 주차 진행 일정',
          trailing:
              widget.participation != null &&
                  m.target != null &&
                  !m.readOnly &&
                  {'leader', 'member'}.contains(room['my_target_role'])
              ? Align(
                  alignment: Alignment.centerRight,
                  child: ListenableBuilder(
                    listenable: widget.participation!,
                    builder: (context, _) => ScheduleRefreshButton(
                      onPressed: widget.participation!.canAct
                          ? () async {
                              final c = widget.participation!,
                                  target = m.target!;
                              final success = await updateRoomTimetable(
                                context,
                                c,
                                m.roomId,
                                target,
                              );
                              if (!mounted ||
                                  !context.mounted ||
                                  (!success && c.failure == null)) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '내 일정을 갱신했습니다.'
                                        : recruitmentFailureMessage(c.failure),
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                )
              : null,
          children: [
            if (value.betaData != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ScheduleTag(betaScheduleLabel(value.betaData!)),
              ),
              const SizedBox(height: 18),
              Text(
                betaEffectiveStart(value.betaData) != null
                    ? '${_time(betaEffectiveStart(value.betaData)!)} 출발'
                    : betaScheduleLabel(value.betaData!),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (coordinationWaitMessage(m.readOnly ? null : value.betaData)
                  case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message, style: const TextStyle(fontSize: 12)),
                ),
              if (value.betaData!['beta_schedule'] != null)
                Text(
                  '앱 모집 마감 ${_time(DateTime.parse(value.betaData!['beta_schedule']['admission_deadline'] as String))}',
                  style: const TextStyle(fontSize: 11),
                ),
            ] else ...[
              if (value.starts.isEmpty)
                const Text(
                  '출발 미정 · 확정된 시간 예약은 없어요.',
                  style: TextStyle(fontSize: 13),
                ),
              for (final start in value.starts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _time(start),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '앱 모집 마감 ${_time(start.subtract(const Duration(minutes: 30)))}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            RecruitmentPrimaryButton(
              secondary: true,
              onPressed:
                  widget.participation != null &&
                      m.target != null &&
                      {'leader', 'member'}.contains(room['my_target_role'])
                  ? () => showCycleSchedule(
                      context,
                      widget.participation!,
                      room: m.roomId,
                      target: m.target!,
                      readOnly: room['state'] == 'ended',
                      reader: widget.reader,
                      anchor: widget.recordAnchor,
                    )
                  : null,
              label: room['state'] == 'ended' ? '일정·완료 기록 확인' : '공대원 일정 전체 확인',
            ),
            if (_canLead)
              TextButton(
                onPressed:
                    _canManage &&
                        m.target != null &&
                        room['my_target_role'] == 'leader'
                    ? () => showCycleScheduleCommand(
                        context,
                        widget.participation!,
                        room: m.roomId,
                        target: m.target!,
                        action: 'propose',
                      )
                    : null,
                child: const Text('일정 변경안'),
              ),
          ],
        ),
        if (_canManage &&
            m.target != null &&
            {'leader', 'member'}.contains(room['my_target_role']))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListenableBuilder(
              listenable: widget.participation!,
              builder: (context, _) => FilledButton.icon(
                onPressed: widget.participation!.canAct && !m.loading
                    ? () => showCycleAdmission(
                        context,
                        widget.participation!,
                        room: widget.roomId,
                        target: m.target!,
                        intent: 'change_character',
                      )
                    : null,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('내 캐릭터 변경'),
              ),
            ),
          ),
        RecruitmentSection(
          title: room['state'] == 'ended' ? '참가·완료 기록' : '파티 구성',
          children: [
            if (_canLead) _managementButton('formation', '파티 편성 조정'),
            for (final member in value.members) _member(member, group != null),
          ],
        ),
        if (_canManage &&
            m.cycles != null &&
            m.target == m.cycles!.current.key &&
            m.cycles!.current.permissions['complete']?.allowed == true &&
            {'leader', 'member'}.contains(room['my_target_role']))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CycleOutcomeActions(
              showClosure: false,
              completeLabel: '주차 완료',
              isCurrent: () =>
                  mounted && m.target == m.cycles?.current.key && !m.loading,
              controller: widget.participation!,
              room: m.roomId,
              target: m.target!,
              current: m.cycles!.current.key,
              role: room['my_target_role'] as String,
              playable:
                  m.cycles!.find(m.target!)?.permissions['complete']?.allowed ==
                  true,
              continuation: room['continuation_enabled'] == true,
              raidLabel: _raidLabel,
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (_canManage && m.cycles != null && m.target != null)
              CycleResumeActions(
                controller: widget.participation!,
                room: m.roomId,
                target: m.target!,
                current: m.cycles!.current.key,
                role: room['my_target_role'] as String? ?? 'none',
                state: room['target_state'] as String? ?? '',
                continuation: room['continuation_enabled'] == true,
                playable:
                    m.cycles!
                        .find(m.target!)
                        ?.permissions['complete']
                        ?.allowed ==
                    true,
                raidLabel: _raidLabel,
              ),
            if (_canManage &&
                m.cycles != null &&
                m.target == m.cycles!.current.key &&
                m.cycles!.current.permissions['complete']?.allowed == true &&
                room['continuation_enabled'] == true &&
                value.hasMultipleScheduledDays &&
                {'leader', 'member'}.contains(room['my_target_role']))
              CycleOutcomeActions(
                showCompletion: false,
                controller: widget.participation!,
                room: m.roomId,
                target: m.target!,
                current: m.cycles!.current.key,
                role: room['my_target_role'] as String,
                playable: true,
                continuation: true,
                raidLabel: _raidLabel,
              ),
          ],
        ),
        if (_canManage)
          RecruitmentSection(
            title: m.cycles != null && m.target == m.cycles!.next.key
                ? '다음 주 참가 예정'
                : '다음 주 함께하기',
            children: [
              Text(
                m.cycles != null && m.target == m.cycles!.next.key
                    ? '선택 주차 수요일 10시부터 완료할 수 있어요.'
                    : '다음 주 참가는 별도로 선택합니다.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              if (_canManage && m.cycles != null && m.target != null)
                CycleManagementActions(
                  controller: widget.participation!,
                  room: m.roomId,
                  target: m.target!,
                  current: m.cycles!.current.key,
                  next: m.cycles!.next.key,
                  role: room['my_target_role'] as String? ?? 'none',
                  nextCycleOpen: m.target == m.cycles!.next.key
                      ? room['target_state'] == 'open'
                      : room['continuation_enabled'] == true,
                  nextParticipationAvailable: m.nextParticipationAvailable,
                ),
            ],
          ),
        if (m.membershipMenu != null) _membershipActions(),
        if (m.membershipFailure != null &&
            {'leader', 'member'}.contains(room['my_target_role']))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('탈퇴·해산 메뉴를 불러오지 못했습니다. 새로고침해 주세요.'),
          ),
        if (m.loading) const LinearProgressIndicator(minHeight: 2),
        TextButton(
          onPressed: () {
            widget.onCreateAnother();
            context.push(
              '/recruitments/create${m.target == null ? '' : '?target_cycle_key=${m.target}'}',
            );
          },
          child: const Text('새 모집 만들기'),
        ),
      ],
    );
  }

  Widget _managementButton(String action, String label) => ListenableBuilder(
    listenable: widget.participation!,
    builder: (context, _) => OutlinedButton(
      onPressed: widget.participation!.canAct && !m.loading && m.target != null
          ? () => showCycleManagement(
              context,
              widget.participation!,
              room: m.roomId,
              target: m.target!,
              action: action,
            )
          : null,
      child: Text(label),
    ),
  );

  Widget _membershipActions() {
    final menu = m.membershipMenu!;
    return CycleMembershipActions(
      controller: widget.participation!,
      menu: menu,
      isCurrent: () =>
          mounted &&
          !m.loading &&
          m.target == menu.view &&
          identical(m.membershipMenu, menu),
    );
  }

  Widget _member(Map<String, dynamic> member, bool groupLinked) {
    final c = member['character'] as Map?;
    final display = c?['display'] as Map?;
    final name = display?['character_name'] as String? ?? '캐릭터 미확인';
    final role = c?['selected_role'] == 'support' ? '서포터' : '딜러';
    final leader = member['room_role'] == 'leader';
    final comparison = member['comparison'] as Map?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valueSlot(member),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name${member['is_me'] == true ? ' · 나' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$role${leader ? ' · 공대장' : ''}${display?['class_name'] == null ? '' : ' · ${display!['class_name']}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '아이템레벨 ${display?['item_level'] ?? '확인 필요'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (comparison != null)
                  Text(
                    '전투력 ${DisplayNumberFormatter.whole(comparison['actual'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (member['status'] == 'needs_review')
                  const Text(
                    '캐릭터 상태 확인 필요',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
              ],
            ),
          ),
          if (groupLinked)
            RecruitmentBadge(member['group_member'] == true ? '그룹원' : '비그룹'),
          if (_canManage &&
              m.target != null &&
              _canLead &&
              member['is_me'] == false &&
              member['room_role'] == 'member' &&
              m.value!.cycleMemberIds.containsKey(member['membership_id']))
            ListenableBuilder(
              listenable: widget.participation!,
              builder: (context, _) => IconButton(
                tooltip: '$name님 내보내기',
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: widget.participation!.canAct && !m.loading
                    ? () {
                        final target = m.target!;
                        unawaited(
                          showMemberRemoval(
                            context,
                            widget.participation!,
                            room: m.roomId,
                            target: target,
                            membership: member['membership_id'] as String,
                            member: m
                                .value!
                                .cycleMemberIds[member['membership_id']]!,
                            isCurrent: () => mounted && m.target == target,
                          ),
                        );
                      }
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String valueSlot(Map<String, dynamic> member) {
    if (m.value?.targetKey == null) return '자리 미정';
    final ids = (member['assignments'] as List)
        .map((a) => a['assignment_id'])
        .toSet();
    final slots = m.value!.formation
        .where(
          (s) => s['assignment_id'] != null && ids.contains(s['assignment_id']),
        )
        .toList();
    final labels = slots.map((s) {
      final item = (m.value!.room['items'] as List)
          .where((i) => i['round_id'] == s['round_id'])
          .firstOrNull;
      final size = item?['game_party_size'];
      return size == 8
          ? '${s['party_no']}-${s['slot_no']}'
          : size == 4
          ? '${s['slot_no']}'
          : '자리 미정';
    }).toSet();
    return labels.length == 1 ? labels.single : '자리 미정';
  }

  String _time(DateTime utc) {
    final kst = utc.toUtc().add(const Duration(hours: 9));
    const days = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    return '${days[kst.weekday]} ${kst.month}.${kst.day} ${minuteClock(kst.hour * 60 + kst.minute)}';
  }
}
