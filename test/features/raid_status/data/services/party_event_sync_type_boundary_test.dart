import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  test('완료 히스토리 sync는 완료 3종만 대상으로 하고 알림 type은 건너뛴다', () {
    expect(PartyEventType.partyCompleted.isRaidHistoryEvent, isTrue);
    expect(PartyEventType.partyIncompleteEnded.isRaidHistoryEvent, isTrue);
    expect(PartyEventType.partyCompletionCancelled.isRaidHistoryEvent, isTrue);
    expect(PartyEventType.applicationSubmitted.isRaidHistoryEvent, isFalse);
    expect(PartyEventType.memberJoined.isRaidHistoryEvent, isFalse);
    expect(PartyEventType.tryParse('futureUnknown'), isNull);
  });
}
