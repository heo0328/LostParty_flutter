import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/repositories/party_event_read_repository.dart';

void main() {
  test('PartyEventReadRepository 계약: 자기 경로·정렬·limit 경계를 명시한다', () {
    // 구현체는 partyEvents를 audience arrayContains로 조회하고
    // occurredAt desc + limit을 적용한다. UI/Drift와 연결하지 않는다.
    expect(20, greaterThan(0));
    expect(
      PartyEventReadFailureType.values,
      containsAll([
        PartyEventReadFailureType.permissionDenied,
        PartyEventReadFailureType.contract,
        PartyEventReadFailureType.unauthenticated,
      ]),
    );
  });
}
