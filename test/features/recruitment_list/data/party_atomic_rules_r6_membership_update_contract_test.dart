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
    expect(rules, contains('&& validAtomicRecruitmentJoin('));
    expect(rules, isNot(contains('function validRecruitmentJoin(')));
    expect(rules, isNot(contains('function validMembershipRevisionUpdate(')));
    expect(rules, isNot(contains('function validRecruitmentVisibilityChange(')));
  });

  test('R6 membership·raidState·group·listing 동반 OR를 연다', () {
    expect(rules, contains('function validAtomicJoinedMembership('));
    expect(rules, contains('function validAtomicMemberRemoval('));
    expect(rules, contains('function validAtomicMembershipRaidStateDelete('));
    expect(rules, contains('function validAtomicMemberCharacterChange('));
    expect(rules, contains('function validAtomicGroupRecruitmentOpen('));
    expect(rules, contains('function validAtomicVisibilityListingWrite('));
    expect(rules, contains('&& validAtomicJoinedMembership('));
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

    expect(join, contains('atomicRecruitmentJoinShape(oldData, newData)'));
    expect(join, contains('atomicJoinedMemberMatches('));
    expect(rules, contains("member.role in ['dealer', 'support']"));
    expect(rules, contains('member.partyIndex < recruitment.partyCount'));
    expect(rules, contains('member.slotIndex < recruitment.membersPerParty'));
    expect(join, contains('atomicJoinActorAllowed('));
    expect(join, contains('ownsActiveCharacterForPlayer('));
    expect(join, contains('!hasWeeklyRaidCompletionAfter('));
    expect(join, contains('atomicJoinedStateMatches('));
    expect(join, contains('atomicJoinedEventMatches('));
    expect(join, contains('atomicJoinedListingMatches('));
    expect(join, isNot(contains('getAfter(assignmentPath(')));
    expect(join, isNot(contains('getAfter(recruitmentSlotPath(')));
  });

  test('R6 원자 membership은 권위 모집 전이 envelope에만 결합한다', () {
    final start = rules.indexOf('function validAtomicJoinedMembership(');
    final end = rules.indexOf('function validAtomicMemberRemoval(');
    final membership = rules.substring(start, end);

    expect(membership, contains('atomicJoinProjectionEnvelope('));
    expect(membership, isNot(contains('canApproveApplications(')));
    expect(membership, isNot(contains('isCurrentGroupMember(')));
    expect(membership, isNot(contains('ownsActiveCharacterForPlayer(')));
    expect(membership, isNot(contains('atomicRaidStateListedInTargets(')));
    expect(membership, isNot(contains('getAfter(assignmentPath(')));
  });

  test('R6 가입 Projection은 모집 revision과 신규 slot·target을 결합한다', () {
    final start = rules.indexOf('function atomicJoinProjectionEnvelope(');
    final end = rules.indexOf('function validAtomicJoinedMembership(', start);
    final envelope = rules.substring(start, end);

    expect(envelope, contains('after.memberCount == before.memberCount + 1'));
    expect(envelope, contains('after.revision == before.revision + 1'));
    expect(envelope, contains('after.updatedAt == request.time'));
    expect(envelope, contains('after.partySlots[index].playerId == playerId'));
    expect(
      envelope,
      contains('after.raidStateTargets[index].stateId == stateId'),
    );
  });

  test('R6 가입 raidState·event·listing은 빠른 Projection 분기를 먼저 연다', () {
    expect(rules, contains('function validAtomicJoinedRaidStateProjection('));
    expect(rules, contains('function validAtomicJoinedPartyEvent('));
    expect(rules, contains('function validAtomicJoinListingUpdate('));
    expect(
      rules,
      contains('data.diff(recruitment).affectedKeys().size() == 0'),
    );
    expect(
      rules,
      contains("request.resource.data.type == 'memberJoined'\n"
          '        && validAtomicJoinedPartyEvent('),
    );
    expect(
      rules,
      contains('allow update: if validAtomicJoinListingUpdate('),
    );
  });

  test('R5 create는 승인자가 대상 raidState를 만들 수 있다', () {
    final start = rules.indexOf('function validAtomicRaidStateCreate(');
    final end = rules.indexOf('function atomicIsMembershipEventType(');
    final create = rules.substring(start, end);

    expect(create, contains('canApproveApplications(data.recruitmentId)'));
    expect(create, contains('ownsActiveCharacterForPlayer('));
  });
}
