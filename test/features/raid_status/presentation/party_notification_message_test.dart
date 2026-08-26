import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/presentation/party_notification_message.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  test('이벤트 type별 표시 문구와 이동 경로를 만든다', () {
    expect(
      PartyNotificationMessage.format(
        type: PartyEventType.applicationSubmitted.wireName,
        characterNameSnapshot: '곰곰',
      ),
      '곰곰님이 가입을 신청했습니다.',
    );
    expect(
      PartyNotificationMessage.format(
        type: PartyEventType.memberLeft.wireName,
        characterNameSnapshot: '이슈',
      ),
      '이슈님이 파티에서 탈퇴했습니다.',
    );
    expect(
      PartyNotificationMessage.format(
        type: PartyEventType.partyDisbanded.wireName,
      ),
      '파티 모집이 해산되었습니다.',
    );
    expect(
      PartyNotificationMessage.routeFor(
        type: PartyEventType.memberJoined.wireName,
        recruitmentId: 'party-1',
      ),
      '/raid-status/party-1',
    );
    expect(
      PartyNotificationMessage.routeFor(
        type: PartyEventType.partyCompleted.wireName,
        recruitmentId: 'party-1',
      ),
      '/raid-status',
    );
  });
}
