import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String emulatorTest;
  late String groupLifecycleTest;
  late String firebaseConfig;
  late String workflow;

  setUpAll(() {
    emulatorTest = File(
      'tools/party_group_cutover_rules_test.mjs',
    ).readAsStringSync();
    groupLifecycleTest = File(
      'tools/group_leave_rules_test.mjs',
    ).readAsStringSync();
    firebaseConfig = File('firebase.json').readAsStringSync();
    workflow = File(
      '.github/workflows/party-group-cutover-rules.yml',
    ).readAsStringSync();
  });

  test('F1 그룹 수명주기는 이전·기존 그룹장 탈퇴·1인 해산을 고정한다', () {
    expect(groupLifecycleTest, contains('transferLeadershipTransaction'));
    expect(groupLifecycleTest, contains('formerLeaderLeaveTransaction'));
    expect(groupLifecycleTest, contains('disbandSoloGroupTransaction'));
    expect(
      groupLifecycleTest,
      contains('active recruitment blocks solo group disband'),
    );
    expect(workflow, contains('node tools/group_leave_rules_test.mjs'));
  });

  test('전체 추적 Rules 기준선은 그룹·모집 생성 성공과 충돌 거절을 고정한다', () {
    expect(emulatorTest, contains('group create on clean membershipState'));
    expect(emulatorTest, contains('group create with broken membershipState'));
    expect(emulatorTest, contains('group create with empty list membershipState'));
    expect(emulatorTest, contains('public recruitment create clean'));
    expect(emulatorTest, contains('public recruitment with manual weekly claim'));
    expect(emulatorTest, contains('await assertSucceeds'));
    expect(emulatorTest, contains('await assertFails'));
  });

  test('기준선은 운영 배포 없이 demo 프로젝트와 추적 원본만 사용한다', () {
    expect(firebaseConfig, contains('"rules": "firestore.rules"'));
    expect(firebaseConfig, contains('"indexes": "firestore.indexes.json"'));
    expect(workflow, contains('--config firebase.json'));
    expect(workflow, contains('--project demo-party-group-cutover'));
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('--project lost-party')));
    expect(workflow, isNot(contains('firebase deploy')));
  });
}
