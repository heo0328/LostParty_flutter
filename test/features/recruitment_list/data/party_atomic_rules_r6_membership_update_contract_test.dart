import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R6는 Aggregate 멤버십 update 검증 OR만 연결한다', () {
    expect(rules, contains('function validAtomicPendingApplicationUpdate('));
    expect(rules, contains('function validAtomicRecruitmentJoin('));
    expect(rules, contains('function validAtomicCharacterRevisionUpdate('));
    expect(rules, contains('function validAtomicPositionAggregateUpdate('));
    expect(rules, contains('function validAtomicRecruitmentMemberRemoval('));
    expect(rules, contains('function validAtomicRecruitmentVisibilityChange('));
    expect(rules, contains('|| validAtomicRecruitmentJoin('));
    expect(rules, isNot(contains('function validRecruitmentJoin(')));
    expect(rules, isNot(contains('function validMembershipRevisionUpdate(')));
    expect(
      rules,
      isNot(contains('function validRecruitmentVisibilityChange(')),
    );
  });

  test('R6 membership·raidState·group·listing 동반 OR를 연다', () {
    expect(rules, contains('function validAtomicJoinedMembership('));
    expect(rules, contains('function validAtomicMemberRemoval('));
    expect(rules, contains('function validAtomicMembershipRaidStateDelete('));
    expect(rules, contains('function validAtomicMemberCharacterChange('));
    expect(rules, contains('function validAtomicGroupRecruitmentOpen('));
    expect(rules, contains('function validAtomicVisibilityListingWrite('));
    expect(rules, contains('|| validAtomicJoinedMembership('));
    expect(rules, contains('validAtomicMemberRemoval('));
    expect(rules, contains('|| validAtomicMembershipRaidStateDelete('));
    expect(rules, contains('validAtomicMemberCharacterChange('));
    expect(rules, contains('|| validAtomicGroupRecruitmentOpen('));
    expect(rules, contains('|| validAtomicVisibilityListingWrite('));
  });

  test('R6 원자 가입은 Aggregate 크기와 pending 승인 감소를 검증한다', () {
    final start = rules.indexOf('function validAtomicRecruitmentJoin(');
    final end = rules.indexOf('function validAtomicCharacterRevisionUpdate(');
    final join = rules.substring(start, end);

    expect(join, contains('atomicAggregateSizesMatch(newData)'));
    expect(join, contains("'partySlots', 'raidStateTargets'"));
    expect(join, contains("'pendingApplicationCount'"));
    expect(join, isNot(contains('getAfter(assignmentPath(')));
    expect(join, isNot(contains('getAfter(recruitmentSlotPath(')));
  });

  test('R6 원자 membership은 assignment 대신 raidState를 본다', () {
    final start = rules.indexOf('function validAtomicJoinedMembership(');
    final end = rules.indexOf('function validAtomicMemberRemoval(');
    final membership = rules.substring(start, end);

    expect(membership, contains('before.schemaVersion == 2'));
    expect(membership, contains('atomicRaidStateListedInTargets(after'));
    expect(membership, contains('getAfter(atomicRaidStateDocPath('));
    expect(
      membership,
      contains('exists(groupMemberPath(before.groupId, playerId))'),
    );
    expect(membership, isNot(contains('isCurrentGroupMember(before.groupId)')));
    expect(membership, isNot(contains('getAfter(assignmentPath(')));
  });

  test('R5 create는 승인자가 대상 raidState를 만들 수 있다', () {
    final start = rules.indexOf('function validAtomicRaidStateCreate(');
    final end = rules.indexOf('function atomicIsMembershipEventType(');
    final create = rules.substring(start, end);

    expect(create, contains('canApproveApplications(data.recruitmentId)'));
    expect(create, contains('ownsActiveCharacterForPlayer('));
  });
}
