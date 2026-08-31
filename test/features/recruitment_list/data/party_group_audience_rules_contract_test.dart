import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('group raid create and audience read helpers are in Rules', () {
    expect(rules, contains('function canAccessRecruitmentByAudience(data)'));
    expect(rules, contains("data.visibility == 'group'"));
    expect(rules, contains('&& exists(groupMemberPath(data.groupId, playerId))'));
    expect(rules, contains('canAccessRecruitmentByAudience(recruitment)'));
    expect(rules, contains('canAccessRecruitmentByAudience(data)'));
    expect(rules, contains('function canListRecruitment(data)'));
    expect(rules, contains('allow list: if canListRecruitment(resource.data)'));
    expect(rules, contains('allow get: if canGetRecruitment(recruitmentId)'));
    expect(rules, contains('match /raidListings/{recruitmentId}'));
    expect(rules, contains('function validGroupRaidListingCreate('));
    expect(rules, contains('allow get, list: if isCurrentGroupMember(groupId);'));
  });
}
