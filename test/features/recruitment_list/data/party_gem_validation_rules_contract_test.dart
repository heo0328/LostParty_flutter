import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('지원 보석 검증은 최소 필드와 제한된 상태만 허용한다', () {
    final start = rules.indexOf('function validSubmittedBuildSnapshot');
    final end = rules.indexOf('function validPendingApplication', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final contract = rules.substring(start, end);

    for (final field in const [
      'gemValidationStatus',
      'foreignClassGemCount',
      'unverifiedSameClassGemCount',
      'gemValidatedAt',
      'catalogVersion',
    ]) {
      expect(contract, contains("'$field'"));
    }
    for (final forbidden in const ['tooltip', 'rawJson', 'gems']) {
      expect(contract, isNot(contains("'$forbidden'")));
    }
    expect(contract, contains("data.gemValidationStatus == 'foreignClass'"));
    expect(contract, contains('data.gemValidatedAt is timestamp'));
  });

  test('신청 생성과 재신청 모두 Snapshot 계약을 검증한다', () {
    expect(
      'validSubmittedBuildSnapshot(data.submittedBuildSnapshot)'
          .allMatches(rules)
          .length,
      1,
    );
    expect(
      'validSubmittedBuildSnapshot(newData.submittedBuildSnapshot)'
          .allMatches(rules)
          .length,
      1,
    );
  });
}
