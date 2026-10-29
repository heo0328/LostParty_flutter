import 'dart:async';
import '../../data/beta/beta_read.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../data/cycle_read_repository.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/cycle_search_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../widgets/recruitment_design.dart';
import 'recruitment_filter_page.dart';

class CycleRecruitmentListPage extends StatefulWidget {
  const CycleRecruitmentListPage({
    required this.gateway,
    required this.session,
    required this.changes,
    required this.scopeKey,
    required this.mutations,
    required this.onRoom,
    required this.onCreate,
    required this.onLogin,
    this.groupChanges,
    super.key,
  });
  final CycleInteractionGateway gateway;
  final AccountReadSession session;
  final Listenable changes;
  final String Function() scopeKey;
  final CycleParticipationController mutations;
  final void Function(String, String) onRoom;
  final void Function(String?) onCreate;
  final VoidCallback onLogin;
  final Listenable? groupChanges;
  @override
  State<CycleRecruitmentListPage> createState() =>
      _CycleRecruitmentListPageState();
}

class _CycleRecruitmentListPageState extends State<CycleRecruitmentListPage>
    with WidgetsBindingObserver {
  late final CycleSearchViewModel m;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    m = CycleSearchViewModel(
      groupChanges: widget.groupChanges,
      gateway: widget.gateway,
      session: widget.session,
      changes: widget.changes,
      scopeKey: widget.scopeKey,
      mutations: widget.mutations,
    );
    unawaited(m.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(m.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    m.dispose();
    super.dispose();
  }

  Set<T> toggle<T>(Set<T> values, T value) {
    final next = {...values};
    if (!next.add(value)) next.remove(value);
    return next;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('레이드 모집')),
        actions: [
          IconButton(
            onPressed: m.loading ? null : m.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RecruitmentPrimaryButton(
            label: '+ 모집 만들기',
            onPressed: () => widget.onCreate(m.target),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: m.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (m.cycles != null)
              RecruitmentWeekTabs(
                cycles: m.cycles!,
                value: m.target,
                onChanged: m.selectTarget,
              ),
            const SizedBox(height: 16),
            RecruitmentDesignCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final entry in const {
                        'all': '전체',
                        'general': '일반',
                        'group_linked': '그룹',
                      }.entries)
                        TextButton(
                          onPressed: () => m.update(
                            m.filter.copy(
                              category: entry.key,
                              clearGroup: entry.key != 'group_linked',
                            ),
                          ),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: m.filter.category == entry.key
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: m.target == null || m.catalog == null
                          ? null
                          : () => openRecruitmentFilter(context, m),
                      child: const Text(
                        '레이드 · 난이도 · 숙련도  ⌄',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            RecruitmentDesignCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: m.target == null
                              ? null
                              : () => m.update(
                                  m.filter.copy(
                                    descending: !m.filter.descending,
                                  ),
                                ),
                          child: Text(
                            '참가인원 정렬 ${m.filter.descending ? '↓' : '↑'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: m.target == null
                            ? null
                            : () => showRecruitmentRemainingSlots(context, m),
                        child: Text(
                          m.filter.remaining.isEmpty
                              ? '남은 자리 전체'
                              : '남은 자리 ${(m.filter.remaining.toList()..sort()).join('·')}명',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  RecruitmentPrimaryButton(
                    label: '날짜 · 시간대 · 일정 상태 ⌄',
                    secondary: true,
                    onPressed: m.target == null || m.catalog == null
                        ? null
                        : () => openRecruitmentFilter(context, m),
                  ),
                ],
              ),
            ),
            CycleCommandBanner(controller: widget.mutations),
            if (!widget.session.isAuthenticated)
              Center(
                child: FilledButton(
                  onPressed: widget.onLogin,
                  child: const Text('로그인 후 모집 확인'),
                ),
              ),
            if (m.loading) const LinearProgressIndicator(),
            if (m.failure != null)
              Column(
                children: [
                  Text(recruitmentFailureMessage(m.failure)),
                  TextButton(
                    onPressed: m.refresh,
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            if (!m.loading &&
                !m.candidateLoading &&
                !m.groupLoading &&
                !m.selectionPending &&
                m.candidateFailure == null &&
                m.groupFailure == null &&
                m.failure == null &&
                m.rows.isEmpty &&
                widget.session.isAuthenticated)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Text('조건에 맞는 모집이 없습니다.', textAlign: TextAlign.center),
              ),
            for (final room in m.rows) _card(room),
            if (m.cursor != null)
              TextButton(
                onPressed: m.loading ? null : () => m.search(more: true),
                child: const Text('더 보기'),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _card(CycleRoomCard room) {
    String label(Map<String, dynamic> item) {
      final raid = m.catalog?.raids
          .where((r) => r.raidId == item['raid_id'])
          .firstOrNull;
      final diff = raid?.difficulties
          .where((d) => d.difficultyId == item['difficulty_id'])
          .firstOrNull;
      return '${raid?.displayName ?? item['raid_id']} · ${diff?.name ?? item['difficulty_id']}';
    }

    final leader = room.wire['leader_display'] as Map?;
    final schedule = room.betaData?['beta_schedule'] as Map?;
    final groupId = room.wire['group_id'] as String?;
    final groupName = retainedGroupLabel(room.betaData);
    final state = schedule?['coordination_state'];
    final effective =
        betaEffectiveStart(room.betaData) ?? room.starts.firstOrNull;
    String departure = '일정 정보 없음';
    if (effective != null) {
      final local = effective.add(const Duration(hours: 9));
      final suffix = state == 'coordinating' || state == 'base_committed'
          ? '출발 예정'
          : state == 'needs_review' || state == 'deadline_pending'
          ? '기본 약속'
          : '출발';
      departure =
          '${' 월화수목금토일'[local.weekday]} ${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $suffix';
    }
    final deadline = schedule?['admission_deadline'] as String?;
    String? extra;
    if (state == 'coordinating') {
      final needed =
          (schedule!['early_additional_members'] as int? ?? 0) + 1 - room.count;
      extra = needed > 0 ? '$needed명 더 모이면 조율' : '공통 시간 조율 중';
    } else if (deadline != null) {
      final time = DateTime.parse(
        deadline,
      ).toUtc().add(const Duration(hours: 9));
      extra =
          '모집 마감 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: room.canView ? () => widget.onRoom(room.id, m.target!) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (schedule != null || groupId != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: schedule == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: recruitmentSelectionFill,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    betaScheduleLabel(room.betaData!),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (groupId != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: recruitmentSelectionFill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '그룹',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                groupName ?? '그룹명 확인 불가',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                Text(
                  room.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${room.items.map(label).join(' · ')} / ${recruitmentExperiences[room.wire['experience_level']] ?? '제한 없음'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  departure,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '참가 ${room.count}/${room.capacity}${extra == null ? '' : ' · $extra'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${room.wire['admission_mode'] == 'direct_join' ? '바로 참가' : '공대장 승인'}${leader?['character_name'] == null ? '' : ' · ${leader!['character_name']}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
