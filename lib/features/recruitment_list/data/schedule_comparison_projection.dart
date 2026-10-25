import '../../account/domain/play_availability.dart';
import '../domain/schedule_comparison.dart';
import 'cycle_schedule.dart';

// Project an already validated server snapshot into local comparison rows.
ScheduleComparison scheduleComparisonFromView(CycleScheduleView view) {
  final copies = view.betaData?['availability_copies'] as Map?;
  return ScheduleComparison(view.target, [
    for (final raw in view.data['members'] as List)
      _row(raw as Map, copies?[raw['cycle_member_id']] as Map?),
  ]);
}

ScheduleMemberRow _row(Map raw, Map? copy) {
  final submission = raw['submission'] as Map,
      busy = raw['anonymous_busy'] as Map;
  final unavailable = submission['state'] == 'unavailable';
  final state = unavailable
      ? TimetableState.unavailable
      : copy?['state'] == 'unset'
      ? TimetableState.unset
      : submission['state'] == 'ready'
      ? TimetableState.configured
      : TimetableState.unavailable;
  return ScheduleMemberRow(
    id: raw['cycle_member_id'] as String,
    name: raw['display']?['character_name'] as String? ?? '캐릭터명 확인 실패',
    state: state,
    intervals: state == TimetableState.configured
        ? [
            for (final row in submission['intervals'] as List)
              PlayTimeRow.fromJson(Map<String, dynamic>.from(row as Map)),
          ]
        : [],
    busyAvailable: busy['state'] == 'ready',
    busy: [
      for (final item in busy['intervals'] as List)
        (
          DateTime.parse(item['starts_at'] as String).toUtc(),
          DateTime.parse(item['ends_at'] as String).toUtc(),
        ),
    ],
  );
}
