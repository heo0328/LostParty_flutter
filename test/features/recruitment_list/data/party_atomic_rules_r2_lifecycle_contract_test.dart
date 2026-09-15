import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R2는 lifecycle 검증을 atomic 접두사로 추가한다', () {
    expect(rules, contains('function validAtomicLifecycleUpdate('));
    expect(rules, contains('function validAtomicRaidStateUpdate('));
    expect(rules, contains('function validAtomicRaidStateDelete('));
    expect(rules, contains('function validAtomicLifecyclePartyEvent('));
    expect(rules, contains('function validAtomicGroupRecruitmentClose('));
    expect(rules, contains('|| validAtomicLifecycleUpdate('));
    expect(rules, isNot(contains('function validCycleCompletion(')));
    expect(rules, isNot(contains('function validRecruitmentDisband(')));
    expect(rules, contains('function validGroupDisbandUpdate('));
  });

  test('R2 raidStates는 lifecycle update·delete를 연고 create는 R5에 맡긴다', () {
    final start = rules.indexOf('match /raidStates/{stateId}');
    final end = rules.indexOf('match /characterActivity/{characterId}', start);
    final block = rules.substring(start, end);
    expect(block, contains('validAtomicRaidStateUpdate('));
    expect(block, contains('validAtomicRaidStateDelete('));
  });

  test('R2 partyEvents는 lifecycle create를 연다', () {
    final start = rules.indexOf('match /partyEvents/{eventId}');
    final end = rules.indexOf('match /recruitments/{recruitmentId}', start);
    final block = rules.substring(start, end);
    expect(block, contains('validAtomicLifecyclePartyEvent('));
  });

  test('R2 listing·group update는 기존 분기와 lifecycle OR를 함께 둔다', () {
    expect(rules, contains('|| validAtomicLifecycleListingUpdate('));
    expect(rules, contains('|| validAtomicLifecycleListingDelete('));
    expect(rules, contains('|| validAtomicGroupRecruitmentClose('));
    expect(rules, contains('function validGroupRaidListingDelete('));
  });

  test('Close/Open은 lastRecruitmentId 가드 뒤에만 getAfter.data를 본다', () {
    expect(rules, contains('function validAtomicGroupRecruitmentCloseBody('));
    expect(rules, contains('function validAtomicGroupRecruitmentOpenBody('));
    expect(
      rules,
      contains('existsAfter(recruitmentPath(newData.lastRecruitmentId))'),
    );
    expect(rules, contains('newData.lastRecruitmentId is string'));
  });
}
