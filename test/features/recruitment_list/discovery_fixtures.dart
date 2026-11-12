/// Test server projection for the explicitly requested discovery profile.
Map<String, dynamic> discoveryWire(Map<String, dynamic> rich) {
  final data = Map<String, dynamic>.from(rich['data'] as Map);
  final cards = (data['items'] as List).map((raw) {
    final card = Map<String, dynamic>.from(raw as Map);
    final schedule = card['beta_schedule'] as Map?;
    final fields =
        'room_id revision title scope group_id admission_mode experience_level app_capacity app_member_count items combat_requirement continuation_enabled room_cycle_id target_cycle_key target_generation target_revision target_state restricted schedule_summary leader_display'
            .split(' ');
    return <String, dynamic>{
      for (final key in fields) key: card[key],
      'view_detail_permission': (card['permissions'] as Map)['view_detail'],
      'schedule': schedule == null
          ? null
          : {
              for (final key
                  in 'coordination_state effective_starts_at effective_ends_at admission_deadline confirmed_starts_at confirmed_ends_at'
                      .split(' '))
                key: schedule[key],
              'coordination_progress':
                  schedule['coordination_state'] == 'coordinating'
                  ? {'status': 'waiting_members', 'missing_members': 1}
                  : {'status': 'not_applicable', 'missing_members': null},
            },
    };
  }).toList();
  return {
    ...rich,
    'data': {
      ...data,
      'items': cards,
      'filter_scope_digest': data['filter_scope_digest'] == null
          ? null
          : List.filled(64, 'd').join(),
      'total_count': cards.length,
      'result_revision': List.filled(64, 'a').join(),
    },
  };
}
