import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;
  late String repository;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
    repository = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_party_cycle_command_repository.dart',
    ).readAsStringSync();
  });

  test('해산 Transaction은 모든 읽기 뒤 v2 슬롯 Claim을 삭제한다', () {
    final start = repository.indexOf(
      'Future<PartyCycleResult> disband(PartyDisbandCommand command)',
    );
    final end = repository.indexOf(
      'Future<PartyCycleResult> purgeStaleOwnAssignment(',
      start,
    );
    final disband = repository.substring(start, end);
    final slotRead = disband.indexOf('final slotSnapshots =');
    final firstWrite = disband.indexOf('transaction.delete(current.reference)');
    final slotDelete = disband.indexOf('transaction.delete(slot.reference)');

    expect(slotRead, greaterThan(0));
    expect(firstWrite, greaterThan(slotRead));
    expect(slotDelete, greaterThan(firstWrite));
    expect(disband, contains("r['slotLedgerVersion'] == 2"));
    expect(disband, contains("slot.data()?['playerId'] != current.id"));
  });

  test('공용 partyEvents Rules는 lifecycle·membership create만 연다', () {
    final start = rules.indexOf('match /partyEvents/{eventId}');
    final end = rules.indexOf('match /recruitments/{recruitmentId}', start);
    final block = rules.substring(start, end);

    expect(block, contains('validAtomicLifecyclePartyEvent('));
    expect(block, contains('validAtomicMembershipPartyEvent('));
    expect(block, isNot(contains('function validPlayerEvent(')));
  });
}
