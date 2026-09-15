import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R4는 schemaVersion 2 원자 생성 검증을 추가하고 v1 생성을 유지한다', () {
    expect(rules, contains('function validAtomicInitialRecruitment('));
    expect(rules, contains('function validInitialRecruitment('));
    expect(rules, contains('|| validAtomicInitialRecruitment('));
    expect(rules, contains('data.schemaVersion == 1'));
    expect(rules, contains('data.schemaVersion == 2'));
  });

  test('R4 원자 생성은 Aggregate·명령 봉투 초기값과 raidState를 검증한다', () {
    final start = rules.indexOf('function validAtomicInitialRecruitment(');
    final end = rules.indexOf('function validGroupRaidListingDelete(');
    final create = rules.substring(start, end);

    expect(create, contains('data.partySlots.size() == 1'));
    expect(create, contains('data.raidStateTargets.size() == 1'));
    expect(create, contains('data.commandTargets.size() == 0'));
    expect(create, contains('data.pendingApplicationCount == 0'));
    expect(create, contains('data.nonGroupMemberCount == (data.groupId == null ? 1 : 0)'));
    expect(create, contains('data.lastCommandId == null'));
    expect(create, contains('getAfter(atomicRaidStatePath(target)).data'));
    expect(create, isNot(contains('getAfter(recruitmentSlotPath(')));
    expect(create, isNot(contains('getAfter(assignmentPath(')));
  });

  test('R4 원자 생성은 leader membership과 partySlots[0]를 맞춘다', () {
    expect(rules, contains('function atomicInitialPartySlotMatches('));
    expect(rules, contains('slot.countedAsNonGroupMember == false'));
    expect(
      rules,
      contains('getAfter(recruitmentMemberPath(recruitmentId, playerId)).data'),
    );
  });
}
