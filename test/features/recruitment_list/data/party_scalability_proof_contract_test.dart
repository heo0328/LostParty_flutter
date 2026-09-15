import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String proofRules;
  late String emulatorTest;
  late String emulatorConfig;
  late String workflow;

  setUpAll(() {
    proofRules = File('tools/party_scalability_proof.rules').readAsStringSync();
    emulatorTest = File(
      'tools/party_scalability_rules_test.mjs',
    ).readAsStringSync();
    emulatorConfig = File(
      'tools/party_scalability_firebase.json',
    ).readAsStringSync();
    workflow = File(
      '.github/workflows/party-scalability-proof.yml',
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
    final source = functionSource('targetMatchesTransition', 'allTargetsMatch');

    expect(source.split('getAfter(').length - 1, 1);
    expect(source.split('existsAfter(').length - 1, 1);
    expect(source, isNot(contains('get(bindingPath')));
    expect(source, isNot(contains('/members/')));
    expect(source, isNot(contains('/slots/')));
  });

  test('그룹 모집 종료 검증은 변경 후 그룹 원본만 한 번 읽는다', () {
    final source = functionSource(
      'validGroupLifecycleCount',
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
    expect(emulatorTest, contains('completedDisband: true'));
    expect(emulatorTest, contains('closesActiveRecruitment'));
    expect(emulatorTest, contains('transaction.delete(listingRef)'));
    expect(
      emulatorTest,
      contains('missed active cycle advances without stale state'),
    );
  });

  test('운영 Rules R1 scaffold는 raidStates·partyEvents 경로만 닫힌 채로 둔다', () {
    final productionRules = File('firestore.rules').readAsStringSync();

    expect(productionRules, contains('match /partyEvents/{eventId}'));
    expect(productionRules, contains('match /raidStates/{stateId}'));
    expect(
      productionRules,
      contains('// R1 scaffold: 통합 raidState 경로만 예약한다'),
    );
    expect(
      productionRules,
      contains('// R1 scaffold: 공용 파티 이벤트 경로만 예약한다'),
    );
    expect(productionRules, isNot(contains('function validLifecycleUpdate(')));
    expect(productionRules, isNot(contains('function validRaidStateUpdate(')));
  });

  test('CI 증명은 운영 프로젝트와 운영 Rules를 참조하지 않는다', () {
    expect(emulatorConfig, contains('party_scalability_proof.rules'));
    expect(workflow, contains('--project demo-party-scalability'));
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('--project lost-party')));
    expect(emulatorConfig, isNot(contains('firestore.rules"')));
  });
}
