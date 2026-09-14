import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart';

void main() {
  Map<String, Object?> document() => {
    'recruitmentId': 'recruitment-1',
    'leaderPlayerId': 'player-0',
    'currentCycleKey': '2026-09-09',
    'currentCycleStatus': 'active',
    'revision': 4,
    'partySlots': [
      {
        'playerId': 'player-0',
        'characterId': 'character-0',
        'role': 'dealer',
        'classKey': '버서커',
        'partyIndex': 0,
        'slotIndex': 0,
      },
    ],
    'nonGroupMemberCount': 0,
    'pendingApplicationCount': 0,
    'pendingNonGroupApplicantCount': 0,
  };

  test('모집 문서의 고정 슬롯과 집계를 Domain Aggregate로 읽는다', () {
    final aggregate = PartyAtomicDocumentMapper.aggregate(document());

    expect(aggregate.recruitmentId, 'recruitment-1');
    expect(aggregate.memberCount, 1);
    expect(aggregate.partySlots.single.classKey, '버서커');
  });

  test('누락되거나 알 수 없는 필드는 과거 자료로 추측하지 않고 거절한다', () {
    final missing = document()..remove('partySlots');
    final unknownRole = document();
    (unknownRole['partySlots']! as List).first['role'] = 'unknown';

    expect(
      () => PartyAtomicDocumentMapper.aggregate(missing),
      throwsFormatException,
    );
    expect(
      () => PartyAtomicDocumentMapper.aggregate(unknownRole),
      throwsFormatException,
    );
  });
}
