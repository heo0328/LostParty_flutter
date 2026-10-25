import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../domain/departure_search_selection.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/cycle_search_view_model.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/recruitment_design.dart';
import '../widgets/group_candidate_filter.dart';

Future<void> openRecruitmentFilter(
  BuildContext context,
  CycleSearchViewModel model,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(builder: (_) => RecruitmentFilterPage(model: model)),
);
Future<void> showRecruitmentRemainingSlots(
  BuildContext context,
  CycleSearchViewModel model,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => _RemainingSelector(model: model),
);

class RecruitmentFilterPage extends StatefulWidget {
  const RecruitmentFilterPage({super.key, required this.model});
  final CycleSearchViewModel model;
  @override
  State<RecruitmentFilterPage> createState() => _RecruitmentFilterPageState();
}

class _RecruitmentFilterPageState extends State<RecruitmentFilterPage> {
  late final CycleSearchViewModel m;
  late final String binding;
  String? error;
  @override
  void initState() {
    super.initState();
    m = widget.model.draft();
    binding = m.scopeKey();
    if (m.filter.category == 'group_linked' && m.groups.isEmpty) {
      unawaited(m.loadGroups());
    }
  }

  @override
  void dispose() {
    m.dispose();
    super.dispose();
  }

  Set<T> toggle<T>(Set<T> values, T item) {
    final next = {...values};
    if (!next.add(item)) next.remove(item);
    return next;
  }

  void departure(DepartureSearchSelection value) =>
      m.update(m.filter.copy(departure: value));
  Widget options<T>(
    Map<T, String> values,
    Set<T> selected,
    ValueChanged<Set<T>> onChanged, {
    int columns = 3,
  }) => LayoutBuilder(
    builder: (ctx, box) => Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final entry in values.entries)
          SizedBox(
            width: (box.maxWidth - (columns - 1) * 8) / columns,
            child: RecruitmentOptionButton(
              text: entry.value,
              selected: selected.contains(entry.key),
              onPressed: () => onChanged(toggle(selected, entry.key)),
            ),
          ),
      ],
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
  String clock(int? value) => value == null
      ? '선택'
      : '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  Future<void> pickTime(bool end) async {
    final before = m.filter.departure;
    final value = end ? before.to : before.from;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (value ?? (end ? 1200 : 1020)) ~/ 60 % 24,
        minute: (value ?? 0) % 60,
      ),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (!mounted || binding != m.scopeKey() || result == null) return;
    final minute = result.hour * 60 + result.minute;
    departure(end ? before.copy(to: minute) : before.copy(from: minute));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) {
      final f = m.filter,
          d = f.departure,
          active = binding == m.scopeKey() && m.session.isAuthenticated;
      final date = d.weekday == null || m.target == null
          ? null
          : d.date(m.target!, d.weekday!);
      final ready =
          active &&
          d.valid &&
          m.target != null &&
          d.validFor(m.target!) &&
          !m.groupLoading &&
          !m.candidateLoading &&
          !m.selectionPending &&
          m.groupFailure == null &&
          m.candidateFailure == null;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leadingWidth: 40,
          titleSpacing: 0,
          titleTextStyle: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: 20),
          title: const Text('레이드 모집 · 필터'),
          actions: [
            TextButton(
              onPressed: active
                  ? () => m.update(CycleSearchFilter(category: f.category))
                  : null,
              child: const Text('초기화'),
            ),
          ],
        ),
        body: !active
            ? const Center(child: Text('로그인 상태가 변경되었습니다. 다시 열어 주세요.'))
            : ListView(
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
                        heading('레이드 · 난이도 · 숙련도'),
                        options<String>(
                          {
                            for (final raid in m.catalog?.raids ?? [])
                              if (raid.isActive) raid.raidId: raid.displayName,
                          },
                          f.raids,
                          (v) => m.update(f.copy(raids: v)),
                        ),
                        const SizedBox(height: 12),
                        options<String>(
                          {
                            for (final raid in m.catalog?.raids ?? [])
                              for (final level in raid.difficulties)
                                if (level.isActive)
                                  level.difficultyId: level.name,
                          },
                          f.difficulties,
                          (v) => m.update(f.copy(difficulties: v)),
                        ),
                        const SizedBox(height: 12),
                        options<String>(
                          {'unrestricted': '제한 없음', ...recruitmentExperiences},
                          f.experiences,
                          (v) => m.update(f.copy(experiences: v)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    m.update(f.copy(descending: !f.descending)),
                                child: Text(
                                  '참가인원 정렬 ${f.descending ? '↓' : '↑'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) => _RemainingSelector(model: m),
                              ),
                              child: Text(
                                f.remaining.isEmpty
                                    ? '남은 자리 전체'
                                    : '남은 자리 ${(f.remaining.toList()..sort()).join('·')}명',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (f.category == 'group_linked')
                    RecruitmentDesignCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading('연결 그룹'),
                          options<String>(
                            {
                              for (final group in m.groups)
                                group.id: group.name,
                            },
                            f.groupIds,
                            m.selectGroups,
                            columns: 2,
                          ),
                          const SizedBox(height: 12),
                          options<String>(
                            {
                              '': '공개범위 전체',
                              'public': '전체 공개',
                              'group': '그룹 전용',
                            },
                            {f.admissionScope ?? ''},
                            (v) {
                              final selected =
                                  v.difference({
                                    f.admissionScope ?? '',
                                  }).firstOrNull ??
                                  '';
                              m.update(
                                f.copy(
                                  admissionScope: selected,
                                  clearScope: selected.isEmpty,
                                ),
                              );
                            },
                          ),
                          if (m.groupLoading) const LinearProgressIndicator(),
                          if (m.groupFailure != null)
                            Text(recruitmentFailureMessage(m.groupFailure)),
                        ],
                      ),
                    ),
                  RecruitmentDesignCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading('날짜 · 시간대'),
                        label('출발 날짜'),
                        Row(
                          children: [
                            for (final day in const [3, 4, 5, 6, 7, 1, 2])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: RecruitmentOptionButton(
                                    key: ValueKey('departure-day-$day'),
                                    text: ' 월화수목금토일'[day],
                                    selected: d.weekday == day,
                                    onPressed: () => departure(
                                      d.copy(
                                        weekday: day,
                                        clearDay: d.weekday == day,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          date == null
                              ? '날짜 무관'
                              : '${date.month}월 ${date.day}일 ${' 월화수목금토일'[date.weekday]}요일',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        label('출발 시간대'),
                        Row(
                          children: [
                            Expanded(
                              child: RecruitmentOptionButton(
                                text: '시간 무관',
                                selected: !d.timeEnabled,
                                onPressed: () =>
                                    departure(d.copy(timeEnabled: false)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RecruitmentOptionButton(
                                text: '시간대 지정',
                                selected: d.timeEnabled,
                                onPressed: () =>
                                    departure(d.copy(timeEnabled: true)),
                              ),
                            ),
                          ],
                        ),
                        if (d.timeEnabled) ...[
                          const SizedBox(height: 22),
                          const Text(
                            '출발 시간 범위',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => pickTime(false),
                                    child: Text(
                                      clock(d.from),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const Text('~'),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => pickTime(true),
                                    child: Text(
                                      clock(d.to),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!d.valid ||
                              m.target != null && !d.validFor(m.target!))
                            const Text(
                              '선택 주차 안에서 시작·끝을 서로 다른 5분 단위로 골라 주세요.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                              ),
                            ),
                          if (d.from != null && d.to != null && d.to! < d.from!)
                            const Text(
                              '끝 시각은 다음 날입니다.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                        const SizedBox(height: 28),
                        label('일정 상태 · 복수 선택'),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 104,
                            child: RecruitmentOptionButton(
                              text: '전체',
                              selected: d.groups.isEmpty,
                              onPressed: () => departure(d.copy(groups: {})),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        options<String>(
                          {'coordinating': '조기 조율 중', 'confirmed': '출발 확정'},
                          d.groups,
                          (v) => departure(d.copy(groups: v)),
                          columns: 2,
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          '조율 중에도 기본 출발 시간으로 검색해요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  const SizedBox(height: 12),
                  RecruitmentPrimaryButton(
                    label: '조건 적용',
                    onPressed: ready
                        ? () {
                            if (widget.model.applyDraft(m)) {
                              Navigator.pop(context);
                            } else {
                              setState(
                                () => error = '주차나 참가 정보가 변경되었습니다. 다시 확인해 주세요.',
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  RecruitmentPrimaryButton(
                    label: '그룹원·캐릭터 필터 보기',
                    secondary: true,
                    onPressed: f.groupId == null || m.groupLoading
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _GroupFilterPage(model: m),
                            ),
                          ),
                  ),
                  if (f.category == 'group_linked' && f.groupId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '그룹 하나를 선택하면 그룹원별 캐릭터를 고를 수 있어요.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
      );
    },
  );
}

class _RemainingSelector extends StatelessWidget {
  const _RemainingSelector({required this.model});
  final CycleSearchViewModel model;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RecruitmentOptionButton(
              text: '전체',
              selected: model.filter.remaining.isEmpty,
              onPressed: () => model.update(model.filter.copy(remaining: {})),
            ),
            for (var n = 1; n <= 7; n++)
              RecruitmentOptionButton(
                text: '$n명',
                selected: model.filter.remaining.contains(n),
                onPressed: () {
                  final values = {...model.filter.remaining};
                  if (!values.add(n)) values.remove(n);
                  model.update(model.filter.copy(remaining: values));
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _GroupFilterPage extends StatelessWidget {
  const _GroupFilterPage({required this.model});
  final CycleSearchViewModel model;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('그룹원 · 캐릭터')),
    body: ListenableBuilder(
      listenable: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '그룹원별로 캐릭터를 선택해요.',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          GroupCandidateFilter(model: model),
        ],
      ),
    ),
  );
}
