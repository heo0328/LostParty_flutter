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

  test('R7 stale raidState delete는 stateId를 검증한다', () {
    final start = rules.indexOf('function validAtomicStaleRaidStateDelete(');
    final end = rules.indexOf('function validAtomicInitialLeaderMembership(', start);
    final block = rules.substring(start, end);
    expect(
      block,
      contains("stateId == oldData.characterId + '_' + oldData.raidId"),
    );
  });
}
