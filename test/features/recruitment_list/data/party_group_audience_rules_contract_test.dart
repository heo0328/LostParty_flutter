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
    expect(rules, contains('&& exists(groupMemberPath(data.groupId, playerId))'));
    expect(rules, contains('canAccessRecruitmentByAudience(recruitment)'));
    expect(rules, contains('canAccessRecruitmentByAudience(data)'));
    expect(rules, contains('function canListRecruitment(data)'));
    expect(rules, contains('allow list: if canListRecruitment(resource.data)'));
    expect(rules, contains('allow get: if canGetRecruitment(recruitmentId)'));
    expect(rules, contains('match /raidListings/{recruitmentId}'));
    expect(rules, contains('function validGroupRaidListingCreate('));
    expect(rules, contains('data.diff(recruitment).affectedKeys().size() == 0'));
    expect(rules, contains("after.status == 'disbanded'"));
    expect(rules, contains('function validGroupRaidListingDelete('));
    expect(rules, contains('allow update: if validGroupRaidListingCreate('));
    expect(rules, contains('function validRecruitmentVisibilityChange('));
    expect(rules, contains('allow delete: if validGroupRaidListingDelete(groupId, recruitmentId);'));
    expect(rules, contains('allow get, list: if isCurrentGroupMember(groupId);'));
  });
}
