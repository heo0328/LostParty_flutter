import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('신규 모집과 슬롯 문서는 점유 원장 버전 및 membership 일치를 요구한다', () {
    final recruitmentStart = rules.indexOf(
      'function validInitialRecruitment',
    );
    final recruitmentEnd = rules.indexOf(
      'function validInitialLeaderMembership',
    );
    final recruitmentRule = rules.substring(recruitmentStart, recruitmentEnd);
    expect(recruitmentRule, contains('data.slotLedgerVersion == 2'));
    expect(rules, contains('match /slots/{slotId}'));
    expect(rules, isNot(contains(r'$(partyIndex)_$(slotIndex)')));
    expect(
      rules,
      contains(
        r'/documents/recruitments/$(recruitmentId)/slots/1_3',
      ),
    );
    expect(rules, contains('member.partyIndex == data.partyIndex'));
    expect(rules, contains('member.slotIndex == data.slotIndex'));
    expect(rules, isNot(contains("'role', 'classNameSnapshot', 'updatedAt'")));
  });

  test('자리 변경은 공대장·revision·최소 슬롯 Claim을 함께 요구한다', () {
    expect(rules, contains('function validPositionRevisionUpdate'));
    expect(rules, contains('function validMemberPositionChange'));
    expect(rules, isNot(contains('function validPartyCompositionForMember')));
    expect(rules, contains('recruitment.leaderPlayerId == currentPlayerId()'));
    expect(rules, contains("get('slotLedgerVersion', 0) != 2"));
    expect(
      rules,
      contains('previousMember.partyIndex != oldData.partyIndex'),
    );
  });
}
