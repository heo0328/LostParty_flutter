import 'cycle_action_dialog_route.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/membership_actions.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/cycle_participation_controller.dart';
import 'cycle_participation_widgets.dart';

String membershipActionLabel(String action, String view, String current) =>
    switch (action) {
      'leave_target' => view == current ? '이번주 탈퇴' : '다음주 탈퇴',
      'leave_all' => '모두 탈퇴',
      _ => '모집 해산',
    };

/// Server options control visibility and eligibility, including opposite-week
/// leadership. Keep the approved centered leave row and separate red button.
class CycleMembershipActions extends StatelessWidget {
  const CycleMembershipActions({
    required this.controller,
    required this.menu,
    required this.isCurrent,
    super.key,
  });
  final CycleParticipationController controller;
  final MembershipActionContext menu;
  final bool Function() isCurrent;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      Widget button(String action) {
        final option = menu.options[action] as Map;
        final permission = option['permission'] as Map;
        final enabled =
            permission['allowed'] == true && controller.canAct && isCurrent();
        final label = membershipActionLabel(
          action,
          menu.view,
          menu.scope['current_cycle_key'] as String,
        );
        final onPressed = enabled
            ? () => showDialog<void>(
                context: context,
                routeSettings: cycleActionDialogRoute(menu.room, menu.view),
                builder: (_) => _MembershipDialog(
                  controller: controller,
                  room: menu.room,
                  view: menu.view,
                  current: menu.scope['current_cycle_key'] as String,
                  action: action,
                  isCurrent: isCurrent,
                ),
              )
            : null;
        final child = action == 'dissolve_led_targets'
            ? FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(label),
              )
            : OutlinedButton(onPressed: onPressed, child: Text(label));
        return permission['allowed'] == true
            ? child
            : Tooltip(
                message: recruitmentFailureMessage(
                  permission['reason'] as String?,
                ),
                child: child,
              );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final action in ['leave_target', 'leave_all'])
                  if (menu.options[action]['visible'] == true) button(action),
              ],
            ),
          ),
          if (menu.options['dissolve_led_targets']['visible'] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(child: button('dissolve_led_targets')),
            ),
        ],
      );
    },
  );
}

class _MembershipDialog extends StatefulWidget {
  const _MembershipDialog({
    required this.controller,
    required this.room,
    required this.view,
    required this.current,
    required this.action,
    required this.isCurrent,
  });
  final CycleParticipationController controller;
  final String room, view, current, action;
  final bool Function() isCurrent;
  @override
  State<_MembershipDialog> createState() => _MembershipDialogState();
}

class _MembershipDialogState extends State<_MembershipDialog> {
  CycleParticipationController get c => widget.controller;
  late final String binding;
  MembershipActionPreview? preview;
  String? key, hint;
  bool loading = true, closing = false;
  bool get valid =>
      mounted &&
      c.session.isAuthenticated &&
      c.scopeKey() == binding &&
      widget.isCurrent();

  @override
  void initState() {
    super.initState();
    binding = c.scopeKey();
    c.addListener(changed);
    unawaited(load());
  }

  void changed() {
    final success = c.membershipSuccess;
    if (!mounted ||
        c.scopeKey() != binding ||
        closing ||
        key == null ||
        success?.$1 != key) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> load() async {
    if (!valid || !c.canAct) return;
    setState(() {
      loading = true;
      preview = null;
    });
    final menu = await c.membershipContext(widget.room, widget.view);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!valid || menu == null) return;
      if (menu.scope['current_cycle_key'] != widget.current) {
        hint = '주차가 바뀌었습니다. 닫은 뒤 다시 확인해 주세요.';
        return;
      }
      final option = menu.options[widget.action] as Map;
      if (option['visible'] == true &&
          option['permission']['allowed'] == true) {
        preview = menu.select(widget.action);
      } else {
        hint = recruitmentFailureMessage(
          option['permission']['reason'] as String?,
        );
      }
    });
  }

  Future<void> submit() async {
    final p = preview;
    if (!valid || loading || !c.canAct || p == null) return;
    setState(() {
      loading = true;
      hint = null;
    });
    await c.performMembershipAction(
      p,
      isCurrent: () => valid,
      onPrepared: (value) => key = value,
    );
    if (!mounted || closing) return;
    setState(() {
      loading = false;
    });
    // Changed impact requires a new explicit confirmation. Never silently submit
    // the newly read target/leader set after a stale-context rejection.
    if (!c.hasPending && c.failure != null) {
      hint = recruitmentFailureMessage(c.failure);
      if (valid) await load();
    }
  }

  @override
  void dispose() {
    c.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = preview;
      final dissolve = widget.action == 'dissolve_led_targets';
      return AlertDialog(
        title: Text(
          membershipActionLabel(widget.action, widget.view, widget.current),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) const LinearProgressIndicator(),
                if (p != null) ...[
                  for (final target in p.impact['targets'] as List) ...[
                    Text(
                      '${target['target_cycle_key'] == p.context.scope['current_cycle_key'] ? '이번주' : '다음주'} · ${target['target_cycle_key']} 주차',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      dissolve
                          ? '참가자 ${target['affected_members'].length}명 · 모든 파티원이 탈퇴 처리됩니다.'
                          : '내 참가와 예약을 해제합니다.',
                    ),
                    if (target['successor'] != null)
                      Text(
                        '공대장 자동 승계 · ${target['successor']['character_name'] ?? '다음 참가자'}',
                      ),
                    if (target['transition'] == 'close_empty')
                      const Text('마지막 참가자 탈퇴로 이 주차 모집이 종료됩니다.'),
                    if (target['transition'] == 'leadership_pending')
                      const Text('탈퇴 후 공대장 승계는 참가 상태 확인이 필요합니다.'),
                    const SizedBox(height: 8),
                  ],
                  if (p.affected.isEmpty)
                    const Text('현재 참가 중인 주차는 없습니다. 이 모집에서 탈퇴합니다.'),
                  if (widget.action == 'leave_all')
                    const Text('이번주·다음주 참가와 미결 신청을 취소하고 모집에서 탈퇴합니다.'),
                  if (dissolve) const Text('내가 공대장인 위 주차만 해산합니다.'),
                  const Text('기존 완료 기록은 유지됩니다.'),
                ],
                if (hint != null) Text(hint!),
                if (!valid) const Text('화면이 변경되었습니다. 닫은 뒤 다시 확인해 주세요.'),
                CycleCommandBanner(controller: c),
                if (!loading && !c.hasPending)
                  TextButton(
                    onPressed: valid && c.canAct ? load : null,
                    child: const Text('최신 상태 다시 확인'),
                  ),
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
            onPressed: valid && !loading && c.canAct && p != null
                ? submit
                : null,
            child: Text(dissolve ? '해산' : '탈퇴'),
          ),
        ],
      );
    },
  );
}
