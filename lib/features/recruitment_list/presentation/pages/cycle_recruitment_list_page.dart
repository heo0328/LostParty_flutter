import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/presentation/widgets/member_cycle_selector.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../data/cycle_read_repository.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/cycle_search_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/cycle_participation_widgets.dart';

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
  @override
  State<CycleRecruitmentListPage> createState() =>
      _CycleRecruitmentListPageState();
}

class _CycleRecruitmentListPageState extends State<CycleRecruitmentListPage>
    with WidgetsBindingObserver {
  late final CycleSearchViewModel m;
  bool expanded = false, remainingExpanded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    m = CycleSearchViewModel(
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

  Widget chips<T>(
    Map<T, String> choices,
    Set<T> selected,
    void Function(Set<T>) change,
  ) => Wrap(
    spacing: 4,
    runSpacing: 2,
    children: [
      for (final e in choices.entries)
        FilterChip(
          label: Text(e.value),
          selected: selected.contains(e.key),
          onSelected: (_) => change(toggle(selected, e.key)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelStyle: const TextStyle(fontSize: 10),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('파티 모집')),
        actions: [
          IconButton(
            onPressed: m.loading ? null : () => m.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onCreate(m.target),
        icon: const Icon(Icons.add),
        label: const Text('모집 만들기'),
      ),
      body: Column(
        children: [
          if (m.cycles != null && m.target != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: MemberCycleSelector(
                cycles: m.cycles!,
                value: m.target!,
                onChanged: m.selectTarget,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: m.refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('전체')),
                        ButtonSegment(value: 'general', label: Text('일반')),
                        ButtonSegment(value: 'group_linked', label: Text('그룹')),
                      ],
                      selected: {m.filter.category},
                      onSelectionChanged: (s) {
                        final v = s.single;
                        m.update(
                          m.filter.copy(
                            category: v,
                            clearGroup: v != 'group_linked',
                          ),
                        );
                        if (v == 'group_linked') unawaited(m.loadGroups());
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Card(
                      color: AppColors.primarySubtle,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () => setState(() => expanded = !expanded),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '레이드 · 난이도 · 숙련도',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                ],
                              ),
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 8),
                              chips<String>(
                                {
                                  for (final r in m.catalog?.raids ?? [])
                                    if (r.isActive) r.raidId: r.displayName,
                                },
                                m.filter.raids,
                                (s) => m.update(m.filter.copy(raids: s)),
                              ),
                              const SizedBox(height: 6),
                              chips<String>(
                                {
                                  for (final r in m.catalog?.raids ?? [])
                                    for (final d in r.difficulties)
                                      if (d.isActive) d.difficultyId: d.name,
                                },
                                m.filter.difficulties,
                                (s) => m.update(m.filter.copy(difficulties: s)),
                              ),
                              const SizedBox(height: 6),
                              chips<String>(
                                {
                                  'unrestricted': '제한 없음',
                                  ...recruitmentExperiences,
                                },
                                m.filter.experiences,
                                (s) => m.update(m.filter.copy(experiences: s)),
                              ),
                              if (m.filter.category == 'group_linked') ...[
                                const SizedBox(height: 8),
                                const Text(
                                  '연결 그룹',
                                  style: TextStyle(fontSize: 11),
                                ),
                                chips<String>(
                                  {for (final g in m.groups) g.id: g.name},
                                  m.filter.groupIds,
                                  m.selectGroups,
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    for (final e in const {
                                      '': '공개범위 전체',
                                      'public': '전체 공개',
                                      'group': '그룹 전용',
                                    }.entries)
                                      ChoiceChip(
                                        label: Text(e.value),
                                        labelStyle: const TextStyle(
                                          fontSize: 10,
                                        ),
                                        selected:
                                            (m.filter.admissionScope ?? '') ==
                                            e.key,
                                        onSelected: (_) => m.update(
                                          m.filter.copy(
                                            admissionScope: e.key,
                                            clearScope: e.key.isEmpty,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                if (m.groupLoading)
                                  const LinearProgressIndicator(),
                                if (m.groupFailure != null)
                                  Text(
                                    recruitmentFailureMessage(m.groupFailure),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                if (m.groupContext != null) ...[
                                  const Text(
                                    '그룹원 · 대표 캐릭터',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  chips<String>(
                                    {
                                      for (final member
                                          in m.groupContext!.members)
                                        member['member_ref'] as String:
                                            ((member['display']
                                                        as Map?)?['character_name'] ??
                                                    (member['display']
                                                        as Map?)?['representative_character_name'] ??
                                                    '대표 캐릭터 미설정')
                                                as String,
                                    },
                                    m.filter.members.keys.toSet(),
                                    (refs) => m.update(
                                      m.filter.copy(
                                        members: {
                                          for (final ref in refs)
                                            ref: m.filter.members[ref] ?? {},
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      m.update(CycleSearchFilter()),
                                  child: const Text('필터 초기화'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: () => m.update(
                              m.filter.copy(descending: !m.filter.descending),
                            ),
                            child: Text(
                              '참가인원 정렬 ${m.filter.descending ? '↓ 많은 순' : '↑ 적은 순'}',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => remainingExpanded = !remainingExpanded,
                          ),
                          child: Text(
                            m.filter.remaining.isEmpty
                                ? '남은 자리 전체 ▾'
                                : '남은 자리 ${(m.filter.remaining.toList()..sort()).join('·')} ▾',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remainingExpanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('전체'),
                            selected: m.filter.remaining.isEmpty,
                            onSelected: (_) =>
                                m.update(m.filter.copy(remaining: {})),
                          ),
                          for (var n = 1; n <= 7; n++)
                            FilterChip(
                              label: Text('$n'),
                              selected: m.filter.remaining.contains(n),
                              onSelected: (_) => m.update(
                                m.filter.copy(
                                  remaining: toggle(m.filter.remaining, n),
                                ),
                              ),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(recruitmentFailureMessage(m.failure)),
                          TextButton(
                            onPressed: () => m.refresh(),
                            child: const Text('다시 불러오기'),
                          ),
                        ],
                      ),
                    ),
                  if (!m.loading &&
                      m.failure == null &&
                      m.rows.isEmpty &&
                      widget.session.isAuthenticated)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Text(
                        '조건에 맞는 모집이 없습니다.',
                        textAlign: TextAlign.center,
                      ),
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
        ],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: room.canView ? () => widget.onRoom(room.id, m.target!) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (room.wire['group_id'] != null)
                    const Text(
                      '그룹',
                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${room.count}/${room.capacity}명',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                room.items.map(label).join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                '${room.starts.isEmpty ? '출발 미정' : room.starts.map((v) => v.add(const Duration(hours: 9)).toIso8601String().substring(5, 16).replaceAll('T', ' ')).join(' / ')} · ${recruitmentExperiences[room.wire['experience_level']] ?? '제한 없음'}${leader?['character_name'] == null ? '' : ' · ${leader!['character_name']}'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                room.wire['admission_mode'] == 'direct_join'
                    ? '바로 참가'
                    : '공대장 승인',
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
