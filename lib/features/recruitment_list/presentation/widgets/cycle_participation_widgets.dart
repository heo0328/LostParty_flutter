import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/domain/member_cycle_models.dart';
import '../../../account/domain/role_summary.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../viewmodels/admission_selection_view_model.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import 'recruitment_section.dart';
import 'cycle_session_display_widgets.dart';

class CycleCommandBanner extends StatelessWidget {
  const CycleCommandBanner({required this.controller, super.key});
  final CycleParticipationController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      if (!c.hasPending && c.failure == null && c.notice == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.hasPending)
              Text('요청 대상 주차 · ${c.pendingTarget}\n아직 결과를 확인하지 못했습니다.'),
            if (c.failure != null)
              Text(
                recruitmentFailureMessage(c.failure),
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            if (c.notice != null)
              Text(c.notice!, style: const TextStyle(fontSize: 12)),
            if (c.hasPending)
              TextButton(
                onPressed: c.canRetry ? () => c.retry() : null,
                child: const Text('같은 요청 다시 확인'),
              ),
            if (c.busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      );
    },
  );
}

Future<void> showCycleAdmission(
  BuildContext context,
  CycleParticipationController controller, {
  required String room,
  required String target,
  required String intent,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: .9,
    child: _CycleAdmissionSheet(
      controller: controller,
      room: room,
      target: target,
      intent: intent,
    ),
  ),
);

class _CycleAdmissionSheet extends StatefulWidget {
  const _CycleAdmissionSheet({
    required this.controller,
    required this.room,
    required this.target,
    required this.intent,
  });
  final CycleParticipationController controller;
  final String room, target, intent;
  @override
  State<_CycleAdmissionSheet> createState() => _CycleAdmissionSheetState();
}

class _CycleAdmissionSheetState extends State<_CycleAdmissionSheet> {
  late final AdmissionSelectionViewModel m;
  bool _closing = false;
  List<RecruitmentCharacter> get characters => m.characters;
  String? get character => m.character;
  String? get error => m.failure;
  String get role => m.role;
  bool get loading => m.loading || m.submitting;
  CycleAdmissionPreview? get preview => m.preview;
  Set<String> get chosen => m.chosen;
  @override
  void initState() {
    super.initState();
    m = AdmissionSelectionViewModel(
      controller: widget.controller,
      room: widget.room,
      target: widget.target,
      intent: widget.intent,
    );
    m.addListener(_changed);
    unawaited(m.load());
  }

  void _changed() {
    if (!mounted) return;
    if (m.completed && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    final p = preview;
    if (p == null) return;
    if (widget.intent == 'change_character') {
      final selected = characters.singleWhere((v) => v.id == character);
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('참가 캐릭터 변경'),
          content: Text(
            '${widget.target} 주차 · ${selected.name} · ${role == 'support' ? '서포터' : '딜러'}\n${m.placementMessage}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('변경'),
            ),
          ],
        ),
      );
      if (!mounted || ok != true || !identical(preview, p)) return;
    }
    await m.submit();
  }

  @override
  void dispose() {
    m.removeListener(_changed);
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller, p = preview;
      final selected = characters.where((v) => v.id == character).firstOrNull;
      final label = widget.intent == 'apply'
          ? '참가 신청'
          : widget.intent == 'join'
          ? '바로 참가'
          : '내 캐릭터 변경';
      final requiredSelected = p != null && p.display.selectionReady(chosen);
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
              ],
            ),
            Text(
              '대상 주차 · ${widget.target}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (characters.isEmpty && !loading && error == null)
              Text(m.emptyMessage),
            if (characters.isEmpty && !loading && error == null)
              for (final message in m.exclusionMessages)
                Text(message, style: const TextStyle(fontSize: 12)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 60,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: characters.length,
              itemBuilder: (context, i) {
                final value = characters[i];
                return InkWell(
                  onTap: loading || !c.canAct
                      ? null
                      : () => unawaited(m.selectCharacter(value.id)),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: value.id == character
                          ? AppColors.primarySubtle
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value.id == character
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.accountLabel,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 8),
                        ),
                        Text(
                          '${value.name} · ${value.className}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Lv.${value.itemLevel ?? '확인 필요'}',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (selected?.supportsBothRoles == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'dealer',
                      label: const Text('딜러'),
                      enabled: m.roleAllowed('dealer'),
                    ),
                    ButtonSegment(
                      value: 'support',
                      label: const Text('서포터'),
                      enabled: m.roleAllowed('support'),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: loading || !c.canAct
                      ? null
                      : (v) => unawaited(m.selectRole(v.single)),
                ),
              ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Text(
                recruitmentFailureMessage(error),
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            if (p != null && !p.permission.allowed)
              Text(
                recruitmentFailureMessage(p.permission.reason),
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            if (p != null)
              CycleSessionDisplayView(
                display: p.display,
                chosen: chosen,
                onChanged: !c.canAct || loading ? null : m.chooseSessions,
              ),
            CycleCommandBanner(controller: c),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  !loading &&
                      c.canAct &&
                      p?.permission.allowed == true &&
                      requiredSelected
                  ? _confirm
                  : null,
              child: Text('$label · ${widget.target}'),
            ),
            if (!loading && p == null && !c.hasPending)
              TextButton(
                onPressed: c.canAct ? () => m.load(preserve: true) : null,
                child: const Text('참가 조건 다시 확인'),
              ),
          ],
        ),
      );
    },
  );
}

Future<void> showCycleApplicationDecision(
  BuildContext context,
  CycleParticipationController controller,
  String id,
  String target,
  String action, {
  String? room,
}) async {
  final preview = await controller.review(id, target, expectedRoom: room);
  if (!context.mounted || preview == null) return;
  if (preview.data['state'] != 'pending') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이미 처리된 신청입니다. 목록을 새로고침해 주세요.')),
    );
    return;
  }
  if (action != 'withdraw') {
    final p = preview.review?['permissions'] as Map?;
    if (p?[action] == null ||
        CyclePermission.fromJson(roleMap(p![action])).allowed != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p?[action] == null
                ? '현재 이 신청을 처리할 권한이 없습니다.'
                : recruitmentFailureMessage(
                    CyclePermission.fromJson(roleMap(p![action])).reason,
                  ),
          ),
        ),
      );
      return;
    }
  }
  final name = (preview.data['display'] as Map)['character_name'] ?? '신청 캐릭터';
  final label = action == 'approve'
      ? '승인'
      : action == 'reject'
      ? '거절'
      : '신청 철회';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$label 확인'),
      content: Text('$target 주차 · $name\n이 신청을 $label하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(label),
        ),
      ],
    ),
  );
  if (ok == true) await controller.decide(preview, action);
}

class CycleRoomApplications extends StatefulWidget {
  const CycleRoomApplications({
    required this.controller,
    required this.room,
    required this.target,
    super.key,
  });
  final CycleParticipationController controller;
  final String room, target;
  @override
  State<CycleRoomApplications> createState() => _CycleRoomApplicationsState();
}

class _CycleRoomApplicationsState extends State<CycleRoomApplications> {
  List<Map<String, dynamic>> rows = [];
  String? cursor, error;
  bool loading = false, opened = false;
  int mutation = 0, generation = 0;
  final cursors = <String>{};
  @override
  void initState() {
    super.initState();
    mutation = widget.controller.mutationVersion;
    widget.controller.addListener(_changed);
  }

  void _changed() {
    final c = widget.controller;
    if (!c.busy && c.mutationVersion != mutation) {
      mutation = c.mutationVersion;
      if (opened &&
          c.lastRoom == widget.room &&
          c.lastTarget == widget.target) {
        unawaited(_load());
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _load({bool more = false}) async {
    if (loading || !widget.controller.canAct || (more && cursor == null)) {
      return;
    }
    final g = ++generation, next = more ? cursor : null;
    setState(() {
      opened = true;
      loading = true;
      error = null;
    });
    try {
      final raw = await widget.controller.applications(
        widget.room,
        widget.target,
        cursor: next,
      );
      if (!mounted || g != generation) return;
      if (raw == null) {
        setState(() => error = widget.controller.failure);
        return;
      }
      final d = raw['data'] as Map,
          added = (d['items'] as List).cast<Map<String, dynamic>>();
      final newCursor = d['next_cursor'] as String?;
      if (more &&
          newCursor != null &&
          (newCursor == next || cursors.contains(newCursor))) {
        throw const FormatException('Cursor loop');
      }
      final combined = more ? [...rows, ...added] : added;
      if (combined.map((r) => r['application_id']).toSet().length !=
          combined.length) {
        throw const FormatException('Duplicate application');
      }
      if (!more) cursors.clear();
      if (newCursor != null) cursors.add(newCursor);
      setState(() {
        rows = combined;
        cursor = newCursor;
      });
    } catch (_) {
      if (mounted && g == generation) {
        setState(() => error = 'INVALID_RESPONSE');
      }
    } finally {
      if (mounted && g == generation) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RecruitmentSection(
    title: '신청 관리',
    children: [
      if (!opened)
        TextButton(
          onPressed: widget.controller.canAct ? () => _load() : null,
          child: const Text('신청자 확인'),
        ),
      if (opened)
        TextButton(
          onPressed: loading || !widget.controller.canAct
              ? null
              : () => _load(),
          child: const Text('신청 목록 새로고침'),
        ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(recruitmentFailureMessage(error)),
      if (opened && !loading && error == null && rows.isEmpty)
        const Text('대기 중인 신청이 없습니다.'),
      for (final row in rows)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${(row['display'] as Map)['character_name'] ?? '신청 캐릭터'} · ${row['selected_role'] == 'support' ? '서포터' : '딜러'}',
            style: const TextStyle(fontSize: 12),
          ),
          subtitle: const Text(
            '승인 대기 · 좌석 미확정',
            style: TextStyle(fontSize: 11),
          ),
          trailing: Wrap(
            children: [
              for (final action in ['reject', 'approve'])
                TextButton(
                  onPressed: widget.controller.canAct
                      ? () => showCycleApplicationDecision(
                          context,
                          widget.controller,
                          row['application_id'] as String,
                          widget.target,
                          action,
                          room: widget.room,
                        )
                      : null,
                  child: Text(action == 'approve' ? '승인' : '거절'),
                ),
            ],
          ),
        ),
      if (cursor != null)
        TextButton(
          onPressed: loading || !widget.controller.canAct
              ? null
              : () => _load(more: true),
          child: const Text('더 보기'),
        ),
    ],
  );
}
