import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('group raid create and audience read helpers are in Rules', () {
    expect(rules, contains('function canAccessRecruitmentByAudience(data)'));
    expect(rules, contains("data.visibility == 'public'"));
    expect(rules, contains("data.visibility == 'group'"));
    expect(rules, contains("&& (data.visibility == 'public'"));
    expect(
      rules,
      contains('&& exists(groupMemberPath(data.groupId, playerId))'),
    );
    expect(rules, contains('canAccessRecruitmentByAudience(recruitment)'));
    expect(rules, contains('canAccessRecruitmentByAudience(data)'));
    expect(rules, contains('function canListRecruitment(data)'));
    expect(rules, contains('allow list: if canListRecruitment(resource.data)'));
    expect(rules, contains('allow get: if canGetRecruitment(recruitmentId)'));
    expect(rules, contains('match /raidListings/{recruitmentId}'));
    expect(rules, contains('function validGroupRaidListingCreate('));
    expect(
      rules,
      contains('data.diff(recruitment).affectedKeys().size() == 0'),
    );
    expect(rules, contains("after.status == 'disbanded'"));
    expect(rules, contains('function validGroupRaidListingBackfill('));
    expect(rules, contains('function validGroupRaidListingDelete('));
    expect(rules, contains('allow update: if validGroupRaidListingCreate('));
    expect(rules, contains('function validRecruitmentVisibilityChange('));
    expect(
      rules,
      contains(
        'allow delete: if validGroupRaidListingDelete(groupId, recruitmentId);',
      ),
    );
    expect(
      rules,
      contains('allow get, list: if isCurrentGroupMember(groupId);'),
    );
    expect(rules, contains('function isLostGroupQualificationCleanup('));
    expect(rules, contains('function removedMemberId(oldIds, newIds)'));
    expect(rules, contains('function removedMemberIdLow(oldIds, kept)'));
    expect(rules, contains('function removedMemberIdHigh(oldIds, kept)'));
  });

  test('firestore.rules 괄호와 중괄호 수가 맞다', () {
    expect('('.allMatches(rules).length, ')'.allMatches(rules).length);
    expect('{'.allMatches(rules).length, '}'.allMatches(rules).length);
    expect(rules, isNot(contains(')))))))))))))))')));
  });
}
