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
  });
}
