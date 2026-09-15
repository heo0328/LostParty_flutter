import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R1 경로는 유지되고 raidStates create는 계속 닫혀 있다', () {
    final raidStatesStart = rules.indexOf('match /raidStates/{stateId}');
    final raidStatesEnd = rules.indexOf(
      'match /characterActivity/{characterId}',
      raidStatesStart,
    );
    final partyEventsStart = rules.indexOf('match /partyEvents/{eventId}');
    expect(raidStatesStart, greaterThanOrEqualTo(0));
    expect(partyEventsStart, greaterThanOrEqualTo(0));
    final raidStates = rules.substring(raidStatesStart, raidStatesEnd);
    expect(raidStates, contains('allow create: if false'));
    expect(raidStates, contains('playerId == currentPlayerId()'));
  });

  test('R1은 구 assignment·Claim·개인 event 경로를 유지한다', () {
    expect(rules, contains('match /activeRaidAssignments/{assignmentId}'));
    expect(rules, contains('match /weeklyRaidClaims/{claimId}'));
    expect(rules, contains('match /events/{eventId}'));
  });
}
