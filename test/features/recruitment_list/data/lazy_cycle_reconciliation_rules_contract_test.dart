import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('반복방 직접 승계는 현재 주차 시간 범위만 허용한다', () {
    expect(rules, contains('newData.cycleStartedAt >= oldData.cycleEndsAt'));
    expect(rules, contains('request.time >= newData.cycleStartedAt'));
    expect(rules, contains('request.time < newData.cycleEndsAt'));
  });

  test('반복방은 현재 멤버의 raidState 생성과 회차 갱신만 허용한다', () {
    expect(rules, contains('function validAtomicAdvanceRaidStateCreate('));
    expect(rules, contains('function validAtomicRaidStateUpdate('));
    expect(
      rules,
      contains(
        "newData.diff(oldData).affectedKeys().hasOnly([\n          'status', 'source', 'cycleKey', 'revision', 'completedAt',\n          'updatedAt'",
      ),
    );
    expect(rules, contains('newData.cycleKey == recruitment.currentCycleKey'));
    expect(rules, contains('atomicAdvanceStateMatchesSlot(recruitment, data)'));
  });

  test('다음 주차 생성은 현재 멤버와 정확한 원자 명령 대상만 허용한다', () {
    expect(rules, contains("recruitment.lastCommandType == 'advanceCycle'"));
    expect(rules, contains('data.recruitmentId == recruitment.recruitmentId'));
    expect(
      rules,
      contains('atomicCommandIncludes(recruitment, playerId, stateId)'),
    );
    expect(rules, contains('atomicAdvanceStateMatchesSlot(recruitment, data)'));
  });

  test('회차 승계 raidState도 Character와 raidId canonical 키를 쓴다', () {
    expect(
      RegExp(
        "stateId == data.characterId \\+ '_' \\+ data.raidId",
      ).allMatches(rules).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('구 assignment 신규 쓰기는 닫고 개인 완료에 따른 자기 정리만 허용한다', () {
    expect(
      rules,
      contains('function validLegacyAssignmentConsumedByPersonalCompletion('),
    );
    expect(rules, contains('allow create, update: if false;'));
    expect(
      rules,
      contains(
        'allow delete: if validLegacyAssignmentConsumedByPersonalCompletion(',
      ),
    );
    expect(rules, contains("state.status == 'completed'"));
    expect(rules, contains("state.source == 'manual'"));
    expect(rules, contains('!(playerId in recruitment.memberPlayerIds)'));
  });
}
