import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R7는 C*에서 떼어낸 legacy validator 본문을 제거한다', () {
    expect(rules, isNot(contains('function validInitialRecruitment(')));
    expect(rules, isNot(contains('function validPlayerEvent(')));
    expect(rules, isNot(contains('function validCycleCompletion(')));
    expect(rules, isNot(contains('function validRecruitmentJoin(')));
    expect(rules, contains('function validAtomicInitialRecruitment('));
    expect(rules, contains('function validAtomicRecruitmentJoin('));
  });

  test('R7 stale raidState delete는 orphan·incompleteEnded도 허용한다', () {
    final start = rules.indexOf('function validAtomicStaleRaidStateDelete(');
    final end = rules.indexOf('function validAtomicInitialLeaderMembership(', start);
    final block = rules.substring(start, end);
    expect(
      block,
      contains("stateId == oldData.characterId + '_' + oldData.raidId"),
    );
    expect(block, contains('!exists(path)'));
    expect(block, contains("recruitment.status == 'incompleteEnded'"));
    expect(rules, contains('function validAtomicStaleRaidStateRecruitment('));
  });

  test('원자 생성은 그룹 activeRecruitmentCount getAfter와 맞춘다', () {
    final start = rules.indexOf('function validAtomicInitialRecruitment(');
    final end = rules.indexOf('function atomicRaidStateTargetAt(', start);
    final create = rules.substring(start, end);
    expect(
      create,
      contains('getAfter(groupPath(data.groupId)).data.activeRecruitmentCount'),
    );
    expect(
      create,
      isNot(contains("data.groupActiveRecruitmentCountAfter\n          == (data.groupId == null ? 0 : 1)")),
    );
  });
}
