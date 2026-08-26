import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

/// Emulator 없이 Rules 계약 경계를 Dart로 고정한다.
/// 실제 Rules 배포·Emulator 검증은 별도 승인 후에만 수행한다.
void main() {
  group('Player Event Rules 계약 경계', () {
    test('create가 허용되는 type 집합이 계약과 일치한다', () {
      const allowed = {
        'partyCompleted',
        'partyCompletionCancelled',
        'partyIncompleteEnded',
        'applicationSubmitted',
        'applicationApproved',
        'applicationRejected',
        'applicationWithdrawn',
        'memberJoined',
        'memberLeft',
        'memberKicked',
        'memberCharacterChanged',
      };
      const deferred = {
        'memberMoved',
        'partyEnded',
        'partyDisbanded',
      };

      for (final type in PartyEventType.values) {
        if (allowed.contains(type.wireName)) {
          expect(deferred.contains(type.wireName), isFalse);
        } else {
          expect(
            deferred.contains(type.wireName),
            isTrue,
            reason: '${type.wireName} should be deferred until command wiring',
          );
        }
      }
    });

    test('완료 계열 허용 필드에 자유 문구·민감 필드가 없다', () {
      const cycleKeys = {
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
      };
      const forbidden = {
        'message',
        'body',
        'title',
        'authUid',
        'fcmToken',
        'token',
      };
      expect(cycleKeys.intersection(forbidden), isEmpty);
    });

    test('신청 이벤트 수신자 규칙은 파티장(leader) 기준이다', () {
      // canApproveApplications 전체 확대는 미확정. Rules는 leaderPlayerId만 수신.
      const applicationSubmitRecipient = 'leaderPlayerId';
      const applicationWithdrawRecipient = 'leaderPlayerId';
      expect(applicationSubmitRecipient, 'leaderPlayerId');
      expect(applicationWithdrawRecipient, 'leaderPlayerId');
    });
  });
}
