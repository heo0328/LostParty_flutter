import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String proofRules;
  late String emulatorTest;

  setUpAll(() {
    proofRules = File(
      'tools/party_scalability_proof.rules',
    ).readAsStringSync();
    emulatorTest = File(
      'tools/party_scalability_rules_test.mjs',
    ).readAsStringSync();
  });

  String functionSource(String name, String nextName) {
    final start = proofRules.indexOf('function $name(');
    final end = proofRules.indexOf('function $nextName(', start);
    expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
    expect(end, greaterThan(start), reason: '$nextName must follow $name');
    return proofRules.substring(start, end);
  }

  test('모집 원본은 최대 8개 raidState 결과를 모두 검증한다', () {
    final source = functionSource('allTargetsMatch', 'validLifecycleShape');

    expect(source.split('targetMatchesTransition(').length - 1, 8);
    for (var index = 0; index < 8; index += 1) {
      expect(source, contains('targetMatchesTransition(data, $index)'));
    }
  });

  test('각 대상 검증은 실행 경로당 문서 접근 한 번만 사용한다', () {
    final source = functionSource(
      'targetMatchesTransition',
      'allTargetsMatch',
    );

    expect(source.split('getAfter(').length - 1, 1);
    expect(source.split('existsAfter(').length - 1, 1);
    expect(source, isNot(contains('get(bindingPath')));
    expect(source, isNot(contains('/members/')));
    expect(source, isNot(contains('/slots/')));
  });

  test('그룹 해산 모집 검증은 변경 후 그룹 원본만 한 번 읽는다', () {
    final source = functionSource(
      'validGroupAfterDisband',
      'validLifecycleUpdate',
    );

    expect(source.split('getAfter(groupPath').length - 1, 1);
    expect(source, isNot(contains('get(groupPath')));
  });

  test('Emulator 계약은 1 2 4 8인과 핵심 거절 경로를 포함한다', () {
    expect(emulatorTest, contains('[1, 2, 4, 8]'));
    expect(emulatorTest, contains("'complete'"));
    expect(emulatorTest, contains("'cancelCompletion'"));
    expect(emulatorTest, contains("'advanceCycle'"));
    expect(emulatorTest, contains("'disband'"));
    expect(emulatorTest, contains('{ omitLast: true }'));
    expect(emulatorTest, contains('{ staleRevision: true }'));
    expect(emulatorTest, contains("authenticatedContext('outsider-auth')"));
  });

  test('증명 단계는 운영 Rules와 Router를 변경하지 않는다', () {
    final productionRules = File('firestore.rules').readAsStringSync();

    expect(productionRules, isNot(contains('match /partyEvents/{eventId}')));
    expect(productionRules, isNot(contains('match /raidStates/{stateId}')));
  });
}
