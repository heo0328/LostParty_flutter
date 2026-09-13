import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('신규 모집과 슬롯 문서는 점유 원장 버전 및 membership 일치를 요구한다', () {
    expect(rules, contains('data.slotLedgerVersion == 1'));
    expect(rules, contains('match /slots/{slotId}'));
    expect(rules, contains('member.partyIndex == data.partyIndex'));
    expect(rules, contains('member.slotIndex == data.slotIndex'));
    expect(rules, contains('member.role == data.role'));
    expect(
      rules,
      contains('member.classNameSnapshot == data.classNameSnapshot'),
    );
  });

  test('자리 변경은 공대장·revision·서버 파티 구성 검사를 함께 요구한다', () {
    expect(rules, contains('function validPositionRevisionUpdate'));
    expect(rules, contains('function validMemberPositionChange'));
    expect(rules, contains('function validPartyCompositionForMember'));
    expect(rules, contains('recruitment.leaderPlayerId == currentPlayerId()'));
    expect(rules, contains("get('slotLedgerVersion', 0) != 1"));
  });
}
