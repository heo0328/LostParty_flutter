import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R5 raidStates create는 membership raidState 검증 OR를 연다', () {
    final start = rules.indexOf('match /raidStates/{stateId}');
    final end = rules.indexOf('match /characterActivity/{characterId}', start);
    final block = rules.substring(start, end);

    expect(rules, contains('function validAtomicRaidStateCreate('));
    expect(block, contains('validAtomicRaidStateCreate('));
    expect(block, isNot(contains('allow create: if false')));
    expect(block, contains('validAtomicRaidStateUpdate('));
    expect(block, contains('validAtomicRaidStateDelete('));
  });

  test('R5 raidState create는 v2 모집·raidStateTargets·주간 Claim을 검증한다', () {
    final start = rules.indexOf('function validAtomicRaidStateCreate(');
    final end = rules.indexOf('function atomicIsMembershipEventType(');
    final create = rules.substring(start, end);

    expect(create, contains('recruitment.schemaVersion == 2'));
    expect(create, contains('!atomicIsLifecycleCommand(recruitment)'));
    expect(create, contains('atomicRaidStateListedInTargets(recruitment'));
    expect(create, contains('!hasWeeklyRaidClaimAfter('));
    expect(create, isNot(contains('getAfter(assignmentPath(')));
  });

  test('R5 partyEvents create는 가입·membership·lifecycle 이벤트를 병행한다', () {
    final start = rules.indexOf('match /partyEvents/{eventId}');
    final end = rules.indexOf('match /recruitments/{recruitmentId}', start);
    final block = rules.substring(start, end);

    expect(rules, contains('function validAtomicMembershipPartyEvent('));
    expect(block, contains('validAtomicJoinedPartyEvent('));
    expect(block, contains('|| validAtomicMembershipPartyEvent('));
    expect(block, contains('|| validAtomicLifecyclePartyEvent('));
  });

  test('R5 membership 이벤트는 Write Plan 유형과 revision 봉투를 허용한다', () {
    final start = rules.indexOf('function validAtomicMembershipPartyEvent(');
    final end = rules.indexOf('function validGroupRaidListingDelete(');
    final event = rules.substring(start, end);

    expect(rules, contains("type == 'partyCreated'"));
    expect(rules, contains("type == 'memberJoined'"));
    expect(rules, contains("type == 'applicationSubmitted'"));
    expect(rules, contains("type == 'memberLeft'"));
    expect(event, contains('data.commandRevision == recruitment.revision'));
    expect(event, contains("data.type in ['memberLeft', 'memberKicked']"));
    expect(event, contains('!atomicIsLifecycleCommand(recruitment)'));
  });
}
