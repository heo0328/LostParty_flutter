import 'package:flutter/material.dart';
import '../../../account/domain/member_cycle_models.dart';
import '../../../account/domain/role_summary.dart';
import '../../data/cycle_session_display.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';

String _stamp(Object value) {
  final t = DateTime.parse(
    value as String,
  ).toUtc().add(const Duration(hours: 9));
  return '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
      '(${const ['월', '화', '수', '목', '금', '토', '일'][t.weekday - 1]}) '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String cycleDisplayTimeRange(Map<String, dynamic> s) {
  if (s['starts_at'] == null) return '시간 미정';
  return '${_stamp(s['starts_at']!)} ~ ${s['ends_at'] == null ? '종료 미정' : _stamp(s['ends_at']!)} · KST';
}

/// Shares presentation only; selection and permissions remain context-owned.
class CycleSessionDisplayView extends StatelessWidget {
  const CycleSessionDisplayView({
    required this.display,
    this.chosen = const {},
    this.onChanged,
    super.key,
  });
  final CycleSessionDisplay display;
  final Set<String> chosen;
  final ValueChanged<Set<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (display.kind == 'none') return const SizedBox.shrink();
    if (display.selectable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (display.sessions.isNotEmpty)
            const Text('참가할 일정', style: TextStyle(fontWeight: FontWeight.w600)),
          for (final s in display.sessions)
            Builder(
              builder: (context) {
                final p = CyclePermission.fromJson(roleMap(s['permission']));
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${s['required'] == true ? '필수' : '선택'} · ${cycleDisplayTimeRange(s)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    [
                      s['state'] == 'confirmed' ? '확정' : '미확정',
                      if (!p.allowed)
                        recruitmentFailureMessage(p.reason)
                      else if (s['join_deadline'] != null)
                        '참가 마감 ${_stamp(s['join_deadline']!)}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: chosen.contains(s['session_id']),
                  onChanged: !p.allowed || onChanged == null
                      ? null
                      : (v) {
                          final next = {...chosen};
                          if (v == true) {
                            next.add(s['session_id'] as String);
                          } else {
                            next.remove(s['session_id']);
                          }
                          onChanged!(next);
                        },
                );
              },
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '다음 주 일정 미리보기',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Text(
          '시간 확정과 예약은 참가 후 별도로 확인합니다.',
          style: TextStyle(fontSize: 11),
        ),
        if (display.previews.isEmpty)
          const Text('일정 미지정', style: TextStyle(fontSize: 12)),
        for (final g in display.previews)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${g['required'] == true ? '필수' : '선택'} · ${g['occurrence_mode'] == 'each' ? '각 일정' : '후보 중 한 일정'}',
                  style: const TextStyle(fontSize: 12),
                ),
                if ((g['alternatives'] as List).isEmpty)
                  Text(
                    g['day_scope'] == 'any_current_cycle'
                        ? '주차 전체 · 조율 대기'
                        : '일정 미지정',
                    style: const TextStyle(fontSize: 11),
                  ),
                for (final a
                    in (g['alternatives'] as List).cast<Map<String, dynamic>>())
                  Text(
                    '${cycleDisplayTimeRange(a)} · ${const {'on_open': '개방 시 생성 예정', 'after_group_selection': '후보 선택 후 확정', 'after_coordination': '조율 대기', 'not_scheduled': '일정 미지정'}[a['materialization']]}',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
