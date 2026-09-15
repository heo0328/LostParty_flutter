import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R3 그룹 생성은 activeRecruitmentCount 0을 허용·강제한다', () {
    final start = rules.indexOf('function validInitialGroup(');
    final end = rules.indexOf('function validInitialGroupMember(');
    final initialGroupRule = rules.substring(start, end);

    expect(initialGroupRule, contains("'activeRecruitmentCount'"));
    expect(initialGroupRule, contains('data.activeRecruitmentCount == 0'));
    expect(initialGroupRule, isNot(contains("'lastRecruitmentId'")));
  });

  test('R3 close는 활성 수 감소와 affectedKeys만 허용한다', () {
    final start = rules.indexOf('function validAtomicGroupRecruitmentClose(');
    final end = rules.indexOf('function validGroupRaidListingDelete(');
    final close = rules.substring(start, end);

    expect(close, contains('oldData.activeRecruitmentCount is int'));
    expect(close, contains('oldData.activeRecruitmentCount > 0'));
    expect(close, contains('newData.lastRecruitmentId is string'));
    expect(close, contains('existsAfter(recruitmentPath(newData.lastRecruitmentId))'));
    expect(
      close,
      contains(
        "newData.diff(oldData).affectedKeys().hasOnly([\n"
        "          'activeRecruitmentCount', 'lastRecruitmentId',\n"
        "          'revision', 'updatedAt'\n"
        '        ])',
      ),
    );
    expect(
      close,
      contains(
        'newData.activeRecruitmentCount == oldData.activeRecruitmentCount - 1',
      ),
    );
    expect(rules, contains('function validAtomicGroupRecruitmentCloseBody('));
    expect(rules, contains('function validAtomicGroupRecruitmentOpenBody('));
    expect(
      rules,
      contains('existsAfter(recruitmentPath(newData.lastRecruitmentId))'),
    );
  });

  test('R3 group update는 close OR를 유지하고 구 해산 경로를 닫지 않는다', () {
    expect(rules, contains('|| validAtomicGroupRecruitmentClose('));
    expect(rules, contains('function validGroupDisbandUpdate('));
    expect(rules, contains('allow update: if validGroupDisbandUpdate('));
  });
}
