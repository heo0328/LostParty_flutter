import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('클라이언트 분석 보석 요약은 Rules 복잡도에 추가하지 않는다', () {
    expect(rules, isNot(contains('function validSubmittedBuildSnapshot')));
    expect(rules, isNot(contains('function validGemValidationSnapshot')));
    expect(rules, isNot(contains('gemValidationStatus')));
    expect(rules, contains('gemValidationSnapshot'));
    expect(rules, contains('buildIntegritySnapshot'));
  });

  test('파티 캐릭터 변경은 통합 오류 Snapshot만 추가 변경할 수 있다', () {
    final start = rules.indexOf('function validMemberCharacterChange');
    final end = rules.indexOf('\n    function ', start + 1);
    final function = rules.substring(start, end);

    expect(function, contains("'gemValidationSnapshot'"));
    expect(function, contains("'buildIntegritySnapshot'"));
    expect(function, isNot(contains('gemValidationStatus')));
  });
}
