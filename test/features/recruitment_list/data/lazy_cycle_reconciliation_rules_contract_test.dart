import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('반복방 직접 승계는 현재 주차 시간 범위만 허용한다', () {
    expect(rules, contains('newData.cycleStartedAt >= oldData.cycleEndsAt'));
    expect(rules, contains('request.time >= newData.cycleStartedAt'));
    expect(rules, contains('request.time < newData.cycleEndsAt'));
  });

  test('반복방 assignment 생성과 회차 갱신만 별도 허용한다', () {
    expect(rules, contains('function validCycleAdvanceAssignmentCreate('));
    expect(rules, contains('function validCycleAdvanceAssignmentUpdate('));
    expect(
      rules,
      contains(
        "newData.diff(data).affectedKeys().hasOnly([\n          'cycleKey', 'updatedAt'",
      ),
    );
    expect(rules, contains('newData.cycleKey == after.currentCycleKey'));
  });

  test('1회성 만료 전환은 해당 이전 점유 삭제만 허용한다', () {
    expect(rules, contains('let oneShotCycleAdvanceRemoval ='));
    expect(rules, contains('data.cycleKey == recruitment.currentCycleKey'));
    expect(rules, contains("after.status == 'incompleteEnded'"));
  });

  test('회차 승계 assignment도 Character와 raidId canonical 키를 쓴다', () {
    expect(
      RegExp("assignmentId == data.characterId \\+ '_' \\+ data.raidId")
          .allMatches(rules)
          .length,
      greaterThanOrEqualTo(3),
    );
  });

  test('기존 1회성 미완료 종료 점유만 가입 시 교체할 수 있다', () {
    expect(
      rules,
      contains('function validLegacyIncompleteAssignmentReplacement('),
    );
    expect(rules, contains("oldRecruitment.status == 'incompleteEnded'"));
    expect(
      rules,
      contains("oldRecruitment.currentCycleStatus == 'incompleteEnded'"),
    );
    expect(rules, contains('oldRecruitment.continueTogether == false'));
    expect(rules, contains('data.cycleKey != newData.cycleKey'));
    expect(
      rules,
      contains('validJoinedAssignment(playerId, assignmentId, newData)'),
    );
    expect(
      rules,
      contains('validInitialAssignment(playerId, assignmentId, newData)'),
    );
  });
}
