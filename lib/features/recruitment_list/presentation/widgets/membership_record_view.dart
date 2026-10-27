import 'package:flutter/material.dart';
import '../../data/membership_readers.dart';

String membershipRecoveryLabel(MembershipProjection p) =>
    switch (p.recovery['state']) {
      'leadership_pending' => '공대장 승계 확인 필요',
      'review_remaining' => '확인할 참가 정보가 남아 있습니다.',
      'unverified' => '참가 정보 확인 필요',
      _ => p.mode == 'relation_only' ? '선택 주차 참가 없음' : '참가 정보를 확인해 주세요.',
    };

String _time(Object? value) {
  if (value == null) return '미정';
  final t = DateTime.parse(
    value as String,
  ).toUtc().add(const Duration(hours: 9));
  String n(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${n(t.month)}-${n(t.day)} ${n(t.hour)}:${n(t.minute)}:${n(t.second)}';
}

/// Only the proven self snapshot; no current roster, membership or command data.
class MembershipRecordView extends StatelessWidget {
  const MembershipRecordView({required this.record, this.raidLabel, super.key});
  final MembershipRecordSnapshot record;
  final String Function(Map)? raidLabel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '본인 참가 기록 · 읽기 전용',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      for (final a in record.assignments) ...[
        Text(a['character_name'] as String? ?? '캐릭터 이름 미확인'),
        Text(raidLabel?.call(a) ?? '${a['raid_id']} · ${a['difficulty_id']}'),
        Text(switch (a['state']) {
          'completed' => '완료',
          'left' => '참가 종료',
          'stopped_incomplete' => '미완료 종료',
          'legacy_ended' => '종료',
          _ => '당시 참가 기록',
        }),
        if (a['completion_source'] != null)
          Text(a['completion_source'] == 'party' ? '파티 완료 기록' : '개인 완료 기록'),
        if (a['completed_at'] != null) Text('완료 · ${_time(a['completed_at'])}'),
        if (a['ended_at'] != null) Text('종료 · ${_time(a['ended_at'])}'),
        const SizedBox(height: 12),
      ],
      if (record.segments.isNotEmpty)
        const Text('참가 당시 내 일정', style: TextStyle(fontWeight: FontWeight.w600)),
      for (final s in record.segments)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${_time(s['starts_at'])} ~ ${_time(s['ends_at'])}${s['state'] == 'released' ? ' · 예약 해제' : ''}',
          ),
        ),
    ],
  );
}
