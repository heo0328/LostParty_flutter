import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import '../../../account/presentation/widgets/member_cycle_selector.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../widgets/recruitment_section.dart';
import '../widgets/recruitment_start_picker.dart';

class BackendRecruitmentCreatePage extends StatefulWidget {
  const BackendRecruitmentCreatePage({
    required this.model,
    required this.onLogin,
    this.initialTarget,
    this.onCreated,
    super.key,
  });
  final BackendRecruitmentCreateViewModel model;
  final VoidCallback onLogin;
  final String? initialTarget;
  final void Function(String, String)? onCreated;
  @override
  State<BackendRecruitmentCreatePage> createState() =>
      _BackendRecruitmentCreatePageState();
}

class _BackendRecruitmentCreatePageState
    extends State<BackendRecruitmentCreatePage> {
  BackendRecruitmentCreateViewModel get m => widget.model;
  String? _opened;
  bool _bundleExpanded = false;
  @override
  void initState() {
    super.initState();
    m.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(m.activate(target: widget.initialTarget));
        _changed();
      }
    });
  }

  @override
  void dispose() {
    m.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final id = m.createdRoomId;
    if (id != null && _opened != id) {
      _opened = id;
      for (final target in m.createdTargetKeys) {
        widget.onCreated?.call(id, target);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && m.createdRoomId == id) {
          context.pushReplacement(
            '/recruitments/$id${m.createdTargetKey == null ? '' : '?target_cycle_key=${m.createdTargetKey}'}',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const OwnershipNoticeTitle(child: Text('모집 만들기'))),
    body: !m.session.isAuthenticated
        ? _message('로그인 후 모집을 만들 수 있어요.', action: widget.onLogin, label: '로그인')
        : !m.eligible
        ? _message(
            '인증한 원정대의 활동 캐릭터로 모집을 만들 수 있어요.',
            action: () => context.go('/account'),
            label: '내 계정 확인',
          )
        : m.loading && m.catalog == null
        ? const Center(child: CircularProgressIndicator())
        : m.catalog == null
        ? _message(
            recruitmentFailureMessage(m.failure),
            action: m.load,
            label: '다시 불러오기',
          )
        : _form(),
  );

  Widget _message(
    String text, {
    required VoidCallback action,
    required String label,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: action, child: Text(label)),
        ],
      ),
    ),
  );

  String _dayLabel(int weekday) {
    const names = {3: '수', 4: '목', 5: '금', 6: '토', 7: '일', 1: '월', 2: '화'};
    final date = BackendRecruitmentCreateViewModel.startPolicy.dateForDay(
      m.serverNow,
      weekday,
      targetCycleKey: m.draft.targetCycleKey,
    );
    return '${names[weekday]} ${date.month}/${date.day}';
  }

  Widget _form() {
    final d = m.draft;
    final validation = m.validationMessage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (m.cycles != null && d.targetCycleKey != null && !m.hasPending)
          MemberCycleSelector(
            cycles: m.cycles!,
            value: d.targetCycleKey!,
            enabled: m.editable,
            onChanged: (t) => m.selectCycle(t),
          ),
        if (m.hasPending) ...[
          if (d.targetCycleKey != null)
            Text('생성 대상 주차 · ${d.targetCycleKey}', textAlign: TextAlign.center),
          _pending(),
        ],
        AbsorbPointer(
          absorbing: !m.editable,
          child: Column(
            children: [
              RecruitmentSection(
                title: '기본 정보',
                children: [
                  _fieldButton(
                    '파티장 캐릭터 · 참가 역할',
                    m.character == null
                        ? '캐릭터 선택'
                        : '${m.character!.name} / ${d.role == 'support' ? '서포터' : '딜러'}',
                    _chooseCharacter,
                    key: const ValueKey('backend-create-character'),
                  ),
                  if (m.character?.supportsBothRoles == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final role in ['dealer', 'support'])
                            ChoiceChip(
                              label: Text(role == 'dealer' ? '딜러' : '서포터'),
                              selected: d.role == role,
                              onSelected: (_) => m.update(d.copy(role: role)),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _input(
                    '모집 제목 · 비우면 기본 제목',
                    d.title,
                    (v) => m.update(m.draft.copy(title: v)),
                    hint: m.defaultTitle,
                    name: 'title',
                  ),
                  const SizedBox(height: 8),
                  if (d.items.isNotEmpty && m.availabilityReady) _raidFields(0),
                  if (m.raidOptions.isEmpty)
                    Text(
                      !m.availabilityReady
                          ? '참가 가능한 레이드를 확인하고 있어요.'
                          : '이 캐릭터로 모집할 수 있는 레이드가 없어요. 참가·완료 상태와 아이템 레벨을 확인해 주세요.',
                    ),
                ],
              ),
              RecruitmentSection(
                title: '출발 일정',
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text('출발 시각 미정 또는 수동 설정', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '선택한 레이드 주차의 날짜예요. 지난 요일을 다음 주로 넘기지 않아요.\n'
                    '수동 출발은 생성 시점부터 30분 이후이며, 선택일마다 진행은 모든 날짜가 유효해야 해요.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final day in const [3, 4, 5, 6, 7, 1, 2])
                        FilterChip(
                          label: Text(_dayLabel(day)),
                          selected: d.weekdays.contains(day),
                          visualDensity: VisualDensity.compact,
                          onSelected:
                              !d.weekdays.contains(day) && !m.canSelectDay(day)
                              ? null
                              : (selected) {
                                  if (selected && !m.canSelectDay(day)) return;
                                  final days = {...d.weekdays};
                                  selected ? days.add(day) : days.remove(day);
                                  m.update(
                                    d.copy(
                                      weekdays: days,
                                      clearStart: days.isEmpty,
                                    ),
                                  );
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (d.weekdays.length > 1)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: d.sameStart,
                      title: const Text(
                        '요일별 동일 시각 적용',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (v) => m.update(d.copy(sameStart: v)),
                    ),
                  if (d.sameStart || d.weekdays.isEmpty)
                    _fieldButton(
                      '출발 시각 · KST',
                      d.startMinute == null
                          ? '미정'
                          : minuteClock(d.startMinute!),
                      () => _chooseStart(),
                    )
                  else
                    for (final day in const [
                      3,
                      4,
                      5,
                      6,
                      7,
                      1,
                      2,
                    ].where(d.weekdays.contains))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _fieldButton(
                          '${const {3: '수', 4: '목', 5: '금', 6: '토', 7: '일', 1: '월', 2: '화'}[day]}요일 출발 · KST',
                          d.timeForDay(day) == null
                              ? '미정'
                              : minuteClock(d.timeForDay(day)!),
                          () => _chooseStart(day: day),
                        ),
                      ),
                  if (d.weekdays.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('아래 날짜 중 1회'),
                            selected: !d.eachDay,
                            onSelected: (_) => m.update(d.copy(eachDay: false)),
                          ),
                          ChoiceChip(
                            label: const Text('선택일마다 진행'),
                            selected: d.eachDay,
                            onSelected: (_) => m.update(d.copy(eachDay: true)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    !d.hasManualTime
                        ? '출발 미정 · 아직 시간 예약은 없어요.'
                        : '확정 출발 30분 전부터 신규 모집이 마감돼요.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _bundleExpanded = !_bundleExpanded),
                      icon: Icon(
                        _bundleExpanded ? Icons.expand_less : Icons.add,
                        size: 18,
                      ),
                      label: const Text('묶음 / 진행시간 설정'),
                    ),
                  ),
                  if (_bundleExpanded) ...[
                    for (var i = 0; i < d.items.length; i++) ...[
                      const Divider(),
                      if (i > 0) _raidFields(i),
                      _duration(i),
                      if (i > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              final values = [...m.draft.items]..removeAt(i);
                              m.update(m.draft.copy(items: values));
                            },
                            child: const Text('레이드 제거'),
                          ),
                        ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _addRaid,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('레이드 추가'),
                    ),
                    if (d.items.length > 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '묶음 모집은 최대 4명 · 딜러 3 / 서포터 1',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ] else if (d.items.isNotEmpty)
                    _duration(0),
                ],
              ),
              RecruitmentSection(
                title: '참가 조건',
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '최소 전투력 동시 적용',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: d.sharedPower,
                    onChanged: (v) => m.update(d.copy(sharedPower: v)),
                  ),
                  if (d.sharedPower)
                    _input(
                      '최소 전투력',
                      d.sharedMinimum,
                      (v) => m.update(m.draft.copy(sharedMinimum: v)),
                      name: 'shared',
                      numeric: true,
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final dealer = _input(
                          '딜러 최소 전투력',
                          d.dealerMinimum,
                          (v) => m.update(m.draft.copy(dealerMinimum: v)),
                          name: 'dealer',
                          numeric: true,
                        );
                        final support = _input(
                          '서포터 최소 전투력',
                          d.supportMinimum,
                          (v) => m.update(m.draft.copy(supportMinimum: v)),
                          name: 'support',
                          numeric: true,
                        );
                        return constraints.maxWidth < 310
                            ? Column(
                                children: [
                                  dealer,
                                  const SizedBox(height: 8),
                                  support,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: dealer),
                                  const SizedBox(width: 8),
                                  Expanded(child: support),
                                ],
                              );
                      },
                    ),
                  const SizedBox(height: 10),
                  _dropdown<String>(
                    '숙련도',
                    d.experience ?? '',
                    {'': '제한 없음', ...recruitmentExperiences},
                    (v) => m.update(
                      d.copy(experience: v, clearExperience: v.isEmpty),
                    ),
                  ),
                  if (m.contextLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (m.selection case final c?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '선택 역할 저장 전투력 ${DisplayNumberFormatter.whole(c.actualPower)}${c.hasBuildWarning ? ' · 빌드 확인 안내 있음' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  for (final prospective
                      in m.selection?.prospective ?? <Map<String, dynamic>>[])
                    if ((prospective['permission'] as Map)['allowed'] !=
                        true) ...[
                      Text(
                        '${prospective['target_cycle_key']} 주차 · ${recruitmentFailureMessage((prospective['permission'] as Map)['reason'] as String?)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                      ),
                      for (final conflict in prospective['conflicts'] as List)
                        if (conflict['can_view_detail'] == true &&
                            conflict['room_id'] != null)
                          TextButton(
                            onPressed: () => context.push(
                              '/recruitments/${conflict['room_id']}?target_cycle_key=${conflict['target_cycle_key']}',
                            ),
                            child: Text(
                              conflict['room_title'] as String? ?? '기존 참가 확인',
                            ),
                          ),
                    ],
                ],
              ),
              RecruitmentSection(
                title: '참가 방식 · 공개 범위',
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('파티장 승인'),
                        selected: !d.directJoin,
                        onSelected: (_) => m.update(d.copy(directJoin: false)),
                      ),
                      ChoiceChip(
                        label: const Text('바로 가입'),
                        selected: d.directJoin,
                        onSelected: (_) => m.update(d.copy(directJoin: true)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _fieldButton(
                    '연결 그룹',
                    m.groups
                            .where((g) => g.id == d.groupId)
                            .firstOrNull
                            ?.name ??
                        '없음',
                    _chooseGroup,
                  ),
                  if (m.groupsLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (m.groupFailure != null)
                    Text(
                      recruitmentFailureMessage(m.groupFailure),
                      style: const TextStyle(fontSize: 11),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('전체 공개'),
                        selected: !d.groupOnly,
                        onSelected: (_) => m.update(d.copy(groupOnly: false)),
                      ),
                      ChoiceChip(
                        label: const Text('그룹 전용'),
                        selected: d.groupOnly,
                        onSelected: d.groupId == null
                            ? null
                            : (_) => m.update(d.copy(groupOnly: true)),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '다음 주도 함께하기',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: d.continueTogether,
                    onChanged:
                        d.targetCycleKey != null &&
                            d.targetCycleKey != m.cycles?.current.key
                        ? null
                        : (v) => m.update(d.copy(continueTogether: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (m.failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              recruitmentFailureMessage(m.failure),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        if (m.notice != null)
          Text(m.notice!, style: const TextStyle(fontSize: 12)),
        if (!m.hasPending)
          FilledButton(
            key: const ValueKey('backend-create-submit'),
            onPressed: m.editable && m.delayPassed && validation == null
                ? m.submit
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(m.saving ? '저장 중…' : '모집 생성'),
          ),
        if (!m.hasPending && validation != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              validation,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _pending() => RecruitmentSection(
    title: '생성 결과 확인',
    children: [
      Text(
        m.retryExpired
            ? '이전 요청의 결과를 먼저 확인해 주세요.'
            : '요청 결과를 확인하지 못했어요. 같은 요청으로 다시 확인할 수 있어요.',
        style: const TextStyle(fontSize: 12),
      ),
      if (!m.retryExpired)
        TextButton(
          onPressed: m.canRetry ? m.retry : null,
          child: const Text('같은 요청 다시 확인'),
        ),
      TextButton(
        onPressed: !m.busy && m.delayPassed ? m.checkCurrentRooms : null,
        child: const Text('현재 참가 모집 확인'),
      ),
      for (var i = 0; i < m.recoveryRooms.length; i++)
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => context.push(
                '/recruitments/${m.recoveryRooms[i]}${m.draft.targetCycleKey == null ? '' : '?target_cycle_key=${m.draft.targetCycleKey}'}',
              ),
              child: Text('참가 모집 ${i + 1} 상세'),
            ),
            if (m.cycleGateway == null)
              TextButton(
                onPressed: m.busy
                    ? null
                    : () => m.confirmRecoveredRoom(m.recoveryRooms[i]),
                child: const Text('이 모집으로 결과 확인'),
              ),
          ],
        ),
    ],
  );

  Widget _input(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    required String name,
    String? hint,
    bool numeric = false,
  }) => TextFormField(
    key: ValueKey('$name-${m.session.generation}'),
    initialValue: value,
    onChanged: onChanged,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: const TextStyle(fontSize: 13),
    maxLength: numeric ? 32 : 60,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint ?? '미입력 · 제한 없음',
      counterText: '',
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
    ),
  );

  Widget _fieldButton(
    String label,
    String value,
    VoidCallback action, {
    Key? key,
  }) => InkWell(
    key: key,
    onTap: action,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 13)),
              ),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _dropdown<T>(
    String label,
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed,
  ) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
    ),
    items: choices.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: (v) {
      if (v != null) changed(v);
    },
  );

  List<RaidDefinition> get _raids => m.raidOptions.map((o) => o.raid).toList();
  Widget _raidFields(int index) {
    if (!m.availabilityReady) return const SizedBox.shrink();
    final item = m.draft.items[index];
    final used = {
      for (var i = 0; i < m.draft.items.length; i++)
        if (i != index) m.draft.items[i].raidId,
    };
    final raids = _raids.where((r) => !used.contains(r.raidId)).toList();
    final raid = raids.where((r) => r.raidId == item.raidId).firstOrNull;
    if (raid == null) return const Text('레이드 정보를 다시 불러와 주세요.');
    void replace(RecruitmentItemDraft value) {
      final items = [...m.draft.items];
      items[index] = value;
      m.update(m.draft.copy(items: items));
    }

    return Column(
      children: [
        _dropdown<String>(
          '레이드 ${index + 1}',
          item.raidId,
          {for (final r in raids) r.raidId: r.displayName},
          (id) {
            final r = raids.firstWhere((r) => r.raidId == id);
            replace(
              RecruitmentItemDraft(
                id,
                m.raidOptions
                    .firstWhere((o) => o.raid.raidId == r.raidId)
                    .highestDifficulty
                    .difficultyId,
                minutes: item.minutes,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _dropdown<String>(
          '난이도',
          item.difficultyId,
          {
            for (final d
                in m.raidOptions
                    .firstWhere((o) => o.raid.raidId == raid.raidId)
                    .difficulties)
              d.difficultyId: '${d.name} · Lv.${d.requiredItemLevel}',
          },
          (id) => replace(
            RecruitmentItemDraft(item.raidId, id, minutes: item.minutes),
          ),
        ),
      ],
    );
  }

  void _addRaid() {
    final used = m.draft.items.map((i) => i.raidId).toSet();
    final r = _raids.where((r) => !used.contains(r.raidId)).firstOrNull;
    if (r == null) return;
    m.update(
      m.draft.copy(
        items: [
          ...m.draft.items,
          RecruitmentItemDraft(
            r.raidId,
            m.raidOptions
                .firstWhere((o) => o.raid.raidId == r.raidId)
                .highestDifficulty
                .difficultyId,
          ),
        ],
      ),
    );
  }

  Widget _duration(int index) {
    final item = m.draft.items[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldButton(
            '진행시간',
            item.minutes == null
                ? '클리어시까지'
                : '${item.minutes! ~/ 60}시간 ${item.minutes! % 60}분',
            () async {
              final binding = (
                m.session.userId,
                m.session.generation,
                m.editGeneration,
              );
              final minutes = await _durationDialog(item.minutes);
              if (!mounted ||
                  minutes == null ||
                  binding !=
                      (
                        m.session.userId,
                        m.session.generation,
                        m.editGeneration,
                      ) ||
                  index >= m.draft.items.length) {
                return;
              }
              final items = [...m.draft.items];
              items[index] = RecruitmentItemDraft(
                item.raidId,
                item.difficultyId,
                minutes: minutes < 0 ? null : minutes,
              );
              m.update(m.draft.copy(items: items));
            },
          ),
          if (item.minutes == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '출발 확정 시 난이도에 따라 시간표에 10·20·30분을 예약해요.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseCharacter() async {
    final binding = (m.session.userId, m.session.generation, m.editGeneration);
    final value = await showModalBottomSheet<RecruitmentCharacter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '파티장 캐릭터 선택',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (m.characters.isEmpty) const Text('인증된 활동 캐릭터가 없습니다.'),
              for (final c in m.characters)
                ListTile(
                  dense: true,
                  title: Text(
                    '${c.name} · ${c.className}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${c.accountLabel} · Lv.${DisplayNumberFormatter.whole(c.itemLevel)}${c.representative ? ' · 대표' : ''}',
                  ),
                  trailing: c.id == m.draft.characterId
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted ||
        value == null ||
        binding != (m.session.userId, m.session.generation, m.editGeneration)) {
      return;
    }
    m.update(m.draft.copy(characterId: value.id, role: value.initialRole));
  }

  Future<void> _chooseGroup() async {
    final binding = (m.session.userId, m.session.generation, m.editGeneration);
    await m.loadGroups();
    if (!mounted ||
        !m.editable ||
        binding != (m.session.userId, m.session.generation, m.editGeneration) ||
        m.groupFailure != null) {
      return;
    }
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('연결 그룹 없음'),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final g in m.groups)
              ListTile(
                title: Text(g.name),
                onTap: () => Navigator.pop(context, g.id),
              ),
          ],
        ),
      ),
    );
    if (mounted &&
        value != null &&
        binding == (m.session.userId, m.session.generation, m.editGeneration)) {
      m.update(m.draft.copy(groupId: value, clearGroup: value.isEmpty));
    }
  }

  Future<void> _chooseStart({int? day}) async {
    if (m.draft.weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('출발 요일을 먼저 선택해 주세요.')));
      return;
    }
    final binding = (m.session.userId, m.session.generation, m.editGeneration);
    final value = await _timeDialog(
      day: day,
      initial: day == null ? m.draft.startMinute : m.draft.timeForDay(day),
      resetLabel: day == null ? '미정' : '모두 미정',
    );
    if (!mounted ||
        value == null ||
        binding != (m.session.userId, m.session.generation, m.editGeneration)) {
      return;
    }
    if (value < 0) {
      m.update(m.draft.copy(clearStart: true));
    } else if (!m.canStart(value, day: day)) {
      return;
    } else if (day == null) {
      m.update(m.draft.copy(startMinute: value));
    } else if (m.draft.weekdays.contains(day)) {
      m.update(m.draft.copy(startsByDay: {...m.draft.startsByDay, day: value}));
    }
  }

  Future<int?> _timeDialog({
    int? initial,
    int? day,
    String resetLabel = '미정',
  }) => showDialog<int>(
    context: context,
    builder: (_) => RecruitmentStartPicker(
      initial: initial,
      resetLabel: resetLabel,
      allowed: (minute) => m.canStart(minute, day: day),
    ),
  );

  Future<int?> _durationDialog(int? initial) async {
    var value = initial ?? 60;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('진행시간'),
        content: SizedBox(
          height: 160,
          width: 260,
          child: CupertinoPicker(
            itemExtent: 34,
            scrollController: FixedExtentScrollController(
              initialItem: (value - 10) ~/ 5,
            ),
            onSelectedItemChanged: (v) => value = 10 + v * 5,
            children: [
              for (var i = 10; i <= 1440; i += 5)
                Center(child: Text('${i ~/ 60}시간 ${i % 60}분')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, -1),
            child: const Text('클리어시까지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
}
