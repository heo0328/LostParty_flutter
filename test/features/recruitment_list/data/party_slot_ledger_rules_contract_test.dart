import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('신규 모집과 슬롯 문서는 점유 원장 버전 및 membership 일치를 요구한다', () {
    final recruitmentStart = rules.indexOf(
      'function validAtomicInitialRecruitment',
    );
    final recruitmentEnd = rules.indexOf(
      'function validAtomicInitialLeaderMembership',
    );
    final recruitmentRule = rules.substring(recruitmentStart, recruitmentEnd);
    expect(recruitmentRule, contains('data.slotLedgerVersion == 2'));
    expect(recruitmentRule, contains('data.partySlots.size() == 1'));
    expect(rules, contains('match /slots/{slotId}'));
    expect(rules, isNot(contains(r'$(partyIndex)_$(slotIndex)')));
    expect(
      rules,
      contains(
        r'/documents/recruitments/$(recruitmentId)/slots/1_3',
      ),
    );
    expect(rules, contains('atomicInitialPartySlotMatches(slot, playerId, member)'));
  });

  test('자리 변경은 공대장·revision·Aggregate partySlots를 함께 요구한다', () {
    expect(rules, contains('function validAtomicPositionAggregateUpdate'));
    expect(rules, contains('function validMemberPositionChange'));
    expect(rules, isNot(contains('function validPartyCompositionForMember')));
    expect(rules, contains('recruitment.leaderPlayerId == currentPlayerId()'));
    expect(rules, contains('recruitment.slotLedgerVersion == 2'));
    expect(
      rules,
      contains('newData.partyIndex != oldData.partyIndex'),
    );
  });
}
