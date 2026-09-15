import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;
  late String sync;
  late String router;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
    sync = File(
      'lib/features/raid_status/data/services/'
      'firestore_party_event_sync_service.dart',
    ).readAsStringSync();
    router = File('lib/app/router/app_router.dart').readAsStringSync();
  });

  test('C* partyEvents는 audience get/list와 atomic create만 연다', () {
    final start = rules.indexOf('match /partyEvents/{eventId}');
    final end = rules.indexOf('match /recruitments/{recruitmentId}', start);
    final block = rules.substring(start, end);
    expect(
      block,
      contains("resource.data.audiencePlayerIds.hasAny([currentPlayerId()])"),
    );
    expect(block, contains('validAtomicLifecyclePartyEvent('));
    expect(block, contains('validAtomicMembershipPartyEvent('));
    expect(block, contains('allow update, delete: if false'));
  });

  test('C*는 구 assignment·slot·cycle 쓰기와 파티 Claim·개인 event를 닫는다', () {
    final assignment = rules.substring(
      rules.indexOf('match /activeRaidAssignments/{assignmentId}'),
      rules.indexOf('match /events/{eventId}'),
    );
    expect(assignment, contains('allow list, create, update, delete: if false'));
    expect(rules, contains("== 'manualVerificationDisputeOpened'"));
    expect(rules, isNot(contains('|| validPartyOwnerWeeklyRaidClaimCreate(')));
    expect(rules, contains('allow create, update, delete: if false;'));
    expect(rules, contains('function validAtomicInitialLeaderMembership('));
    expect(rules, contains('function validAtomicStaleRaidStateDelete('));
  });

  test('C* 모집 create/update는 atomic·recurrence만 허용한다', () {
    final start = rules.indexOf('match /recruitments/{recruitmentId}');
    final end = rules.indexOf('match /members/{playerId}', start);
    final block = rules.substring(start, end);
    expect(block, contains('allow create: if validAtomicInitialRecruitment('));
    expect(block, isNot(contains('validInitialRecruitment(')));
    expect(block, contains('validRecurrenceChange('));
    expect(block, contains('validAtomicLifecycleUpdate('));
    expect(block, contains('validAtomicRecruitmentJoin('));
    expect(block, isNot(contains('validRecruitmentJoin(')));
    expect(block, isNot(contains('validCycleCompletion(')));
  });

  test('C* sync는 partyEvents audience 쿼리를 사용한다', () {
    expect(sync, contains(".collection('partyEvents')"));
    expect(sync, contains("arrayContains: playerId"));
    expect(sync, contains('mapShared('));
    expect(sync, isNot(contains(".collection('events')")));
  });

  test('C* Router는 원자 Repository와 어댑터를 연결한다', () {
    expect(router, contains('FirestorePartyAtomicCreateRepository'));
    expect(router, contains('PartyAtomicCycleCommandAdapter'));
    expect(router, contains('PartyAtomicMembershipCommandAdapter'));
    expect(router, isNot(contains('FirestorePartyCreateRepository(')));
    expect(router, isNot(contains('FirestorePartyCycleCommandRepository(')));
  });
}
