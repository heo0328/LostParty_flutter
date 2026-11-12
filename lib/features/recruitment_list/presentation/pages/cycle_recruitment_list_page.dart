import 'dart:async';
import 'dart:math' as math;
import '../../data/discovery_search.dart';
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
    this.detail,
    this.selectedRoom,
    this.onClearSelection,
    this.fullScreenChild = false,
    this.selectedTarget,
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
  final Widget? detail;
  final String? selectedRoom;
  final VoidCallback? onClearSelection;
  final bool fullScreenChild;
  final String? selectedTarget;
  @override
  State<CycleRecruitmentListPage> createState() =>
      _CycleRecruitmentListPageState();
}

class _CycleRecruitmentListPageState extends State<CycleRecruitmentListPage>
    with WidgetsBindingObserver {
  late final CycleSearchViewModel m;
  CycleSearchViewModel? _draft;
  final _weekDrafts = <String, CycleSearchViewModel>{};
  final _scroll = ScrollController();
  bool _filterOpen = false;
  double _bodyHeight = 0;
  double _bodyScale = 1;
  int _seenReset = 0;
  int _seenResult = 0;
  String? _applying;
  CycleSearchViewModel get edit => _draft ??= m.draft();
  bool get dirty =>
      _draft != null && edit.filter.signature != m.filter.signature;
  bool get canApply {
    if (!dirty ||
        m.loading ||
        edit.target == null ||
        edit.groupLoading ||
        edit.candidateLoading ||
        edit.selectionPending ||
        edit.groupFailure != null ||
        edit.candidateFailure != null) {
      return false;
    }
    try {
      edit.filter.body(edit.target!);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _changed() {
    if (!mounted) return;
    if (widget.selectedRoom != null &&
        (m.groupFailure == 'GROUP_NOT_FOUND' || !m.session.isAuthenticated)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClearSelection?.call();
      });
    }
    if (_draft?.target == null && m.target != null) {
      _draft?.dispose();
      _draft = null;
    }
    if (_seenReset != m.resetVersion || _seenResult != m.resultVersion) {
      final reset = _seenReset != m.resetVersion;
      _seenReset = m.resetVersion;
      _seenResult = m.resultVersion;
      final offset = reset
          ? 0.0
          : m.scrollOffsets[(m.target!, m.filter.signature)] ?? 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
    if (_applying != null &&
        !m.loading &&
        m.failure == null &&
        m.displayedSignature == _applying) {
      _applying = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
          widget.onClearSelection?.call();
        }
      });
    }
    setState(() {});
  }

  void _loadMore() {
    if (_scroll.hasClients &&
        m.target != null &&
        m.displayedSignature != null) {
      m.scrollOffsets[(m.target!, m.displayedSignature!)] = _scroll.offset;
    }
    if (_scroll.hasClients &&
        _scroll.position.extentAfter <= _scroll.position.viewportDimension &&
        m.cursor != null &&
        !m.loading &&
        m.failure == null) {
      unawaited(m.search(more: true));
    }
  }

  void _cancel() {
    if (m.target != null) _weekDrafts.remove(m.target);
    _draft?.dispose();
    _draft = null;
    setState(() {});
  }

  void _apply() {
    if (!canApply) return;
    final signature = edit.filter.signature;
    if (m.applyDraft(edit)) {
      _applying = signature;
      setState(() => _filterOpen = false);
      if (!m.loading && m.failure == null) _changed();
    }
  }

  void _quick({String? category, bool? descending}) {
    final changed = m.updateQuick(
      category: category,
      descending: descending,
      draft: _draft,
    );
    if (category == 'group_linked' && _draft != null && edit.groups.isEmpty) {
      unawaited(edit.loadGroups());
    }
    if (changed) _applying = m.filter.signature;
    if (!m.loading && m.failure == null) _changed();
    setState(() {});
  }

  void _resetDetails() {
    _cancel();
    final changed = m.resetDetails();
    if (changed) _applying = m.filter.signature;
    if (!m.loading && m.failure == null) _changed();
    setState(() {});
  }

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
    m.addListener(_changed);
    m.target = widget.selectedTarget;
    _scroll.addListener(_loadMore);
    if (!widget.fullScreenChild) unawaited(m.load());
  }

  @override
  void didUpdateWidget(covariant CycleRecruitmentListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = widget.selectedTarget;
    if (t != null && t != m.target && m.cycles?.find(t) != null) {
      if (m.target != null && _draft != null) _weekDrafts[m.target!] = _draft!;
      _draft = _weekDrafts[t];
      m.selectTarget(t);
    }
    if (oldWidget.fullScreenChild &&
        !widget.fullScreenChild &&
        m.target == null) {
      unawaited(m.load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !m.cacheFresh) {
      unawaited(m.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    m.removeListener(_changed);
    _draft?.dispose();
    for (final d in _weekDrafts.values.toSet()) {
      if (!identical(d, _draft)) d.dispose();
    }
    _scroll.dispose();
    m.dispose();
    super.dispose();
  }

  Set<T> toggle<T>(Set<T> values, T value) {
    final next = {...values};
    if (!next.add(value)) next.remove(value);
    return next;
  }

  Widget _filter() => RecruitmentFilterPage(
    key: ObjectKey(edit),
    model: m,
    draft: edit,
    embedded: true,
    onApply: _apply,
  );

  Future<void> _openFilter(bool wide) async {
    if (wide && _bodyHeight >= 320 * _bodyScale) {
      setState(() => _filterOpen = true);
    } else {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (ctx) => RecruitmentFilterPage(
            model: m,
            draft: edit,
            onApply: () {
              _apply();
              if (_applying != null || !dirty) Navigator.pop(ctx);
            },
          ),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  Widget _list(bool wide) => ListenableBuilder(
    listenable: edit,
    builder: (context, _) => RefreshIndicator(
      onRefresh: m.refresh,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in const {
                'all': '전체',
                'general': '일반',
                'group_linked': '그룹',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: m.filter.category == e.key,
                  onSelected: (_) => _quick(category: e.key),
                ),
              OutlinedButton.icon(
                onPressed: () => _openFilter(wide),
                icon: const Icon(Icons.tune),
                label: const Text('필터'),
              ),
              OutlinedButton.icon(
                onPressed: _resetDetails,
                icon: const Icon(Icons.restart_alt),
                label: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                m.totalCount == null ? '모집 목록' : '모집 ${m.totalCount}개',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                onPressed: () => _quick(descending: !m.filter.descending),
                icon: Icon(
                  m.filter.descending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 16,
                ),
                label: const Text('참가인원 정렬'),
              ),
            ],
          ),
          if (dirty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('필터조건 변경'),
                    OutlinedButton(onPressed: _cancel, child: const Text('취소')),
                    FilledButton(
                      onPressed: canApply ? _apply : null,
                      child: const Text('적용'),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in edit.filter.raids)
                InputChip(
                  label: Text(
                    m.catalog?.raids
                            .where((r) => r.raidId == id)
                            .firstOrNull
                            ?.displayName ??
                        id,
                  ),
                  onDeleted: () => edit.update(
                    edit.filter.copy(raids: {...edit.filter.raids}..remove(id)),
                  ),
                ),
              for (final id in edit.filter.difficulties)
                InputChip(
                  label: Text(
                    m.catalog?.raids
                            .expand((r) => r.difficulties)
                            .where((d) => d.difficultyId == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  ),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      difficulties: {...edit.filter.difficulties}..remove(id),
                    ),
                  ),
                ),
              for (final id in edit.filter.experiences)
                InputChip(
                  label: Text(recruitmentExperiences[id] ?? id),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      experiences: {...edit.filter.experiences}..remove(id),
                    ),
                  ),
                ),
              for (final n in edit.filter.remaining)
                InputChip(
                  label: Text('남은 자리 $n명'),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      remaining: {...edit.filter.remaining}..remove(n),
                    ),
                  ),
                ),
              if (edit.filter.departure.weekday case final int day)
                InputChip(
                  label: Text('${'월화수목금토일'[day - 1]}요일'),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      departure: edit.filter.departure.copy(clearDay: true),
                    ),
                  ),
                ),
              if (edit.filter.departure.timeEnabled)
                InputChip(
                  label: Text(
                    '${_time(edit.filter.departure.from)} ~ ${_time(edit.filter.departure.to)}',
                  ),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      departure: edit.filter.departure.copy(timeEnabled: false),
                    ),
                  ),
                ),
              for (final state in edit.filter.departure.groups)
                InputChip(
                  label: Text(state == 'confirmed' ? '출발 확정' : '조기 조율 중'),
                  onDeleted: () => edit.update(
                    edit.filter.copy(
                      departure: edit.filter.departure.copy(
                        groups: {...edit.filter.departure.groups}
                          ..remove(state),
                      ),
                    ),
                  ),
                ),
              for (final id in edit.filter.groupIds)
                InputChip(
                  label: Text(
                    edit.groups.where((g) => g.id == id).firstOrNull?.name ??
                        '그룹',
                  ),
                  onDeleted: () =>
                      edit.selectGroups({...edit.filter.groupIds}..remove(id)),
                ),
              if (edit.filter.members.isNotEmpty)
                InputChip(
                  label: Text('그룹원 ${edit.filter.members.length}명'),
                  onDeleted: () => edit.update(edit.filter.copy(members: {})),
                ),
            ],
          ),
          if (m.showingPrevious)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('이전 검색 결과입니다. 새 조건의 결과를 확인 중입니다.'),
            ),
          CycleCommandBanner(controller: widget.mutations),
          if (m.loading && !m.loadingMore) const LinearProgressIndicator(),
          if (m.failure != null && !m.loadingMore) _retry(false),
          if (m.groupFailure != null || m.candidateFailure != null)
            Column(
              children: [
                Text(
                  recruitmentFailureMessage(
                    m.groupFailure ?? m.candidateFailure,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openFilter(wide),
                  child: const Text('필터 조건 확인'),
                ),
              ],
            ),
          if (!m.loading &&
              m.failure == null &&
              m.groupFailure == null &&
              m.candidateFailure == null &&
              m.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('조건에 맞는 모집이 없습니다.'),
            ),
          for (final room in m.rows) _card(room),
          if (m.loadingMore) const Center(child: CircularProgressIndicator()),
          if (m.cursor != null && !m.loading)
            m.failure != null
                ? _retry(true)
                : OutlinedButton(
                    onPressed: () => m.search(more: true),
                    child: const Text('더 보기'),
                  ),
        ],
      ),
    ),
  );
  Widget _retry(bool more) => Column(
    children: [
      Text(recruitmentFailureMessage(m.failure)),
      OutlinedButton(
        onPressed: () => more ? m.search(more: true) : m.search(),
        child: const Text('재시도'),
      ),
    ],
  );
  String _time(int? minute) => minute == null
      ? '선택'
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (widget.fullScreenChild) {
        return widget.detail ?? const SizedBox.shrink();
      }
      final scale = math.max(
        1.0,
        MediaQuery.textScalerOf(context).scale(14) / 14,
      );
      final width = math.min(box.maxWidth, 1600.0);
      final wide = width >= 600 * scale && !widget.fullScreenChild;
      final tripleWidth = width >= 1100 * scale && !widget.fullScreenChild;
      final inner = width - 32;
      final filterWidth = (inner * .22).clamp(248 * scale, 320 * scale);
      final remaining = inner - (tripleWidth ? filterWidth + 16 : 0);
      final listWidth = tripleWidth
          ? ((remaining - 16) * .4).clamp(320 * scale, 480 * scale)
          : ((inner - 16) * .42).clamp(248 * scale, 340 * scale);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadMore();
        }
      });
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const OwnershipNoticeTitle(child: Text('레이드 모집')),
          actions: [
            IconButton(
              onPressed: m.loading ? null : m.refresh,
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
            if (wide)
              OutlinedButton(
                onPressed: () => widget.onCreate(m.target),
                child: const Text('+ 모집 만들기'),
              ),
          ],
        ),
        bottomNavigationBar: wide || widget.detail != null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RecruitmentPrimaryButton(
                    label: '+ 모집 만들기',
                    onPressed: () => widget.onCreate(m.target),
                  ),
                ),
              ),
        body: Center(
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                if (m.cycles != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: RecruitmentWeekTabs(
                      cycles: m.cycles!,
                      value: m.target,
                      onChanged: (t) {
                        if (m.target != null && _draft != null) {
                          _weekDrafts[m.target!] = _draft!;
                        }
                        _draft = _weekDrafts[t];
                        m.selectTarget(t);
                        if (widget.selectedRoom != null) {
                          widget.onRoom(widget.selectedRoom!, t);
                        }
                      },
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, body) {
                      _bodyHeight = body.maxHeight;
                      _bodyScale = scale;
                      final triple =
                          tripleWidth && body.maxHeight >= 320 * scale;
                      final currentListWidth = triple
                          ? listWidth
                          : ((inner - 16) * .42).clamp(
                              248 * scale,
                              340 * scale,
                            );
                      final detailLeft =
                          16 +
                          (triple ? filterWidth + 16 : 0) +
                          currentListWidth +
                          16;
                      return Stack(
                        children: [
                          Positioned(
                            left: 16,
                            top: 0,
                            bottom: 0,
                            width: filterWidth,
                            child: Offstage(
                              offstage: !triple,
                              child: _filter(),
                            ),
                          ),
                          Positioned(
                            left: wide
                                ? 16 + (triple ? filterWidth + 16 : 0)
                                : 0,
                            top: 0,
                            bottom: 0,
                            width: wide ? currentListWidth : width,
                            child: Offstage(
                              offstage: !wide && widget.detail != null,
                              child: _list(wide),
                            ),
                          ),
                          Positioned(
                            left: wide ? detailLeft : 0,
                            right: wide ? 16 : 0,
                            top: 0,
                            bottom: 0,
                            child: Offstage(
                              offstage: !wide && widget.detail == null,
                              child:
                                  widget.detail ??
                                  const Center(child: Text('모집을 선택해 주세요')),
                            ),
                          ),
                          if (_filterOpen &&
                              wide &&
                              !triple &&
                              body.maxHeight >= 320 * scale) ...[
                            Positioned.fill(
                              child: ModalBarrier(
                                dismissible: true,
                                onDismiss: () =>
                                    setState(() => _filterOpen = false),
                                color: Colors.black26,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: math.min(width, 320 * scale),
                              child: _filter(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _card(RecruitmentSearchCard room) {
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
    final schedule = room is DiscoveryCard
        ? room.schedule
        : room.betaData?['beta_schedule'] as Map?;
    final groupId = room.wire['group_id'] as String?;
    final groupName = retainedGroupLabel(room.betaData);
    final state = schedule?['coordination_state'];
    final effective = room is DiscoveryCard
        ? room.starts.firstOrNull
        : betaEffectiveStart(room.betaData) ?? room.starts.firstOrNull;
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
      if (room is DiscoveryCard) {
        final progress = schedule!['coordination_progress'] as Map;
        extra = progress['status'] == 'waiting_members'
            ? '${progress['missing_members']}명 더 모이면 조율'
            : '공통 시간 조율 중';
      } else {
        final needed =
            (schedule!['early_additional_members'] as int? ?? 0) +
            1 -
            room.count;
        extra = needed > 0 ? '$needed명 더 모이면 조율' : '공통 시간 조율 중';
      }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: widget.selectedRoom == room.id
                ? AppColors.primary
                : const Color(0xFFE8E4EC),
          ),
        ),
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
                                    betaScheduleLabel({
                                      'beta_schedule': schedule,
                                    }),
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
