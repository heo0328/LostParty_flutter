import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';

void main() {
  Map<String, Object?> document() => {
    'recruitmentId': 'recruitment-1',
    'raidId': 'raid-1',
    'difficultyId': 'hard',
    'leaderPlayerId': 'player-0',
    'currentCycleKey': '2026-09-09',
    'currentCycleStatus': 'active',
    'status': 'active',
    'visibility': 'public',
    'continueTogether': true,
    'revision': 4,
    'partySlots': [
      <String, Object?>{
        'playerId': 'player-0',
        'characterId': 'character-0',
        'role': 'dealer',
        'classKey': '버서커',
        'partyIndex': 0,
        'slotIndex': 0,
        'countedAsNonGroupMember': false,
      },
    ],
    'nonGroupMemberCount': 0,
    'pendingApplicationCount': 0,
    'pendingNonGroupApplicantCount': 0,
  };

  test('모집 문서의 고정 슬롯과 집계를 Domain Aggregate로 읽는다', () {
    final aggregate = PartyAtomicDocumentMapper.aggregate(document());

    expect(aggregate.recruitmentId, 'recruitment-1');
    expect(aggregate.raidId, 'raid-1');
    expect(aggregate.difficultyId, 'hard');
    expect(aggregate.memberCount, 1);
    expect(aggregate.partySlots.single.classKey, '버서커');
  });

  test('legacy 누락과 명시 차수를 구분하고 손상 차수는 거절한다', () {
    for (final revision in [null, 0, 3]) {
      final data = document();
      final slot = (data['partySlots']! as List).first as Map<String, Object?>;
      if (revision != null) slot['ownershipRevision'] = revision;
      final parsed = PartyAtomicDocumentMapper.aggregate(
        data,
      ).partySlots.single;
      expect(PartyAtomicDocumentMapper.slot(parsed), slot);
    }
    for (final revision in [null, -1, 1.5, '1']) {
      final data = document();
      (data['partySlots']! as List).first['ownershipRevision'] = revision;
      expect(
        () => PartyAtomicDocumentMapper.aggregate(data),
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
    }
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

  test('미완료 종료 모집은 재시도 판정을 위해 종료 상태와 명령을 그대로 읽는다', () {
    final ended = document()
      ..['status'] = 'incompleteEnded'
      ..['currentCycleStatus'] = 'incompleteEnded'
      ..['lastCommandId'] = 'incompleteEnd_recruitment-1_4'
      ..['lastCommandType'] = 'incompleteEnd';

    final aggregate = PartyAtomicDocumentMapper.aggregate(ended);

    expect(aggregate.currentCycleStatus, PartyRaidStateStatus.incompleteEnded);
    expect(aggregate.status, PartyRecruitmentStatus.incompleteEnded);
    expect(aggregate.lastCommandType, PartyAtomicCommandType.incompleteEnd);
  });
}
