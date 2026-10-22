import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/cycle_management.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import 'cycle_participation_widgets.dart';

class CycleManagementActions extends StatelessWidget {
  const CycleManagementActions({
    required this.controller,
    required this.room,
    required this.target,
    required this.current,
    required this.next,
    required this.role,
    super.key,
  });
  final CycleParticipationController controller;
  final String room, target, current, next, role;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Wrap(
      spacing: 6,
      children: [
        if (target == current && {'leader', 'member'}.contains(role)) ...[
          if (role == 'leader') button(context, 'open', next),
          button(context, 'continue', next),
          button(context, 'decline', next),
        ],
        if ({'leader', 'member'}.contains(role))
          button(context, 'cancel', target),
        if (role == 'leader') ...[
          for (final action in [
            'transfer',
            'formation',
            'remove',
            'settings',
            'common',
            'end',
          ])
            button(context, action, target),
        ],
        if (role != 'none') button(context, 'leave', target),
        if (target == next) button(context, 'reopen', target),
      ],
    ),
  );
  Widget button(BuildContext context, String action, String t) => TextButton(
    onPressed: controller.canAct
        ? () => showCycleManagement(
            context,
            controller,
            room: room,
            target: t,
            action: action,
          )
        : null,
    child: Text(
      cycleManagementLabels[action]!,
      style: const TextStyle(fontSize: 12),
    ),
  );
}

Future<void> showCycleManagement(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String action,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ManagementDialog(
    controller: controller,
    room: room,
    target: target,
    action: action,
  ),
);

class _ManagementDialog extends StatefulWidget {
  const _ManagementDialog({
    required this.controller,
    required this.room,
    required this.target,
    required this.action,
  });
  final CycleParticipationController controller;
  final String room, target, action;
  @override
  State<_ManagementDialog> createState() => _ManagementDialogState();
}

class _ManagementDialogState extends State<_ManagementDialog> {
  CycleManagementPreview? preview;
  String? error, candidate;
  bool loading = true, alternative = false;
  List<RecruitmentCharacter> characters = [];
  String? character, group;
  String role = 'dealer',
      visibility = 'public',
      admission = 'leader_only',
      experience = '';
  final title = TextEditingController(),
      dealer = TextEditingController(),
      support = TextEditingController();
  final sessions = <String>{};
  final placements = <Map<String, dynamic>>[];
  bool initialized = false;
  int generation = 0;
  late final String binding;
  @override
  void initState() {
    super.initState();
    binding = widget.controller.scopeKey();
    unawaited(load());
  }

  @override
  void dispose() {
    generation++;
    title.dispose();
    dealer.dispose();
    support.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final e = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    final p = await widget.controller.management(
      widget.room,
      widget.target,
      widget.action,
      query: alternative && character != null
          ? {'character_id': character, 'selected_role': role}
          : {},
    );
    if (!mounted || e != generation) return;
    if (p != null && !initialized) {
      initialized = true;
      if (p.action == 'settings') {
        final d = p.data, c = d['combat_requirement'] as Map;
        experience = d['experience_level'] as String? ?? '';
        admission = d['admission_mode'] as String;
        dealer.text = c['dealer_min'] as String? ?? '';
        support.text = c['support_min'] as String? ?? '';
      }
      if (p.action == 'common') {
        final d = p.data['current_settings'] as Map;
        title.text = d['title'] as String;
        visibility = d['scope'] as String;
        group = d['group_id'] as String?;
      }
      if (p.action == 'formation') {
        final room = p.data['room'] as Map;
        for (final raw in p.data['members'] as List) {
          final m = raw as Map;
          for (final rawA in m['assignments'] as List) {
            final a = rawA as Map;
            if (a['state'] != 'active') continue;
            final slot = (p.data['formation_slots'] as List)
                .where((s) => s['assignment_id'] == a['assignment_id'])
                .firstOrNull;
            if (m['target_state'] != 'participating') continue;
            final item = (room['items'] as List).firstWhere(
              (i) => i['item_id'] == a['item_id'],
            );
            final size = item['game_party_size'] as int,
                capacity = room['app_capacity'] as int;
            placements.add({
              'cycle_member_id': m['cycle_member_id'],
              'expected_cycle_member_revision': m['cycle_member_revision'],
              'item_id': a['item_id'],
              'party_no': slot?['party_no'] ?? a['party_no'],
              'slot_no': slot?['slot_no'] ?? a['slot_no'],
              '_name':
                  (m['character'] as Map?)?['display']?['character_name'] ??
                  '캐릭터 미확인',
              '_capacity': size < capacity ? size : capacity,
            });
          }
        }
      }
    }
    setState(() {
      preview = p;
      loading = false;
      error = p == null ? widget.controller.failure : null;
    });
  }

  Future<void> alternatives() async {
    setState(() => loading = true);
    final values = await widget.controller.characters();
    if (!mounted) return;
    setState(() {
      characters = values ?? [];
      alternative = true;
      loading = false;
    });
  }

  Map<String, dynamic> input() => {
    'sessions': sessions.toList(),
    'candidate': candidate,
    'title': title.text,
    'scope': visibility,
    'group_id': group,
    'experience_level': experience.isEmpty ? null : experience,
    'admission_mode': admission,
    'combat_requirement': {
      'input_mode': 'per_role',
      'dealer_min': dealer.text.trim().isEmpty ? null : dealer.text.trim(),
      'support_min': support.text.trim().isEmpty ? null : support.text.trim(),
    },
    'placements': [
      for (final p in placements)
        {
          for (final e in p.entries)
            if (!e.key.startsWith('_')) e.key: e.value,
        },
    ],
  };
  Future<void> submit() async {
    final p = preview;
    if (p == null) return;
    setState(() => loading = true);
    await widget.controller.manage(p, input());
    if (!mounted) return;
    if (widget.controller.failure == null || widget.controller.hasPending) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      loading = false;
      error = widget.controller.failure;
    });
  }

  Widget text(String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(v, style: const TextStyle(fontSize: 12)),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      if (!widget.controller.session.isAuthenticated ||
          binding != widget.controller.scopeKey()) {
        return AlertDialog(
          title: const Text('로그인 상태 변경'),
          content: const Text('현재 계정으로 모집을 다시 확인해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      }
      final p = preview, d = p?.data;
      final permission = p == null
          ? null
          : p.contextual
          ? d!['permission']
          : p.action == 'settings'
          ? (d!['permissions'] as Map)['edit_settings']
          : null;
      final allowed =
          p != null &&
          (permission == null || (permission as Map)['allowed'] == true);
      final selectionReady = p == null
          ? false
          : (!{'transfer', 'remove'}.contains(p.action) || candidate != null) &&
                (!(p.opening || p.action == 'continue') ||
                    (d!['selection'] != null &&
                        (d['target_session_ids'] as List).every(
                          sessions.contains,
                        )));
      return AlertDialog(
        title: Text(cycleManagementLabels[widget.action]!),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text(
                  p?.global == true
                      ? '공통 관리 · 영향 주차 확인'
                      : '${widget.target} 주차',
                ),
                if (loading) const LinearProgressIndicator(),
                if (error != null) text(recruitmentFailureMessage(error)),
                if (p != null) ...[
                  if (!allowed)
                    text(
                      recruitmentFailureMessage(
                        (permission as Map)['reason'] as String?,
                      ),
                    ),
                  if (p.global) ...[
                    text(
                      p.action == 'common'
                          ? '제목과 공개 정보는 방의 공통 정보입니다.'
                          : '아래 주차의 참가·점유·예약에도 영향을 줍니다.',
                    ),
                    for (final i in d!['impact_cycles'] as List)
                      text(
                        '${i['target_cycle_key']} · 참가 ${i['member_count']}명 · 예약 ${i['reservation_count']}건',
                      ),
                  ] else if (p.action == 'cancel') ...[
                    text('이 주차의 참가와 예약을 해제합니다. 다른 주차와 기존 완료 기록은 유지됩니다.'),
                    text(
                      d!['mode'] == 'close_target'
                          ? '마지막 참가자이므로 이 주차의 모집이 종료됩니다.'
                          : d['mode'] == 'auto_successor'
                          ? '공대장은 ${(d['successor'] as Map)['character_name'] ?? '다음 참가자'}에게 승계됩니다.'
                          : '선택 주차에서 탈퇴합니다.',
                    ),
                  ] else if (p.action == 'transfer')
                    text('선택한 참가자에게 이 주차의 공대장을 위임합니다. 본인의 참가는 유지됩니다.'),
                  if (p.continuation || p.opening) ...[
                    if (d!['selection'] != null && p.action != 'decline')
                      text(
                        alternative
                            ? '선택한 캐릭터로 참가합니다.'
                            : '이번 주에 참가한 캐릭터와 역할로 참가합니다.',
                      ),
                    if (p.opening)
                      text(
                        '선택 주차를 열고 본인이 첫 참가자·공대장이 됩니다. 다른 참가자는 직접 참가를 선택합니다.',
                      ),
                    for (final conflict in d['conflicts'] as List) ...[
                      text(
                        '${conflict['room_title'] ?? '기존 참가 모집'} · ${conflict['target_cycle_key']} · ${conflict['raid_id']}',
                      ),
                      if (conflict['can_view_detail'] == true)
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  final router = GoRouter.of(context);
                                  Navigator.pop(context);
                                  router.push(
                                    '/recruitments/${conflict['room_id']}?target_cycle_key=${conflict['target_cycle_key']}',
                                  );
                                },
                          child: const Text('기존 참가 확인'),
                        ),
                    ],
                    if ((d['conflicts'] as List).isNotEmpty &&
                        !alternative &&
                        p.action != 'decline')
                      TextButton(
                        onPressed: loading ? null : alternatives,
                        child: const Text('다른 캐릭터로 참가'),
                      ),
                    if (alternative) ...[
                      DropdownButtonFormField<String>(
                        initialValue: character,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '참가 캐릭터'),
                        items: [
                          for (final c in characters)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} · ${c.className}'),
                            ),
                        ],
                        onChanged: loading
                            ? null
                            : (v) {
                                setState(() {
                                  character = v;
                                  role = 'dealer';
                                });
                                unawaited(load());
                              },
                      ),
                      if (characters.any(
                        (c) => c.id == character && c.supportsBothRoles,
                      ))
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          items: const [
                            DropdownMenuItem(
                              value: 'dealer',
                              child: Text('딜러'),
                            ),
                            DropdownMenuItem(
                              value: 'support',
                              child: Text('서포터'),
                            ),
                          ],
                          onChanged: loading
                              ? null
                              : (v) {
                                  setState(() => role = v!);
                                  unawaited(load());
                                },
                        ),
                    ],
                    if (p.action != 'decline')
                      for (final id
                          in (d['target_session_ids'] as List).cast<String>())
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '필수 일정 ${(d['target_session_ids'] as List).indexOf(id) + 1} 참가 확인',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: sessions.contains(id),
                          onChanged: loading
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    sessions.add(id);
                                  } else {
                                    sessions.remove(id);
                                  }
                                }),
                        ),
                  ],
                  if ({'transfer', 'remove'}.contains(p.action))
                    DropdownButtonFormField<String>(
                      key: ValueKey('candidate/$generation'),
                      initialValue: candidate,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '대상 참가자'),
                      items: [
                        if (p.action == 'transfer')
                          for (final c in d!['candidates'] as List)
                            if (c['permission']['allowed'] == true)
                              DropdownMenuItem(
                                value: c['cycle_member_id'] as String,
                                child: Text(
                                  c['character_name'] as String? ?? '캐릭터 미확인',
                                ),
                              ),
                        if (p.action == 'remove')
                          for (final m in d!['members'] as List)
                            if (m['is_me'] == false &&
                                m['target_role'] == 'member' &&
                                m['cycle_member_id'] != null)
                              DropdownMenuItem(
                                value: m['cycle_member_id'] as String,
                                child: Text(
                                  (m['character']
                                              as Map?)?['display']?['character_name']
                                          as String? ??
                                      '캐릭터 미확인',
                                ),
                              ),
                      ],
                      onChanged: loading
                          ? null
                          : (v) => setState(() => candidate = v),
                    ),
                  if (p.action == 'settings') ...[
                    DropdownButtonFormField<String>(
                      initialValue: experience,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('숙련도 제한 없음'),
                        ),
                        for (final e in recruitmentExperiences.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: loading
                          ? null
                          : (v) => setState(() => experience = v!),
                    ),
                    TextField(
                      controller: dealer,
                      enabled: !loading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '딜러 최소 전투력',
                        hintText: '비우면 제한 없음',
                      ),
                    ),
                    TextField(
                      controller: support,
                      enabled: !loading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '서포터 최소 전투력',
                        hintText: '비우면 제한 없음',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: admission,
                      items: const [
                        DropdownMenuItem(
                          value: 'leader_only',
                          child: Text('공대장 승인'),
                        ),
                        DropdownMenuItem(
                          value: 'direct_join',
                          child: Text('바로 참가'),
                        ),
                      ],
                      onChanged: loading
                          ? null
                          : (v) => setState(() => admission = v!),
                    ),
                  ],
                  if (p.action == 'common') ...[
                    TextField(
                      controller: title,
                      maxLength: 60,
                      enabled: !loading,
                      decoration: const InputDecoration(
                        labelText: '모집 제목',
                        hintText: '비우면 기존 제목 유지',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      items: [
                        const DropdownMenuItem(
                          value: 'public',
                          child: Text('전체 공개'),
                        ),
                        if (group != null)
                          const DropdownMenuItem(
                            value: 'group',
                            child: Text('그룹 전용'),
                          ),
                      ],
                      onChanged: loading
                          ? null
                          : (v) => setState(() => visibility = v!),
                    ),
                    if (group != null) text('기존 연결 그룹이 유지됩니다.'),
                  ],
                  if (p.action == 'formation')
                    for (final place in placements)
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          '${place['cycle_member_id']}/${place['item_id']}/$generation',
                        ),
                        initialValue:
                            ((place['party_no'] as int) - 1) * 4 +
                            (place['slot_no'] as int),
                        decoration: InputDecoration(
                          labelText:
                              '${place['_name']} · 레이드 ${(d!['room']['items'] as List).indexWhere((i) => i['item_id'] == place['item_id']) + 1}',
                        ),
                        items: [
                          for (
                            var slot = 1;
                            slot <= (place['_capacity'] as int);
                            slot++
                          )
                            DropdownMenuItem(
                              value: slot,
                              child: Text(
                                (place['_capacity'] as int) == 4
                                    ? '$slot'
                                    : '${(slot - 1) ~/ 4 + 1}-${(slot - 1) % 4 + 1}',
                              ),
                            ),
                        ],
                        onChanged: loading
                            ? null
                            : (slot) => setState(() {
                                place['party_no'] = (slot! - 1) ~/ 4 + 1;
                                place['slot_no'] = (slot - 1) % 4 + 1;
                              }),
                      ),
                ],
                if (!loading)
                  TextButton(
                    onPressed: () {
                      initialized = false;
                      placements.clear();
                      candidate = null;
                      sessions.clear();
                      unawaited(load());
                    },
                    child: const Text('최신 상태 다시 확인'),
                  ),
                CycleCommandBanner(controller: widget.controller),
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
                !loading &&
                    allowed &&
                    selectionReady &&
                    widget.controller.canAct
                ? submit
                : null,
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
