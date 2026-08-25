import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_write_plan.dart';

void main() {
  test('회차 이벤트 ID와 Player별 로컬 히스토리 payload가 안정적이다', () {
    final eventId = PartyEventWritePlan.id(recruitmentId: 'party', cycleKey: '2026-08-26', eventRevision: 2, type: 'partyCompletionCancelled');
    final plan = PartyEventWritePlan.cycle(eventId: eventId, type: 'partyCompletionCancelled', playerId: 'player', recruitmentId: 'party', cycleKey: '2026-08-26', raidId: 'serca', difficultyId: 'hard', eventRevision: 2, memberSnapshot: const {'characterId': 'character', 'characterNameSnapshot': '바드', 'classNameSnapshot': '바드', 'role': 'support', 'partyIndex': 0}, serverTimestamp: Object(), expiresAt: Object());
    expect(eventId, 'party_2026-08-26_2_partyCompletionCancelled');
    expect(plan['playerId'], 'player');
    expect(plan['characterId'], 'character');
    expect(plan['eventRevision'], 2);
  });
}
