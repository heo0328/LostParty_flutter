import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  group('PartyEventWritePlan', () {
    test('회차 이벤트 ID와 Player별 로컬 히스토리 payload가 안정적이다', () {
      final eventId = PartyEventWritePlan.id(
        recruitmentId: 'party',
        cycleKey: '2026-08-26',
        eventRevision: 2,
        type: 'partyCompletionCancelled',
      );
      final plan = PartyEventWritePlan.cycle(
        eventId: eventId,
        type: 'partyCompletionCancelled',
        playerId: 'player',
        recruitmentId: 'party',
        cycleKey: '2026-08-26',
        raidId: 'serca',
        difficultyId: 'hard',
        eventRevision: 2,
        memberSnapshot: const {
          'characterId': 'character',
          'characterNameSnapshot': '바드',
          'classNameSnapshot': '바드',
          'role': 'support',
          'partyIndex': 0,
        },
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(eventId, 'party_2026-08-26_2_partyCompletionCancelled');
      expect(plan['playerId'], 'player');
      expect(plan['characterId'], 'character');
      expect(plan['eventRevision'], 2);
      expect(plan.keys, containsAll([
        'schemaVersion',
        'eventId',
        'type',
        'playerId',
        'recruitmentId',
        'cycleKey',
        'raidId',
        'difficultyId',
        'eventRevision',
        'characterId',
        'characterNameSnapshot',
        'classNameSnapshot',
        'role',
        'partyIndex',
        'occurredAt',
        'expiresAt',
      ]));
    });

    test('신청 이벤트 ID는 application revision 기준이며 recruitment revision과 섞지 않는다', () {
      final eventId = PartyEventWritePlan.applicationId(
        recruitmentId: 'party',
        applicationPlayerId: 'applicant',
        applicationRevision: 3,
        type: PartyEventType.applicationSubmitted.wireName,
      );
      expect(eventId, 'party_applicant_3_applicationSubmitted');

      final payload = PartyEventWritePlan.application(
        eventId: eventId,
        type: PartyEventType.applicationSubmitted,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        applicationRevision: 3,
        actorPlayerId: 'applicant',
        applicantCharacterNameSnapshot: '곰곰',
        applicantClassNameSnapshot: '바드',
        applicantRole: 'support',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(payload['playerId'], 'leader');
      expect(payload['eventRevision'], 3);
      expect(payload['actorPlayerId'], 'applicant');
      expect(payload.containsKey('message'), isFalse);
    });

    test('멤버십 이벤트 ID는 recruitment revision 기준이다', () {
      final eventId = PartyEventWritePlan.membershipId(
        recruitmentId: 'party',
        targetPlayerId: 'joiner',
        recruitmentRevision: 5,
        type: PartyEventType.memberJoined.wireName,
      );
      expect(eventId, 'party_joiner_5_memberJoined');

      final payload = PartyEventWritePlan.membership(
        eventId: eventId,
        type: PartyEventType.memberJoined,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        recruitmentRevision: 5,
        actorPlayerId: 'joiner',
        characterNameSnapshot: '이슈',
        classNameSnapshot: '기상술사',
        role: 'dealer',
        partyIndex: 0,
        slotIndex: 1,
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(payload['eventRevision'], 5);
      expect(payload['partyIndex'], 0);
      expect(payload['slotIndex'], 1);
    });

    test('종료·해산 ID는 cycleKey와 recruitment revision을 사용한다', () {
      final eventId = PartyEventWritePlan.lifecycleId(
        recruitmentId: 'party',
        cycleKey: '2026-08-26',
        recruitmentRevision: 7,
        type: PartyEventType.partyDisbanded.wireName,
      );
      expect(eventId, 'party_2026-08-26_7_partyDisbanded');
    });
  });
}
