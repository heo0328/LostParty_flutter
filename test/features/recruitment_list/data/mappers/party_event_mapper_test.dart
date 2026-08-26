import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_mapper.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  const mapper = PartyEventMapper(
    toDateTime: _toDateTime,
  );

  test('완료 계열 문서를 PartyEvent로 매핑한다', () {
    final event = mapper.map({
      'schemaVersion': 1,
      'eventId': 'party_2026-08-26_1_partyCompleted',
      'type': 'partyCompleted',
      'playerId': 'player',
      'recruitmentId': 'party',
      'cycleKey': '2026-08-26',
      'raidId': 'serca',
      'difficultyId': 'hard',
      'eventRevision': 1,
      'characterId': 'character',
      'characterNameSnapshot': '바드',
      'classNameSnapshot': '바드',
      'role': 'support',
      'partyIndex': 0,
      'occurredAt': DateTime.utc(2026, 8, 26, 12),
      'expiresAt': DateTime.utc(2026, 9, 23, 12),
    }, documentId: 'party_2026-08-26_1_partyCompleted');

    expect(event, isNotNull);
    expect(event!.knownType, PartyEventType.partyCompleted);
    expect(event.isRaidHistoryEvent, isTrue);
    expect(event.characterId, 'character');
  });

  test('알 수 없는 type은 knownType null로 보존하고 매핑을 실패시키지 않는다', () {
    final event = mapper.map({
      'schemaVersion': 1,
      'eventId': 'party_x_1_futureNotice',
      'type': 'futureNotice',
      'playerId': 'player',
      'recruitmentId': 'party',
      'eventRevision': 1,
      'occurredAt': DateTime.utc(2026, 8, 26),
      'expiresAt': DateTime.utc(2026, 9, 23),
    });

    expect(event, isNotNull);
    expect(event!.type, 'futureNotice');
    expect(event.knownType, isNull);
    expect(event.isRaidHistoryEvent, isFalse);
  });

  test('필수 필드 누락·documentId 불일치는 null', () {
    expect(
      mapper.map({
        'eventId': 'a',
        'type': 'partyCompleted',
        'playerId': 'p',
        'recruitmentId': 'r',
        'eventRevision': 1,
        'occurredAt': DateTime.utc(2026, 8, 26),
        'expiresAt': DateTime.utc(2026, 9, 23),
      }, documentId: 'other'),
      isNull,
    );
    expect(
      mapper.map({
        'eventId': 'a',
        'type': 'partyCompleted',
        'playerId': 'p',
        'recruitmentId': 'r',
        'eventRevision': 1,
      }),
      isNull,
    );
  });

  test('PartyEventType.tryParse는 wire name만 인식한다', () {
    expect(
      PartyEventType.tryParse('applicationSubmitted'),
      PartyEventType.applicationSubmitted,
    );
    expect(PartyEventType.tryParse('unknown'), isNull);
    expect(PartyEventType.partyCompleted.isRaidHistoryEvent, isTrue);
    expect(PartyEventType.memberJoined.isRaidHistoryEvent, isFalse);
  });
}

DateTime _toDateTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  throw FormatException('Expected DateTime, got $value');
}
