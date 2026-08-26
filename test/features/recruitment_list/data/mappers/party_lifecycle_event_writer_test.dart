import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_mapper.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_event_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_event.dart';

void main() {
  group('회차·해산 이벤트 확장', () {
    test('해산 이벤트 ID는 cycleKey와 recruitment revision을 사용한다', () {
      final eventId = PartyEventWritePlan.lifecycleId(
        recruitmentId: 'party',
        cycleKey: '2026-08-26',
        recruitmentRevision: 9,
        type: PartyEventType.partyDisbanded.wireName,
      );
      expect(eventId, 'party_2026-08-26_9_partyDisbanded');

      final payload = PartyEventWritePlan.lifecycle(
        eventId: eventId,
        type: PartyEventType.partyDisbanded,
        recipientPlayerId: 'member',
        recruitmentId: 'party',
        cycleKey: '2026-08-26',
        recruitmentRevision: 9,
        actorPlayerId: 'leader',
        characterNameSnapshot: '곰곰',
        endReason: 'disbandedByLeader',
        serverTimestamp: Object(),
        expiresAt: Object(),
      );
      expect(payload['playerId'], 'member');
      expect(payload['actorPlayerId'], 'leader');
      expect(payload['endReason'], 'disbandedByLeader');
      expect(payload.containsKey('message'), isFalse);
    });

    test('완료 3종은 공통 PartyEvent로 매핑되고 알림 후보이다', () {
      const mapper = PartyEventMapper(toDateTime: _toDateTime);
      for (final type in [
        PartyEventType.partyCompleted,
        PartyEventType.partyCompletionCancelled,
        PartyEventType.partyIncompleteEnded,
      ]) {
        final event = mapper.map({
          'schemaVersion': 1,
          'eventId': 'party_2026-08-26_1_${type.wireName}',
          'type': type.wireName,
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
          'occurredAt': DateTime.utc(2026, 8, 26),
          'expiresAt': DateTime.utc(2026, 9, 23),
        });
        expect(event, isNotNull);
        expect(event!.knownType, type);
        expect(event.isRaidHistoryEvent, isTrue);
        expect(type.isNotificationCandidate, isTrue);
      }
      expect(PartyEventType.partyDisbanded.isNotificationCandidate, isTrue);
      expect(PartyEventType.partyEnded.isNotificationCandidate, isFalse);
      expect(PartyEventType.memberMoved.isNotificationCandidate, isFalse);
    });
  });
}

DateTime _toDateTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  throw FormatException('Expected DateTime, got $value');
}
