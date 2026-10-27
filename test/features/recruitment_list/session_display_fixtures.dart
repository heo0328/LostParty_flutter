import '../account/backend_read/member_cycles_test.dart' as f1;

String displayId(int i) =>
    '12345678-1234-4234-8234-${i.toString().padLeft(12, '0')}';
Map<String, dynamic> actualDisplay(String id, {bool required = false}) => {
  'session_id': id,
  'revision': 1,
  'schedule_revision': 1,
  'state': 'unconfirmed',
  'required': required,
  'starts_at': null,
  'ends_at': null,
  'join_deadline': null,
  'permission': f1.permit(),
};
Map<String, dynamic> displayWire(
  Map scope, {
  String kind = 'existing',
  List<Map<String, dynamic>> sessions = const [],
}) => {
  'kind': kind,
  'selection_mode': kind == 'existing'
      ? 'select_session_ids'
      : kind == 'none'
      ? 'no_session_selection'
      : 'opening_implicit_enrolment',
  'target_cycle_key': scope['target_cycle_key'],
  'room_cycle_id': scope['room_cycle_id'],
  'target_generation': scope['target_generation'],
  'plan_revision': kind == 'opening_preview' ? null : 1,
  'display_revision': List.filled(64, 'a').join(),
  'sessions': sessions,
  'previews': <Map<String, dynamic>>[],
};

Map<String, dynamic> previewGroup({
  String mode = 'manual',
  int count = 1,
  String occurrence = 'one_of',
}) => {
  'preview_group_ref': List.filled(64, 'b').join(),
  'source_group_revision': 1,
  'planning_mode': mode,
  'occurrence_mode': occurrence,
  'day_scope': count == 0 ? 'any_current_cycle' : 'selected_weekdays',
  'required': true,
  'alternatives': [
    for (var i = 0; i < count; i++)
      {
        'preview_ref': i.toRadixString(16).padLeft(64, '0'),
        'session_id': null,
        'state': 'preview',
        'weekday': 3,
        'starts_at': mode == 'manual' ? '2026-11-03T15:05:00Z' : null,
        'ends_at': null,
        'time_state': mode == 'manual' ? 'start_only' : 'undetermined',
        'materialization': mode == 'manual'
            ? (occurrence == 'each' || count == 1
                  ? 'on_open'
                  : 'after_group_selection')
            : mode == 'coordinated'
            ? 'after_coordination'
            : 'not_scheduled',
      },
  ],
};
