import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R1 scaffold는 raidStates·partyEvents 경로를 열고 쓰기는 닫는다', () {
    final raidStatesStart = rules.indexOf('match /raidStates/{stateId}');
    final raidStatesEnd = rules.indexOf(
      'match /characterActivity/{characterId}',
      raidStatesStart,
    );
    final partyEventsStart = rules.indexOf('match /partyEvents/{eventId}');
    final partyEventsEnd = rules.indexOf(
      'match /recruitments/{recruitmentId}',
      partyEventsStart,
    );
    expect(raidStatesStart, greaterThanOrEqualTo(0));
    expect(raidStatesEnd, greaterThan(raidStatesStart));
    expect(partyEventsStart, greaterThanOrEqualTo(0));
    expect(partyEventsEnd, greaterThan(partyEventsStart));

    final raidStates = rules.substring(raidStatesStart, raidStatesEnd);
    final partyEvents = rules.substring(partyEventsStart, partyEventsEnd);

    expect(raidStates, contains('allow create, update, delete: if false'));
    expect(raidStates, contains('playerId == currentPlayerId()'));
    expect(raidStates, isNot(contains('validRaidStateUpdate')));
    expect(
      partyEvents,
      contains('allow get, list, create, update, delete: if false'),
    );
    expect(partyEvents, isNot(contains('validEvent')));
  });

  test('R1은 구 assignment·Claim·개인 event 경로를 유지한다', () {
    expect(rules, contains('match /activeRaidAssignments/{assignmentId}'));
    expect(rules, contains('match /weeklyRaidClaims/{claimId}'));
    expect(rules, contains('match /events/{eventId}'));
  });
}
