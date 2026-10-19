const ownerId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const proofId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const disputeId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const regId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const charId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const commandKey = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const secondKey = '11111111-1111-4111-8111-111111111111';
const wireNow = '2026-10-19T01:00:00Z';
DateTime get clockNow => DateTime.parse(wireNow);

Map<String, dynamic> contextJson() => {
  'relation': 'other',
  'notice_code': 'OTHER_OWNER_VERIFIED',
  'observed_at': wireNow,
  'can_start_claim': true,
  'blocked_reason': null,
};
Map<String, dynamic> targetJson() => {
  'server_name': '서버',
  'character_name': 'Hero',
};
Map<String, dynamic> proofJson({
  bool defense = false,
  bool registered = false,
}) => {
  'verification_id': proofId,
  'version': 1,
  'purpose': defense ? 'defense' : 'claim',
  'source': defense
      ? 'dispute_defense'
      : registered
      ? 'registration'
      : 'direct_input',
  'source_registration_id': defense || registered ? regId : null,
  'equipment_status': 'pending',
  'ownership_outcome': 'none',
  'ownership_context': contextJson(),
  'target': targetJson(),
  'required_slots': ['장갑'],
  'created_at': wireNow,
  'equipment_expires_at': '2026-10-19T01:10:00Z',
  'server_now': wireNow,
  'ended_at': null,
  'result_code': null,
  'dispute_id': defense ? disputeId : null,
  'registration_id': defense || registered ? regId : null,
  'allowed_actions': ['confirm', 'cancel'],
};
Map<String, dynamic> disputeJson({
  String role = 'challenger',
  bool due = false,
}) => {
  'dispute_id': disputeId,
  'version': 1,
  'viewer_role': role,
  'state': 'defending',
  'phase': due ? 'settlement_due' : 'awaiting_defense',
  'target': targetJson(),
  'started_at': wireNow,
  'defense_deadline': '2026-10-20T01:00:00Z',
  'server_now': due ? '2026-10-20T01:00:00Z' : wireNow,
  'defense_available_until': due ? null : '2026-10-20T01:00:00Z',
  'resolved_at': null,
  'reason_code': null,
  'next_retry_at': null,
  'my_registration_id': role == 'owner' ? regId : null,
  'my_active_verification_ids': <String>[],
  'allowed_actions': due
      ? ['request_settlement']
      : role == 'owner'
      ? ['start_defense']
      : ['cancel_dispute'],
};
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  String? cursor,
}) => {
  'items': items,
  'next_cursor': cursor,
  'feed_revision': 1,
  'server_now': wireNow,
};
Map<String, dynamic> previewJson() => {
  'preview': {
    'characters': [
      {
        ...targetJson(),
        'class_name': '바드',
        'character_level': 60,
        'item_level': '1600.00',
        'combat_power': null,
      },
    ],
    'server_fetched_at': wireNow,
    'expires_at': '2026-10-19T01:30:00Z',
  },
  'ownership_context': contextJson(),
  'server_now': wireNow,
};
