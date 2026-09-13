import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  group('멤버십 이벤트 연결 ID·수신자 경계', () {
    test('즉시 가입 memberJoined는 recruitment revision 기준이고 가입자 본인은 제외한다', () {
      final eventId = PartyEventWritePlan.membershipId(
        recruitmentId: 'party',
        targetPlayerId: 'joiner',
        recruitmentRevision: 4,
        type: PartyEventType.memberJoined.wireName,
      );
      expect(eventId, 'party_joiner_4_memberJoined');

      final payload = PartyEventWritePlan.membership(
        eventId: eventId,
        type: PartyEventType.memberJoined,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        recruitmentRevision: 4,
        actorPlayerId: 'joiner',
        targetPlayerId: 'joiner',
        characterNameSnapshot: '이슈',
        classNameSnapshot: '기상술사',
        role: 'dealer',
        partyIndex: 0,
        slotIndex: 1,
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(payload['playerId'], 'leader');
      expect(payload['actorPlayerId'], 'joiner');
      expect(payload['playerId'], isNot(payload['actorPlayerId']));
    });

    test('탈퇴·추방·캐릭터 변경의 수신자·Snapshot 경계를 구분한다', () {
      final left = PartyEventWritePlan.membership(
        eventId: 'party_leaver_5_memberLeft',
        type: PartyEventType.memberLeft,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        recruitmentRevision: 5,
        actorPlayerId: 'leaver',
        targetPlayerId: 'leaver',
        characterNameSnapshot: '곰곰',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      final kicked = PartyEventWritePlan.membership(
        eventId: 'party_target_6_memberKicked',
        type: PartyEventType.memberKicked,
        recipientPlayerId: 'target',
        recruitmentId: 'party',
        recruitmentRevision: 6,
        actorPlayerId: 'leader',
        targetPlayerId: 'target',
        targetCharacterNameSnapshot: '이슈',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      final changed = PartyEventWritePlan.membership(
        eventId: 'party_member_7_memberCharacterChanged',
        type: PartyEventType.memberCharacterChanged,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        recruitmentRevision: 7,
        actorPlayerId: 'member',
        targetPlayerId: 'member',
        characterNameSnapshot: '새캐릭',
        previousCharacterNameSnapshot: '옛캐릭',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );

      expect(left['characterNameSnapshot'], '곰곰');
      expect(kicked['targetCharacterNameSnapshot'], '이슈');
      expect(kicked['targetPlayerId'], 'target');
      expect(changed['previousCharacterNameSnapshot'], '옛캐릭');
      expect(changed['characterNameSnapshot'], '새캐릭');
    });

    test('승인은 memberJoined가 아니라 applicationApproved다', () {
      expect(
        PartyEventType.applicationApproved.wireName,
        'applicationApproved',
      );
      expect(
        PartyEventType.memberJoined.wireName,
        isNot(PartyEventType.applicationApproved.wireName),
      );
    });

    test('자리 조정은 기존 memberMoved 이벤트 유형과 목적 슬롯을 사용한다', () {
      final payload = PartyEventWritePlan.membership(
        eventId: 'party_member_8_memberMoved',
        type: PartyEventType.memberMoved,
        recipientPlayerId: 'member',
        recruitmentId: 'party',
        recruitmentRevision: 8,
        actorPlayerId: 'leader',
        targetPlayerId: 'member',
        partyIndex: 1,
        slotIndex: 2,
        serverTimestamp: Object(),
        expiresAt: Object(),
      );

      expect(payload['type'], 'memberMoved');
      expect(payload['partyIndex'], 1);
      expect(payload['slotIndex'], 2);
    });
  });
}
