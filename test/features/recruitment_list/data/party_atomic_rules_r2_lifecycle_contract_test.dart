import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R2는 lifecycle 검증을 atomic 접두사로 추가하고 구 cycle·disband를 유지한다', () {
    expect(rules, contains('function validAtomicLifecycleUpdate('));
    expect(rules, contains('function validAtomicRaidStateUpdate('));
    expect(rules, contains('function validAtomicRaidStateDelete('));
    expect(rules, contains('function validAtomicLifecyclePartyEvent('));
    expect(rules, contains('function validAtomicGroupRecruitmentClose('));
    expect(rules, contains('|| validAtomicLifecycleUpdate('));
    expect(rules, contains('function validCycleCompletion('));
    expect(rules, contains('function validRecruitmentDisband('));
    expect(rules, contains('function validGroupDisbandUpdate('));
  });

  test('R2 raidStates는 create를 닫고 lifecycle update·delete만 연다', () {
    final start = rules.indexOf('match /raidStates/{stateId}');
    final end = rules.indexOf('match /characterActivity/{characterId}', start);
    final block = rules.substring(start, end);
    expect(block, contains('allow create: if false'));
    expect(block, contains('validAtomicRaidStateUpdate('));
    expect(block, contains('validAtomicRaidStateDelete('));
  });

  test('R2 partyEvents는 lifecycle create만 연다', () {
    final start = rules.indexOf('match /partyEvents/{eventId}');
    final end = rules.indexOf('match /recruitments/{recruitmentId}', start);
    final block = rules.substring(start, end);
    expect(block, contains('validAtomicLifecyclePartyEvent('));
    expect(block, contains('allow get, list, update, delete: if false'));
  });

  test('R2 listing·group update는 기존 분기와 lifecycle OR를 함께 둔다', () {
    expect(rules, contains('|| validAtomicLifecycleListingUpdate('));
    expect(rules, contains('|| validAtomicLifecycleListingDelete('));
    expect(rules, contains('|| validAtomicGroupRecruitmentClose('));
    expect(rules, contains('function validGroupRaidListingDelete('));
  });
}
