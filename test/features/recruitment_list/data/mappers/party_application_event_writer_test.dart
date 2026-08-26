import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  group('신청 이벤트 연결 ID·수신자 경계', () {
    test('신청·재신청 이벤트는 신청자 revision 기준이고 파티장이 수신한다', () {
      final submitted = PartyEventWritePlan.applicationId(
        recruitmentId: 'party',
        applicationPlayerId: 'applicant',
        applicationRevision: 1,
        type: PartyEventType.applicationSubmitted.wireName,
      );
      final reapply = PartyEventWritePlan.applicationId(
        recruitmentId: 'party',
        applicationPlayerId: 'applicant',
        applicationRevision: 2,
        type: PartyEventType.applicationSubmitted.wireName,
      );
      expect(submitted, 'party_applicant_1_applicationSubmitted');
      expect(reapply, 'party_applicant_2_applicationSubmitted');
      expect(submitted, isNot(reapply));

      final payload = PartyEventWritePlan.application(
        eventId: submitted,
        type: PartyEventType.applicationSubmitted,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        applicationRevision: 1,
        actorPlayerId: 'applicant',
        applicantCharacterNameSnapshot: '곰곰',
        applicantClassNameSnapshot: '바드',
        applicantRole: 'support',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(payload['playerId'], 'leader');
      expect(payload['actorPlayerId'], 'applicant');
      expect(payload['playerId'], isNot(payload['actorPlayerId']));
    });

    test('승인·거절은 신청자가 수신하고 철회는 파티장이 수신한다', () {
      final approved = PartyEventWritePlan.application(
        eventId: 'party_applicant_2_applicationApproved',
        type: PartyEventType.applicationApproved,
        recipientPlayerId: 'applicant',
        recruitmentId: 'party',
        applicationRevision: 2,
        actorPlayerId: 'leader',
        applicantCharacterNameSnapshot: '곰곰',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      final rejected = PartyEventWritePlan.application(
        eventId: 'party_applicant_3_applicationRejected',
        type: PartyEventType.applicationRejected,
        recipientPlayerId: 'applicant',
        recruitmentId: 'party',
        applicationRevision: 3,
        actorPlayerId: 'leader',
        applicantCharacterNameSnapshot: '곰곰',
        rejectionCount: 1,
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      final withdrawn = PartyEventWritePlan.application(
        eventId: 'party_applicant_2_applicationWithdrawn',
        type: PartyEventType.applicationWithdrawn,
        recipientPlayerId: 'leader',
        recruitmentId: 'party',
        applicationRevision: 2,
        actorPlayerId: 'applicant',
        applicantCharacterNameSnapshot: '곰곰',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );

      expect(approved['playerId'], 'applicant');
      expect(rejected['playerId'], 'applicant');
      expect(rejected['rejectionCount'], 1);
      expect(withdrawn['playerId'], 'leader');
    });

    test('즉시 가입은 신청 이벤트 type을 쓰지 않는다', () {
      // memberJoined는 멤버십 연결 작업 범위다.
      expect(
        PartyEventType.memberJoined.wireName,
        isNot(contains('application')),
      );
    });
  });
}
